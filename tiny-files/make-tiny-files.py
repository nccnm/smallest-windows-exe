# Writes the six files of the "old records" test into this folder: 20.com, 97.exe, 133.exe, 252.exe,
# 267.exe and 268.exe. Then run run-all.cmd to see which ones Windows accepts.
#   20.com   make20.py (the 20-byte DOS .COM Hello World)
#   97/133/252.exe   sweep2.build32(size): PE32 (x86) headers with e_lfanew = 4, no sections, cut to size
#   268.exe  tinype64.build(268, SizeOfHeaders = 0): byte-identical to pe268/make268.py's tiny268.exe
#   267.exe  268.exe with the last byte cut off
# Nothing is executed here. Run: python make-tiny-files.py
import os
import runpy
import shutil

HERE = os.path.dirname(os.path.abspath(__file__))
os.chdir(HERE)

from sweep2 import build32
from tinype64 import build

runpy.run_path("make20.py")                      # writes MYHELLO.COM
shutil.copyfile("MYHELLO.COM", "20.com")
files = {f"{s}.exe": build32(s) for s in (97, 133, 252)}
files["268.exe"] = build(268, sizeofheaders=0, sizeofimage=0x200)
files["267.exe"] = files["268.exe"][:267]
for name, data in files.items():
    with open(name, "wb") as f:
        f.write(data)
    print(name, len(data), "bytes")
