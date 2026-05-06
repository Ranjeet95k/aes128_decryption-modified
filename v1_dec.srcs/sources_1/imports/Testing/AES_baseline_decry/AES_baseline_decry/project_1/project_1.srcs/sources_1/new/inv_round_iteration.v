`timescale 1ns / 1ps

module INV_ROUND_ITERATION(
    input clk,
    input [127:0] IN_DATA,
    input [127:0] IN_KEY,
    output [127:0] OUT_DATA
);
    wire [127:0] shift_rows_out, sub_bytes_out, add_key_out;

    // 1. Inverse Shift Rows
    INV_SHIFT_ROWS inv_shift (.IN_DATA(IN_DATA), .OUT_DATA(shift_rows_out));
    
    // 2. Inverse Sub Bytes
    INV_SUB_BYTES inv_sub (.IN_DATA(shift_rows_out), .OUT_DATA(sub_bytes_out));
    
    // 3. Add Round Key
    assign add_key_out = sub_bytes_out ^ IN_KEY;
    
    // 4. Inverse Mix Columns (Note: applied AFTER AddRoundKey in standard AES decryption)
    INV_MIX_COLUMNS inv_mix (.IN_DATA(add_key_out), .OUT_DATA(OUT_DATA));

endmodule