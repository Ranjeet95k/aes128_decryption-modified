`timescale 1ns / 1ps

module tb_AES_LED_Verify;

    reg clk_fpga = 1'b0;
    reg reset    = 1'b0;
    reg btnR     = 1'b0;
    reg btnL     = 1'b0;

    wire [7:0] leds;
    wire led_pass;

    AES_LED_Verify dut (
        .clk_fpga (clk_fpga),
        .reset    (reset),
        .btnR     (btnR),
        .btnL     (btnL),
        .leds     (leds),
        .led_pass (led_pass)
    );

    // 100 MHz clock.
    always #5 clk_fpga = ~clk_fpga;

    initial begin
        reset = 1'b1;
        #100;
        reset = 1'b0;

        // Wait long enough for the iterative AES decrypt module to finish.
        // The board wrapper runs AES on clk_fpga/8 for timing margin.
        #20000;

        if (led_pass)
            $display("AES LED VERIFY PASS: full 128-bit output matched.");
        else
            $display("AES LED VERIFY FAIL: full 128-bit output did not match.");

        $display("byte_sel 0 LEDs = %b, expected 01010010", leds);

        $finish;
    end

endmodule
