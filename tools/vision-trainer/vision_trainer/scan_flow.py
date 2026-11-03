"""Expanded scan ladder: exact -> type -> protection -> narrow -> pick."""

from . import ce_client as ce

NARROW_THRESHOLD = 50
MAX_NARROW_ROUNDS = 5
TYPE_LADDER = ("dword", "float", "double", "word", "byte", "qword")


class ScanError(RuntimeError):
    pass


class NoResults(ScanError):
    pass


class AmbiguousResults(ScanError):
    pass


class NeedNarrowingValue(ScanError):
    pass


class WriteCancelled(ScanError):
    pass


def _result_count(resp):
    if isinstance(resp.get("count"), int):
        return resp["count"]
    if isinstance(resp.get("total"), int):
        return resp["total"]
    results = resp.get("results") or []
    return len(results)


def adjust_to_100x(bridge, label, value, value_type, target_value=None,
                   scan_option="exact", tolerance=0,
                   picker=None, narrow_values=None, writer=None):
    if writer is None:
        raise ScanError(
            "adjust_to_100x requires a writer approval callback — "
            "writes are never sent without a previewed confirmation.")
    trace = []
    value_type = (value_type or "dword").lower()
    tried_types = []
    protections = ["+W-C", "+W"]
    tried = []

    result = None
    type_index = 0
    type_order = [value_type] + [t for t in TYPE_LADDER if t != value_type]
    while type_index < len(type_order):
        vtype = type_order[type_index]
        sweep = list(protections) if vtype == value_type else [protections[0]]
        for protection in sweep:
            tried_types.append((vtype, protection))
            params_value = str(value)
            use_option = scan_option
            value2 = None
            if vtype in ("float", "double") and scan_option == "exact":
                tol = tolerance or (abs(float(value)) * 0.001 or 0.0001)
                params_value = f"{float(value) - tol},{float(value) + tol}"
                use_option = "between"
            resp = bridge.send_command("scan_all", {
                "value": params_value, "type": vtype,
                "protection": protection, "scan_option": use_option,
                **({"value2": str(value2)} if value2 else {}),
            })
            count = _result_count(resp)
            step = (f"scan_all {params_value} type={vtype} "
                    f"protection={protection} -> {count} hits")
            trace.append(step)
            tried.append(step)
            if "protection" not in step:
                trace[-1] = step + " protection"
            if count > 0:
                result = (vtype, protection, count)
                break
        if result:
            break
        type_index += 1

    if not result:
        raise NoResults(
            f"No hits for {label}={value} after {len(tried)} attempts "
            f"({', '.join(f'{t}/{p}' for t, p in tried_types)}). "
            "Try a different value type or change the value in-game.")

    vtype, protection, count = result
    resp = bridge.send_command("get_scan_results",
                               {"offset": 0, "limit": 100})
    total = _result_count(resp)
    candidates = list(resp.get("results") or [])

    narrow_values = list(narrow_values or [])
    rounds = 0
    while total > NARROW_THRESHOLD and rounds < MAX_NARROW_ROUNDS:
        if not narrow_values:
            raise NeedNarrowingValue(
                f"{total} hits remain; change the value in-game and supply "
                "the new number to narrow down.")
        new_value = narrow_values.pop(0)
        resp = bridge.send_command("next_scan", {
            "value": str(new_value), "scan_type": "exact"})
        count = _result_count(resp)
        trace.append(f"next_scan {new_value} -> {count} hits")
        resp = bridge.send_command("get_scan_results",
                                   {"offset": 0, "limit": 100})
        total = _result_count(resp)
        candidates = list(resp.get("results") or [])
        rounds += 1
        trace.append(f"narrow round {rounds}: {total} hits remain")

    if total != 1 and len(candidates) != 1:
        if picker is None:
            raise AmbiguousResults(
                f"{total} candidates for {label}; user must pick one "
                "(refusing to write to multiple addresses).")
        for cand in candidates:
            try:
                bridge.send_command("read_integer", {
                    "address": cand.get("address"),
                    "type": vtype if vtype in (
                        "byte", "word", "dword", "qword",
                        "float", "double") else "dword"})
            except Exception:
                pass
        chosen = picker(candidates)
        candidates = [chosen]

    address = candidates[0].get("address")
    if target_value is None:
        target_value = value * 100 if isinstance(value, (int, float)) else value
    if writer is not None:
        approved = writer({"address": address, "label": label,
                           "observed": value,
                           "target_value": target_value,
                           "value_type": vtype,
                           "scan_option": scan_option,
                           "tolerance": tolerance})
        if not approved:
            raise WriteCancelled(
                f"Write cancelled at {address}.")
    bridge.send_command("write_integer", {
        "address": address, "value": target_value, "type": vtype})
    trace.append(f"write {address} = {target_value} ({vtype})")
    module_offset = ""
    try:
        info = bridge.send_command("get_address_info",
                                   {"address": address})
        if isinstance(info, dict) and info.get("success"):
            module_offset = info.get("symbolic_name", "") or ""
    except Exception:
        module_offset = ""
    signature = None
    try:
        sig_resp = bridge.send_command("generate_signature",
                                       {"address": address})
        if isinstance(sig_resp, dict) and sig_resp.get("success"):
            signature = {"pattern": sig_resp.get("signature"),
                         "module": (module_offset.split("+")[0]
                                    if "+" in module_offset else ""),
                         "offset": sig_resp.get("offset_from_start", 0)}
    except Exception:
        signature = None
    return {"address": address, "label": label,
            "observed_value": value, "target_value": target_value,
            "value_type": vtype, "protection": protection,
            "module_offset": module_offset, "signature": signature,
            "trace": trace}
