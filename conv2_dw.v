// =============================================================================
// conv2_dw.v – Conv2 Depthwise Separable Convolution (DW part)
// -----------------------------------------------------------------------------
// Operation : Depthwise convolution – each input channel is convolved with its
//             own 3×3 kernel independently (no cross-channel mixing).
// Input     : (C=32, H_IN=20, W_IN=4)  INT8
// Kernel    : (C=32, depth=1, KH=3, KW=3)  INT8
// Bias      : 32 × INT16
// Output    : (C=32, H_OUT=18, W_OUT=2)  INT8  (requant + ReLU = Act2 merged)
//
// Architecture:
//   For each channel ch=0..31 and output position (oh, ow):
//     acc = sum over (kh, kw): input[ch][oh+kh][ow+kw] * weight[ch][kh*3+kw]
//     output[ch][oh][ow] = ReLU(requant(acc + bias[ch]))
//
// Input buffer : reads from input_buf[ch][h][w]
//   Flat addr  : ch * H_IN * W_IN + h * W_IN + w
//
// State machine: nested loop over ch, oh, ow; MAC over 9 elements.
// =============================================================================
module conv2_dw #(
    parameter C      = 32,
    parameter H_IN   = 20,
    parameter W_IN   = 4,
    parameter KH     = 3,
    parameter KW     = 3,
    parameter H_OUT  = 18,     // = H_IN - KH + 1
    parameter W_OUT  = 2,      // = W_IN - KW + 1
    parameter K_SIZE = 9,      // = KH * KW
    parameter SHIFT  = 8
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    output reg         done,
    // Input from previous layer (Conv1 output = Act1 output)
    input  wire signed [7:0] input_buf  [0:C*H_IN*W_IN-1],
    // Output feature map
    output reg  signed [7:0] output_buf [0:C*H_OUT*W_OUT-1]
);

    // -------------------------------------------------------------------------
    // Local weight and bias arrays (same LCG as weights_bias_conv2.v, seed=2)
    // -------------------------------------------------------------------------
    reg signed [7:0]  local_w [0:C-1][0:K_SIZE-1]; // [ch][kh*3+kw]
    reg signed [15:0] local_b [0:C-1];

    initial begin : load_weights
        integer ch_i, k_i;
        integer x;
        x = 32'h00000002;
        for (ch_i = 0; ch_i < C; ch_i = ch_i + 1) begin
            for (k_i = 0; k_i < K_SIZE; k_i = k_i + 1) begin
                x = (x * 32'd1664525 + 32'd1013904223) & 32'hFFFFFFFF;
                local_w[ch_i][k_i] = $signed(((x >> 16) % 9) - 4);
            end
        end
        for (ch_i = 0; ch_i < C; ch_i = ch_i + 1)
            local_b[ch_i] = 16'sd0;
    end

    // -------------------------------------------------------------------------
    // State machine
    // -------------------------------------------------------------------------
    localparam ST_IDLE  = 2'd0,
               ST_MAC   = 2'd1,
               ST_STORE = 2'd2,
               ST_DONE  = 2'd3;

    reg [1:0] state;

    reg [5:0] ch;      // channel (0..31)
    reg [4:0] oh;      // output row (0..17)
    reg [1:0] ow;      // output col (0..1)
    reg [3:0] k_cnt;   // kernel index (0..8)

    reg signed [31:0] acc;

    // Current pixel during MAC
    wire [2:0] kh_cur = k_cnt / KW;
    wire [1:0] kw_cur = k_cnt % KW;
    wire signed [7:0] mac_pixel =
        input_buf[ch * (H_IN * W_IN) + (oh + kh_cur) * W_IN + (ow + kw_cur)];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            done  <= 1'b0;
            ch    <= 6'd0; oh <= 5'd0; ow <= 2'd0; k_cnt <= 4'd0;
            acc   <= 32'sd0;
        end else begin
            case (state)

            ST_IDLE: begin
                done <= 1'b0;
                if (start) begin
                    ch <= 6'd0; oh <= 5'd0; ow <= 2'd0;
                    k_cnt <= 4'd0; acc <= 32'sd0;
                    state <= ST_MAC;
                end
            end

            ST_MAC: begin
                acc <= acc + mac_pixel * local_w[ch][k_cnt];
                if (k_cnt == K_SIZE - 1) begin
                    k_cnt <= 4'd0;
                    state <= ST_STORE;
                end else begin
                    k_cnt <= k_cnt + 1;
                end
            end

            ST_STORE: begin : store_blk
                reg signed [31:0] biased;
                reg signed [31:0] shifted;
                reg signed [7:0]  quant;

                biased  = acc + {{16{local_b[ch][15]}}, local_b[ch]};
                shifted = biased >>> SHIFT;

                if      (shifted > 32'sd127)  quant = 8'sd127;
                else if (shifted < -32'sd128) quant = -8'sd128;
                else                          quant = shifted[7:0];

                // ReLU (Act2 merged)
                output_buf[ch * (H_OUT * W_OUT) + oh * W_OUT + ow]
                    <= quant[7] ? 8'sd0 : quant;

                acc <= 32'sd0;

                // Advance position: ow → oh → ch
                if (ow == W_OUT - 1) begin
                    ow <= 2'd0;
                    if (oh == H_OUT - 1) begin
                        oh <= 5'd0;
                        if (ch == C - 1) begin
                            state <= ST_DONE;
                        end else begin
                            ch    <= ch + 1;
                            state <= ST_MAC;
                        end
                    end else begin
                        oh    <= oh + 1;
                        state <= ST_MAC;
                    end
                end else begin
                    ow    <= ow + 1;
                    state <= ST_MAC;
                end
            end

            ST_DONE: begin
                done  <= 1'b1;
                state <= ST_IDLE;
            end
            endcase
        end
    end

endmodule
