// =============================================================================
// weights_bias_conv3.v – Conv3 Pointwise (PW) Layer Weight and Bias ROM
// -----------------------------------------------------------------------------
// Layer: Conv3 – Pointwise Convolution (1×1 convolution)
// Kernel shape : (32, 32, 1, 1)  → 32 output channels, 32 input channels
// Weight count : 32 × 32 = 1024 INT8 values
// Bias count   : 32 INT16 values
//
// Weight address: addr = oc * 32 + ic
//   oc ∈ [0, 31], ic ∈ [0, 31]
// Bias address  : addr = oc  (0 .. 31)
//
// NOTE: Values below are PLACEHOLDER pseudo-random weights.
// Replace with QAT-derived INT8/INT16 parameters.
//
// Interface:
//   w_addr  [9:0] → weight address (0 .. 1023)
//   w_data   [7:0] → INT8 weight
//   b_addr   [4:0] → bias address (0 .. 31)
//   b_data  [15:0] → INT16 bias
// =============================================================================
module weights_bias_conv3 (
    input  wire [9:0]  w_addr,
    output wire signed [7:0]  w_data,
    input  wire [4:0]  b_addr,
    output wire signed [15:0] b_data
);

    reg signed [7:0]  weights [0:1023];
    reg signed [15:0] biases  [0:31];

    initial begin : init_weights
        integer i;
        integer x;
        x = 32'h00000003;   // seed = 3
        for (i = 0; i < 1024; i = i + 1) begin
            x = (x * 32'd1664525 + 32'd1013904223) & 32'hFFFFFFFF;
            weights[i] = $signed(((x >> 16) % 9) - 4);
        end
        for (i = 0; i < 32; i = i + 1)
            biases[i] = 16'sd0;
    end

    assign w_data = weights[w_addr];
    assign b_data = biases[b_addr];

endmodule
