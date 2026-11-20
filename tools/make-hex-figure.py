# Builds one annotated ImHex figure per sample exe of the primer (the eight files of data/pe-anatomy.json).
# Input: ImHex 1.38.1 full-window captures in tools/imhex/<tag>-<first address>.png (same 900 x 1030 window,
#        hex view scrolled to different addresses).
# Output: report/images/06/ui-imhex-<name>.png (English labels) and tools/imhex/vi/ui-imhex-<name>.png (Vietnamese).
# The figure keeps the real window (title bar, toolbar, footer) and stitches the hex rows of the captures into it.
# Every value printed in a label is read from the exe itself, so labels cannot disagree with the bytes shown.
#   python tools/make-hex-figure.py   (after building hello/ and pe268/tiny268.exe; needs Pillow and Segoe UI / Consolas)
import json
import struct
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

sys.stdout.reconfigure(encoding='utf-8')
root = Path(__file__).resolve().parent.parent

# capture prefix, output name, exe, capture start addresses, display name vi / en
FILES = [
    ('tiny268', 'tiny268', 'pe268/tiny268.exe', [0x000], 'PE 268 byte viết tay bằng Python', '268-byte PE hand-written in Python'),
    ('nasm', 'nasm', 'hello/out/nasm_tiny64_cli.exe', [0x000, 0x140], 'NASM, tự dựng PE', 'NASM, hand-built PE'),
    ('msvc_tuned', 'msvc-tuned', 'hello/out/msvc_nocrt_tuned.exe', [0x000, 0x140], 'MSVC C không CRT, đã tinh chỉnh', 'MSVC C without the CRT, tuned'),
    ('win', 'exe-layout', 'hello/out/msvc_nocrt_plain.exe', [0x000, 0x140, 0x3C0, 0x5F0, 0x7D0], 'MSVC C không CRT, cờ mặc định', 'MSVC C without the CRT, default flags'),
    ('msvc_md', 'msvc-md', 'hello/out/msvc_crt_dynamic.exe', [0x000, 0x140, 0x3C0], 'MSVC C có CRT động (/MD)', 'MSVC C with the dynamic CRT (/MD)'),
    ('msvc_mt', 'msvc-mt', 'hello/out/msvc_crt_static.exe', [0x000, 0x140, 0x3C0], 'MSVC C có CRT tĩnh (/MT)', 'MSVC C with the static CRT (/MT)'),
    ('rust_std', 'rust-std', 'hello/out/rust_std_min.exe', [0x000, 0x140, 0x3C0], 'Rust std, tối ưu kích thước', 'Rust std, optimized for size'),
    ('go', 'go', 'hello/out/go_stripped.exe', [0x000, 0x140, 0x3C0], 'Go, đã strip', 'Go, stripped'),
]

# ---- geometry of the ImHex window in the captures ----
ROW_H, ROW0_Y, WIN_W, TOP_H, BOT_Y = 24, 121, 900, 121, 906
bx = lambda c: 126 + 32 * c if c < 8 else 392 + 32 * (c - 8)   # left edge of hex cell c
ax = lambda c: int(658 + 10.95 * c)                              # left edge of ASCII cell c

YEL, AMB, BLU, CYA, GRN, VIO, ORA, PAD = (237, 161, 0), (176, 122, 30), (42, 120, 214), (27, 160, 190), (27, 175, 122), (128, 110, 235), (235, 104, 52), (120, 120, 120)
HEADER_PARTS = ('DOS header', 'DOS stub', 'PE header', 'Section table')

