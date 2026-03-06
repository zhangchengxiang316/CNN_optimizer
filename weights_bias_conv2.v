// =============================================================================
// weights_bias_conv2.v – Conv2 Depthwise (DW) Layer Weight and Bias ROM
// -----------------------------------------------------------------------------
// Layer: Conv2 – Depthwise Separable Convolution (DW part)
// Kernel shape : (32, 1, 3, 3)  → 32 channels, depth 1, 3×3 kernel
// Weight count : 32 × 1 × 3 × 3 = 288 INT8 values
// Bias count   : 32 INT16 values
//
// Weight address: addr = ch * 9 + kh * 3 + kw
//   ch ∈ [0, 31], kh ∈ [0, 2], kw ∈ [0, 2]
// Bias address  : addr = ch  (0 .. 31)
//
// NOTE: Values below are PLACEHOLDER pseudo-random weights.
// Replace with QAT-derived INT8/INT16 parameters.
//
// Interface:
//   w_addr  [8:0] → weight address (0 .. 287)
//   w_data   [7:0] → INT8 weight
//   b_addr   [4:0] → bias address (0 .. 31)
//   b_data  [15:0] → INT16 bias
// =============================================================================
module weights_bias_conv2 (
    input  wire [8:0]  w_addr,
    output wire signed [7:0]  w_data,
    input  wire [4:0]  b_addr,
    output wire signed [15:0] b_data
);

    reg signed [7:0]  weights [0:287];
    reg signed [15:0] biases  [0:31];

    initial begin : init_weights
        integer i;
        integer x;
        x = 32'h00000002;   // seed = 2 (different from Conv1)
        for (i = 0; i < 288; i = i + 1) begin
            x = (x * 32'd1664525 + 32'd1013904223) & 32'hFFFFFFFF;
            weights[i] = $signed(((x >> 16) % 9) - 4);
        end
        for (i = 0; i < 32; i = i + 1)
            biases[i] = 16'sd0;
    end

    assign w_data = weights[w_addr];
    assign b_data = biases[b_addr];

endmodule
