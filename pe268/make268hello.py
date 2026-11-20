# Hand-writes a 268-byte exe for Windows x64 that prints "Hello, World!".
# Same frame as make268.py (e_lfanew = 4, no sections), but the machine code is longer and is packed
# into header fields the loader does not read:
#   0x0C-0x17  TimeDateStamp, PointerToSymbolTable, NumberOfSymbols
#   0x1E-0x2B  linker version, SizeOfCode, SizeOfInitializedData, SizeOfUninitializedData
#   0x8C-0x10B the 16 data directories, unused because NumberOfRvaAndSizes = 0. Only the field 0x94-0x97
#              (import table address) must be 0: on the first run of a new file, Windows still reads it
# With no sections the loader skips the import table, so the code finds WriteFile by itself: it reads the
# PEB to get the kernel32 address, then walks kernel32's export table. The stdout handle also comes from the PEB.
# Matching assembly source: hello268.asm. Run: python make268hello.py -> hello268.exe
import struct

buf = bytearray(268)                             # 268 zero bytes, filled in slot by slot

buf[0x00:0x02] = b"MZ"                           # DOS signature
buf[0x04:0x08] = b"PE\0\0"                       # PE signature, placed right at byte 4
struct.pack_into("<H", buf, 0x08, 0x8664)        # Machine: x64 machine code
struct.pack_into("<H", buf, 0x0A, 0)             # NumberOfSections: no section at all
struct.pack_into("<H", buf, 0x18, 0xF0)          # SizeOfOptionalHeader: 240 bytes
struct.pack_into("<H", buf, 0x1A, 0x0022)        # Characteristics: executable file, 64-bit addresses
struct.pack_into("<H", buf, 0x1C, 0x020B)        # Magic: 64-bit header (PE32+)
struct.pack_into("<I", buf, 0x2C, 0x0C)          # AddressOfEntryPoint: execution starts at byte 0x0C
struct.pack_into("<Q", buf, 0x34, 0x140000000)   # ImageBase
struct.pack_into("<I", buf, 0x3C, 4)             # SectionAlignment = 4, and this is also e_lfanew = 4
struct.pack_into("<I", buf, 0x40, 4)             # FileAlignment = 4
struct.pack_into("<HH", buf, 0x4C, 6, 0)         # subsystem version 6.0
struct.pack_into("<I", buf, 0x54, 0x200)         # SizeOfImage: 512 bytes of memory
struct.pack_into("<H", buf, 0x60, 3)             # Subsystem: console, so there is a stdout
struct.pack_into("<QQ", buf, 0x64, 0x100000, 0x1000)  # stack: reserve 1 MB, commit 4 KB up front
struct.pack_into("<QQ", buf, 0x74, 0x100000, 0x1000)  # heap: reserve 1 MB, commit 4 KB up front

code = {
    0x0C: "6A60 5E 6548AD"      # rax = PEB (reads gs:[0x60])
          "488B5820"            # rbx = PEB->ProcessParameters
          "EB06",               # jump to 0x1E
    0x1E: "488B4018"            # rax = PEB->Ldr
          "488B4020"            # rax = first module: the exe itself
          "488B00"              # next module: ntdll
          "EB61",               # jump to 0x8C
    0x8C: "488B00"              # next module: kernel32
          "488B6820"            # rbp = kernel32 load address
          "6800000000"          # push 0: argument 5 lpOverlapped. The four zero bytes land exactly on field 0x94,
                                # the import table address, the only field here that must be 0 (see above)
          "4883EC20"            # reserve 32 bytes of stack for the called function
          "8B453C 8B940588000000 4801EA"   # rdx = kernel32 export table
          "8B4A18"              # ecx = number of function names
          "448B4220 4901E8"     # r8 = array of function names
          "FFC9 418B3488"       # loop from the end: esi = name number ecx
          "817C3506696C6500 75F0"          # does the name have "ile\0" at byte 6? only WriteFile matches
          "8B7224 4801EE 0FB70C4E"         # ecx = ordinal of the function
          "8B721C 4801EE 8B048E 4801E8"    # rax = address of WriteFile
          "488B4B28"            # rcx = stdout handle, taken from ProcessParameters
          "488D1512000000"      # rdx = address of the string
          "6A0F 4158"           # r8 = 15 bytes
          "4C8D4C2430"          # r9 = memory slot that receives the number of bytes written
          "FFD0"                # WriteFile(stdout, string, 15, &written, 0)
          "31C0 4883C428 C3",   # return exit code 0
}
for at, hexes in code.items():
    b = bytes.fromhex(hexes.replace(" ", ""))
    buf[at:at + len(b)] = b
buf[0xF6:0x105] = b"Hello, World!\r\n"           # the string to print, right after the machine code

open("hello268.exe", "wb").write(buf)
print(len(buf), "bytes")
