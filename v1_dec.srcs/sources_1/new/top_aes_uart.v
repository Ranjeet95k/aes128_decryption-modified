`timescale 1ns / 1ps

module top_aes_uart(
    input clk,
    input rst,
    input rx,
    output tx
);

// UART
wire [7:0] rx_data;
wire rx_done;

reg [7:0] tx_data;
reg tx_start;
wire tx_busy;

uart_rx RX (
    .clk(clk),
    .rx(rx),
    .data_out(rx_data),
    .done(rx_done)
);

uart_tx TX (
    .clk(clk),
    .start(tx_start),
    .data_in(tx_data),
    .tx(tx),
    .busy(tx_busy)
);

// AES
reg [127:0] data_reg = 0;
reg [127:0] key_reg  = 0;
wire [127:0] aes_out;

AES128_DECRYPT_STAGE4 AES (
    .clk(clk),
    .IN_DATA(data_reg),
    .IN_KEY(key_reg),
    .OUT_DATA(aes_out)
);

// FSM
reg [1:0] state = 0;

localparam IDLE     = 0,
           RECEIVE  = 1,
           WAIT_AES = 2,
           SEND     = 3;

reg [5:0] byte_cnt = 0;
reg [7:0] wait_cnt = 0;
reg [127:0] out_buf = 0;
reg [4:0] tx_cnt = 0;

always @(posedge clk) begin
    if (rst) begin
        data_reg <= 0;
        key_reg <= 0;
        tx_data <= 0;
        tx_start <= 0;
        state <= IDLE;
        byte_cnt <= 0;
        wait_cnt <= 0;
        out_buf <= 0;
        tx_cnt <= 0;
    end else begin
        case(state)

        IDLE: begin
            byte_cnt <= 0;
            tx_start <= 0;
            state <= RECEIVE;
        end

        RECEIVE: begin
            tx_start <= 0;
            if (rx_done) begin
                if (byte_cnt < 16)
                    data_reg <= {data_reg[119:0], rx_data};
                else
                    key_reg <= {key_reg[119:0], rx_data};

                byte_cnt <= byte_cnt + 1;

                if (byte_cnt == 31) begin
                    wait_cnt <= 0;
                    state <= WAIT_AES;
                end
            end
        end

        WAIT_AES: begin
            tx_start <= 0;
            wait_cnt <= wait_cnt + 1;

            if (wait_cnt[7]) begin
                out_buf <= aes_out;
                tx_cnt <= 0;
                state <= SEND;
            end
        end

        SEND: begin
            if (!tx_busy) begin
                tx_data <= out_buf[127:120];
                out_buf <= {out_buf[119:0], 8'b0};

                tx_start <= 1;
                tx_cnt <= tx_cnt + 1;

                if (tx_cnt == 15)
                    state <= IDLE;
            end
            else begin
                tx_start <= 0;
            end
        end

        endcase
    end
end

endmodule
