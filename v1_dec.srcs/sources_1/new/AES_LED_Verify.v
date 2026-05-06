`timescale 1ns / 1ps

module AES_LED_Verify(
    input  wire       clk_fpga,   // 100 MHz Basys 3 clock
    input  wire       reset,      // BTNC, active HIGH
    input  wire       btnR,       // BTNR: next byte
    input  wire       btnL,       // BTNL: previous byte
    output wire [7:0] leds,       // LD0-LD7 show selected AES output byte
    output wire       led_pass    // LD15 glows when the full output matches
);

    // Test vector from tb_aes.v.
    localparam [127:0] CIPHER_TEXT  = 128'hc8f7d43cd98f2e5ae110010771705871;
    localparam [127:0] AES_KEY      = 128'h000102030405060708090a0b0c0d0e0f;
    localparam [127:0] EXPECTED_OUT = 128'h4142434445464748494a4b4c4d4e4f52;

    reg [2:0] aes_clk_div = 3'd0;
    wire aes_clk;

    // The AES core is only used for LED verification, so it does not need to run
    // at the full 100 MHz board clock. Divide by 8 and route through BUFG to give
    // the AES round logic a relaxed 80 ns timing requirement.
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

    wire btnR_pulse;
    wire btnL_pulse;

    debounce_pulse db_btnR (
        .clk    (clk_fpga),
        .reset  (reset),
        .btn_in (btnR),
        .pulse  (btnR_pulse)
    );

    debounce_pulse db_btnL (
        .clk    (clk_fpga),
        .reset  (reset),
        .btn_in (btnL),
        .pulse  (btnL_pulse)
    );

    // Selects aes_result[byte_sel*8 +: 8].
    // byte_sel = 0 shows aes_result[7:0], byte_sel = 15 shows aes_result[127:120].
    reg [3:0] byte_sel = 4'd0;

    always @(posedge clk_fpga) begin
        if (reset) begin
            byte_sel <= 4'd0;
        end else begin
            if (btnR_pulse && !btnL_pulse) begin
                byte_sel <= byte_sel + 4'd1;
            end else if (btnL_pulse && !btnR_pulse) begin
                byte_sel <= byte_sel - 4'd1;
            end
        end
    end

    // LD7 is the selected byte MSB and LD0 is the selected byte LSB.
    assign leds = aes_result[byte_sel*8 +: 8];

    assign led_pass = (aes_result == EXPECTED_OUT);

endmodule


module debounce_pulse(
    input  wire clk,
    input  wire reset,
    input  wire btn_in,
    output reg  pulse
);

    // 20 bits at 100 MHz gives about 10.5 ms of debounce time.
    localparam integer CNT_WIDTH = 20;

    reg btn_meta   = 1'b0;
    reg btn_sync   = 1'b0;
    reg btn_stable = 1'b0;
    reg btn_last   = 1'b0;
    reg [CNT_WIDTH-1:0] cnt = {CNT_WIDTH{1'b0}};

    always @(posedge clk) begin
        if (reset) begin
            btn_meta   <= 1'b0;
            btn_sync   <= 1'b0;
            btn_stable <= 1'b0;
            btn_last   <= 1'b0;
            cnt        <= {CNT_WIDTH{1'b0}};
            pulse      <= 1'b0;
        end else begin
            btn_meta <= btn_in;
            btn_sync <= btn_meta;

            pulse <= 1'b0;

            if (btn_sync == btn_stable) begin
                cnt <= {CNT_WIDTH{1'b0}};
            end else begin
                cnt <= cnt + 1'b1;

                if (&cnt) begin
                    btn_stable <= btn_sync;
                    cnt <= {CNT_WIDTH{1'b0}};
                end
            end

            btn_last <= btn_stable;

            if (btn_stable && !btn_last) begin
                pulse <= 1'b1;
            end
        end
    end

endmodule
