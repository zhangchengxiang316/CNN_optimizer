// =============================================================================
// maxpool.v – MaxPool Layer (2×2, stride=2)
// -----------------------------------------------------------------------------
// Operation : 2-D max pooling, kernel 2×2, stride 2, no padding.
// Input     : (C=32, H_IN=18, W_IN=2)  INT8
// Output    : (C=32, H_OUT=9, W_OUT=1)  INT8
//
// For each channel ch and output position (oh, ow):
//   output[ch][oh][ow] = max(input[ch][2*oh+i][2*ow+j]) for i,j in {0,1}
//
// Input flat addr  : ch * (H_IN * W_IN) + h * W_IN + w
// Output flat addr : ch * (H_OUT * W_OUT) + oh * W_OUT + ow
// =============================================================================
module maxpool #(
    parameter C      = 32,
    parameter H_IN   = 18,
    parameter W_IN   = 2,
    parameter KH     = 2,
    parameter KW     = 2,
    parameter STRIDE = 2,
    parameter H_OUT  = 9,    // = H_IN / STRIDE
    parameter W_OUT  = 1     // = W_IN / STRIDE
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    output reg         done,
    input  wire [C*H_IN*W_IN*8-1:0]   input_buf,
    output reg  [C*H_OUT*W_OUT*8-1:0] output_buf
);

    localparam ST_IDLE = 2'd0,
               ST_POOL = 2'd1,
               ST_DONE = 2'd2;

    reg [1:0] state;
    reg [5:0] ch;     // channel (0..31)
    reg [3:0] oh;     // output row (0..8)
    reg [0:0] ow;     // output col (0..0)
    reg [1:0] ki;     // pool kernel index (0..3 = kh*2+kw)

    reg signed [7:0] cur_max;

    wire [1:0] kh_cur = ki[1];   // 0 or 1 (kernel row)
    wire [0:0] kw_cur = ki[0];   // 0 or 1 (kernel col)
    wire signed [7:0] pool_pixel =
        $signed(input_buf[(ch * (H_IN * W_IN) +
                  (oh * STRIDE + kh_cur) * W_IN +
                  (ow * STRIDE + kw_cur)) * 8 +: 8]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE; done <= 1'b0;
            ch <= 6'd0; oh <= 4'd0; ow <= 1'd0; ki <= 2'd0;
            cur_max <= 8'sh80;  // -128 (smallest INT8)
        end else begin
            case (state)

            ST_IDLE: begin
                done <= 1'b0;
                if (start) begin
                    ch <= 6'd0; oh <= 4'd0; ow <= 1'd0; ki <= 2'd0;
                    cur_max <= 8'sh80;
                    state   <= ST_POOL;
                end
            end

            ST_POOL: begin
                // Update running max
                if ($signed(pool_pixel) > $signed(cur_max))
                    cur_max <= pool_pixel;

                if (ki == KH * KW - 1) begin
                    // Save max result (pool_pixel is the last of 4; compare with running max)
                    output_buf[(ch * (H_OUT * W_OUT) + oh * W_OUT + ow) * 8 +: 8]
                        <= ($signed(pool_pixel) > $signed(cur_max))
                           ? pool_pixel : cur_max;

                    ki      <= 2'd0;
                    cur_max <= 8'sh80;

                    // Advance position
                    if (ow == W_OUT - 1) begin
                        ow <= 1'd0;
                        if (oh == H_OUT - 1) begin
                            oh <= 4'd0;
                            if (ch == C - 1) begin
                                state <= ST_DONE;
                            end else begin
                                ch    <= ch + 1;
                            end
                        end else begin
                            oh <= oh + 1;
                        end
                    end else begin
                        ow <= ow + 1;
                    end
                end else begin
                    ki <= ki + 1;
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
