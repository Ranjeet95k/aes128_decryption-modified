`timescale 1ns / 1ps

module tb_AES_ILA_VIO_Verify;

    reg clk_fpga  = 1'b0;
    reg reset     = 1'b0;
    reg btnR      = 1'b0;
    reg btnL      = 1'b0;
    reg vio_reset = 1'b0;
    reg vio_next  = 1'b0;
    reg vio_prev  = 1'b0;

    wire [7:0] leds;
    wire led_pass;
    wire [127:0] dbg_aes_result;
    wire [127:0] dbg_expected_out;
    wire [127:0] dbg_cipher_text;
    wire [127:0] dbg_key;
    wire [7:0] dbg_selected_byte;
    wire [3:0] dbg_byte_sel;
    wire dbg_pass;

    AES_ILA_VIO_Verify dut (
        .clk_fpga          (clk_fpga),
        .reset             (reset),
        .btnR              (btnR),
        .btnL              (btnL),
        .vio_reset         (vio_reset),
        .vio_next          (vio_next),
        .vio_prev          (vio_prev),
        .leds              (leds),
        .led_pass          (led_pass),
        .dbg_aes_result    (dbg_aes_result),
        .dbg_expected_out  (dbg_expected_out),
        .dbg_cipher_text   (dbg_cipher_text),
        .dbg_key           (dbg_key),
        .dbg_selected_byte (dbg_selected_byte),
        .dbg_byte_sel      (dbg_byte_sel),
        .dbg_pass          (dbg_pass)
    );

    // 100 MHz clock.
    always #5 clk_fpga = ~clk_fpga;

    task pulse_vio_next;
        begin
            @(posedge clk_fpga);
            vio_next = 1'b1;
            @(posedge clk_fpga);
            vio_next = 1'b0;
        end
    endtask

    task pulse_vio_prev;
        begin
            @(posedge clk_fpga);
            vio_prev = 1'b1;
            @(posedge clk_fpga);
            vio_prev = 1'b0;
        end
    endtask

    initial begin
        reset = 1'b1;
        vio_reset = 1'b1;
        #200;
        reset = 1'b0;
        vio_reset = 1'b0;

        // AES runs on clk_fpga/8, so allow time for decrypt to finish.
        #20000;

        $display("AES result    = %h", dbg_aes_result);
        $display("Expected      = %h", dbg_expected_out);
        $display("Pass          = %b", dbg_pass);
        $display("Byte sel      = %0d", dbg_byte_sel);
        $display("Selected byte = %h", dbg_selected_byte);

        pulse_vio_next();
        #200;
        $display("After VIO next: byte_sel=%0d selected=%h", dbg_byte_sel, dbg_selected_byte);

        pulse_vio_next();
        #200;
        $display("After VIO next: byte_sel=%0d selected=%h", dbg_byte_sel, dbg_selected_byte);

        pulse_vio_prev();
        #200;
        $display("After VIO prev: byte_sel=%0d selected=%h", dbg_byte_sel, dbg_selected_byte);

        if (dbg_pass && dbg_selected_byte == 8'h4f && dbg_byte_sel == 4'd1)
            $display("AES ILA/VIO VERIFY TEST PASS");
        else
            $display("AES ILA/VIO VERIFY TEST FAIL");

        $finish;
    end

endmodule
