"""Headless wizard state machine (Tkinter main.py drives this)."""

import os

from . import ce_client as ce
from . import anchor as anchor_mod
from . import freeze as freeze_mod
from . import offline_gate as offline_gate_mod
from . import profiles as profiles_mod
from . import runbook as runbook_mod


class FlowState:
    def __init__(self, bridge, config, runbook_dir=None, profiles_dir=None):
        self.bridge = bridge
        self.config = config
        self.runbook_dir = runbook_dir or runbook_mod.default_runbook_dir()
        self.profiles_dir = profiles_dir or profiles_mod.default_profiles_dir()
        self.registry = freeze_mod.WorkerRegistry(bridge)
        self.applied_patches = []
        self.stage = "setup" if not config else "process"
        self.settings_return = False
        self.process_id = None
        self.process_name = ""
        self.last_process = ""
        self.window_title = ""
        self.window_handle = ""
        self.values = []
        self.selected = None
        self.write_result = None
        self.last_multiplier = 100
        self.last_plan_fallback = False
        self.before_b64 = ""
        self.after_b64 = ""
        self.last_error = ""
        self.drafts = []
        self.locked_pids = set()
        self.refused = False

    def open_settings(self):
        self.settings_return = True
        self.stage = "setup"

    def check_offline_gate(self, selection, window_title="",
                             modules=None):
        reason = offline_gate_mod.check_process_name(selection)
        if reason:
            return reason
        reason = offline_gate_mod.check_modules(modules or [])
        if reason:
            return reason
        return offline_gate_mod.check_window_title(
            window_title or self.window_title)

    def _resolve_pid_name(self, pid):
        try:
            resp = self.bridge.send_command("get_process_list", {})
            if not resp.get("success"):
                return ""
            for p in resp.get("processes", []):
                if not isinstance(p, dict):
                    continue
                try:
                    entry_pid = int(p.get("pid", -1))
                except (TypeError, ValueError):
                    continue
                if entry_pid == pid:
                    return str(p.get("name", "") or "")
        except Exception:
            return ""
        return ""

    def detach(self):
        try:
            self.bridge.send_command("close_process", {})
        except Exception:
            pass
        self.process_id = None
        self.process_name = ""
        self.window_handle = ""
        self.values = []
        self.selected = None
        self.write_result = None
        self.before_b64 = ""
        self.after_b64 = ""
        self.stage = "process"

    def attach_process(self, selection, window_title="", modules=None):
        self.refused = False
        selection = str(selection).strip()
        numeric = selection.isdecimal()
        if numeric and int(selection) in self.locked_pids:
            self.last_error = offline_gate_mod.REFUSE_MESSAGE.format(
                reason="previously refused PID")
            self.refused = True
            return False
        candidate = selection
        if numeric:
            resolved = self._resolve_pid_name(int(selection))
            if resolved:
                candidate = resolved
        reason = self.check_offline_gate(candidate, window_title,
                                          modules=modules)
        if reason:
            self.last_error = offline_gate_mod.REFUSE_MESSAGE.format(
                reason=reason)
            if numeric:
                self.locked_pids.add(int(selection))
            if self.process_id:
                self.detach()
            else:
                self.process_id = None
                self.stage = "process"
            self.refused = True
            return False
        try:
            resp = self.bridge.send_command(
                "open_process", {"process_id_or_name": str(selection)})
            if not resp.get("success"):
                self.last_error = str(resp.get("error", "open failed"))
                return False
            pid = int(resp.get("process_id", 0) or 0)
            if not pid and numeric:
                pid = int(selection)
            check = self.bridge.send_command("get_opened_process_id")
            if check.get("success") and int(check.get("process_id", -1)) != pid and pid:
                self.last_error = (
                    f"attached PID {check.get('process_id')} != {pid}")
                self.detach()
                return False
            if not check.get("success") and not pid:
                self.last_error = str(check.get("error", "no process"))
                self.detach()
                return False
            self.process_id = pid or int(check.get("process_id", 0) or 0)
            try:
                resp = self.bridge.send_command("enum_modules", {})
                post_modules = (resp.get("modules", [])
                                if resp.get("success") else [])
            except Exception:
                post_modules = []
            post = (offline_gate_mod.check_modules(post_modules)
                    or offline_gate_mod.check_window_title(
                        window_title or self.window_title))
            if post:
                self.last_error = offline_gate_mod.REFUSE_MESSAGE.format(
                    reason=post)
                if self.process_id:
                    self.locked_pids.add(self.process_id)
                self.detach()
                self.refused = True
                return False
            self.last_process = str(selection)
            self.process_name = (candidate if numeric and candidate != selection
                                 else str(selection))
            self.stage = "capture"
            self.last_error = ""
            self.refused = False
            return True
        except Exception as exc:
            self.last_error = str(exc)
            return False

    def reapply_profile(self, writer=None, process_name=None):
        """Re-locate + re-write every saved cheat without a rescan.
        Each write goes through writer({cheat, address, old_value,
        new_value, label}) per-cheat and only happens on True. Opening a
        profile never auto-writes."""
        if writer is None:
            raise ValueError(
                "reapply_profile requires a per-cheat confirm callback — "
                "opening a profile never auto-writes.")
        game = process_name or self.process_name
        path = profiles_mod.resolve_path(game,
                                         base_dir=self.profiles_dir)
        results = []
        for cheat in profiles_mod.list_cheats(path):
            outcome = {"label": cheat.get("label", "stat"),
                       "address": ""}
            try:
                resolved = anchor_mod.resolve_anchor(
                    self.bridge, cheat,
                    expected_value=cheat.get("target_value"),
                    rescan=None)
                address = resolved["address"]
                outcome["address"] = address
                outcome["level"] = resolved["level"]
                old = self._read_current(address, cheat)
                approved = writer({"cheat": cheat,
                                   "address": address,
                                   "old_value": old,
                                   "new_value": cheat.get("target_value"),
                                   "label": outcome["label"]})
                if not approved:
                    outcome["status"] = "skipped_user"
                    results.append(outcome)
                    continue
                mode = cheat.get("mode", "one_shot")
                if mode == "display":
                    outcome["status"] = "display_only"
                    results.append(outcome)
                    continue
                resp = self.bridge.send_command("write_integer", {
                    "address": address,
                    "value": cheat.get("target_value"),
                    "type": cheat.get("value_type", "dword")})
                if not resp.get("success"):
                    outcome["status"] = "failed"
                    outcome["error"] = str(resp.get("error", "write failed"))
                    results.append(outcome)
                    continue
                if mode == "freeze":
                    self.registry.start_freeze(
                        outcome["label"], address,
                        cheat.get("target_value"),
                        cheat.get("value_type", "dword"))
                    outcome["status"] = "frozen"
                else:
                    outcome["status"] = "written"
                learned = resolved.get("learned") or {}
                if learned:
                    for key in ("module_offset", "signature"):
                        if learned.get(key):
                            cheat[key] = learned[key]
                    cheat["last_address"] = address
                    profiles_mod.upsert_cheat(path, game, cheat)
            except anchor_mod.AmbiguousSignature as exc:
                outcome.update(status="ambiguous", error=str(exc))
            except Exception as exc:
                outcome.update(status="failed", error=str(exc))
            results.append(outcome)
        return results

    def _read_current(self, address, cheat):
        try:
            resp = self.bridge.send_command("read_integer", {
                "address": address,
                "type": cheat.get("value_type", "dword")})
            if resp.get("success"):
                return resp.get("value")
        except Exception:
            return None
        return None

    def confirm_yes(self, runbook_dir=None, notes=""):
        from . import scan_flow
        base = runbook_dir or self.runbook_dir
        path = runbook_mod.resolve_path(self.process_name or "game",
                                        base_dir=base)
        trace = (self.write_result or {}).get("trace", [])
        narrow_rounds = sum(1 for t in trace if "narrow round" in t)
        hits = []
        for t in trace:
            import re
            m = re.search(r"(\d+) hits", t)
            if m:
                hits.append(int(m.group(1)))
        entry = {
            "process": self.process_name or "game",
            "window_title": self.window_title,
            "label": (self.selected or {}).get("label", "stat")
            if isinstance(self.selected, dict)
            else str(self.selected or "stat"),
            "observed_value": ((self.selected or {}).get("value")
                               if isinstance(self.selected, dict) else ""),
            "target_value": (self.write_result or {}).get("target_value", ""),
            "value_type": (self.write_result or {}).get("value_type", ""),
            "scan_recipe": {
                "type": (self.write_result or {}).get("value_type", ""),
                "protection": (self.write_result or {}).get("protection", ""),
                "scan_option": "exact",
                "narrow_rounds": narrow_rounds,
                "hits": hits,
            },
            "address": (self.write_result or {}).get("address", ""),
            "module_offset": (self.write_result or {}).get("module_offset", ""),
            "multiplier": (self.write_result or {}).get("multiplier", 100),
            "fallback_used": (self.write_result or {}).get("fallback", False),
            "vision_model": (self.config or {}).get("vision_model", ""),
            "adjust_model": (self.config or {}).get("adjust_model", ""),
            "endpoint": (self.config or {}).get("endpoint", ""),
            "verified": True,
            "notes": notes,
        }
        runbook_mod.save_entry(path, entry)
        profile_path = profiles_mod.resolve_path(
            self.process_name or "game", base_dir=self.profiles_dir)
        cheat = {
            "label": entry["label"],
            "value_type": entry["value_type"] or "dword",
            "mode": "one_shot",
            "recipe": entry["scan_recipe"],
            "anchor": ({"module_offset": (self.write_result or {}).get(
                "module_offset")} if (self.write_result or {}).get(
                "module_offset") else None),
            "last_address": entry["address"],
            "module_offset": (self.write_result or {}).get(
                "module_offset", ""),
            "signature": (self.write_result or {}).get("signature"),
            "target_value": entry["target_value"],
            "verified": True,
            "look_for": (f"Check {entry['label']} shows "
                         f"{entry['target_value']} in-game"),
        }
        profiles_mod.upsert_cheat(profile_path,
                                  self.process_name or "game", cheat)
        self.stage = "done"
        return path

    def confirm_no(self):
        self.stage = "refine"
        return True

    def mark_session_active(self):
        try:
            marker = self._stale_marker()
            os.makedirs(os.path.dirname(marker), exist_ok=True)
            with open(marker, "w", encoding="utf-8") as f:
                f.write("active")
        except OSError:
            pass

    def clear_session_marker(self):
        try:
            os.remove(self._stale_marker())
        except OSError:
            pass

    def _stale_marker(self):
        return os.path.join(self.runbook_dir, "..", "stale-session.marker")

    def session_was_unclean(self):
        return os.path.exists(self._stale_marker())

    def shutdown(self):
        results = []
        for label in list(self.registry.freezes.keys()):
            ok = self.registry.stop_freeze(label, restore=True)
            results.append({"label": label, "restored": ok})
        for patch in self.applied_patches:
            ok = False
            try:
                resp = self.bridge.send_command("write_memory", {
                    "address": patch.get("address"),
                    "bytes": list(patch.get("original_bytes", []))})
                ok = bool(resp.get("success"))
            except Exception:
                ok = False
            results.append({"label": f"patch@{patch.get('address')}",
                            "restored": ok})
        self.registry.restore_all()
        try:
            self.bridge.send_command("clear_all_breakpoints")
        except Exception:
            pass
        self.applied_patches = []
        self.clear_session_marker()
        return results
