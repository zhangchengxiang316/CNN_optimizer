// =============================================================================
// conv3_pw.v – Conv3 Pointwise (1×1) Convolution Layer
// -----------------------------------------------------------------------------
// Operation : Pointwise (1×1) convolution.
//             Equivalent to a fully-connected operation applied at each
//             spatial location independently.
// Input     : (C_IN=32, H=18, W=2)  INT8
// Kernel    : (C_OUT=32, C_IN=32, 1, 1)  INT8
// Bias      : 32 × INT16
// Output    : (C_OUT=32, H=18, W=2)  INT8  (requant; no activation here)
//
// The 32-PE systolic design computes all 32 output channels for one spatial
// position in parallel.  It iterates over 32 input channels per output
// position (32 MAC cycles), then advances to the next position.
//
// Input flat addr  : ic * (H * W) + h * W + w
// Output flat addr : oc * (H * W) + h * W + w
// =============================================================================
module conv3_pw #(
    parameter C_IN   = 32,
    parameter C_OUT  = 32,
    parameter H      = 18,
    parameter W      = 2,
    parameter SHIFT  = 8
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    output reg         done,
    input  wire [C_IN*H*W*8-1:0]   input_buf,
    output reg  [C_OUT*H*W*8-1:0]  output_buf
);

    // -------------------------------------------------------------------------
    // Local weight array: local_w[oc][ic] – same LCG as weights_bias_conv3.v
    // -------------------------------------------------------------------------
    reg signed [7:0]  local_w [0:C_OUT-1][0:C_IN-1];
    reg signed [15:0] local_b [0:C_OUT-1];

    initial begin : load_weights
        integer oc_i, ic_i;
        integer x;
        x = 32'h00000003;
        for (oc_i = 0; oc_i < C_OUT; oc_i = oc_i + 1) begin
            for (ic_i = 0; ic_i < C_IN; ic_i = ic_i + 1) begin
                x = (x * 32'd1664525 + 32'd1013904223) & 32'hFFFFFFFF;
                local_w[oc_i][ic_i] = $signed(((x >> 16) % 9) - 4);
            end
        end
        for (oc_i = 0; oc_i < C_OUT; oc_i = oc_i + 1)
            local_b[oc_i] = 16'sd0;
    end

    // -------------------------------------------------------------------------
    // 32 PE accumulators
    // -------------------------------------------------------------------------
    reg signed [31:0] pe_acc [0:C_OUT-1];

    // -------------------------------------------------------------------------
    // State machine
    // -------------------------------------------------------------------------
    localparam ST_IDLE  = 3'd0,
               ST_CLEAR = 3'd1,
               ST_MAC   = 3'd2,
               ST_STORE = 3'd3,
               ST_DONE  = 3'd4;

    reg [2:0] state;
    reg [4:0] oh;      // spatial row (0..H-1=17)
    reg [1:0] ow;      // spatial col (0..W-1=1)
    reg [5:0] ic;      // input channel (0..C_IN-1=31)
    reg [5:0] oc_s;    // output channel counter for STORE (0..C_OUT-1=31)

    // Input pixel broadcast during MAC: all 32 OCs see the same ic-pixel
    wire signed [7:0] mac_pixel = $signed(input_buf[(ic * (H * W) + oh * W + ow) * 8 +: 8]);

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE; done <= 1'b0;
            oh <= 5'd0; ow <= 2'd0; ic <= 6'd0; oc_s <= 6'd0;
            for (i = 0; i < C_OUT; i = i + 1) pe_acc[i] <= 32'sd0;
        end else begin
            case (state)

            ST_IDLE: begin
                done <= 1'b0;
                if (start) begin
                    oh <= 5'd0; ow <= 2'd0;
                    state <= ST_CLEAR;
                end
            end

            ST_CLEAR: begin
                for (i = 0; i < C_OUT; i = i + 1) pe_acc[i] <= 32'sd0;
                ic    <= 6'd0;
                state <= ST_MAC;
            end

            // All 32 OC accumulators updated in parallel each cycle
            ST_MAC: begin
                for (i = 0; i < C_OUT; i = i + 1)
                    pe_acc[i] <= pe_acc[i] + mac_pixel * local_w[i][ic];

                if (ic == C_IN - 1) begin
                    ic    <= 6'd0;
                    oc_s  <= 6'd0;
                    state <= ST_STORE;
                end else begin
                    ic <= ic + 1;
                end
            end

            ST_STORE: begin : store_blk
                reg signed [31:0] biased;
                reg signed [31:0] shifted;
                reg signed [7:0]  quant;

                biased  = pe_acc[oc_s] + {{16{local_b[oc_s][15]}}, local_b[oc_s]};
                shifted = biased >>> SHIFT;

                if      (shifted > 32'sd127)  quant = 8'sd127;
                else if (shifted < -32'sd128) quant = -8'sd128;
                else                          quant = shifted[7:0];

                // No activation after Conv3 (activation is implicit via MaxPool + FC)
                output_buf[(oc_s * (H * W) + oh * W + ow) * 8 +: 8] <= quant;

                if (oc_s == C_OUT - 1) begin
                    oc_s <= 6'd0;
                    if (ow == W - 1) begin
                        ow <= 2'd0;
                        if (oh == H - 1) begin
                            state <= ST_DONE;
                        end else begin
                            oh    <= oh + 1;
                            state <= ST_CLEAR;
                        end
                    end else begin
                        ow    <= ow + 1;
                        state <= ST_CLEAR;
                    end
                end else begin
                    oc_s <= oc_s + 1;
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
