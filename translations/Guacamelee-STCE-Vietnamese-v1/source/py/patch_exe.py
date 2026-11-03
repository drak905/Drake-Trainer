"""Build the Vietnamese-enabled Game.exe from the vanilla Game.exe (Guacamelee! STCE, Epic build 29-06-2023).

Adds a 7th entry ("Tiếng Việt") to the Options > Language list and makes language slot 6 (formerly the disabled
"Japanese" slot) the Vietnamese one.  All edits are listed in PATCHES / new section ".viet".

usage: python patch_exe.py <vanilla Game.exe> <out Game.exe>
"""
import hashlib
import struct
import sys

VANILLA_SHA256 = 'DE6CEC52F06B8E0FC835356B31AB80891BC4BA6431823B0EEF6FC02C480209F2'
IB = 0x400000


def rel32(src_va_after, dst_va):
    return struct.pack('<i', dst_va - src_va_after)


def build(data):
    data = bytearray(data)
    pe = struct.unpack_from('<I', data, 0x3C)[0]
    assert data[pe:pe + 4] == b'PE\0\0'
    nsec = struct.unpack_from('<H', data, pe + 6)[0]
    opt_size = struct.unpack_from('<H', data, pe + 20)[0]
    opt = pe + 24
    sec_tab = opt + opt_size
    assert nsec == 7
    secs = []
    for i in range(nsec):
        o = sec_tab + 40 * i
        name = bytes(data[o:o + 8]).rstrip(b'\0')
        vsize, va, rsize, roff = struct.unpack_from('<IIII', data, o + 8)
        secs.append((name, va, vsize, roff, rsize))

    def va2off(va):
        rva = va - IB
        for _, sva, vs, roff, rs in secs:
            if sva <= rva < sva + max(vs, rs):
                return rva - sva + roff
        raise ValueError(hex(va))

    # ---- new section .viet --------------------------------------------------------------------
    last = secs[-1]
    assert last[0] == b'.rsrc'
    new_va_rva = (last[1] + last[2] + 0xFFF) & ~0xFFF           # 0x9ef000 - IB
    new_va = IB + new_va_rva
    file_end = len(data)
    assert file_end == last[3] + last[4], 'unexpected overlay data'
    # header room for one more section header?
    first_raw = min(s[3] for s in secs)
    assert sec_tab + 40 * (nsec + 1) <= first_raw

    NAME = new_va + 0x00          # "Vietnamese\0"           (narrow, command line / logging table)
    TABLE = new_va + 0x10         # 7 x dword  list index -> language id
    WNAME = new_va + 0x30         # L"Vietnamese\0"          (wide, language-file header table)
    KEY = new_va + 0x50           # L"VietnameseLang\0"
    CODE = new_va + 0x80

    blob = bytearray(0x200)
    blob[0x00:0x0B] = b'Vietnamese\0'
    for i in range(7):
        struct.pack_into('<I', blob, 0x10 + 4 * i, i)
    blob[0x30:0x30 + 22] = 'Vietnamese'.encode('utf-16-le') + b'\0\0'
    blob[0x50:0x50 + 30] = 'VietnameseLang'.encode('utf-16-le') + b'\0\0'

    # code cave: add the 7th list entry, then run the instruction we overwrote and return
    FN_GETTEXT, FN_ADDITEM, RET = 0x76D880, 0x442590, 0x753D2C
    code = bytearray()
    code += b'\x68' + struct.pack('<I', KEY)                                  # push KEY
    code += b'\xE8' + rel32(CODE + len(code) + 5, FN_GETTEXT)                 # call GetText
    code += b'\x8B\x8F\xCC\x00\x00\x00'                                        # mov ecx,[edi+0xCC]
    code += b'\x83\xC4\x04'                                                    # add esp,4
    code += b'\x50'                                                            # push eax
    code += b'\xE8' + rel32(CODE + len(code) + 5, FN_ADDITEM)                 # call AddListItem
    code += b'\x8B\x8F\x14\x02\x00\x00'                                        # mov ecx,[edi+0x214] (original)
    code += b'\xE9' + rel32(CODE + len(code) + 5, RET)                        # jmp back
    blob[0x80:0x80 + len(code)] = code

    # ---- patches in existing code/data ---------------------------------------------------------
    def patch(va, old, new):
        o = va2off(va)
        assert bytes(data[o:o + len(old)]) == old, 'vanilla bytes differ at %x: %s' % (va, bytes(data[o:o + len(old)]).hex())
        assert len(old) == len(new)
        data[o:o + len(new)] = new

    # 1. language list builder: after the 6th AddListItem, jump to the cave
    patch(0x753D26, b'\x8B\x8F\x14\x02\x00\x00', b'\xE9' + rel32(0x753D26 + 5, CODE) + b'\x90')
    # 2. search loop for the current language: use the 7-entry table, limit 7*4
    patch(0x753D30, b'\x39\x88\x28\xFD\x8F\x00', b'\x39\x88' + struct.pack('<I', TABLE))
    patch(0x753D3B, b'\x83\xF8\x18', b'\x83\xF8\x1C')
    # 3. list selection handler: list index -> language id
    patch(0x75263C, b'\x8B\x0C\x85\x28\xFD\x8F\x00', b'\x8B\x0C\x85' + struct.pack('<I', TABLE))
    # 4. language name tables (slot 6 "Japanese" -> "Vietnamese"): command parser/logging + language-file header match
    patch(0x9555E8, struct.pack('<I', 0x9025AC), struct.pack('<I', NAME))
    patch(0x955618, struct.pack('<I', 0x90265C), struct.pack('<I', WNAME))
    # 5. default-language selection from the Windows UI language: slot 6 = LANGID 0x2A (Vietnamese)
    patch(0x902AE8 + 24, struct.pack('<I', 17), struct.pack('<I', 0x2A))

    # ---- write the new section header + raw data ---------------------------------------------
    o = sec_tab + 40 * nsec
    hdr = b'.viet\0\0\0' + struct.pack('<IIIIIIHHI', 0x200, new_va_rva, 0x200, file_end, 0, 0, 0, 0, 0x60000020)
    data[o:o + 40] = hdr
    struct.pack_into('<H', data, pe + 6, nsec + 1)
    size_of_image = new_va_rva + 0x1000
    struct.pack_into('<I', data, opt + 56, size_of_image)
    data += blob
    return bytes(data)


def fix_checksum(data):
    import pefile
    pe = pefile.PE(data=data)
    pe.OPTIONAL_HEADER.CheckSum = pe.generate_checksum()
    return pe.write()


def main():
    src, dst = sys.argv[1:3]
    d = open(src, 'rb').read()
    h = hashlib.sha256(d).hexdigest().upper()
    if h != VANILLA_SHA256:
        print('WARNING: input is not the known vanilla build (sha256 %s)' % h)
    out = build(d)
    out = fix_checksum(out)
    open(dst, 'wb').write(out)
    print('wrote', dst, len(out), hashlib.sha256(out).hexdigest().upper())


if __name__ == '__main__':
    main()
