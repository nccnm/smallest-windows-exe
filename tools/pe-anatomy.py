# Reads the PE layout of the sample executables and writes tools/out/pe-anatomy.json.
# Run: python tools/pe-anatomy.py (after building hello/ and pe268/tiny268.exe)
# Every number comes from the file's own headers. Nothing is executed.
import json
import struct
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
samples = [
    ('tiny268', '268-byte PE hand-written in Python', 'pe268/tiny268.exe'),
    ('nasm', 'NASM, hand-built PE', 'hello/out/nasm_tiny64_cli.exe'),
    ('msvc_tuned', 'MSVC C without the CRT, tuned', 'hello/out/msvc_nocrt_tuned.exe'),
    ('msvc_plain', 'MSVC C without the CRT, default flags', 'hello/out/msvc_nocrt_plain.exe'),
    ('msvc_md', 'MSVC C with the dynamic CRT (/MD)', 'hello/out/msvc_crt_dynamic.exe'),
    ('msvc_mt', 'MSVC C with the static CRT (/MT)', 'hello/out/msvc_crt_static.exe'),
    ('rust_std', 'Rust std, optimized for size', 'hello/out/rust_std_min.exe'),
    ('go', 'Go, stripped', 'hello/out/go_stripped.exe'),
]
DIRS = ['export', 'import', 'resource', 'exception', 'security', 'basereloc', 'debug', 'architecture',
        'globalptr', 'tls', 'loadconfig', 'boundimport', 'iat', 'delayimport', 'clr', 'reserved']


def parse(path):
    d = path.read_bytes()
    e_lfanew = struct.unpack_from('<I', d, 0x3C)[0]
    assert d[:2] == b'MZ' and d[e_lfanew:e_lfanew + 4] == b'PE\0\0'
    machine, nsec, _, _, _, opt_size, _ = struct.unpack_from('<HHIIIHH', d, e_lfanew + 4)
    opt = e_lfanew + 24
    magic = struct.unpack_from('<H', d, opt)[0]
    assert magic == 0x20B, 'PE32+ only'
    entry = struct.unpack_from('<I', d, opt + 16)[0]
    sect_align, file_align = struct.unpack_from('<II', d, opt + 32)
    size_image, size_headers = struct.unpack_from('<II', d, opt + 56)
    subsystem = struct.unpack_from('<H', d, opt + 68)[0]
    ndirs = struct.unpack_from('<I', d, opt + 108)[0]
    dirs = {}
    for i in range(min(ndirs, 16)):
        off = opt + 112 + i * 8
        if off + 8 > len(d):
            break
        rva, size = struct.unpack_from('<II', d, off)
        if rva or size:
            dirs[DIRS[i]] = [rva, size]
    table = opt + opt_size
    sections = []
    for i in range(nsec):
        o = table + i * 40
        name = d[o:o + 8].rstrip(b'\0').decode('ascii', 'replace')
        vsize, va, rsize, rptr = struct.unpack_from('<IIII', d, o + 8)
        sections.append({'name': name, 'virtual_size': vsize, 'rva': va, 'raw_size': rsize, 'raw_offset': rptr})

    def rva_to_off(rva):
        for s in sections:
            if s['rva'] <= rva < s['rva'] + max(s['virtual_size'], s['raw_size']):
                return rva - s['rva'] + s['raw_offset']
        return rva if rva < size_headers else None

    imports = []
    if 'import' in dirs and sections:
        o = rva_to_off(dirs['import'][0])
        while o is not None and o + 20 <= len(d):
            ilt, _, _, name_rva, iat = struct.unpack_from('<IIIII', d, o)
            if not (ilt or name_rva or iat):
                break
            n = rva_to_off(name_rva)
            dll = d[n:d.index(b'\0', n)].decode('ascii', 'replace') if n is not None else '?'
            t = rva_to_off(ilt or iat)
            count = 0
            while t is not None and t + 8 <= len(d) and struct.unpack_from('<Q', d, t)[0]:
                count += 1
                t += 8
            imports.append({'dll': dll, 'functions': count})
            o += 20
    header_struct_end = table + nsec * 40
    raw_total = sum(s['raw_size'] for s in sections)
    first_raw = min((s['raw_offset'] for s in sections if s['raw_size']), default=len(d))
    return {
        'bytes': len(d), 'e_lfanew': e_lfanew, 'sections_count': nsec, 'optional_header_size': opt_size,
        'entry_rva': entry, 'section_alignment': sect_align, 'file_alignment': file_align,
        'size_of_headers': size_headers, 'size_of_image': size_image, 'subsystem': subsystem,
        'data_directories': dirs, 'sections': sections, 'imports': imports,
        # Byte budget of the file on disk.
        'budget': {
            'dos_header_and_stub': min(e_lfanew, len(d)),
            'pe_headers': min(header_struct_end, len(d)) - e_lfanew,
            'header_padding': max(0, first_raw - header_struct_end) if sections else 0,
            'sections_raw': raw_total,
            'after_sections': max(0, len(d) - max((s['raw_offset'] + s['raw_size'] for s in sections), default=len(d))),
        },
    }


out = []
for key, label, rel in samples:
    p = root / rel
    if not p.exists():
        print('missing', rel, file=sys.stderr)
        continue
    out.append({'id': key, 'label': label, 'path': rel, **parse(p)})
(root / 'tools' / 'out').mkdir(exist_ok=True)
(root / 'tools' / 'out' / 'pe-anatomy.json').write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding='utf-8', newline='\n')
for r in out:
    b = r['budget']
    print(f"{r['id']:11} {r['bytes']:>8} B  e_lfanew={r['e_lfanew']:<4} sec={r['sections_count']} falign={r['file_alignment']:<5} "
          f"hdr={b['dos_header_and_stub']}+{b['pe_headers']}+pad{b['header_padding']} raw={b['sections_raw']} tail={b['after_sections']}  "
          + ' '.join(f"{s['name']}:{s['raw_size']}" for s in r['sections'])
          + '  imports: ' + ', '.join(f"{i['dll']}({i['functions']})" for i in r['imports'])
          + '  dirs: ' + ','.join(r['data_directories']))