L = {
    'vi': dict(
        title='{name}: {size} byte, xem bằng ImHex', num=lambda n: f'{n:,}'.replace(',', ' '),
        sub='Cửa sổ ImHex 1.38.1 thật, ghép từ {k} ảnh chụp. Màu nền, khung sáng và số tròn là phần vẽ thêm. Cột Address là địa chỉ của byte đầu mỗi dòng, mỗi dòng 16 byte.',
        sub1='Cửa sổ ImHex 1.38.1 thật. Màu nền, khung sáng và số tròn là phần vẽ thêm. Cột Address là địa chỉ của byte đầu mỗi dòng, mỗi dòng 16 byte.',
        zero='từ {a} tới {b}: {n} byte toàn số 0', sec='{a} tới {b}: section {s}, {n} byte trong file, không vẽ', rest='{a} tới {b}: {n} byte còn lại của header, không vẽ',
        unit='byte', used='dùng thật', note='Số nhiều byte được ghi ngược: byte thấp đứng trước. Ví dụ D0 00 00 00 là 0x000000D0. Vùng nền xám là byte đệm.',
        reg={'Section table': 'Bảng section'},
        mz=('"MZ"', 'chữ ký DOS. Windows nhìn hai byte này đầu tiên'), lfa=('e_lfanew = 0x{v:X}', 'PE header bắt đầu ở địa chỉ 0x{v:X}'),
        lfa2=('e_lfanew = {v}, cũng là SectionAlignment = {v}', 'một ô dùng cho hai nghĩa, nhờ vậy PE header chồng lên DOS header'),
        stub=('Dòng chữ của DOS stub', '"This program cannot be run in DOS mode"'), pe=('"PE\\0\\0"', 'chữ ký PE, đúng chỗ e_lfanew chỉ tới'),
        mach=('Machine = 0x{v:X}', 'mã máy x64'), nsec=('NumberOfSections = {v}', 'file có {v} section'), nsec0=('NumberOfSections = 0', 'không có section nào'),
        soh=('SizeOfOptionalHeader = {v} byte', ''), magic=('Magic = 0x{v:X}', 'header kiểu 64-bit (PE32+)'),
        ep=('AddressOfEntryPoint = 0x{v:X}', 'lệnh đầu tiên, tính theo địa chỉ trong bộ nhớ'), base=('ImageBase = 0x{v:X}', 'địa chỉ file muốn được nạp vào'),
        sa=('SectionAlignment = 0x{v:X}', 'trong bộ nhớ, section bắt đầu ở bội số {d}'), fa=('FileAlignment = 0x{v:X}', 'trong file, section bắt đầu ở bội số {d}'),
        sub_=('Subsystem = {v}', {2: 'chương trình cửa sổ (GUI), không mở console', 3: 'chương trình console'}),
        imp=('Data directory số 1', 'bảng import ở RVA 0x{v:X}, dài {n} byte'), noimp=('Data directory số 1 = 0', 'không có bảng import: file không xin DLL nào'),
        secrow=('Section {i}: "{s}"', 'nội dung ở 0x{p:X}, chiếm {raw} byte trong file, dùng thật {used} byte'),
        code=('Mã máy của chương trình', '{n} byte, bắt đầu ở đúng chỗ entry point chỉ tới'), code0=('Lệnh đầu tiên (entry point)', 'mã máy bắt đầu chạy từ đây'),
        code268=('Mã máy: 6A 2A 58 C3', 'push 42, pop rax, ret. Bốn byte này nằm ngay trong header'),
        hello=('Chuỗi "Hello, World!"', 'dữ liệu chương trình in ra'), dll=('Tên DLL xin dùng', '"{s}"'),
    ),
    'en': dict(
        title='{name}: {size} bytes, viewed in ImHex', num=lambda n: f'{n:,}',
        sub='The real ImHex 1.38.1 window, stitched from {k} captures. Tints, bright boxes and numbered circles were drawn on top. The Address column is the address of the first byte of each row; each row is 16 bytes.',
        sub1='The real ImHex 1.38.1 window. Tints, bright boxes and numbered circles were drawn on top. The Address column is the address of the first byte of each row; each row is 16 bytes.',
        zero='{a} to {b}: {n} zero bytes', sec='{a} to {b}: section {s}, {n} bytes in the file, not drawn', rest='{a} to {b}: the remaining {n} bytes of the headers, not drawn',
        unit='bytes', used='used', note='Multi-byte numbers are stored low byte first. For example D0 00 00 00 is 0x000000D0. Gray areas are padding.',
        reg={},
        mz=('"MZ"', 'the DOS signature. Windows looks at these two bytes first'), lfa=('e_lfanew = 0x{v:X}', 'the PE header starts at address 0x{v:X}'),
        lfa2=('e_lfanew = {v}, also SectionAlignment = {v}', 'one field with two meanings, which lets the PE header overlap the DOS header'),
        stub=('The DOS stub message', '"This program cannot be run in DOS mode"'), pe=('"PE\\0\\0"', 'the PE signature, right where e_lfanew points'),
        mach=('Machine = 0x{v:X}', 'x64 machine code'), nsec=('NumberOfSections = {v}', 'the file has {v} sections'), nsec0=('NumberOfSections = 0', 'no section at all'),
        soh=('SizeOfOptionalHeader = {v} bytes', ''), magic=('Magic = 0x{v:X}', '64-bit header (PE32+)'),
        ep=('AddressOfEntryPoint = 0x{v:X}', 'first instruction, as a memory address'), base=('ImageBase = 0x{v:X}', 'where the file would like to be loaded'),
        sa=('SectionAlignment = 0x{v:X}', 'in memory, sections start at multiples of {d}'), fa=('FileAlignment = 0x{v:X}', 'in the file, sections start at multiples of {d}'),
        sub_=('Subsystem = {v}', {2: 'window (GUI) program, opens no console', 3: 'console program'}),
        imp=('Data directory 1', 'import table at RVA 0x{v:X}, {n} bytes long'), noimp=('Data directory 1 = 0', 'no import table: the file asks for no DLL'),
        secrow=('Section {i}: "{s}"', 'content at 0x{p:X}, {raw} bytes in the file, {used} bytes really used'),
        code=('The machine code of the program', '{n} bytes, starting exactly where the entry point points'), code0=('First instruction (entry point)', 'the machine code starts running here'),
        code268=('Machine code: 6A 2A 58 C3', 'push 42, pop rax, ret. These four bytes sit inside the header'),
        hello=('The string "Hello, World!"', 'the data the program prints'), dll=('Name of the requested DLL', '"{s}"'),
    ),
}

