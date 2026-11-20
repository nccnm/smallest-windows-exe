"""Rebuilds the 20-byte DOS .COM file "HELLO WORLD" (gnostice article, 2011).

A .COM file has no header: the first byte is already a machine instruction. DOS copies the whole file
into memory at address 0x100 and runs it from there. This is 16-bit code for the 8086 CPU.
"""
code = bytes([
    0xB4, 0x09,        # 0x100  mov ah, 9      select DOS service 9: print a string
    0xBA, 0x08, 0x01,  # 0x102  mov dx, 0x108  string address = 0x100 + 8
    0xCD, 0x21,        # 0x105  int 0x21       call DOS
    0xC3,              # 0x107  ret            return control to DOS
])
text = b"HELLO WORLD$"   # 0x108  service 9 prints until it meets a $ sign
data = code + text
assert len(data) == 20
open("MYHELLO.COM", "wb").write(data)
print(len(data), "bytes:", data.hex())
