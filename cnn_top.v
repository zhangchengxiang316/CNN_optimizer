// =============================================================================
// cnn_top.v – Top-Level CNN Accelerator Module
// -----------------------------------------------------------------------------
// Network topology:
//   Conv1 (1×11×7) + Act1 (ReLU) → Conv2 DW (3×3) + Act2 (ReLU)
//   → Conv3 PW (1×1) → MaxPool (2×2 s=2) → FC → Sigmoid
//
// Layer I/O tensor sizes:
//   Input          : (1, 30, 10)    = 300  INT8
//   Conv1+Act1 out : (32, 20, 4)   = 2560 INT8
//   Conv2+Act2 out : (32, 18, 2)   = 1152 INT8
//   Conv3 out      : (32, 18, 2)   = 1152 INT8
//   MaxPool out    : (32, 9, 1)    =  288 INT8  (= FC input, flattened)
//   FC out         : (2)           =    2 INT8
//   Sigmoid out    : (2)           =    2 FP32
//
// Control:
//   start    : pulse high for one cycle to begin inference
//   done     : asserted when sigmoid outputs are valid (held until next start)
//   result0  : FP32 sigmoid output for class 0
//   result1  : FP32 sigmoid output for class 1
//
// Dataflow:
//   The layers are chained sequentially.  Each layer's done signal triggers
//   the next layer's start signal (one-cycle pipeline stage).
// =============================================================================
module cnn_top (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    output reg         done,
    output reg  [31:0] result0,   // FP32 sigmoid output, class 0
    output reg  [31:0] result1    // FP32 sigmoid output, class 1
);

    // -------------------------------------------------------------------------
    // Inter-layer buffers
    // -------------------------------------------------------------------------
    // Conv1 output (= Act1 output)  (32, 20, 4)
    wire signed [7:0] conv1_out [0:32*20*4-1];
    // Conv2 DW output (= Act2 output)  (32, 18, 2)
    wire signed [7:0] conv2_out [0:32*18*2-1];
    // Conv3 PW output  (32, 18, 2)
    wire signed [7:0] conv3_out [0:32*18*2-1];
    // MaxPool output  (32, 9, 1)
    wire signed [7:0] pool_out  [0:32*9*1-1];
    // FC output  (2)
    wire signed [7:0] fc_out    [0:1];

    // -------------------------------------------------------------------------
    // Done / start pipeline
    // -------------------------------------------------------------------------
    wire conv1_done, conv2_done, conv3_done, pool_done, fc_done;
    reg  conv2_start, conv3_start, pool_start, fc_start;

    // Pipeline: each done pulse is used as start for the next layer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            conv2_start <= 1'b0;
            conv3_start <= 1'b0;
            pool_start  <= 1'b0;
            fc_start    <= 1'b0;
            done        <= 1'b0;
            result0     <= 32'd0;
            result1     <= 32'd0;
        end else begin
            // Default: deassert start pulses
            conv2_start <= 1'b0;
            conv3_start <= 1'b0;
            pool_start  <= 1'b0;
            fc_start    <= 1'b0;
            done        <= 1'b0;

            if (conv1_done) conv2_start <= 1'b1;
            if (conv2_done) conv3_start <= 1'b1;
            if (conv3_done) pool_start  <= 1'b1;
            if (pool_done)  fc_start    <= 1'b1;
            if (fc_done) begin
                // Apply sigmoid and signal done
                result0 <= sig_out0;
                result1 <= sig_out1;
                done    <= 1'b1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Sigmoid LUT for both FC outputs
    // -------------------------------------------------------------------------
    wire [31:0] sig_out0, sig_out1;
    sigmoid_lut u_sig0 (.data_in(fc_out[0]), .data_out(sig_out0));
    sigmoid_lut u_sig1 (.data_in(fc_out[1]), .data_out(sig_out1));

    // -------------------------------------------------------------------------
    // Layer instantiations
    // -------------------------------------------------------------------------

    // Conv1 + Act1 (ReLU merged inside conv1)
    conv1 u_conv1 (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (start),
        .done       (conv1_done),
        .output_buf (conv1_out)
    );

    // Conv2 DW + Act2 (ReLU merged inside conv2_dw)
    conv2_dw u_conv2 (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (conv2_start),
        .done       (conv2_done),
        .input_buf  (conv1_out),
        .output_buf (conv2_out)
    );

    // Conv3 PW
    conv3_pw u_conv3 (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (conv3_start),
        .done       (conv3_done),
        .input_buf  (conv2_out),
        .output_buf (conv3_out)
    );

    // MaxPool
    maxpool u_pool (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (pool_start),
        .done       (pool_done),
        .input_buf  (conv3_out),
        .output_buf (pool_out)
    );

    // FC
    fc_layer u_fc (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (fc_start),
        .done       (fc_done),
        .input_buf  (pool_out),
        .output_buf (fc_out)
    );

endmodule
