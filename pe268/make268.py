# Hand-writes a 268-byte exe for Windows x64. The program only returns exit code 42.
# Run: python make268.py  ->  tiny268.exe ; check: run tiny268.exe, then `echo %ERRORLEVEL%`
import struct

buf = bytearray(268)                             # 268 zero bytes, filled in slot by slot

buf[0x00:0x02] = b"MZ"                           # DOS signature: Windows looks at these 2 bytes first
buf[0x04:0x08] = b"PE\0\0"                       # PE signature, placed right at byte 4
struct.pack_into("<H", buf, 0x08, 0x8664)        # Machine: x64 machine code
struct.pack_into("<H", buf, 0x0A, 0)             # NumberOfSections: no section at all
buf[0x0C:0x10] = bytes([0x6A, 0x2A, 0x58, 0xC3])  # machine code: push 42 ; pop rax ; ret
struct.pack_into("<H", buf, 0x18, 0xF0)          # SizeOfOptionalHeader: 240 bytes
struct.pack_into("<H", buf, 0x1A, 0x0022)        # Characteristics: executable file, uses 64-bit addresses
struct.pack_into("<H", buf, 0x1C, 0x020B)        # Magic: 64-bit header (PE32+)
struct.pack_into("<I", buf, 0x2C, 0x0C)          # AddressOfEntryPoint: execution starts at byte 0x0C
struct.pack_into("<Q", buf, 0x34, 0x140000000)   # ImageBase: the address it would like to be loaded at
struct.pack_into("<I", buf, 0x3C, 4)             # SectionAlignment = 4, and this is also e_lfanew = 4
struct.pack_into("<I", buf, 0x40, 4)             # FileAlignment = 4
struct.pack_into("<HH", buf, 0x4C, 6, 0)         # subsystem version 6.0
struct.pack_into("<I", buf, 0x54, 0x200)         # SizeOfImage: needs 512 bytes of memory
struct.pack_into("<H", buf, 0x60, 2)             # Subsystem: GUI, opens no console window
struct.pack_into("<QQ", buf, 0x64, 0x100000, 0x1000)  # stack: reserve 1 MB, commit 4 KB up front
struct.pack_into("<QQ", buf, 0x74, 0x100000, 0x1000)  # heap: reserve 1 MB, commit 4 KB up front

open("tiny268.exe", "wb").write(buf)
print(len(buf), "bytes")
