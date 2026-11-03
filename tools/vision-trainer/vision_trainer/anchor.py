"""Anchor resolution: module+offset -> signature -> chain -> rescan+learn.

Raw addresses go stale under ASLR and are never trusted on their own.
"""

ALLOWED_TYPES = ("byte", "word", "dword", "qword", "float", "double")


class AnchorError(RuntimeError):
    pass


class NoAnchor(AnchorError):
    pass


class AmbiguousSignature(AnchorError):
    pass


def _plausible(observed, expected, value_type="dword"):
    if expected is None:
        return True
    try:
        if str(value_type).lower() in ("float", "double"):
            return abs(float(observed) - float(expected)) <= max(
                abs(float(expected)) * 0.05, 0.001)
        return int(observed) == int(expected)
    except (TypeError, ValueError):
        return False


def _verify(bridge, address, expected_value, value_type):
    vtype = (value_type or "dword").lower()
    if vtype not in ALLOWED_TYPES:
        vtype = "dword"
    resp = bridge.send_command("read_integer",
                               {"address": address, "type": vtype})
    if not resp.get("success"):
        return False
    return _plausible(resp.get("value"), expected_value, vtype)


def _parse_offset(module_offset):
    if not module_offset or "+" not in str(module_offset):
        return None, 0
    module, _, off = str(module_offset).rpartition("+")
    try:
        return module.strip(), int(off.strip(), 16)
    except ValueError:
        return None, 0


def _add_offset(address_hex, delta):
    try:
        return hex(int(address_hex, 16) + int(delta))
    except (TypeError, ValueError):
        return address_hex


def resolve_anchor(bridge, cheat, expected_value=None, rescan=None):
    anchor = cheat.get("anchor") or {}
    value_type = cheat.get("value_type", "dword")

    module_offset = anchor.get("module_offset")
    if module_offset:
        resp = bridge.send_command("get_symbol_address",
                                   {"symbol": module_offset})
        if resp.get("success") and resp.get("address"):
            addr = resp["address"]
            if _verify(bridge, addr, expected_value, value_type):
                return {"address": addr, "level": "module_offset",
                        "learned": {}}

    sig = anchor.get("signature")
    module = anchor.get("module", "")
    ambiguous_sig = False
    if sig:
        resp = bridge.send_command("aob_scan_module_unique", {
            "pattern": sig, "module_name": module or
            (module_offset or "").split("+")[0],
            "protection": "+X"})
        if resp.get("success") and resp.get("address"):
            addr = _add_offset(resp["address"],
                               anchor.get("offset", 0))
            if _verify(bridge, addr, expected_value, value_type):
                return {"address": addr, "level": "signature",
                        "learned": {}}
        # AD-7: ambiguous signatures refuse that rung and fall through to
        # the next rung rather than guessing or aborting the ladder.
        ambiguous_sig = int(resp.get("count", 1) or 0) != 1

    chain = anchor.get("pointer_chain")
    if chain:
        resp = bridge.send_command("read_pointer_chain", {
            "base": chain.get("base"), "offsets": chain.get("offsets", [])})
        if resp.get("success") and resp.get("final_address"):
            check = bridge.send_command("validate_pointer_chains", {
                "chains": [{"base": chain.get("base"),
                            "offsets": chain.get("offsets", [])}],
                "target": resp["final_address"]})
            matches = check.get("matches", []) if check.get("success") \
                else [{"final": resp["final_address"]}]
            if matches:
                addr = resp["final_address"]
                if _verify(bridge, addr, expected_value, value_type):
                    return {"address": addr, "level": "pointer_chain",
                            "learned": {}}

    if rescan is None:
        if ambiguous_sig:
            raise AmbiguousSignature(
                f"signature matched {resp.get('count', '?')} times "
                "(expected 1); refusing to guess — re-capture required.")
        raise NoAnchor(
            "no usable anchor and no rescan available; "
            "raw last_address is never trusted under ASLR.")
    found = rescan(bridge, cheat)
    learned = {k: found.get(k) for k in ("module_offset", "signature")
               if found.get(k)}
    return {"address": found.get("address"), "level": "rescan",
            "learned": learned}
