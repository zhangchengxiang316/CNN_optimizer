// =============================================================================
// tb_cnn_top.v – ModelSim Testbench for CNN Accelerator
// -----------------------------------------------------------------------------
// Simulates one inference pass through the complete CNN pipeline.
//
// Compilation (ModelSim / Questa):
//   vlog -sv pe.v line_buffer.v requantize.v relu.v sigmoid_lut.v \
//              weights_bias_conv1.v weights_bias_conv2.v \
//              weights_bias_conv3.v weights_bias_fc.v input_data.v \
//              conv1.v conv2_dw.v conv3_pw.v maxpool.v fc_layer.v \
//              cnn_top.v tb_cnn_top.v
//   vsim -t 1ns tb_cnn_top
//
// OR use the do-file:  vsim -do "do run_sim.do"
//
// Expected outputs are deterministic (all weights initialised with a fixed LCG
// seed).  The $display lines show the FP32 hex representation of the two
// Sigmoid outputs.
// =============================================================================
`timescale 1ns/1ps

module tb_cnn_top;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg         clk;
    reg         rst_n;
    reg         start;
    wire        done;
    wire [31:0] result0;
    wire [31:0] result1;

    // -------------------------------------------------------------------------
    // Clock: 10 ns period (100 MHz)
    // -------------------------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    cnn_top u_dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (start),
        .done    (done),
        .result0 (result0),
        .result1 (result1)
    );

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    integer cycle_count;

    initial begin
        // Initialise
        rst_n = 1'b0;
        start = 1'b0;
        cycle_count = 0;

        // Hold reset for 4 cycles
        repeat (4) @(posedge clk);
        @(negedge clk) rst_n = 1'b1;

        // One cycle delay then assert start
        @(negedge clk) start = 1'b1;
        @(negedge clk) start = 1'b0;

        $display("[TB] CNN inference started at time %0t ns", $time);

        // Wait for done (with timeout)
        fork
            begin : wait_done
                wait (done === 1'b1);
                $display("[TB] CNN inference done at time %0t ns (cycle %0d)",
                         $time, cycle_count);
                $display("[TB] result0 (class 0 FP32 hex) = 0x%08h", result0);
                $display("[TB] result1 (class 1 FP32 hex) = 0x%08h", result1);
                disable timeout_blk;
            end
            begin : timeout_blk
                repeat (200000) @(posedge clk);
                $display("[TB] TIMEOUT: done not asserted within 200000 cycles");
                disable wait_done;
            end
        join

        // Verify layer intermediate outputs
        $display("--- Spot-check layer outputs ---");
        $display("[TB] Conv1 output_buf[0] = %0d (INT8)",
                 $signed(u_dut.u_conv1.output_buf[0]));
        $display("[TB] Conv1 output_buf[1] = %0d",
                 $signed(u_dut.u_conv1.output_buf[1]));
        $display("[TB] Conv2 output_buf[0] = %0d",
                 $signed(u_dut.u_conv2.output_buf[0]));
        $display("[TB] Conv3 output_buf[0] = %0d",
                 $signed(u_dut.u_conv3.output_buf[0]));
        $display("[TB] Pool  output_buf[0] = %0d",
                 $signed(u_dut.u_pool.output_buf[0]));
        $display("[TB] FC    output_buf[0] = %0d",
                 $signed(u_dut.u_fc.output_buf[0]));
        $display("[TB] FC    output_buf[1] = %0d",
                 $signed(u_dut.u_fc.output_buf[1]));

        // Additional checks
        $display("--- Checking done deasserts after one cycle ---");
        @(posedge clk);
        #1;   // let non-blocking assignments settle before reading done
        if (done === 1'b0)
            $display("[TB] PASS: done deasserted correctly");
        else
            $display("[TB] WARN: done still high (check cnn_top state machine)");

        #20;
        $display("[TB] Simulation complete.");
        $finish;
    end

    // -------------------------------------------------------------------------
    // Cycle counter
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) cycle_count <= 0;
        else        cycle_count <= cycle_count + 1;
    end

    // -------------------------------------------------------------------------
    // Optional: dump waveforms
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("cnn_top_tb.vcd");
        $dumpvars(0, tb_cnn_top);
    end

endmodule
