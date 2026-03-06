// =============================================================================
// pe.v – Processing Element for Systolic Array
// -----------------------------------------------------------------------------
// Each PE performs a signed 8×8 multiply-accumulate:
//   acc = acc + signed(data_in) × signed(weight_in)
//
// Usage inside systolic array:
//   - clear   : reset accumulator to 0 before a new window/output channel
//   - en      : enable MAC operation on the current clock edge
//   - acc_out : INT32 partial sum, read after all kernel elements are done
// =============================================================================
module pe (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        clear,        // synchronous clear of accumulator
    input  wire        en,           // enable MAC this cycle
    input  wire signed [7:0]  data_in,    // INT8 input pixel / feature
    input  wire signed [7:0]  weight_in,  // INT8 weight
    output reg  signed [31:0] acc_out     // INT32 accumulator
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            acc_out <= 32'sd0;
        else if (clear)
            acc_out <= 32'sd0;
        else if (en)
            acc_out <= acc_out + (data_in * weight_in);
    end

endmodule
