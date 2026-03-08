# CNN_optimizer

基于脉动阵列的 INT8 量化 CNN 硬件加速器（Verilog 实现，支持 ModelSim 仿真）。

## 项目简介

本项目针对**高性能应用场景**（Speed = 1000K 输入特征图/秒），实现了一条轻量语音分类 CNN 的完整硬件推理流水线。输入为 MFCC 特征图（1×30×10），输出两个类别的 Sigmoid 概率。

## 快速开始（ModelSim）

```tcl
do run_sim.do
```

## 文件列表

| 文件 | 说明 |
|------|------|
| `pe.v` | 处理单元（MAC） |
| `line_buffer.v` | 11 行行缓存 |
| `requantize.v` | INT32 → INT8 重量化 |
| `relu.v` | ReLU 激活 |
| `sigmoid_lut.v` | Sigmoid 查找表（INT8 → FP32） |
| `input_data.v` | 输入特征图 ROM |
| `weights_bias_conv1/2/3/fc.v` | 各层权重 & 偏置 ROM |
| `conv1.v` | Conv1 + Act1（11×7 卷积 + ReLU） |
| `conv2_dw.v` | Conv2 深度卷积 + Act2 |
| `conv3_pw.v` | Conv3 逐点卷积 |
| `maxpool.v` | 2×2 最大池化 |
| `fc_layer.v` | 全连接层 |
| `cnn_top.v` | 顶层流水线 |
| `tb_cnn_top.v` | ModelSim 仿真测试台 |
| `run_sim.do` | 一键仿真脚本 |

## 架构详解

👉 **[点击查看各层原理图解（中文，面向初学者）](ARCHITECTURE.md)**

文档包含：
- 每层的直观类比与 ASCII 示意图
- 脉动阵列、行缓存、重量化的原理解释
- 完整数据流表格与计算量估算
- 如何替换真实训练权重的指南