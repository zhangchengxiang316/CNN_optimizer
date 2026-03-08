// =============================================================================
// weights_bias_fc.v – Fully-Connected Layer Weight and Bias ROM
// -----------------------------------------------------------------------------
// Layer: FC (Fully Connected)
// Weight shape : (2, 288)  → 2 output neurons, 288 input features (flattened)
// Weight count : 2 × 288 = 576 INT8 values
// Bias count   : 2 INT16 values
//
// Weight address: addr = oc * 288 + ic
//   oc ∈ [0, 1], ic ∈ [0, 287]
// Bias address  : addr = oc  (0 .. 1)
//
// The 288 input features are the flattened MaxPool output: 32 channels ×
// 9 rows × 1 column = 288.
//
// NOTE: Values below are PLACEHOLDER pseudo-random weights.
// Replace with QAT-derived INT8/INT16 parameters.
//
// Interface:
//   w_addr  [9:0] → weight address (0 .. 575)
//   w_data   [7:0] → INT8 weight
//   b_addr   [0:0] → bias address (0 .. 1)
//   b_data  [15:0] → INT16 bias
// =============================================================================
module weights_bias_fc (
    input  wire [9:0]  w_addr,
    output wire signed [7:0]  w_data,
    input  wire        b_addr,
    output wire signed [15:0] b_data
);

    reg signed [7:0]  weights [0:575];
    reg signed [15:0] biases  [0:1];

    initial begin : init_weights
        integer i;
        integer x;
        x = 32'h00000004;   // seed = 4
        for (i = 0; i < 576; i = i + 1) begin
            x = (x * 32'd1664525 + 32'd1013904223) & 32'hFFFFFFFF;
            weights[i] = $signed(((x >> 16) % 9) - 4);
        end
        biases[0] = 16'sd0;
        biases[1] = 16'sd0;
    end

    assign w_data = weights[w_addr];
    assign b_data = biases[b_addr];

endmodule
