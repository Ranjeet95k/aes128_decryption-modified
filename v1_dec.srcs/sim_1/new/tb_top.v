`timescale 1ns / 1ps

module tb_top;

    reg clk_fpga = 1'b0;
    reg reset = 1'b1;
    reg rx = 1'b1;
    wire tx;
    wire [7:0] leds;
    wire done_led;

    localparam integer CLKS_PER_BIT = 868;
    localparam integer CLK_PERIOD_NS = 10;
    localparam integer BIT_PERIOD_NS = CLKS_PER_BIT * CLK_PERIOD_NS;

    reg [7:0] cipher [0:15];
    reg [7:0] key [0:15];
    reg [7:0] expected [0:15];
    reg [7:0] received [0:15];
    integer i;
    integer errors;

    always #(CLK_PERIOD_NS / 2) clk_fpga = ~clk_fpga;

    top_aes_uart DUT (
        .clk_fpga(clk_fpga),
        .reset(reset),
        .rx(rx),
        .tx(tx),
        .leds(leds),
        .done_led(done_led)
    );

    task uart_send_byte;
        input [7:0] data;
        integer bit_idx;
        begin
            rx = 1'b0;
            #(BIT_PERIOD_NS);

            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                rx = data[bit_idx];
                #(BIT_PERIOD_NS);
            end

            rx = 1'b1;
            #(BIT_PERIOD_NS);
        end
    endtask

    task uart_receive_byte;
        output [7:0] data;
        integer bit_idx;
        begin
            wait (tx == 1'b0);
            #(BIT_PERIOD_NS + (BIT_PERIOD_NS / 2));

            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                data[bit_idx] = tx;
                #(BIT_PERIOD_NS);
            end

            if (tx !== 1'b1) begin
                $display("ERROR: stop bit was not high at time %0t", $time);
                errors = errors + 1;
            end

            #(BIT_PERIOD_NS / 2);
        end
    endtask

    initial begin
        cipher[0]=8'hc8; cipher[1]=8'hf7; cipher[2]=8'hd4; cipher[3]=8'h3c;
        cipher[4]=8'hd9; cipher[5]=8'h8f; cipher[6]=8'h2e; cipher[7]=8'h5a;
        cipher[8]=8'he1; cipher[9]=8'h10; cipher[10]=8'h01; cipher[11]=8'h07;
        cipher[12]=8'h71; cipher[13]=8'h70; cipher[14]=8'h58; cipher[15]=8'h71;

        key[0]=8'h00; key[1]=8'h01; key[2]=8'h02; key[3]=8'h03;
        key[4]=8'h04; key[5]=8'h05; key[6]=8'h06; key[7]=8'h07;
        key[8]=8'h08; key[9]=8'h09; key[10]=8'h0a; key[11]=8'h0b;
        key[12]=8'h0c; key[13]=8'h0d; key[14]=8'h0e; key[15]=8'h0f;

        expected[0]=8'h41; expected[1]=8'h42; expected[2]=8'h43; expected[3]=8'h44;
        expected[4]=8'h45; expected[5]=8'h46; expected[6]=8'h47; expected[7]=8'h48;
        expected[8]=8'h49; expected[9]=8'h4a; expected[10]=8'h4b; expected[11]=8'h4c;
        expected[12]=8'h4d; expected[13]=8'h4e; expected[14]=8'h4f; expected[15]=8'h52;

        errors = 0;

        repeat (20) @(posedge clk_fpga);
        reset = 1'b0;
        repeat (20) @(posedge clk_fpga);

        for (i = 0; i < 16; i = i + 1) begin
            uart_send_byte(cipher[i]);
        end

        for (i = 0; i < 16; i = i + 1) begin
            uart_send_byte(key[i]);
        end

        for (i = 0; i < 16; i = i + 1) begin
            uart_send_byte(expected[i]);
        end

        for (i = 0; i < 16; i = i + 1) begin
            uart_receive_byte(received[i]);
            if (received[i] !== expected[i]) begin
                $display("ERROR: byte %0d expected 0x%02h got 0x%02h", i, expected[i], received[i]);
                errors = errors + 1;
            end
        end

        wait (done_led == 1'b1);

        if (errors == 0) begin
            $display("PASS: UART AES-128 decrypt returned expected plaintext.");
        end else begin
            $display("FAIL: %0d error(s) detected.", errors);
        end

        #1000;
        $finish;
    end

endmodule
