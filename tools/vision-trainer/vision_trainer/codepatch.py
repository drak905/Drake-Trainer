"""Code-patch escalation for stubborn values (game rewrites the write).

Safety rules (Apprentice): never displace RIP-relative without relocation
check; signature must match exactly once; keep original bytes for restore.
"""

import re


class PatchError(RuntimeError):
    pass


class NoWriterHit(PatchError):
    pass


class AmbiguousSignature(PatchError):
    pass


def locate_writer(bridge, address, bp_id="vt_writer"):
    bridge.send_command("set_data_breakpoint", {
        "address": address, "access_type": "w", "size": 4, "id": bp_id})
    try:
        resp = bridge.send_command("get_breakpoint_hits",
                                   {"id": bp_id, "clear": True,
                                    "limit": 10})
    finally:
        try:
            bridge.send_command("remove_breakpoint", {"id": bp_id})
        except Exception:
            pass
    hits = resp.get("hits", []) if resp.get("success") else []
    if not hits:
        raise NoWriterHit(
            f"no write hit on {address}; change the value in-game while "
            "the watch is armed, then retry.")
    hit = hits[0]
    return {"address": hit.get("address", ""),
            "instruction": hit.get("instruction", ""),
            "size": hit.get("size", 0),
            "registers": hit.get("registers", {})}


def classify_instruction(instruction, size=0):
    text = (instruction or "").strip().lower()
    if "rip" in text:
        return {"action": "skip",
                "reason": "RIP-relative operand: displacing it without "
                          "relocation check would crash; use freeze instead."}
    if re.match(r"mov\s+\[.*\],\s*"
                r"(e|r)?(?:[abcd]x|[sd]i|bp|8|9|1[0-5])\w*", text):
        return {"action": "nop", "nop_bytes": size or 0,
                "reason": "register->memory store: NOP the writer so the "
                          "game never puts the old value back."}
    if re.match(r"mov\s+\[.*\],\s*(0x[0-9a-f]+|\d+)", text):
        return {"action": "replace",
                "reason": "constant store: replace the immediate with the "
                          "target value instead of NOPing."}
    return {"action": "skip",
            "reason": f"unrecognized writer shape {instruction!r}; "
                      "refusing to patch blindly."}


def nop_fill(length):
    if length <= 0:
        raise ValueError("NOP fill length must be >= 1")
    return [0x90] * length


def fingerprint_writer(bridge, writer_address, module_name):
    sig_resp = bridge.send_command("generate_signature",
                                   {"address": writer_address})
    if not sig_resp.get("success") or not sig_resp.get("signature"):
        raise PatchError(
            f"could not generate signature: {sig_resp.get('error')}")
    pattern = sig_resp["signature"]
    check = bridge.send_command("aob_scan_module_unique", {
        "pattern": pattern, "module_name": module_name,
        "protection": "+X"})
    if not check.get("success"):
        raise AmbiguousSignature(
            f"signature matched {check.get('count', '?')} times "
            "(expected 1); refusing to patch — re-capture required.")
    return {"signature": pattern, "module": module_name,
            "offset": sig_resp.get("offset_from_start", 0),
            "address": check.get("address", writer_address)}


def apply_patch(bridge, address, patched_bytes):
    read = bridge.send_command("read_memory",
                               {"address": address,
                                "size": len(patched_bytes)})
    if not read.get("success"):
        raise PatchError(f"could not read original bytes: {read}")
    original = list(read.get("bytes", []))
    bridge.send_command("write_memory",
                        {"address": address,
                         "bytes": list(patched_bytes)})
    return {"address": address, "original_bytes": original,
            "patched_bytes": list(patched_bytes)}


def restore_patch(bridge, patch):
    bridge.send_command("write_memory", {
        "address": patch.get("address"),
        "bytes": list(patch.get("original_bytes", []))})
    return True


def escalate_stubborn_value(bridge, address, value_type, module_name,
                            target_value=None):
    hit = locate_writer(bridge, address)
    disasm = bridge.send_command("disassemble",
                                 {"address": hit["address"], "count": 1})
    instructions = disasm.get("instructions", []) if disasm.get(
        "success") else []
    text = instructions[0].get("instruction",
                               hit.get("instruction", "")) if instructions \
        else hit.get("instruction", "")
    size = instructions[0].get("size", 0) if instructions else 0
    plan = classify_instruction(text, size=size)
    if plan["action"] == "skip":
        return {"patched": False, "plan": plan, "hit": hit}
    fingerprint = fingerprint_writer(bridge, hit["address"], module_name)
    if plan["action"] == "nop":
        patched_bytes = nop_fill(plan["nop_bytes"] or size or 1)
    else:
        patched_bytes = nop_fill(size or 1)
    patch = apply_patch(bridge, hit["address"], patched_bytes)
    patch["fingerprint"] = fingerprint
    return {"patched": True, "plan": plan, "hit": hit,
            "patch": patch, "fingerprint": fingerprint}