font = lambda n, sz: ImageFont.truetype(f'C:/Windows/Fonts/{n}', sz)
F_T, F_S, F_H, F_L, F_R, F_M, F_B, F_BS, F_G = (font('segoeuib.ttf', 34), font('segoeui.ttf', 21), font('segoeuib.ttf', 24), font('segoeui.ttf', 22),
                                                font('segoeuib.ttf', 25), font('consolab.ttf', 22), font('segoeuib.ttf', 19), font('segoeuib.ttf', 17), font('segoeui.ttf', 17))
INK, INK2, PAGE = (240, 240, 240), (178, 178, 178), (24, 24, 27)
MX, GAP_H, LEG_W = 22, 34, 650
LEG_X = MX + WIN_W + 34
W = LEG_X + LEG_W + 22


CLEAN = Image.open(root / 'tools/imhex/win-000.png').convert('RGB')


def wrap(d, text, fnt, width):
    out, cur = [], ''
    for w in text.split(' '):
        if cur and d.textlength(cur + ' ' + w, font=fnt) > width:
            out.append(cur); cur = w
        else:
            cur = (cur + ' ' + w).strip()
    return out + [cur]


def analyse(exe):
    """Regions, fields and section list of one PE file. A field is (key, format args, [(offset, length), ...])."""
    u16 = lambda o: struct.unpack_from('<H', exe, o)[0]
    u32 = lambda o: struct.unpack_from('<I', exe, o)[0]
    u64 = lambda o: struct.unpack_from('<Q', exe, o)[0]
    pe = u32(0x3C); opt = pe + 24; nsec = u16(pe + 6); sec = opt + u16(pe + 20)
    assert exe[:2] == b'MZ' and exe[pe:pe + 4] == b'PE\0\0' and u16(opt) == 0x20B
    secs = []
    for i in range(nsec):
        o = sec + 40 * i
        nm = exe[o:o + 8].rstrip(b'\0').decode('latin1')
        vs, va, raw, ptr, ch = u32(o + 8), u32(o + 12), u32(o + 16), u32(o + 20), u32(o + 36)
        secs.append(dict(i=i + 1, o=o, name=nm, vs=vs, va=va, raw=raw, ptr=ptr, used=min(vs, raw) if vs else raw,
                         col=GRN if ch & 0x20 else (VIO if nm.startswith(('.rdata', '.data', '.idata')) else ORA)))
    hdr_end = sec + 40 * nsec
    regions = [(0, min(0x40, pe), YEL, 'DOS header')] + ([(0x40, pe, AMB, 'DOS stub')] if pe > 0x40 else [])
    regions.append((pe, min(len(exe), sec), BLU, 'PE header'))
    if nsec:
        regions.append((sec, hdr_end, CYA, 'Section table'))
    regions += [(s['ptr'], s['ptr'] + s['used'], s['col'], s['name']) for s in secs if s['raw']]
    overlap = pe + 56 == 0x3C                       # e_lfanew and SectionAlignment are the same four bytes
    F = [('mz', {}, [(0, 2)]), ('lfa2' if overlap else 'lfa', dict(v=pe), [(0x3C, 4)])]
    m = exe.find(b'This program cannot be run in DOS mode')
    if 0 < m < pe:
        F.append(('stub', {}, [(m, 38)]))
    F += [('pe', {}, [(pe, 4)]), ('mach', dict(v=u16(pe + 4)), [(pe + 4, 2)]), ('nsec' if nsec else 'nsec0', dict(v=nsec), [(pe + 6, 2)]),
          ('soh', dict(v=u16(pe + 20)), [(pe + 20, 2)]), ('magic', dict(v=u16(opt)), [(opt, 2)]), ('ep', dict(v=u32(opt + 16)), [(opt + 16, 4)]),
          ('base', dict(v=u64(opt + 24)), [(opt + 24, 8)])]
    if not overlap:
        F.append(('sa', dict(v=u32(opt + 32), d=u32(opt + 32)), [(opt + 32, 4)]))
    F += [('fa', dict(v=u32(opt + 36), d=u32(opt + 36)), [(opt + 36, 4)]), ('sub_', dict(v=u16(opt + 68)), [(opt + 68, 2)])]
    if opt + 128 <= len(exe) and u32(opt + 108) > 1:
        F.append(('imp', dict(v=u32(opt + 120), n=u32(opt + 124)), [(opt + 120, 8)]) if u32(opt + 120) else ('noimp', {}, [(opt + 120, 8)]))
    F += [('secrow', dict(i=s['i'], s=s['name'], p=s['ptr'], raw=s['raw'], used=s['used']), [(s['o'], 8), (s['o'] + 20, 4)]) for s in secs]
    ep = u32(opt + 16)
    host = next((s for s in secs if s['va'] <= ep < s['va'] + max(s['vs'], s['raw'])), None)
    epo = ep - host['va'] + host['ptr'] if host else ep
    if not secs:
        F.append(('code268', {}, [(epo, 4)]))
    elif host['used'] <= 96 and epo == host['ptr']:
        F.append(('code', dict(n=host['used']), [(epo, host['used'])]))
    else:
        F.append(('code0', {}, [(epo, 4)]))
    m = exe.find(b'Hello, World!')
    if m > 0:
        F.append(('hello', {}, [(m, 13)]))
    m = exe.lower().find(b'kernel32.dll')
    if m > 0:
        F.append(('dll', dict(s=exe[m:m + 12].decode()), [(m, 12)]))
    F.sort(key=lambda f: f[2][0][0])
    return dict(pe=pe, sec=sec, hdr_end=hdr_end, secs=secs, regions=regions, fields=F, epo=epo)


