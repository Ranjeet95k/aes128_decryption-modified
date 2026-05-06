`timescale 1ns / 1ps

module AES_ILA_VIO_Verify(
    input  wire         clk_fpga,          // 100 MHz Basys 3 clock
    input  wire         reset,             // Optional physical BTNC reset
    input  wire         btnR,              // Optional physical BTNR next byte
    input  wire         btnL,              // Optional physical BTNL previous byte
    input  wire         vio_reset,         // VIO reset control
    input  wire         vio_next,          // VIO next-byte control, edge detected
    input  wire         vio_prev,          // VIO previous-byte control, edge detected
    output wire [7:0]   leds,              // LD0-LD7 selected byte view
    output wire         led_pass,          // LD15 pass indicator
    output wire [127:0] dbg_aes_result,    // ILA probe, width 128
    output wire [127:0] dbg_expected_out,  // ILA probe, width 128
    output wire [127:0] dbg_cipher_text,   // ILA probe, width 128
    output wire [127:0] dbg_key,           // ILA probe, width 128
    output wire [7:0]   dbg_selected_byte, // ILA probe, width 8
    output wire [3:0]   dbg_byte_sel,      // ILA probe, width 4
    output wire         dbg_pass           // ILA probe, width 1
);

    // Test vector from tb_aes.v.
    localparam [127:0] CIPHER_TEXT  = 128'hc8f7d43cd98f2e5ae110010771705871;
    localparam [127:0] AES_KEY      = 128'h000102030405060708090a0b0c0d0e0f;
    localparam [127:0] EXPECTED_OUT = 128'h4142434445464748494a4b4c4d4e4f52;

    reg [2:0] aes_clk_div = 3'd0;
    wire aes_clk;

    // Keep the AES core on a slower clock for timing closure on Artix-7.
    always @(posedge clk_fpga) begin
        aes_clk_div <= aes_clk_div + 3'd1;
    end

    BUFG aes_clk_bufg (
        .I (aes_clk_div[2]),
        .O (aes_clk)
    );

    wire [127:0] aes_result;

    AES128_DECRYPT_STAGE4 aes_dut (
        .clk      (aes_clk),
        .IN_DATA  (CIPHER_TEXT),
        .IN_KEY   (AES_KEY),
        .OUT_DATA (aes_result)
    );

    wire reset_all = reset | vio_reset;

    wire btnR_pulse;
    wire btnL_pulse;

    debounce_pulse db_btnR (
        .clk    (clk_fpga),
        .reset  (reset_all),
        .btn_in (btnR),
        .pulse  (btnR_pulse)
    );

    debounce_pulse db_btnL (
        .clk    (clk_fpga),
        .reset  (reset_all),
        .btn_in (btnL),
        .pulse  (btnL_pulse)
    );

    // VIO controls are synchronous to clk_fpga, so use edge detection instead
    // of debounce. Toggle a VIO control 0->1 to generate one pulse.
    reg vio_next_d = 1'b0;
    reg vio_prev_d = 1'b0;

    always @(posedge clk_fpga) begin
        if (reset_all) begin
            vio_next_d <= 1'b0;
            vio_prev_d <= 1'b0;
        end else begin
            vio_next_d <= vio_next;
            vio_prev_d <= vio_prev;
        end
    end

    wire vio_next_pulse = vio_next & ~vio_next_d;
    wire vio_prev_pulse = vio_prev & ~vio_prev_d;
    wire next_pulse = btnR_pulse | vio_next_pulse;
    wire prev_pulse = btnL_pulse | vio_prev_pulse;

    reg [3:0] byte_sel = 4'd0;

    always @(posedge clk_fpga) begin
        if (reset_all) begin
            byte_sel <= 4'd0;
        end else begin
            if (next_pulse && !prev_pulse) begin
                byte_sel <= byte_sel + 4'd1;
            end else if (prev_pulse && !next_pulse) begin
                byte_sel <= byte_sel - 4'd1;
            end
        end
    end

    wire [7:0] selected_byte = aes_result[byte_sel*8 +: 8];
    wire pass = (aes_result == EXPECTED_OUT);

    assign leds = selected_byte;
    assign led_pass = pass;

    assign dbg_aes_result    = aes_result;
    assign dbg_expected_out  = EXPECTED_OUT;
    assign dbg_cipher_text   = CIPHER_TEXT;
    assign dbg_key           = AES_KEY;
    assign dbg_selected_byte = selected_byte;
    assign dbg_byte_sel      = byte_sel;
    assign dbg_pass          = pass;

endmodule
