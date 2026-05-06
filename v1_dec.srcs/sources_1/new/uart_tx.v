`timescale 1ns / 1ps

module uart_tx #(parameter CLKS_PER_BIT = 868)(
    input clk,
    input start,
    input [7:0] data_in,
    output reg tx   = 1,
    output reg busy = 0
);
    reg [3:0]  bit_index = 0;
    reg [13:0] clk_count = 0;
    reg [9:0]  tx_frame  = 10'h3FF; // full 10-bit frame stored at load

    always @(posedge clk) begin
        if (start && !busy) begin
            busy      <= 1;
            bit_index <= 0;
            clk_count <= 0;
            // Build full frame once: bit0=start, bits1-8=data LSB first, bit9=stop
            tx_frame  <= {1'b1, data_in, 1'b0};
            tx        <= 0; // bit 0 = start bit, drive immediately
        end
        else if (busy) begin
            if (clk_count == CLKS_PER_BIT - 1) begin
                clk_count <= 0;
                bit_index <= bit_index + 1;
                if (bit_index < 9) begin
                    // Drive the next bit directly from frame by index
                    tx <= tx_frame[bit_index + 1];
                end
                else begin
                    // bit_index == 9, stop bit just finished
                    tx   <= 1;
                    busy <= 0;
                end
            end
            else begin
                clk_count <= clk_count + 1;
            end
        end
    end
endmodule
