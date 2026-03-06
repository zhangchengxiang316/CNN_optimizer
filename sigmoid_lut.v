// =============================================================================
// sigmoid_lut.v – Sigmoid Activation via 256-entry Lookup Table
// -----------------------------------------------------------------------------
// Converts an INT8 input value to an IEEE-754 single-precision FP32 output.
//
// Scale convention: each INT8 unit represents 1/32 of the real pre-sigmoid
// value.  The 256-entry LUT covers the input range [-4.0, +3.969] (step 1/32),
// which captures the full dynamic range of the sigmoid function.
//
// Addressing:
//   addr = data_in interpreted as unsigned 8-bit index.
//   0..127  → positive inputs  0.000 ..  3.969
//   128..255 → negative inputs -4.000 .. -0.031
//
// Output: data_out[31:0] is the IEEE-754 FP32 sigmoid value.
// =============================================================================
module sigmoid_lut (
    input  wire [7:0]  data_in,    // INT8 input (signed, used as LUT index)
    output wire [31:0] data_out    // FP32 output
);

    reg [31:0] lut [0:255];

    initial begin
        // ---- Positive inputs (0 .. 127) → sigmoid(0.000) .. sigmoid(3.969) ----
        lut[8'd  0] = 32'h3F000000; // sigmoid(0.000) = 0.50000
        lut[8'd  1] = 32'h3F01FFF5; // sigmoid(0.031) = 0.50781
        lut[8'd  2] = 32'h3F03FFAB; // sigmoid(0.062) = 0.51562
        lut[8'd  3] = 32'h3F05FEE0; // sigmoid(0.094) = 0.52342
        lut[8'd  4] = 32'h3F07FD56; // sigmoid(0.125) = 0.53121
        lut[8'd  5] = 32'h3F09FACE; // sigmoid(0.156) = 0.53898
        lut[8'd  6] = 32'h3F0BF708; // sigmoid(0.188) = 0.54674
        lut[8'd  7] = 32'h3F0DF1C7; // sigmoid(0.219) = 0.55447
        lut[8'd  8] = 32'h3F0FEACD; // sigmoid(0.250) = 0.56218
        lut[8'd  9] = 32'h3F11E1DD; // sigmoid(0.281) = 0.56985
        lut[8'd 10] = 32'h3F13D6BC; // sigmoid(0.312) = 0.57750
        lut[8'd 11] = 32'h3F15C930; // sigmoid(0.344) = 0.58510
        lut[8'd 12] = 32'h3F17B900; // sigmoid(0.375) = 0.59267
        lut[8'd 13] = 32'h3F19A5F2; // sigmoid(0.406) = 0.60019
        lut[8'd 14] = 32'h3F1B8FD0; // sigmoid(0.438) = 0.60766
        lut[8'd 15] = 32'h3F1D7666; // sigmoid(0.469) = 0.61509
        lut[8'd 16] = 32'h3F1F597F; // sigmoid(0.500) = 0.62246
        lut[8'd 17] = 32'h3F2138E9; // sigmoid(0.531) = 0.62977
        lut[8'd 18] = 32'h3F231473; // sigmoid(0.562) = 0.63703
        lut[8'd 19] = 32'h3F24EBF0; // sigmoid(0.594) = 0.64423
        lut[8'd 20] = 32'h3F26BF31; // sigmoid(0.625) = 0.65135
        lut[8'd 21] = 32'h3F288E0D; // sigmoid(0.656) = 0.65842
        lut[8'd 22] = 32'h3F2A5859; // sigmoid(0.688) = 0.66541
        lut[8'd 23] = 32'h3F2C1DEE; // sigmoid(0.719) = 0.67233
        lut[8'd 24] = 32'h3F2DDEA8; // sigmoid(0.750) = 0.67918
        lut[8'd 25] = 32'h3F2F9A62; // sigmoid(0.781) = 0.68595
        lut[8'd 26] = 32'h3F3150FC; // sigmoid(0.812) = 0.69264
        lut[8'd 27] = 32'h3F330256; // sigmoid(0.844) = 0.69925
        lut[8'd 28] = 32'h3F34AE54; // sigmoid(0.875) = 0.70579
        lut[8'd 29] = 32'h3F3654D9; // sigmoid(0.906) = 0.71223
        lut[8'd 30] = 32'h3F37F5CD; // sigmoid(0.938) = 0.71859
        lut[8'd 31] = 32'h3F399119; // sigmoid(0.969) = 0.72487
        lut[8'd 32] = 32'h3F3B26A8; // sigmoid(1.000) = 0.73106
        lut[8'd 33] = 32'h3F3CB666; // sigmoid(1.031) = 0.73716
        lut[8'd 34] = 32'h3F3E4042; // sigmoid(1.062) = 0.74317
        lut[8'd 35] = 32'h3F3FC42E; // sigmoid(1.094) = 0.74909
        lut[8'd 36] = 32'h3F41421C; // sigmoid(1.125) = 0.75491
        lut[8'd 37] = 32'h3F42BA00; // sigmoid(1.156) = 0.76065
        lut[8'd 38] = 32'h3F442BD2; // sigmoid(1.188) = 0.76629
        lut[8'd 39] = 32'h3F459789; // sigmoid(1.219) = 0.77184
        lut[8'd 40] = 32'h3F46FD20; // sigmoid(1.250) = 0.77730
        lut[8'd 41] = 32'h3F485C91; // sigmoid(1.281) = 0.78266
        lut[8'd 42] = 32'h3F49B5DC; // sigmoid(1.312) = 0.78793
        lut[8'd 43] = 32'h3F4B08FE; // sigmoid(1.344) = 0.79311
        lut[8'd 44] = 32'h3F4C55F8; // sigmoid(1.375) = 0.79819
        lut[8'd 45] = 32'h3F4D9CCC; // sigmoid(1.406) = 0.80317
        lut[8'd 46] = 32'h3F4EDD7E; // sigmoid(1.438) = 0.80807
        lut[8'd 47] = 32'h3F501813; // sigmoid(1.469) = 0.81287
        lut[8'd 48] = 32'h3F514C90; // sigmoid(1.500) = 0.81757
        lut[8'd 49] = 32'h3F527AFD; // sigmoid(1.531) = 0.82219
        lut[8'd 50] = 32'h3F53A362; // sigmoid(1.562) = 0.82671
        lut[8'd 51] = 32'h3F54C5CA; // sigmoid(1.594) = 0.83114
        lut[8'd 52] = 32'h3F55E240; // sigmoid(1.625) = 0.83548
        lut[8'd 53] = 32'h3F56F8CE; // sigmoid(1.656) = 0.83973
        lut[8'd 54] = 32'h3F580982; // sigmoid(1.688) = 0.84390
        lut[8'd 55] = 32'h3F59146A; // sigmoid(1.719) = 0.84797
        lut[8'd 56] = 32'h3F5A1994; // sigmoid(1.750) = 0.85195
        lut[8'd 57] = 32'h3F5B1910; // sigmoid(1.781) = 0.85585
        lut[8'd 58] = 32'h3F5C12EC; // sigmoid(1.812) = 0.85966
        lut[8'd 59] = 32'h3F5D073C; // sigmoid(1.844) = 0.86339
        lut[8'd 60] = 32'h3F5DF60E; // sigmoid(1.875) = 0.86704
        lut[8'd 61] = 32'h3F5EDF76; // sigmoid(1.906) = 0.87060
        lut[8'd 62] = 32'h3F5FC387; // sigmoid(1.938) = 0.87408
        lut[8'd 63] = 32'h3F60A252; // sigmoid(1.969) = 0.87748
        lut[8'd 64] = 32'h3F617BEB; // sigmoid(2.000) = 0.88080
        lut[8'd 65] = 32'h3F625066; // sigmoid(2.031) = 0.88404
        lut[8'd 66] = 32'h3F631FD7; // sigmoid(2.062) = 0.88720
        lut[8'd 67] = 32'h3F63EA53; // sigmoid(2.094) = 0.89029
        lut[8'd 68] = 32'h3F64AFED; // sigmoid(2.125) = 0.89331
        lut[8'd 69] = 32'h3F6570BB; // sigmoid(2.156) = 0.89625
        lut[8'd 70] = 32'h3F662CD2; // sigmoid(2.188) = 0.89912
        lut[8'd 71] = 32'h3F66E446; // sigmoid(2.219) = 0.90192
        lut[8'd 72] = 32'h3F67972D; // sigmoid(2.250) = 0.90465
        lut[8'd 73] = 32'h3F68459D; // sigmoid(2.281) = 0.90731
        lut[8'd 74] = 32'h3F68EFAA; // sigmoid(2.312) = 0.90991
        lut[8'd 75] = 32'h3F69956B; // sigmoid(2.344) = 0.91244
        lut[8'd 76] = 32'h3F6A36F3; // sigmoid(2.375) = 0.91490
        lut[8'd 77] = 32'h3F6AD459; // sigmoid(2.406) = 0.91730
        lut[8'd 78] = 32'h3F6B6DB1; // sigmoid(2.438) = 0.91964
        lut[8'd 79] = 32'h3F6C0312; // sigmoid(2.469) = 0.92192
        lut[8'd 80] = 32'h3F6C948F; // sigmoid(2.500) = 0.92414
        lut[8'd 81] = 32'h3F6D223E; // sigmoid(2.531) = 0.92630
        lut[8'd 82] = 32'h3F6DAC33; // sigmoid(2.562) = 0.92841
        lut[8'd 83] = 32'h3F6E3283; // sigmoid(2.594) = 0.93046
        lut[8'd 84] = 32'h3F6EB543; // sigmoid(2.625) = 0.93245
        lut[8'd 85] = 32'h3F6F3485; // sigmoid(2.656) = 0.93440
        lut[8'd 86] = 32'h3F6FB060; // sigmoid(2.688) = 0.93629
        lut[8'd 87] = 32'h3F7028E5; // sigmoid(2.719) = 0.93812
        lut[8'd 88] = 32'h3F709E29; // sigmoid(2.750) = 0.93991
        lut[8'd 89] = 32'h3F71103F; // sigmoid(2.781) = 0.94165
        lut[8'd 90] = 32'h3F717F3A; // sigmoid(2.812) = 0.94335
        lut[8'd 91] = 32'h3F71EB2C; // sigmoid(2.844) = 0.94499
        lut[8'd 92] = 32'h3F725429; // sigmoid(2.875) = 0.94660
        lut[8'd 93] = 32'h3F72BA41; // sigmoid(2.906) = 0.94815
        lut[8'd 94] = 32'h3F731D88; // sigmoid(2.938) = 0.94967
        lut[8'd 95] = 32'h3F737E0E; // sigmoid(2.969) = 0.95114
        lut[8'd 96] = 32'h3F73DBE6; // sigmoid(3.000) = 0.95257
        lut[8'd 97] = 32'h3F74371F; // sigmoid(3.031) = 0.95397
        lut[8'd 98] = 32'h3F748FCB; // sigmoid(3.062) = 0.95532
        lut[8'd 99] = 32'h3F74E5FB; // sigmoid(3.094) = 0.95663
        lut[8'd100] = 32'h3F7539BD; // sigmoid(3.125) = 0.95791
        lut[8'd101] = 32'h3F758B23; // sigmoid(3.156) = 0.95915
        lut[8'd102] = 32'h3F75DA3B; // sigmoid(3.188) = 0.96036
        lut[8'd103] = 32'h3F762714; // sigmoid(3.219) = 0.96153
        lut[8'd104] = 32'h3F7671BF; // sigmoid(3.250) = 0.96267
        lut[8'd105] = 32'h3F76BA48; // sigmoid(3.281) = 0.96378
        lut[8'd106] = 32'h3F7700BF; // sigmoid(3.312) = 0.96486
        lut[8'd107] = 32'h3F774532; // sigmoid(3.344) = 0.96590
        lut[8'd108] = 32'h3F7787AD; // sigmoid(3.375) = 0.96691
        lut[8'd109] = 32'h3F77C840; // sigmoid(3.406) = 0.96790
        lut[8'd110] = 32'h3F7806F5; // sigmoid(3.438) = 0.96886
        lut[8'd111] = 32'h3F7843DB; // sigmoid(3.469) = 0.96979
        lut[8'd112] = 32'h3F787EFE; // sigmoid(3.500) = 0.97069
        lut[8'd113] = 32'h3F78B86B; // sigmoid(3.531) = 0.97156
        lut[8'd114] = 32'h3F78F02C; // sigmoid(3.562) = 0.97241
        lut[8'd115] = 32'h3F79264E; // sigmoid(3.594) = 0.97324
        lut[8'd116] = 32'h3F795ADC; // sigmoid(3.625) = 0.97404
        lut[8'd117] = 32'h3F798DE1; // sigmoid(3.656) = 0.97482
        lut[8'd118] = 32'h3F79BF69; // sigmoid(3.688) = 0.97558
        lut[8'd119] = 32'h3F79EF7D; // sigmoid(3.719) = 0.97631
        lut[8'd120] = 32'h3F7A1E28; // sigmoid(3.750) = 0.97702
        lut[8'd121] = 32'h3F7A4B74; // sigmoid(3.781) = 0.97771
        lut[8'd122] = 32'h3F7A776B; // sigmoid(3.812) = 0.97838
        lut[8'd123] = 32'h3F7AA216; // sigmoid(3.844) = 0.97904
        lut[8'd124] = 32'h3F7ACB80; // sigmoid(3.875) = 0.97967
        lut[8'd125] = 32'h3F7AF3B0; // sigmoid(3.906) = 0.98028
        lut[8'd126] = 32'h3F7B1AB0; // sigmoid(3.938) = 0.98088
        lut[8'd127] = 32'h3F7B4088; // sigmoid(3.969) = 0.98145
        // ---- Negative inputs (128 .. 255) → sigmoid(-4.000) .. sigmoid(-0.031) ----
        lut[8'd128] = 32'h3C9357D1; // sigmoid(-4.000) = 0.01799
        lut[8'd129] = 32'h3C97EEF7; // sigmoid(-3.969) = 0.01855
        lut[8'd130] = 32'h3C9CAA03; // sigmoid(-3.938) = 0.01912
        lut[8'd131] = 32'h3CA18A02; // sigmoid(-3.906) = 0.01972
        lut[8'd132] = 32'h3CA69009; // sigmoid(-3.875) = 0.02033
        lut[8'd133] = 32'h3CABBD33; // sigmoid(-3.844) = 0.02096
        lut[8'd134] = 32'h3CB112A3; // sigmoid(-3.812) = 0.02162
        lut[8'd135] = 32'h3CB69185; // sigmoid(-3.781) = 0.02229
        lut[8'd136] = 32'h3CBC3B0A; // sigmoid(-3.750) = 0.02298
        lut[8'd137] = 32'h3CC2106C; // sigmoid(-3.719) = 0.02369
        lut[8'd138] = 32'h3CC812EF; // sigmoid(-3.688) = 0.02442
        lut[8'd139] = 32'h3CCE43DC; // sigmoid(-3.656) = 0.02518
        lut[8'd140] = 32'h3CD4A486; // sigmoid(-3.625) = 0.02596
        lut[8'd141] = 32'h3CDB3649; // sigmoid(-3.594) = 0.02676
        lut[8'd142] = 32'h3CE1FA88; // sigmoid(-3.562) = 0.02759
        lut[8'd143] = 32'h3CE8F2AF; // sigmoid(-3.531) = 0.02844
        lut[8'd144] = 32'h3CF02034; // sigmoid(-3.500) = 0.02931
        lut[8'd145] = 32'h3CF78495; // sigmoid(-3.469) = 0.03021
        lut[8'd146] = 32'h3CFF2159; // sigmoid(-3.438) = 0.03114
        lut[8'd147] = 32'h3D037C08; // sigmoid(-3.406) = 0.03210
        lut[8'd148] = 32'h3D07852A; // sigmoid(-3.375) = 0.03309
        lut[8'd149] = 32'h3D0BACE3; // sigmoid(-3.344) = 0.03410
        lut[8'd150] = 32'h3D0FF40B; // sigmoid(-3.312) = 0.03514
        lut[8'd151] = 32'h3D145B7B; // sigmoid(-3.281) = 0.03622
        lut[8'd152] = 32'h3D18E414; // sigmoid(-3.250) = 0.03733
        lut[8'd153] = 32'h3D1D8EBA; // sigmoid(-3.219) = 0.03847
        lut[8'd154] = 32'h3D225C56; // sigmoid(-3.188) = 0.03964
        lut[8'd155] = 32'h3D274DD6; // sigmoid(-3.156) = 0.04085
        lut[8'd156] = 32'h3D2C642E; // sigmoid(-3.125) = 0.04209
        lut[8'd157] = 32'h3D31A056; // sigmoid(-3.094) = 0.04337
        lut[8'd158] = 32'h3D37034A; // sigmoid(-3.062) = 0.04468
        lut[8'd159] = 32'h3D3C8E0C; // sigmoid(-3.031) = 0.04603
        lut[8'd160] = 32'h3D4241A2; // sigmoid(-3.000) = 0.04743
        lut[8'd161] = 32'h3D481F18; // sigmoid(-2.969) = 0.04886
        lut[8'd162] = 32'h3D4E277E; // sigmoid(-2.938) = 0.05033
        lut[8'd163] = 32'h3D545BE9; // sigmoid(-2.906) = 0.05185
        lut[8'd164] = 32'h3D5ABD73; // sigmoid(-2.875) = 0.05340
        lut[8'd165] = 32'h3D614D3A; // sigmoid(-2.844) = 0.05501
        lut[8'd166] = 32'h3D680C60; // sigmoid(-2.812) = 0.05665
        lut[8'd167] = 32'h3D6EFC0C; // sigmoid(-2.781) = 0.05835
        lut[8'd168] = 32'h3D761D6B; // sigmoid(-2.750) = 0.06009
        lut[8'd169] = 32'h3D7D71AC; // sigmoid(-2.719) = 0.06188
        lut[8'd170] = 32'h3D827D02; // sigmoid(-2.688) = 0.06371
        lut[8'd171] = 32'h3D865BD4; // sigmoid(-2.656) = 0.06560
        lut[8'd172] = 32'h3D8A55EB; // sigmoid(-2.625) = 0.06755
        lut[8'd173] = 32'h3D8E6BE7; // sigmoid(-2.594) = 0.06954
        lut[8'd174] = 32'h3D929E68; // sigmoid(-2.562) = 0.07159
        lut[8'd175] = 32'h3D96EE12; // sigmoid(-2.531) = 0.07370
        lut[8'd176] = 32'h3D9B5B89; // sigmoid(-2.500) = 0.07586
        lut[8'd177] = 32'h3D9FE772; // sigmoid(-2.469) = 0.07808
        lut[8'd178] = 32'h3DA49275; // sigmoid(-2.438) = 0.08036
        lut[8'd179] = 32'h3DA95D39; // sigmoid(-2.406) = 0.08270
        lut[8'd180] = 32'h3DAE4868; // sigmoid(-2.375) = 0.08510
        lut[8'd181] = 32'h3DB354AC; // sigmoid(-2.344) = 0.08756
        lut[8'd182] = 32'h3DB882AD; // sigmoid(-2.312) = 0.09009
        lut[8'd183] = 32'h3DBDD317; // sigmoid(-2.281) = 0.09269
        lut[8'd184] = 32'h3DC34695; // sigmoid(-2.250) = 0.09535
        lut[8'd185] = 32'h3DC8DDD0; // sigmoid(-2.219) = 0.09808
        lut[8'd186] = 32'h3DCE9974; // sigmoid(-2.188) = 0.10088
        lut[8'd187] = 32'h3DD47A29; // sigmoid(-2.156) = 0.10375
        lut[8'd188] = 32'h3DDA8099; // sigmoid(-2.125) = 0.10669
        lut[8'd189] = 32'h3DE0AD6C; // sigmoid(-2.094) = 0.10971
        lut[8'd190] = 32'h3DE70147; // sigmoid(-2.062) = 0.11280
        lut[8'd191] = 32'h3DED7CD0; // sigmoid(-2.031) = 0.11596
        lut[8'd192] = 32'h3DF420A9; // sigmoid(-2.000) = 0.11920
        lut[8'd193] = 32'h3DFAED73; // sigmoid(-1.969) = 0.12252
        lut[8'd194] = 32'h3E00F1E6; // sigmoid(-1.938) = 0.12592
        lut[8'd195] = 32'h3E048226; // sigmoid(-1.906) = 0.12940
        lut[8'd196] = 32'h3E0827C7; // sigmoid(-1.875) = 0.13296
        lut[8'd197] = 32'h3E0BE312; // sigmoid(-1.844) = 0.13661
        lut[8'd198] = 32'h3E0FB44E; // sigmoid(-1.812) = 0.14034
        lut[8'd199] = 32'h3E139BC2; // sigmoid(-1.781) = 0.14415
        lut[8'd200] = 32'h3E1799AF; // sigmoid(-1.750) = 0.14805
        lut[8'd201] = 32'h3E1BAE57; // sigmoid(-1.719) = 0.15203
        lut[8'd202] = 32'h3E1FD9F6; // sigmoid(-1.688) = 0.15610
        lut[8'd203] = 32'h3E241CC7; // sigmoid(-1.656) = 0.16027
        lut[8'd204] = 32'h3E287701; // sigmoid(-1.625) = 0.16452
        lut[8'd205] = 32'h3E2CE8D6; // sigmoid(-1.594) = 0.16886
        lut[8'd206] = 32'h3E317277; // sigmoid(-1.562) = 0.17329
        lut[8'd207] = 32'h3E36140D; // sigmoid(-1.531) = 0.17781
        lut[8'd208] = 32'h3E3ACDC2; // sigmoid(-1.500) = 0.18243
        lut[8'd209] = 32'h3E3F9FB6; // sigmoid(-1.469) = 0.18713
        lut[8'd210] = 32'h3E448A07; // sigmoid(-1.438) = 0.19193
        lut[8'd211] = 32'h3E498CCF; // sigmoid(-1.406) = 0.19683
        lut[8'd212] = 32'h3E4EA820; // sigmoid(-1.375) = 0.20181
        lut[8'd213] = 32'h3E53DC09; // sigmoid(-1.344) = 0.20689
        lut[8'd214] = 32'h3E592891; // sigmoid(-1.312) = 0.21207
        lut[8'd215] = 32'h3E5E8DBA; // sigmoid(-1.281) = 0.21734
        lut[8'd216] = 32'h3E640B81; // sigmoid(-1.250) = 0.22270
        lut[8'd217] = 32'h3E69A1DC; // sigmoid(-1.219) = 0.22816
        lut[8'd218] = 32'h3E6F50B8; // sigmoid(-1.188) = 0.23371
        lut[8'd219] = 32'h3E7517FF; // sigmoid(-1.156) = 0.23935
        lut[8'd220] = 32'h3E7AF791; // sigmoid(-1.125) = 0.24509
        lut[8'd221] = 32'h3E8077A4; // sigmoid(-1.094) = 0.25091
        lut[8'd222] = 32'h3E837F7C; // sigmoid(-1.062) = 0.25683
        lut[8'd223] = 32'h3E869335; // sigmoid(-1.031) = 0.26284
        lut[8'd224] = 32'h3E89B2B1; // sigmoid(-1.000) = 0.26894
        lut[8'd225] = 32'h3E8CDDCE; // sigmoid(-0.969) = 0.27513
        lut[8'd226] = 32'h3E901465; // sigmoid(-0.938) = 0.28141
        lut[8'd227] = 32'h3E93564E; // sigmoid(-0.906) = 0.28777
        lut[8'd228] = 32'h3E96A358; // sigmoid(-0.875) = 0.29421
        lut[8'd229] = 32'h3E99FB53; // sigmoid(-0.844) = 0.30075
        lut[8'd230] = 32'h3E9D5E08; // sigmoid(-0.812) = 0.30736
        lut[8'd231] = 32'h3EA0CB3C; // sigmoid(-0.781) = 0.31405
        lut[8'd232] = 32'h3EA442B1; // sigmoid(-0.750) = 0.32082
        lut[8'd233] = 32'h3EA7C424; // sigmoid(-0.719) = 0.32767
        lut[8'd234] = 32'h3EAB4F4F; // sigmoid(-0.688) = 0.33459
        lut[8'd235] = 32'h3EAEE3E7; // sigmoid(-0.656) = 0.34158
        lut[8'd236] = 32'h3EB2819D; // sigmoid(-0.625) = 0.34865
        lut[8'd237] = 32'h3EB62820; // sigmoid(-0.594) = 0.35577
        lut[8'd238] = 32'h3EB9D71A; // sigmoid(-0.562) = 0.36297
        lut[8'd239] = 32'h3EBD8E2F; // sigmoid(-0.531) = 0.37023
        lut[8'd240] = 32'h3EC14D03; // sigmoid(-0.500) = 0.37754
        lut[8'd241] = 32'h3EC51334; // sigmoid(-0.469) = 0.38491
        lut[8'd242] = 32'h3EC8E05F; // sigmoid(-0.438) = 0.39234
        lut[8'd243] = 32'h3ECCB41D; // sigmoid(-0.406) = 0.39981
        lut[8'd244] = 32'h3ED08E01; // sigmoid(-0.375) = 0.40733
        lut[8'd245] = 32'h3ED46D9F; // sigmoid(-0.344) = 0.41490
        lut[8'd246] = 32'h3ED85287; // sigmoid(-0.312) = 0.42250
        lut[8'd247] = 32'h3EDC3C46; // sigmoid(-0.281) = 0.43015
        lut[8'd248] = 32'h3EE02A67; // sigmoid(-0.250) = 0.43782
        lut[8'd249] = 32'h3EE41C72; // sigmoid(-0.219) = 0.44553
        lut[8'd250] = 32'h3EE811F0; // sigmoid(-0.188) = 0.45326
        lut[8'd251] = 32'h3EEC0A64; // sigmoid(-0.156) = 0.46102
        lut[8'd252] = 32'h3EF00553; // sigmoid(-0.125) = 0.46879
        lut[8'd253] = 32'h3EF4023F; // sigmoid(-0.094) = 0.47658
        lut[8'd254] = 32'h3EF800AB; // sigmoid(-0.062) = 0.48438
        lut[8'd255] = 32'h3EFC0015; // sigmoid(-0.031) = 0.49219
    end

    assign data_out = lut[data_in];

endmodule
