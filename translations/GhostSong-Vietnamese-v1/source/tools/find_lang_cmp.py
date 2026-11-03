"""Find the 'languageChoice < 7' compare / '= 7' store in settingsfabio.Update (by calls to LocalizationManager.SetLangTo)."""
import sys, pefile
from capstone import Cs, CS_ARCH_X86, CS_MODE_64
GAME = r"E:\GOGGalaxy\Ghost Song\GameAssembly.dll"
pe = pefile.PE(GAME, fast_load=True)
base = pe.OPTIONAL_HEADER.ImageBase
data = open(GAME, "rb").read()
def rva2off(rva):
    for s in pe.sections:
        if s.VirtualAddress <= rva < s.VirtualAddress + s.Misc_VirtualSize:
            return s.PointerToRawData + (rva - s.VirtualAddress)
START = int(sys.argv[1], 16) if len(sys.argv) > 1 else 0x11E6A20
SIZE = int(sys.argv[2], 16) if len(sys.argv) > 2 else 0x6000
TARGET = int(sys.argv[3], 16) if len(sys.argv) > 3 else 0x1184AB0
off = rva2off(START)
md = Cs(CS_ARCH_X86, CS_MODE_64)
md.detail = False
ins = list(md.disasm(data[off:off + SIZE], base + START))
print("decoded", len(ins), "instructions")
hits = []
for i, x in enumerate(ins):
    if x.mnemonic == "call" and x.op_str.startswith("0x") and int(x.op_str, 16) == base + TARGET:
        hits.append(i)
print("calls to target at idx", hits)
for h in hits:
    lo = max(0, h - 45)
    for x in ins[lo:h + 3]:
        print("%X  %-6s %s    | %s" % (x.address - base, x.mnemonic, x.op_str, data[rva2off(x.address - base):rva2off(x.address - base) + x.size].hex()))
    print("-----")
