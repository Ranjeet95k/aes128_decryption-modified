import argparse
import sys
import time

import serial

DEFAULT_CIPHER = bytes.fromhex("C8 F7 D4 3C D9 8F 2E 5A E1 10 01 07 71 70 58 75")
DEFAULT_KEY = bytes.fromhex("00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F")
DEFAULT_EXPECTED = bytes.fromhex("41 42 43 44 45 46 47 48 49 4A 4B 4C 4D 4E 4F 52")


def hex_string(data):
    return " ".join(f"{b:02X}" for b in data)


def printable_ascii(data):
    return "".join(chr(b) if 32 <= b <= 126 else "." for b in data)


def main():
    parser = argparse.ArgumentParser(description="Basys 3 UART AES-128 decrypt test")
    parser.add_argument("port", help="Serial port, for example COM9")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--cipher", default=DEFAULT_CIPHER.hex(), help="16 ciphertext bytes as hex")
    parser.add_argument("--key", default=DEFAULT_KEY.hex(), help="16 AES key bytes as hex")
    parser.add_argument("--expected", default=DEFAULT_EXPECTED.hex(), help="16 expected plaintext bytes as hex")
    parser.add_argument("--timeout", type=float, default=3.0)
    args = parser.parse_args()

    cipher = bytes.fromhex(args.cipher)
    key = bytes.fromhex(args.key)
    expected = bytes.fromhex(args.expected)
    if len(cipher) != 16 or len(key) != 16 or len(expected) != 16:
        print(f"ERROR: cipher, key, and expected plaintext must each be 16 bytes, got {len(cipher)}, {len(key)}, and {len(expected)}")
        return 2

    payload = cipher + key + expected

    try:
        with serial.Serial(args.port, args.baud, timeout=args.timeout) as ser:
            ser.reset_input_buffer()
            ser.reset_output_buffer()
            time.sleep(0.1)
            ser.write(payload)
            ser.flush()
            received = ser.read(16)
    except serial.SerialException as exc:
        print(f"ERROR: could not open/use serial port {args.port}: {exc}")
        return 2

    print(f"Cipher HEX:    {hex_string(cipher)}")
    print(f"Key HEX:       {hex_string(key)}")
    print(f"Received HEX:  {hex_string(received)}")
    print(f"Received ASCII:{printable_ascii(received)}")
    print(f"Expected HEX:  {hex_string(expected)}")
    print(f"Expected ASCII:{printable_ascii(expected)}")

    if received == expected:
        print("PASS")
        return 0

    print("FAIL")
    return 1


if __name__ == "__main__":
    sys.exit(main())
