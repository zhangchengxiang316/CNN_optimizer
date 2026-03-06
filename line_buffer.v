// =============================================================================
// line_buffer.v – Row Line Buffer for Conv1 Sliding Window
// -----------------------------------------------------------------------------
// Design parameters:
//   COL_NUM  = 10   (input feature-map width)
//   ROW_NUM  = 11   (kernel height of Conv1 = 11)
//   DATA_W   =  8   (INT8 pixels)
//
// Operation:
//   Pixels are written one at a time (din / din_valid).
//   Internally the buffer stores the last ROW_NUM complete rows.
//   Once ROW_NUM rows are available dout_valid is asserted and dout exposes
//   all ROW_NUM × COL_NUM pixels simultaneously to the systolic array.
//
//   dout bit layout (row-major):
//     dout[ (r*COL_NUM+c)*DATA_W +: DATA_W ] = row_mem[r][c]
//   where r = 0 is the most-recently-received row.
//
// Shift policy:
//   Each time a complete row (COL_NUM pixels) has been received the internal
//   row array shifts: row_mem[k] ← row_mem[k-1] for k = ROW_NUM-1 .. 1,
//   and row_mem[0] ← newly received row.  This means dout always presents
//   the latest ROW_NUM rows ready for window extraction.
// =============================================================================
module line_buffer #(
    parameter COL_NUM = 10,   // input columns (Conv1: 10)
    parameter ROW_NUM = 11,   // rows to buffer  (Conv1 kernel height: 11)
    parameter DATA_W  = 8     // pixel bit-width
) (
    input  wire                                         clk,
    input  wire                                         rst_n,
    // Pixel input stream (one pixel per valid cycle, row-major order)
    input  wire [DATA_W-1:0]                            din,
    input  wire                                         din_valid,
    // Full-window output
    output reg  [DATA_W*COL_NUM*ROW_NUM-1:0]            dout,
    output reg                                          dout_valid  // high once ROW_NUM rows filled
);

    // -------------------------------------------------------------------------
    // Internal storage
    // -------------------------------------------------------------------------
    reg [DATA_W-1:0] cur_row [0:COL_NUM-1];  // staging register for current incoming row
    reg [DATA_W-1:0] row_mem [0:ROW_NUM-1][0:COL_NUM-1];  // buffered rows

    reg [3:0] wcol;       // column write pointer (0 .. COL_NUM-1)
    reg [3:0] rows_cnt;   // number of complete rows stored (saturates at ROW_NUM)

    integer i, j;

    // -------------------------------------------------------------------------
    // Flatten row_mem into dout (combinational)
    // -------------------------------------------------------------------------
    integer ri, ci;
    always @(*) begin
        for (ri = 0; ri < ROW_NUM; ri = ri + 1)
            for (ci = 0; ci < COL_NUM; ci = ci + 1)
                dout[(ri * COL_NUM + ci) * DATA_W +: DATA_W] = row_mem[ri][ci];
    end

    // -------------------------------------------------------------------------
    // Write logic
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wcol       <= 4'd0;
            rows_cnt   <= 4'd0;
            dout_valid <= 1'b0;
            for (i = 0; i < COL_NUM; i = i + 1)
                cur_row[i] <= {DATA_W{1'b0}};
            for (i = 0; i < ROW_NUM; i = i + 1)
                for (j = 0; j < COL_NUM; j = j + 1)
                    row_mem[i][j] <= {DATA_W{1'b0}};
        end else if (din_valid) begin
            if (wcol == COL_NUM - 1) begin
                // -----------------------------------------------------------
                // Row complete: shift row_mem down and insert new row at [0]
                // Use non-blocking: old values of cur_row[0..COL_NUM-2] are
                // still valid; current din is the last pixel.
                // -----------------------------------------------------------
                wcol <= 4'd0;

                // Shift existing rows toward higher indices (older rows)
                for (i = ROW_NUM-1; i > 0; i = i - 1)
                    for (j = 0; j < COL_NUM; j = j + 1)
                        row_mem[i][j] <= row_mem[i-1][j];

                // New row[0]: pixels 0..COL_NUM-2 from staging, last from din
                for (j = 0; j < COL_NUM-1; j = j + 1)
                    row_mem[0][j] <= cur_row[j];
                row_mem[0][COL_NUM-1] <= din;

                // Row counter (saturates at ROW_NUM)
                if (rows_cnt < ROW_NUM)
                    rows_cnt <= rows_cnt + 1;

                // Assert valid once ROW_NUM rows have been filled
                // rows_cnt == ROW_NUM-1 means we are completing the ROW_NUM-th row
                if (rows_cnt == ROW_NUM - 1)
                    dout_valid <= 1'b1;
            end else begin
                // Buffer pixel into current row staging register
                cur_row[wcol] <= din;
                wcol           <= wcol + 1;
            end
        end
    end

endmodule
