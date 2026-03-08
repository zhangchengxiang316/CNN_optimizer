# =============================================================================
# run_sim.do – ModelSim/Questa simulation script for CNN Accelerator
# =============================================================================
# Usage:
#   1. Open ModelSim
#   2. cd to the directory containing these .v files
#   3. do run_sim.do
# OR from command line:
#   vsim -c -do run_sim.do
# =============================================================================

# Create and map a work library
vlib work
vmap work work

# Compile all source files (Verilog-2001 compatible; -sv is optional)
# Files can also be compiled individually, e.g.: vlog -work work conv1.v
vlog -work work \
    pe.v \
    line_buffer.v \
    requantize.v \
    relu.v \
    sigmoid_lut.v \
    weights_bias_conv1.v \
    weights_bias_conv2.v \
    weights_bias_conv3.v \
    weights_bias_fc.v \
    input_data.v \
    conv1.v \
    conv2_dw.v \
    conv3_pw.v \
    maxpool.v \
    fc_layer.v \
    cnn_top.v \
    tb_cnn_top.v

# Start simulation
vsim -t 1ns -novopt work.tb_cnn_top

# Add key waveforms
add wave -divider "Control"
add wave -radix binary   /tb_cnn_top/clk
add wave -radix binary   /tb_cnn_top/rst_n
add wave -radix binary   /tb_cnn_top/start
add wave -radix binary   /tb_cnn_top/done
add wave -divider "Results (FP32 hex)"
add wave -radix hex      /tb_cnn_top/result0
add wave -radix hex      /tb_cnn_top/result1
add wave -divider "Conv1 state"
add wave -radix unsigned /tb_cnn_top/u_dut/u_conv1/state
add wave -radix unsigned /tb_cnn_top/u_dut/u_conv1/oh
add wave -radix unsigned /tb_cnn_top/u_dut/u_conv1/ow
add wave -radix unsigned /tb_cnn_top/u_dut/u_conv1/k_cnt
add wave -divider "Conv2 DW state"
add wave -radix unsigned /tb_cnn_top/u_dut/u_conv2/state
add wave -divider "Conv3 PW state"
add wave -radix unsigned /tb_cnn_top/u_dut/u_conv3/state
add wave -divider "MaxPool state"
add wave -radix unsigned /tb_cnn_top/u_dut/u_pool/state
add wave -divider "FC state"
add wave -radix unsigned /tb_cnn_top/u_dut/u_fc/state

# Run for a long time (adjust if simulation is too slow)
run 2000us

wave zoom full