def build(tag, outname, exe_rel, starts, names, lang):
    t = L[lang]
    exe = (root / exe_rel).read_bytes()
    A = analyse(exe)
    caps = {a: Image.open(root / f'tools/imhex/{tag}-{a:03x}.png').convert('RGB') for a in starts}
    BG = CLEAN.getpixel((5, 112))
    covered = [a for a in range(0, len(exe), 16) if any(0 <= a - s <= 31 * 16 for s in starts)]
    big = len(exe) > covered[-1] + 16
    if big:   # large file: only the headers are drawn, each section becomes one note line
        assert A['hdr_end'] <= covered[-1], (tag, hex(A['hdr_end']))
        covered = [a for a in covered if a < ((A['hdr_end'] + 15) // 16 + 1) * 16]

    def row_img(addr):
        a0 = max(s for s in starts if s <= addr and addr - s <= 31 * 16)
        y = ROW0_Y + ROW_H * ((addr - a0) // 16)
        return caps[a0].crop((0, y, 862, y + ROW_H))

    # collapse stretches of four or more all-zero rows
    plan, i = [], 0   # ('row', addr) or ('gap', text)
    while i < len(covered):
        j = i
        while j < len(covered) and not any(exe[covered[j]:covered[j] + 16]):
            j += 1
        if j - i >= 4:
            a, b = covered[i], min(len(exe), covered[j - 1] + 16)
            plan.append(('gap', t['zero'].format(a=f'0x{a:03X}', b=f'0x{b - 1:03X}', n=t['num'](b - a)))); i = j
        else:
            plan.append(('row', covered[i])); i += 1
    if big:
        end, first = covered[-1] + 16, min(s['ptr'] for s in A['secs'] if s['raw'])
        if first > end:
            plan.append(('gap', t['rest'].format(a=f'0x{end:03X}', b=f'0x{first - 1:03X}', n=t['num'](first - end))))
        plan += [('gap', t['sec'].format(a=f'0x{s["ptr"]:X}', b=f'0x{s["ptr"] + s["raw"] - 1:X}', s=s['name'], n=t['num'](s['raw']))) for s in A['secs'] if s['raw']]

    im = Image.new('RGB', (W, 6000), PAGE)
    d = ImageDraw.Draw(im, 'RGBA')
    d.text((MX, 20), t['title'].format(name=names[lang], size=t['num'](len(exe))), font=F_T, fill=INK)
    y = 72
    for line in wrap(d, t['sub'].format(k=len(starts)) if len(starts) > 1 else t['sub1'], F_S, W - 2 * MX):
        d.text((MX, y), line, font=F_S, fill=INK2); y += 29
    wy = y + 16
    im.paste(CLEAN.crop((0, 0, WIN_W, TOP_H)), (MX, wy))            # toolbar and column header from a capture with no tooltip
    im.paste(caps[0].crop((0, 0, WIN_W, 38)), (MX, wy))             # title bar of this file
    y = wy + TOP_H
    ypos = {}
    for kind, v in plan:
        h = ROW_H if kind == 'row' else GAP_H
        d.rectangle((MX, y, MX + WIN_W - 1, y + h), fill=BG + (255,))
        if kind == 'row':
            im.paste(row_img(v), (MX, y)); ypos[v] = y
        else:
            tw = d.textlength(v, font=F_G); cy = y + h // 2
            d.line((MX + 14, cy, MX + 60, cy), fill=(110, 110, 110)); d.text((MX + 72, cy), v, font=F_G, fill=(200, 200, 200), anchor='lm')
            d.line((MX + 84 + tw, cy, MX + 850, cy), fill=(110, 110, 110))
        y += h
    d.rectangle((MX, y, MX + WIN_W - 1, y + 8), fill=BG + (255,)); y += 8
    im.paste(CLEAN.crop((0, BOT_Y, WIN_W, 1030)), (MX, y))
    wend = y + 1030 - BOT_Y
    d.rectangle((MX, wy, MX + WIN_W - 1, wend - 1), outline=(70, 70, 76, 255))

    def cells(a, b):
        for addr, yy in ypos.items():
            c0, c1 = max(a, addr) - addr, min(b, addr + 16, len(exe)) - addr
            if c0 < c1:
                yield yy, c0, c1 - 1

    def cell_fill(yy, c, col, alpha):
        d.rectangle((MX + bx(c), yy, MX + bx(c) + 31, yy + ROW_H - 1), fill=col + (alpha,))
        d.rectangle((MX + ax(c), yy, MX + ax(c + 1) - 1, yy + ROW_H - 1), fill=col + (alpha,))

    region_of = lambda o: next((r for r in A['regions'] if r[0] <= o < r[1]), None)
    for addr, yy in ypos.items():
        for c in range(min(16, len(exe) - addr)):
            r = region_of(addr + c)
            cell_fill(yy, c, r[2] if r else PAD, 62 if r else 50)
        r = region_of(addr)
        if r:
            d.rectangle((MX + 2, yy, MX + 7, yy + ROW_H - 1), fill=r[2] + (255,))

    ly, n = wy, 0
    for a, b, col, nm in A['regions']:
        if not any(True for _ in cells(a, b)):
            continue
        bright = tuple(min(255, int(v * 0.45 + 140)) for v in col)
        ly = max(ly + 14, next(cells(a, b))[0] - 34)
        size = f'{t["num"](b - a)} {t["unit"]}' + ('' if nm in HEADER_PARTS else f' {t["used"]}')
        title = t['reg'].get(nm, nm)
        d.rectangle((LEG_X, ly + 4, LEG_X + 7, ly + 30), fill=col + (255,))
        d.text((LEG_X + 18, ly), title, font=F_R, fill=bright + (255,))
        d.text((LEG_X + 30 + d.textlength(title, font=F_R), ly + 5), f'0x{a:03X}, {size}', font=F_S, fill=INK2)
        ly += 42
        for key, args, ranges in A['fields']:
            if not a <= ranges[0][0] < b or not any(True for _ in cells(ranges[0][0], ranges[0][0] + ranges[0][1])):
                continue
            n += 1
            head, rest = t[key]
            if isinstance(rest, dict):
                rest = rest.get(args['v'], '')
            fa = dict(args)
            for k in ('d', 'raw', 'used', 'n'):
                if k in fa and isinstance(fa[k], int):
                    fa[k] = t['num'](fa[k])
            head, rest = head.format(**fa), rest.format(**fa)
            for o, ln in ranges:
                for yy, c0, c1 in cells(o, o + ln):
                    d.rectangle((MX + bx(c0), yy, MX + bx(c1) + 30, yy + ROW_H - 1), fill=bright + (70,), outline=bright + (255,), width=2)
                    d.rectangle((MX + ax(c0), yy, MX + ax(c1 + 1) - 1, yy + ROW_H - 1), fill=bright + (70,))
            yy, c0, _ = next(cells(ranges[0][0], ranges[0][0] + ranges[0][1]))
            cx, cy = MX + bx(c0) - 5, yy - 1
            d.ellipse((cx - 13, cy - 13, cx + 13, cy + 13), fill=bright + (255,), outline=(0, 0, 0, 255), width=2)
            d.text((cx, cy), str(n), font=F_BS, fill=(0, 0, 0), anchor='mm')
            d.ellipse((LEG_X, ly, LEG_X + 34, ly + 34), fill=bright + (255,))
            d.text((LEG_X + 17, ly + 17), str(n), font=F_B, fill=(0, 0, 0), anchor='mm')
            d.text((LEG_X + 46, ly + 6), f'0x{ranges[0][0]:03X}', font=F_M, fill=bright + (255,))
            tx = LEG_X + 122
            hw = d.textlength(head, font=F_H)
            if rest and hw + 14 + d.textlength(rest, font=F_L) <= W - MX - tx:   # short entry: one line
                d.text((tx, ly + 2), head, font=F_H, fill=INK); d.text((tx + hw + 14, ly + 4), rest, font=F_L, fill=(205, 205, 205)); ly += 46
                continue
            for line in wrap(d, head, F_H, W - MX - tx):
                d.text((tx, ly + 2), line, font=F_H, fill=INK); ly += 32
            for line in (wrap(d, rest, F_L, W - MX - tx) if rest else []):
                d.text((tx, ly + 1), line, font=F_L, fill=(205, 205, 205)); ly += 30
            ly += 12
    y = max(wend, ly) + 18
    for line in wrap(d, t['note'], F_S, W - 2 * MX):
        d.text((MX, y), line, font=F_S, fill=INK2); y += 29
    out = root / ('tools/imhex/vi' if lang == 'vi' else 'report/images/06') / f'ui-imhex-{outname}.png'
    out.parent.mkdir(parents=True, exist_ok=True)
    im.crop((0, 0, W, y + 16)).save(out, optimize=True)
    return dict(file=out.name, width=W, height=y + 16, fields=n)


summary = {}
for tag, outname, exe_rel, starts, vi, en in FILES:
    for lang in ('vi', 'en'):
        r = build(tag, outname, exe_rel, starts, {'vi': vi, 'en': en}, lang)
        summary.setdefault(lang, []).append(r)
    A = analyse((root / exe_rel).read_bytes())
    print(f"{outname}: {r['width']}x{r['height']}, {r['fields']} fields, pe=0x{A['pe']:X}, hdr_end=0x{A['hdr_end']:X}, entry file offset 0x{A['epo']:X}; " +
          ', '.join(f"{s['name']} ptr=0x{s['ptr']:X} raw={s['raw']} used={s['used']}" for s in A['secs']))
(root / 'tools/imhex/figures.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
