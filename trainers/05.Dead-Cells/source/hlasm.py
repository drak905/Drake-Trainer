"""Tiny assembler + function patch helpers on top of hlcode."""
import hlcode
from hlcode import Op, OPIDX, JUMP_P, SWITCH, NARGS


class Asm:
    """Builds a straight-line op list with forward jumps to named labels."""

    def __init__(self, regs):
        self.regs = list(regs)
        self.ops = []
        self.fix = []      # (op index, operand position, label)
        self.labels = {}

    def reg(self, t):
        self.regs.append(t)
        return len(self.regs) - 1

    def op(self, name, *p):
        self.ops.append(Op(OPIDX[name], list(p)))
        return len(self.ops) - 1

    def jmp(self, name, *args, to):
        jp = JUMP_P[OPIDX[name]] - 1
        p = list(args)
        p.insert(jp, 0)
        i = self.op(name, *p)
        self.fix.append((i, jp, to))

    def label(self, name):
        if name in self.labels:
            raise ValueError("dup label " + name)
        self.labels[name] = len(self.ops)

    def resolve(self, base=0, extra=None):
        """base: final op index of the first op of this block.
        extra: {label: final op index} for targets outside the block."""
        labels = {k: base + v for k, v in self.labels.items()}
        if extra:
            labels.update(extra)
        for i, jp, lab in self.fix:
            off = labels[lab] - (base + i + 1)
            if off < 0:
                raise ValueError(f"backward jump to {lab} not allowed")
            self.ops[i].p[jp] = off
        return self.ops


def _remap_jumps(ops, mapping, pos, k):
    """Fix relative jumps of original ops after inserting k ops before index pos."""
    def m(j):
        return j if j < pos else j + k
    for i, o in enumerate(ops):
        ni = m(i)
        if o.op in JUMP_P:
            jp = JUMP_P[o.op] - 1
            t = i + 1 + o.p[jp]
            o.p[jp] = (pos if t == pos else m(t)) - (ni + 1)
        elif o.op == SWITCH:
            cnt = o.p[1]
            for q in list(range(2, 2 + cnt)) + [len(o.p) - 1]:
                t = i + 1 + o.p[q]
                o.p[q] = (pos if t == pos else m(t)) - (ni + 1)


def insert(code, f, pos, asm, labels=None):
    """Insert asm ops before original op index `pos` of function f.
    Labels 'body' (= original op at pos) and ('old', n) style names in `labels` dict
    {name: original_index} are available as jump targets."""
    k = len(asm.ops)
    extra = {"body": pos + k}
    for name, oi in (labels or {}).items():
        extra[name] = oi if oi < pos else oi + k
    new_ops = asm.resolve(pos, extra)
    _remap_jumps(f.ops, None, pos, k)
    f.ops = f.ops[:pos] + new_ops + f.ops[pos:]
    f.regs = asm.regs
    if f.debug is not None:
        d = f.debug[pos] if pos < len(f.debug) else f.debug[-1]
        f.debug = f.debug[:pos] + [d] * k + f.debug[pos:]
    if f.assigns is not None:
        na = []
        for a in f.assigns:
            a = list(a)
            if a[1] - 1 >= pos:
                a[1] += k
            na.append(tuple(a))
        f.assigns = na
    f.dirty = True


def new_function(code, ftype, asm, debug_pos):
    f = hlcode.Function()
    f.type = ftype
    f.findex = len(code.functions) + len(code.natives)
    f.regs = asm.regs
    f.ops = asm.resolve()
    f.debug = [debug_pos] * len(f.ops) if code.hasdebug else None
    f.assigns = [] if code.hasdebug and code.version >= 3 else None
    f.dirty = True
    code.functions.append(f)
    return f.findex
