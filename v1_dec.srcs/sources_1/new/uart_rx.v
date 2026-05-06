`timescale 1ns / 1ps

module uart_rx #(
    parameter integer CLKS_PER_BIT = 868
)(
    input  wire       clk,
    input  wire       rx,
    output reg  [7:0] data_out,
    output reg        done
);

    localparam [2:0] S_IDLE  = 3'd0;
    localparam [2:0] S_START = 3'd1;
    localparam [2:0] S_DATA  = 3'd2;
    localparam [2:0] S_STOP  = 3'd3;
    localparam [2:0] S_DONE  = 3'd4;

    reg [2:0]  state = S_IDLE;
    reg [15:0] clk_count = 16'd0;
    reg [2:0]  bit_index = 3'd0;
    reg [7:0]  rx_shift = 8'd0;

    always @(posedge clk) begin
        done <= 1'b0;

        case (state)
            S_IDLE: begin
                clk_count <= 16'd0;
                bit_index <= 3'd0;

                if (rx == 1'b0) begin
                    state <= S_START;
                end
            end

            S_START: begin
                if (clk_count == ((CLKS_PER_BIT - 1) / 2)) begin
                    if (rx == 1'b0) begin
                        clk_count <= 16'd0;
                        state <= S_DATA;
                    end else begin
                        state <= S_IDLE;
                    end
                end else begin
                    clk_count <= clk_count + 16'd1;
                end
            end

            S_DATA: begin
                if (clk_count == CLKS_PER_BIT - 1) begin
                    clk_count <= 16'd0;
                    rx_shift[bit_index] <= rx;

                    if (bit_index == 3'd7) begin
                        bit_index <= 3'd0;
                        state <= S_STOP;
                    end else begin
                        bit_index <= bit_index + 3'd1;
                    end
                end else begin
                    clk_count <= clk_count + 16'd1;
                end
            end

            S_STOP: begin
                if (clk_count == CLKS_PER_BIT - 1) begin
                    clk_count <= 16'd0;
                    data_out <= rx_shift;
                    state <= S_DONE;
                end else begin
                    clk_count <= clk_count + 16'd1;
                end
            end

            S_DONE: begin
                done <= 1'b1;
                state <= S_IDLE;
            end

            default: begin
                state <= S_IDLE;
            end
        endcase
    end

endmodule
