// =============================================================================
// fc_layer.v – Fully Connected (FC) Layer
// -----------------------------------------------------------------------------
// Operation : Dense matrix-vector multiplication.
// Input     : 288 INT8 values (flattened MaxPool output: 32 ch × 9 × 1)
// Weight    : (2, 288) INT8
// Bias      : 2 × INT16
// Output    : 2 INT8 values (requantised; passed to Sigmoid)
//
// Architecture:
//   2 PEs in parallel (one per output neuron), each accumulating over
//   288 input elements.  Equivalent to the systolic array with 2 PEs.
//
// Input flat addr  : ic  (0..287)
// Output flat addr : oc  (0..1)
// =============================================================================
module fc_layer #(
    parameter C_IN  = 288,
    parameter C_OUT = 2,
    parameter SHIFT = 8
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    output reg         done,
    input  wire signed [7:0] input_buf  [0:C_IN-1],
    output reg  signed [7:0] output_buf [0:C_OUT-1]
);

    // -------------------------------------------------------------------------
    // Local weight and bias arrays (same LCG as weights_bias_fc.v, seed=4)
    // -------------------------------------------------------------------------
    reg signed [7:0]  local_w [0:C_OUT-1][0:C_IN-1];
    reg signed [15:0] local_b [0:C_OUT-1];

    initial begin : load_weights
        integer oc_i, ic_i;
        integer x;
        x = 32'h00000004;
        for (oc_i = 0; oc_i < C_OUT; oc_i = oc_i + 1) begin
            for (ic_i = 0; ic_i < C_IN; ic_i = ic_i + 1) begin
                x = (x * 32'd1664525 + 32'd1013904223) & 32'hFFFFFFFF;
                local_w[oc_i][ic_i] = $signed(((x >> 16) % 9) - 4);
            end
        end
        local_b[0] = 16'sd0;
        local_b[1] = 16'sd0;
    end

    // -------------------------------------------------------------------------
    // 2 PE accumulators
    // -------------------------------------------------------------------------
    reg signed [31:0] pe_acc [0:C_OUT-1];

    // -------------------------------------------------------------------------
    // State machine
    // -------------------------------------------------------------------------
    localparam ST_IDLE  = 2'd0,
               ST_MAC   = 2'd1,
               ST_STORE = 2'd2,
               ST_DONE  = 2'd3;

    reg [1:0]  state;
    reg [8:0]  ic;      // input channel counter (0..287)
    reg [1:0]  oc_s;    // output channel for STORE (0..1)

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE; done <= 1'b0;
            ic <= 9'd0; oc_s <= 2'd0;
            for (i = 0; i < C_OUT; i = i + 1) pe_acc[i] <= 32'sd0;
        end else begin
            case (state)

            ST_IDLE: begin
                done <= 1'b0;
                if (start) begin
                    ic   <= 9'd0;
                    for (i = 0; i < C_OUT; i = i + 1) pe_acc[i] <= 32'sd0;
                    state <= ST_MAC;
                end
            end

            // Both output neurons accumulate in parallel for each input
            ST_MAC: begin
                for (i = 0; i < C_OUT; i = i + 1)
                    pe_acc[i] <= pe_acc[i] + input_buf[ic] * local_w[i][ic];

                if (ic == C_IN - 1) begin
                    ic    <= 9'd0;
                    oc_s  <= 2'd0;
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

                output_buf[oc_s] <= quant;

                if (oc_s == C_OUT - 1) begin
                    state <= ST_DONE;
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
