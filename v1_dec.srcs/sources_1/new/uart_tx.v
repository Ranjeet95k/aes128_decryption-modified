`timescale 1ns / 1ps

module uart_tx #(
    parameter integer CLKS_PER_BIT = 868
)(
    input  wire       clk,
    input  wire       start,
    input  wire [7:0] data_in,
    output reg        tx,
    output wire       busy
);

    localparam [2:0] S_IDLE  = 3'd0;
    localparam [2:0] S_START = 3'd1;
    localparam [2:0] S_DATA  = 3'd2;
    localparam [2:0] S_STOP  = 3'd3;
    localparam [2:0] S_CLEAN = 3'd4;

    reg [2:0]  state = S_IDLE;
    reg [15:0] clk_count = 16'd0;
    reg [2:0]  bit_index = 3'd0;
    reg [7:0]  tx_shift = 8'd0;

    assign busy = (state != S_IDLE);

    initial begin
        tx = 1'b1;
    end

    always @(posedge clk) begin
        case (state)
            S_IDLE: begin
                tx <= 1'b1;
                clk_count <= 16'd0;
                bit_index <= 3'd0;

                if (start == 1'b1) begin
                    tx_shift <= data_in;
                    state <= S_START;
                end
            end

            S_START: begin
                tx <= 1'b0;
                if (clk_count == CLKS_PER_BIT - 1) begin
                    clk_count <= 16'd0;
                    state <= S_DATA;
                end else begin
                    clk_count <= clk_count + 16'd1;
                end
            end

            S_DATA: begin
                tx <= tx_shift[bit_index];
                if (clk_count == CLKS_PER_BIT - 1) begin
                    clk_count <= 16'd0;

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
                tx <= 1'b1;
                if (clk_count == CLKS_PER_BIT - 1) begin
                    clk_count <= 16'd0;
                    state <= S_CLEAN;
                end else begin
                    clk_count <= clk_count + 16'd1;
                end
            end

            S_CLEAN: begin
                state <= S_IDLE;
            end

            default: begin
                tx <= 1'b1;
                state <= S_IDLE;
            end
        endcase
    end

endmodule
