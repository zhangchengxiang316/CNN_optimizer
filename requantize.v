// =============================================================================
// requantize.v – INT32 → INT8 Re-quantization
// -----------------------------------------------------------------------------
// Converts a 32-bit accumulator value (with bias added) back to INT8 range
// according to a fixed-point scale factor implemented as an arithmetic
// right-shift.
//
// Formula:
//   shifted = (acc_in + sign_extend(bias_in)) >>> SHIFT
//   out      = clamp(shifted, -128, 127)
//
// The SHIFT parameter encodes the scale factor: scale = 2^(-SHIFT).
// Typical value: SHIFT = 8 (scale ≈ 0.0039).
// Replace SHIFT with the per-layer quantization-aware training scale.
// =============================================================================
module requantize #(
    parameter SHIFT = 8   // right-shift amount (adjust per layer after QAT)
) (
    input  wire signed [31:0] acc_in,    // INT32 accumulator
    input  wire signed [15:0] bias_in,   // INT16 bias
    output reg  signed [7:0]  data_out   // INT8 output
);

    wire signed [31:0] biased  = acc_in + {{16{bias_in[15]}}, bias_in};
    wire signed [31:0] shifted = biased >>> SHIFT;

    always @(*) begin
        if      (shifted > 32'sd127)  data_out = 8'sd127;
        else if (shifted < -32'sd128) data_out = -8'sd128;
        else                          data_out = shifted[7:0];
    end

endmodule
