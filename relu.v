// =============================================================================
// relu.v – ReLU Activation (INT8)
// -----------------------------------------------------------------------------
// output = max(0, input)
// For INT8 signed values the sign bit is bit 7.
// =============================================================================
module relu (
    input  wire signed [7:0] data_in,
    output wire signed [7:0] data_out
);
    // If sign bit is set (negative), output zero; otherwise pass through.
    assign data_out = data_in[7] ? 8'sd0 : data_in;

endmodule
