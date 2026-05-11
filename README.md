# AES-128 UART Decrypt — Basys 3 FPGA

A hardware AES-128 decryption core implemented in Verilog, targeting the **Digilent Basys 3** (Artix-7 `xc7a35tcpg236-1`). The design receives ciphertext and key over UART, decrypts using a custom iterative AES-128 architecture, and transmits the plaintext back over UART. A PASS/FAIL indicator LED shows whether the result matches the expected output.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Custom Cipher Algorithm](#custom-cipher-algorithm)
- [UART Protocol](#uart-protocol)
- [Pin Assignments](#pin-assignments)
- [Clock Domains](#clock-domains)
- [Testing](#testing)
  - [Hardware Test (Python)](#hardware-test-python)
- [Test Vectors](#test-vectors)

---

## Architecture Overview

```
Host PC
  │  (UART 115200 8N1)
  ▼
uart_rx  ──►  top_aes_uart  ──►  uart_tx  ──►  Host PC
                   │
                   ▼
          AES128_DECRYPT_STAGE4
          (iterative, aes_clk = clk_fpga/8)
                   │
                   ▼
              plain_buf  ──►  leds[7:0]
                          ──►  done_led
```

The top-level `top_aes_uart` module implements a simple FSM:

| State      | Description                                              |
|------------|----------------------------------------------------------|
| `IDLE`     | Reset all registers, transition immediately to RECEIVE   |
| `RECEIVE`  | Collect 48 bytes: 16 cipher + 16 key + 16 expected       |
| `WAIT_AES` | Wait 2048 clock cycles for the AES core to settle        |
| `SEND`     | Transmit all 16 plaintext bytes back over UART           |
| `DONE`     | Assert `done_led` if plaintext == expected; await retry  |

---

## Custom Cipher Algorithm

This design implements a **non-standard AES variant**. The encryption and decryption differ from standard AES-128 in the following ways:

- **Initial key permutation (`KEY_MODIFY_PART`)**: Before key expansion, the user key is transformed by XOR-ing each 32-bit word with an RCON value derived from `(word_msb + offset) % 32`, where the offsets are +3, +5, +7, +9 for words 0–3 respectively. This produces K0.
- **Key expansion**: Standard AES key schedule is applied (via `GENERATE_KEY`) starting from K0 to derive round keys K1–K9.
- **Round structure** (`ROUND_ITERATION`): SubBytes → XOR keyout_0 → ShiftRows → ModAddition(keyout_1) → MixColumns → XOR OUT_KEY.
- **`MOD_ADDITION`**: A byte-wise modular addition (mod 256) with the round key, rather than the standard XOR AddRoundKey.

The inverse operations mirror this structure exactly.

---

## UART Protocol

| Parameter    | Value       |
|--------------|-------------|
| Baud rate    | 115200      |
| Data bits    | 8           |
| Parity       | None        |
| Stop bits    | 1           |
| Byte order   | Big-endian (MSB of 128-bit value sent first) |

**Host → FPGA (48 bytes total):**

```
Bytes  0–15 : Ciphertext (128-bit, big-endian)
Bytes 16–31 : AES Key    (128-bit, big-endian)
Bytes 32–47 : Expected plaintext (for PASS/FAIL check)
```

**FPGA → Host (16 bytes):**

```
Bytes 0–15 : Decrypted plaintext (128-bit, big-endian)
```

After transmission, `done_led` is asserted if `plaintext == expected`.

---

## Pin Assignments

| Signal       | Pin  | Description                        |
|--------------|------|------------------------------------|
| `clk_fpga`   | W5   | 100 MHz system clock               |
| `reset`      | U18  | Active-high reset (BTNC)           |
| `rx`         | B18  | UART RX (USB-UART bridge)          |
| `tx`         | A18  | UART TX (USB-UART bridge)          |
| `leds[0]`    | U16  | LSB of latest received/sent byte   |
| `leds[1–7]`  | E19, U19, V19, W18, U15, U14, V14 | — |
| `done_led`   | L1   | PASS indicator (plaintext matched) |

---

## Clock Domains

The design uses two clock domains:

| Clock      | Source              | Frequency  | Used for              |
|------------|---------------------|------------|-----------------------|
| `clk_fpga` | W5 (board crystal)  | 100 MHz    | UART, FSM control     |
| `aes_clk`  | `clk_fpga` ÷ 8 via BUFG | 12.5 MHz | AES decrypt core   |

The XDC constrains these as asynchronous groups. The wrapper ensures AES inputs are stable before `WAIT_AES` begins and samples the output only after a fixed 2048-cycle delay, making the CDC paths safe despite having no formal synchronizer.


### Hardware Test (Python)

Requires `pyserial`:

```bash
pip install pyserial
python uart_aes_decrypt_test.py COMx
```

Replace `COMx` with the correct serial port (`/dev/ttyUSB0` on Linux).

**Optional arguments:**

```
--baud      Baud rate (default: 115200)
--cipher    Ciphertext as hex string (default: see below)
--key       AES key as hex string
--expected  Expected plaintext as hex string
--timeout   Serial read timeout in seconds (default: 3.0)
```

**Example output (PASS):**

```
Cipher HEX:    C8 F7 D4 3C D9 8F 2E 5A E1 10 01 07 71 70 58 75
Key HEX:       00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F
Received HEX:  41 42 43 44 45 46 47 48 49 4A 4B 4C 4D 4E 4F 52
Received ASCII:ABCDEFGHIJKLMNOR
Expected HEX:  41 42 43 44 45 46 47 48 49 4A 4B 4C 4D 4E 4F 52
Expected ASCII:ABCDEFGHIJKLMNOR
PASS
```

---

## Test Vectors

| Field            | Value                                      |
|------------------|--------------------------------------------|
| **Ciphertext**   | `C8 F7 D4 3C D9 8F 2E 5A E1 10 01 07 71 70 58 75` |
| **Key**          | `00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F` |
| **Plaintext**    | `41 42 43 44 45 46 47 48 49 4A 4B 4C 4D 4E 4F 52` |
| **ASCII**        | `ABCDEFGHIJKLMNOR`                          |

A second test :

| Field            | Value                                      |
|------------------|--------------------------------------------|
| **Ciphertext**   | `31 96 DE 4D 67 2D 06 A0 D5 2D 94 7A E3 EE A7 89` |
| **Key**          | `00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F` |
| **Plaintext**    | `41 42 43 44 45 46 47 48 49 4A 4B 4C 4D 4E 4F 54` |
| **ASCII**        | `ABCDEFGHIJKLMNOT`                          |
