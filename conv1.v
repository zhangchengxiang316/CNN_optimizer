// =============================================================================
// conv1.v – Conv1 Regular Convolution Layer with 32-PE Systolic Array
// -----------------------------------------------------------------------------
// Operation : Regular 2-D convolution, valid padding, stride = 1
// Input     : (C_IN=1, H_IN=30, W_IN=10)  INT8
// Kernel    : (C_OUT=32, C_IN=1, KH=11, KW=7)  INT8
// Bias      : 32 × INT16
// Output    : (C_OUT=32, H_OUT=20, W_OUT=4)  INT8 (requant + ReLU / Act1 merged)
//
// Architecture:
//   Line Buffer : internal row_mem[0:KH-1][0:W_IN-1] stores last KH=11 rows.
//     row_mem[0]     = most recently received row (newest)
//     row_mem[KH-1]  = oldest buffered row
//
//   Systolic Array (32 PEs in parallel):
//     K_SIZE=77 cycles per output position; each cycle ALL 32 PEs receive
//     the same broadcast input pixel and multiply by their own weight.
//     local_w[oc][k_cnt] = weight for output channel oc, kernel element k_cnt.
//
//   Re-quantisation + ReLU applied in 32 sequential store cycles.
//
// State machine:
//   IDLE  → FEED (load initial KH rows, pixel by pixel)
//         → CLEAR → MAC → STORE → FEED (1 new row) → CLEAR → ...
//         → DONE
//
// Row_mem window extraction for output (oh, ow):
//   kernel (kh, kw): input row = oh + kh → row_mem index = KH-1-kh
//   (constant regardless of oh since row_mem always holds the latest KH rows)
//
// Output memory (flat, channel-major):
//   addr = oc * (H_OUT * W_OUT) + oh * W_OUT + ow  →  Total = 2560 bytes
// =============================================================================
module conv1 #(
    parameter C_IN   = 1,
    parameter H_IN   = 30,
    parameter W_IN   = 10,
    parameter C_OUT  = 32,
    parameter KH     = 11,
    parameter KW     = 7,
    parameter H_OUT  = 20,     // = H_IN - KH + 1
    parameter W_OUT  = 4,      // = W_IN - KW + 1
    parameter K_SIZE = 77,     // = KH * KW
    parameter SHIFT  = 8       // re-quantisation right-shift
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    output reg         done,
    output reg [C_OUT*H_OUT*W_OUT*8-1:0] output_buf
);

    // -------------------------------------------------------------------------
    // Local weight array: same LCG as weights_bias_conv1.v (seed=1)
    // Replace these values with actual QAT-trained INT8 weights.
    // -------------------------------------------------------------------------
    reg signed [7:0]  local_w [0:C_OUT-1][0:K_SIZE-1];
    reg signed [15:0] local_b [0:C_OUT-1];

    initial begin : load_weights
        integer oc_i, k_i;
        integer x;
        x = 32'h00000001;
        for (oc_i = 0; oc_i < C_OUT; oc_i = oc_i + 1)
            for (k_i = 0; k_i < K_SIZE; k_i = k_i + 1) begin
                x = (x * 32'd1664525 + 32'd1013904223) & 32'hFFFFFFFF;
                local_w[oc_i][k_i] = $signed(((x >> 16) % 9) - 4);
            end
        for (oc_i = 0; oc_i < C_OUT; oc_i = oc_i + 1)
            local_b[oc_i] = 16'sd0;
    end

    // -------------------------------------------------------------------------
    // Input data ROM
    // -------------------------------------------------------------------------
    reg  [8:0]  in_addr;
    wire signed [7:0] in_data;
    input_data u_in (.addr(in_addr), .data_out(in_data));

    // -------------------------------------------------------------------------
    // Line buffer: row_mem[0] = newest row, row_mem[KH-1] = oldest
    // cur_row: staging register for the row currently being streamed in
    // -------------------------------------------------------------------------
    reg signed [7:0]  row_mem [0:KH-1][0:W_IN-1];
    reg signed [7:0]  cur_row [0:W_IN-1];

    // -------------------------------------------------------------------------
    // 32 PE accumulators (INT32)
    // -------------------------------------------------------------------------
    reg signed [31:0] pe_acc [0:C_OUT-1];

    // -------------------------------------------------------------------------
    // State machine
    // -------------------------------------------------------------------------
    localparam ST_IDLE  = 3'd0,
               ST_FEED  = 3'd1,   // stream input pixels into line buffer
               ST_CLEAR = 3'd2,   // zero PE accumulators
               ST_MAC   = 3'd3,   // K_SIZE-cycle parallel MAC
               ST_STORE = 3'd4,   // apply bias/requant/ReLU, save 32 outputs
               ST_DONE  = 3'd5;

    reg [2:0] state;

    reg [3:0] wcol;       // column write pointer (0..W_IN-1)
    reg [3:0] rows_cnt;   // complete rows buffered (0..KH, saturates at KH)
    reg [4:0] oh;         // current output row (0..H_OUT-1 = 19)
    reg [2:0] ow;         // current output col (0..W_OUT-1 = 3)
    reg [6:0] k_cnt;      // kernel element index (0..K_SIZE-1 = 76)
    reg [5:0] oc_s;       // output channel counter in STORE (0..31)

    // Broadcast pixel for the current MAC step
    // k_cnt encodes kh*KW + kw; we index row_mem as [KH-1-kh][ow+kw]
    wire [3:0] kh_cur = k_cnt[6:0] / KW;   // 0..10
    wire [2:0] kw_cur = k_cnt[6:0] % KW;   // 0..6
    wire signed [7:0] mac_pixel = row_mem[KH-1-kh_cur][ow + kw_cur];

    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= ST_IDLE;
            done      <= 1'b0;
            wcol      <= 4'd0;
            rows_cnt  <= 4'd0;
            oh        <= 5'd0;
            ow        <= 3'd0;
            k_cnt     <= 7'd0;
            oc_s      <= 6'd0;
            in_addr   <= 9'd0;
            for (i = 0; i < C_OUT;  i = i + 1) pe_acc[i]     <= 32'sd0;
            for (i = 0; i < KH;     i = i + 1)
                for (j = 0; j < W_IN; j = j + 1) row_mem[i][j] <= 8'sd0;
            for (i = 0; i < W_IN;   i = i + 1) cur_row[i]    <= 8'sd0;
        end else begin
            case (state)

            // -----------------------------------------------------------------
            ST_IDLE: begin
                done <= 1'b0;
                if (start) begin
                    wcol     <= 4'd0;
                    rows_cnt <= 4'd0;
                    in_addr  <= 9'd0;
                    state    <= ST_FEED;
                end
            end

            // -----------------------------------------------------------------
            // FEED: stream pixels from input ROM into the line buffer.
            // Pixels arrive one per cycle at in_data (combinatorial on in_addr).
            // Each cycle we store in_data and advance in_addr.
            // When a complete row (W_IN pixels) has been stored, shift row_mem.
            // Transition rule:
            //   - rows_cnt >= KH-1 after this row: have KH rows → go to CLEAR
            //   - rows_cnt <  KH-1: need more rows → stay in FEED
            // -----------------------------------------------------------------
            ST_FEED: begin
                if (wcol == W_IN - 1) begin
                    // -----------------------------------------------------------
                    // Row complete: shift row_mem down and insert new row at [0]
                    // -----------------------------------------------------------
                    for (i = KH-1; i > 0; i = i - 1)
                        for (j = 0; j < W_IN; j = j + 1)
                            row_mem[i][j] <= row_mem[i-1][j];
                    // New row[0]: pixels 0..W_IN-2 from staging, last from in_data
                    for (j = 0; j < W_IN-1; j = j + 1)
                        row_mem[0][j] <= cur_row[j];
                    row_mem[0][W_IN-1] <= in_data;

                    wcol     <= 4'd0;
                    in_addr  <= in_addr + 1;

                    // Count rows (saturates at KH)
                    if (rows_cnt < KH) rows_cnt <= rows_cnt + 1;

                    // Transition: only start computing when KH rows are ready.
                    // rows_cnt is the OLD value (NB assignment above not yet applied).
                    //   rows_cnt == KH-1: completing the KH-th row → go to CLEAR
                    //   rows_cnt >= KH:   loading subsequent rows → go to CLEAR
                    //   rows_cnt <  KH-1: still need more rows → stay in FEED
                    if (rows_cnt >= KH - 1)
                        state <= ST_CLEAR;
                    // else: remain in ST_FEED
                end else begin
                    cur_row[wcol] <= in_data;
                    wcol          <= wcol + 1;
                    in_addr       <= in_addr + 1;
                end
            end

            // -----------------------------------------------------------------
            // CLEAR: zero all PE accumulators for new output position
            // -----------------------------------------------------------------
            ST_CLEAR: begin
                for (i = 0; i < C_OUT; i = i + 1)
                    pe_acc[i] <= 32'sd0;
                k_cnt <= 7'd0;
                state <= ST_MAC;
            end

            // -----------------------------------------------------------------
            // MAC: K_SIZE=77 cycles.
            // All 32 PEs accumulate mac_pixel × local_w[oc][k_cnt] in parallel.
            // -----------------------------------------------------------------
            ST_MAC: begin
                for (i = 0; i < C_OUT; i = i + 1)
                    pe_acc[i] <= pe_acc[i] + mac_pixel * local_w[i][k_cnt];

                if (k_cnt == K_SIZE - 1) begin
                    k_cnt <= 7'd0;
                    oc_s  <= 6'd0;
                    state <= ST_STORE;
                end else
                    k_cnt <= k_cnt + 1;
            end

            // -----------------------------------------------------------------
            // STORE: C_OUT=32 cycles – bias + requantise + ReLU (Act1 merged)
            // -----------------------------------------------------------------
            ST_STORE: begin : store_blk
                reg signed [31:0] biased;
                reg signed [31:0] shifted;
                reg signed [7:0]  quant;

                biased  = pe_acc[oc_s] + {{16{local_b[oc_s][15]}}, local_b[oc_s]};
                shifted = biased >>> SHIFT;

                if      (shifted > 32'sd127)  quant = 8'sd127;
                else if (shifted < -32'sd128) quant = -8'sd128;
                else                          quant = shifted[7:0];

                // ReLU (Act1 merged)
                output_buf[(oc_s * (H_OUT * W_OUT) + oh * W_OUT + ow) * 8 +: 8]
                    <= quant[7] ? 8'sd0 : quant;

                if (oc_s == C_OUT - 1) begin
                    oc_s <= 6'd0;
                    // Advance window: ow first, then oh
                    if (ow == W_OUT - 1) begin
                        ow <= 3'd0;
                        if (oh == H_OUT - 1) begin
                            state <= ST_DONE;
                        end else begin
                            oh    <= oh + 1;
                            state <= ST_FEED;  // load next input row
                        end
                    end else begin
                        ow    <= ow + 1;
                        state <= ST_CLEAR;
                    end
                end else
                    oc_s <= oc_s + 1;
            end

            // -----------------------------------------------------------------
            ST_DONE: begin
                done  <= 1'b1;
                state <= ST_IDLE;
            end

            default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
