# Size floor sweep x64 and x86 (WoW64) with SizeOfHeaders=0 (R1 scratch)
import os, sys, struct, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tinype64 import build, test

RET42 = bytes([0x6A, 0x2A, 0x58, 0xC3])


def build32(size=252, entry=0x0C, soi=0x200, soh=0, sub=2, subver=(6, 0), nrva=0,
            imagebase=0x400000, chars=0x0103, nsect=0, opthdr=0xE0, pad=0x200):
    b = bytearray(max(size, pad))
    b[0:2] = b"MZ"; b[4:8] = b"PE\0\0"
    struct.pack_into("<HHIIIHH", b, 0x08, 0x14C, nsect, 0, 0, 0, opthdr, chars)
    struct.pack_into("<H", b, 0x1C, 0x10B)
    struct.pack_into("<I", b, 0x2C, entry)
    struct.pack_into("<I", b, 0x38, imagebase)
    struct.pack_into("<II", b, 0x3C, 4, 4)
    struct.pack_into("<HH", b, 0x4C, *subver)
    struct.pack_into("<II", b, 0x54, soi, soh)
    struct.pack_into("<H", b, 0x60, sub)
    struct.pack_into("<IIII", b, 0x64, 0x100000, 0x1000, 0x100000, 0x1000)
    struct.pack_into("<I", b, 0x78, nrva)
    b[entry:entry + 4] = RET42
    return bytes(b[:size])

if __name__ == "__main__":   # guard added so make-tiny-files.py can import build32 without running the sweep
    res = []
    for s in (268, 267, 266, 264, 260):
        res.append(test(f"s2_x64_{s}_soh0", build(s, sizeofheaders=0, sizeofimage=0x200)))
        res.append(test(f"s2_x64_{s}_soh0_soi{s}", build(s, sizeofheaders=0, sizeofimage=s)))
    for s in (252, 251, 248, 240, 200, 133, 97):
        res.append(test(f"s2_x86_{s}", build32(s)))
    res.append(test("s2_x86_252_soi252", build32(252, soi=252)))
    res.append(test("s2_x86_268", build32(268)))
    # PE32 with SizeOfOptionalHeader small still needs file >= 252?
    res.append(test("s2_x86_252_opthdr0", build32(252, opthdr=0)))
    json.dump(res, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "results_sweep2.json"), "w"), indent=1)
