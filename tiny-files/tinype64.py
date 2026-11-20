# Parametric x64 tiny PE generator + runner (R1 scratch, 2026-11-17)
# Layout: e_lfanew = 4 (PE header overlaps DOS header), NumberOfSections = 0,
# SectionAlignment = FileAlignment = 4, code lives inside the header.
import struct, subprocess, sys, os, ctypes, json

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "bin")
os.makedirs(OUT, exist_ok=True)

CODE_RET42 = bytes([0x6A, 0x2A, 0x58, 0xC3])  # push 42 ; pop rax ; ret


def build(size=268, entry=0x0C, code=CODE_RET42, nrva=0, sub=2, subver=(6, 0),
          osver=(0, 0), sizeofimage=None, sizeofheaders=None, opthdr=0xF0,
          imagebase=0x0000000140000000, chars=0x0022, stack=(0x100000, 0x1000),
          heap=(0x100000, 0x1000), sectalign=4, filealign=4, codeoff=None,
          nsections=0, pad_to=None):
    buf = bytearray(max(size, 0x200))
    buf[0:2] = b"MZ"
    buf[4:8] = b"PE\0\0"
    struct.pack_into("<HHIIIHH", buf, 0x08, 0x8664, nsections, 0, 0, 0, opthdr, chars)
    o = 0x1C
    struct.pack_into("<H", buf, o, 0x20B)
    struct.pack_into("<I", buf, 0x2C, entry)              # AddressOfEntryPoint
    struct.pack_into("<Q", buf, 0x34, imagebase)          # ImageBase
    struct.pack_into("<II", buf, 0x3C, sectalign, filealign)  # SectionAlignment @0x3C doubles as e_lfanew
    struct.pack_into("<HH", buf, 0x44, *osver)
    struct.pack_into("<HH", buf, 0x4C, *subver)
    soi = sizeofimage if sizeofimage is not None else max(size, 0x200)
    soh = sizeofheaders if sizeofheaders is not None else size
    struct.pack_into("<II", buf, 0x54, soi, soh)
    struct.pack_into("<H", buf, 0x60, sub)
    struct.pack_into("<QQQQ", buf, 0x64, stack[0], stack[1], heap[0], heap[1])
    struct.pack_into("<I", buf, 0x88, nrva)
    co = entry if codeoff is None else codeoff
    buf[co:co + len(code)] = code
    return bytes(buf[:size])


def run(path, timeout=10):
    # Suppress hard-error dialogs; child inherits error mode
    ctypes.windll.kernel32.SetErrorMode(0x0001 | 0x0002 | 0x8000)
    try:
        p = subprocess.run([path], timeout=timeout, capture_output=True)
        rc = p.returncode & 0xFFFFFFFF
        return {"status": "ran", "exit": rc, "exit_hex": hex(rc)}
    except subprocess.TimeoutExpired:
        return {"status": "timeout"}
    except OSError as e:
        return {"status": "createprocess_failed", "winerror": getattr(e, "winerror", None), "msg": str(e)}


def test(name, data, timeout=10):
    path = os.path.join(OUT, name + ".exe")
    with open(path, "wb") as f:
        f.write(data)
    exists = os.path.exists(path)
    r = run(path, timeout) if exists else {"status": "file_vanished"}
    r.update({"name": name, "size": len(data)})
    print(json.dumps(r))
    return r


if __name__ == "__main__":
    results = []
    # Baseline: 268 bytes, code in TimeDateStamp field
    results.append(test("x64_268_ret42", build(268)))
    # Size sweep: truncate the same image
    for s in (267, 264, 260, 256, 252, 248, 240, 224, 200, 160, 128, 100):
        results.append(test(f"x64_{s}_ret42", build(s, sizeofheaders=s, sizeofimage=0x200)))
    # 268 with SizeOfOptionalHeader smaller (does loader read full opt header anyway?)
    results.append(test("x64_268_opthdr0x70", build(268, opthdr=0x70)))
    # Data dirs present (nrva=16) - 268 bytes ends inside DataDirectory[14]
    results.append(test("x64_268_nrva16", build(268, nrva=16)))
    # Console subsystem
    results.append(test("x64_268_console", build(268, sub=3)))
    # Subsystem version low
    results.append(test("x64_268_subver4", build(268, subver=(4, 0))))
    results.append(test("x64_268_subver0", build(268, subver=(0, 0))))
    # Larger SectionAlignment (normal 0x1000 / 0x200)
    # Zero stack/heap
    results.append(test("x64_268_zerostack", build(268, stack=(0, 0), heap=(0, 0))))
    # ImageBase low (0x400000) is impossible with e_lfanew=4 trick; test e_lfanew=4 is forced
    with open(os.path.join(HERE, "results_tinype64.json"), "w") as f:
        json.dump(results, f, indent=1)
