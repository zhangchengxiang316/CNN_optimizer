// =============================================================================
// input_data.v – First-Layer Input Feature Map ROM
// -----------------------------------------------------------------------------
// Stores one MFCC input feature map for simulation / verification.
// Shape: (1, 30, 10) – 1 channel, 30 rows, 10 columns = 300 INT8 pixels.
//
// Address: addr = row * 10 + col
//   row ∈ [0, 29], col ∈ [0, 9]
//
// NOTE: The values below are PLACEHOLDER pseudo-random INT8 values in the
// range [-4, 4].  Replace them with an actual MFCC feature-map extract from
// your dataset for regression testing.
//
// Interface:
//   addr    [8:0] → pixel address (0 .. 299)
//   data_out [7:0] → INT8 pixel value
// =============================================================================
module input_data (
    input  wire [8:0]  addr,
    output wire signed [7:0] data_out
);

    reg signed [7:0] pixels [0:299];

    initial begin : init_pixels
        integer i;
        integer x;
        x = 32'h00000005;   // seed = 5
        for (i = 0; i < 300; i = i + 1) begin
            x = (x * 32'd1664525 + 32'd1013904223) & 32'hFFFFFFFF;
            pixels[i] = $signed(((x >> 16) % 9) - 4);
        end
    end

    assign data_out = pixels[addr];

endmodule
