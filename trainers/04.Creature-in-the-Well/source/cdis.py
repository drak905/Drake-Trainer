"""dis.py <symbol-substring|0xRVA> [-x exact] - annotated disassembly of CITW functions"""
import sys, bisect, pefile, capstone
EXE = r"E:\EpicGames\CreatureintheWell\CITW\Binaries\Win64\CITW-Win64-Shipping.exe"
pe = pefile.PE(EXE, fast_load=True); data = open(EXE,"rb").read()
def rva2off(rva):
    for s in pe.sections:
        if s.VirtualAddress <= rva < s.VirtualAddress + max(s.Misc_VirtualSize, s.SizeOfRawData):
            return s.PointerToRawData + rva - s.VirtualAddress
    return None
syms=[]
for l in open("syms.tsv",encoding="utf8"):
    a,s,n=l.rstrip("\n").split("\t",2); syms.append((int(a,16),int(s),n))
addrs=[s[0] for s in syms]
def name_at(rva):
    i=bisect.bisect_right(addrs,rva)-1
    if i>=0:
        a,s,n=syms[i]
        if rva==a: return n
        if rva<a+max(s,1): return "%s+0x%x"%(n,rva-a)
    return None
def read(rva,n):
    o=rva2off(rva); return data[o:o+n]
def cstr(rva):
    o=rva2off(rva)
    if o is None: return None
    b=data[o:o+80]; 
    try:
        s=b.split(b"\0")[0].decode("ascii")
        if len(s)>=3 and s.isprintable(): return s
    except: pass
    try:
        w=b.decode("utf-16le",errors="ignore").split("\0")[0]
        if len(w)>=3 and w.isprintable(): return "L"+w
    except: pass
def dis(rva,size):
    md=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_64); md.detail=True
    code=read(rva,size)
    for i in md.disasm(code,rva):
        ann=""
        for op in i.operands:
            if op.type==capstone.x86.X86_OP_MEM and op.mem.base==capstone.x86.X86_REG_RIP:
                t=i.address+i.size+op.mem.disp
                n=name_at(t); s=cstr(t)
                ann=" ; ->%x %s %s"%(t,n or "",("'%s'"%s) if s else "")
            elif op.type==capstone.x86.X86_OP_IMM and i.mnemonic in("call","jmp"):
                n=name_at(op.imm)
                ann=" ; ->%x %s"%(op.imm,n or "")
        print("%08x  %-6s %s%s   [%s]"%(i.address,i.mnemonic,i.op_str,ann,i.bytes.hex()))
if __name__=="__main__":
    q=sys.argv[1]
    if q.startswith("0x"):
        rva=int(q,16); size=int(sys.argv[2]) if len(sys.argv)>2 else 128
        dis(rva,size)
    else:
        exact="-x" in sys.argv
        for a,s,n in syms:
            if (n==q) if exact else (q in n):
                if s>0: print("\n### %s rva=%x size=%d"%(n,a,s)); dis(a,s)
