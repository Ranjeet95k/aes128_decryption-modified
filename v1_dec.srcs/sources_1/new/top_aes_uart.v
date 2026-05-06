`timescale 1ns / 1ps

module top_aes_uart(
    input  wire       clk_fpga,
    input  wire       reset,
    input  wire       rx,
    output wire       tx,
    output wire [7:0] leds,
    output wire       done_led
);

    localparam integer CLKS_PER_BIT = 868;
    localparam integer AES_WAIT_CLKS = 2048;

    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] RECEIVE  = 3'd1;
    localparam [2:0] WAIT_AES = 3'd2;
    localparam [2:0] SEND     = 3'd3;
    localparam [2:0] DONE     = 3'd4;

    reg [2:0] state = IDLE;
    reg [127:0] cipher_reg = 128'd0;
    reg [127:0] key_reg = 128'd0;
    reg [127:0] expected_reg = 128'd0;
    reg [127:0] plain_buf = 128'd0;
    reg [5:0] rx_count = 6'd0;
    reg [4:0] tx_count = 5'd0;
    reg [11:0] aes_wait_count = 12'd0;
    reg [7:0] latest_byte = 8'd0;
    reg done_reg = 1'b0;
    reg tx_start = 1'b0;
    reg [7:0] tx_data = 8'd0;
    reg tx_busy_d = 1'b0;
    reg [2:0] aes_clk_div = 3'd0;

    wire aes_clk;
    wire [7:0] rx_data;
    wire rx_done;
    wire tx_busy;
    wire tx_done_pulse;
    wire [127:0] aes_out;

    assign leds = latest_byte;
    assign done_led = done_reg;
    assign tx_done_pulse = (tx_busy_d == 1'b1) && (tx_busy == 1'b0);

    always @(posedge clk_fpga) begin
        if (reset) begin
            aes_clk_div <= 3'd0;
        end else begin
            aes_clk_div <= aes_clk_div + 3'd1;
        end
    end

    BUFG aes_clk_bufg (
        .I(aes_clk_div[2]),
        .O(aes_clk)
    );

    uart_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) RX (
        .clk(clk_fpga),
        .rx(rx),
        .data_out(rx_data),
        .done(rx_done)
    );

    uart_tx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) TX (
        .clk(clk_fpga),
        .start(tx_start),
        .data_in(tx_data),
        .tx(tx),
        .busy(tx_busy)
    );

    AES128_DECRYPT_STAGE4 AES (
        .clk(aes_clk),
        .IN_DATA(cipher_reg),
        .IN_KEY(key_reg),
        .OUT_DATA(aes_out)
    );

    always @(posedge clk_fpga) begin
        if (reset) begin
            state <= IDLE;
            cipher_reg <= 128'd0;
            key_reg <= 128'd0;
            expected_reg <= 128'd0;
            plain_buf <= 128'd0;
            rx_count <= 6'd0;
            tx_count <= 5'd0;
            aes_wait_count <= 12'd0;
            latest_byte <= 8'd0;
            done_reg <= 1'b0;
            tx_start <= 1'b0;
            tx_data <= 8'd0;
            tx_busy_d <= 1'b0;
        end else begin
            tx_start <= 1'b0;
            tx_busy_d <= tx_busy;

            case (state)
                IDLE: begin
                    cipher_reg <= 128'd0;
                    key_reg <= 128'd0;
                    expected_reg <= 128'd0;
                    plain_buf <= 128'd0;
                    rx_count <= 6'd0;
                    tx_count <= 5'd0;
                    aes_wait_count <= 12'd0;
                    done_reg <= 1'b0;
                    state <= RECEIVE;
                end

                RECEIVE: begin
                    if (rx_done) begin
                        latest_byte <= rx_data;

                        if (rx_count < 6'd16) begin
                            cipher_reg[127 - (rx_count[4:0] * 8) -: 8] <= rx_data;
                        end else if (rx_count < 6'd32) begin
                            key_reg[127 - ((rx_count[4:0] - 5'd16) * 8) -: 8] <= rx_data;
                        end else begin
                            expected_reg[127 - ((rx_count - 6'd32) * 8) -: 8] <= rx_data;
                        end

                        if (rx_count == 6'd47) begin
                            aes_wait_count <= 12'd0;
                            state <= WAIT_AES;
                        end else begin
                            rx_count <= rx_count + 6'd1;
                        end
                    end
                end

                WAIT_AES: begin
                    if (aes_wait_count == AES_WAIT_CLKS - 1) begin
                        plain_buf <= aes_out;
                        tx_count <= 5'd0;
                        state <= SEND;
                    end else begin
                        aes_wait_count <= aes_wait_count + 12'd1;
                    end
                end

                SEND: begin
                    if ((tx_busy == 1'b0) && (tx_busy_d == 1'b0) && (tx_start == 1'b0)) begin
                        tx_data <= plain_buf[127 - (tx_count * 8) -: 8];
                        tx_start <= 1'b1;
                    end else if (tx_done_pulse) begin
                        if (tx_count == 5'd15) begin
                            latest_byte <= plain_buf[7:0];
                            done_reg <= (plain_buf == expected_reg);
                            state <= DONE;
                        end else begin
                            tx_count <= tx_count + 5'd1;
                        end
                    end
                end

                DONE: begin
                    done_reg <= (plain_buf == expected_reg);
                    if (rx_done) begin
                        cipher_reg <= {rx_data, 120'd0};
                        key_reg <= 128'd0;
                        expected_reg <= 128'd0;
                        latest_byte <= rx_data;
                        rx_count <= 6'd1;
                        tx_count <= 5'd0;
                        aes_wait_count <= 12'd0;
                        done_reg <= 1'b0;
                        state <= RECEIVE;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
