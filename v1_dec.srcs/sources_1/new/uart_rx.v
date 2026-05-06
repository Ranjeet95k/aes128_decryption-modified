`timescale 1ns / 1ps

module uart_rx #(parameter CLKS_PER_BIT = 868)(
    input clk,
    input rx,
    output reg [7:0] data_out = 0,
    output reg done = 0
);
    reg [3:0]  bit_index = 0;
    reg [13:0] clk_count = 0;
    reg [7:0]  rx_byte   = 0;
    reg        busy      = 0;

    always @(posedge clk) begin
        done <= 0;
        if (!busy && rx == 0) begin
            busy      <= 1;
            clk_count <= 0;
            bit_index <= 0;
        end
        else if (busy) begin
            if (clk_count == CLKS_PER_BIT/2 - 1) begin
                clk_count <= clk_count + 1;
                if (bit_index == 0 && rx != 0)
                    busy <= 0; // false start, abort
            end
            else if (clk_count == CLKS_PER_BIT - 1) begin
                clk_count <= 0;
                if (bit_index < 8) begin
                    rx_byte[bit_index] <= rx;
                    bit_index          <= bit_index + 1;
                end
                else begin
                    busy     <= 0;
                    data_out <= rx_byte;
                    done     <= 1;
                end
            end
            else begin
                clk_count <= clk_count + 1;
            end
        end
    end
endmodule
