"""Vision Trainer — Tkinter wizard driving flow.FlowState.

Offline-game value adjuster: setup -> process -> capture -> extract ->
adjust -> verify -> done. Educational/offline use only.
"""

import os
import sys
import tkinter as tk
from tkinter import messagebox, ttk

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from vision_trainer import ce_client, config as config_mod
from vision_trainer import codepatch as codepatch_mod
from vision_trainer import factory as factory_mod
from vision_trainer import flow as flow_mod
from vision_trainer import freeze as freeze_mod
from vision_trainer import llm_client, profiles as profiles_mod
from vision_trainer import runbook as runbook_mod
from vision_trainer import scan_flow, screenshot


ATTACH_FAILED_TEMPLATE = "Process — Attach failed: {reason}"

PATCH_CONFIRM_TEMPLATE = (
    "Change the value in-game now so the watch can catch the writer of "
    "{address}. This attaches a debugger and patches code. It can crash "
    "or corrupt saves. Offline saves only. Continue?")


UNSAFE_BANNER_COPY = ("UNSAFE ARMED — Freeze/Patch can corrupt saves. "
                      "Restores on clean quit only; killing the app may "
                      "leave game memory changed. Offline games only.")
# Split per-session gates (safety review F1 supersedes first-run-only):
# per-launch persistence only; each launch must re-arm.
FREEZE_ACK_COPY = ("Freeze acknowledgement\n"
                   "Freeze repeatedly writes the value in-game; it can "
                   "corrupt saves. Per session: re-arms each launch.")
PATCH_ACK_COPY = ("Patch acknowledgement\n"
                  "Patch attaches a debugger and modifies game code. "
                  "Per session: re-arms each launch.")


class SetupDialog(tk.Toplevel):
    def __init__(self, parent, cfg):
        super().__init__(parent)
        self.title("Vision Trainer — Setup")
        self.result = None
        cfg = cfg or config_mod.default_config()
        self.freeze_ack_var = tk.BooleanVar(
            value=getattr(parent, "freeze_ack", False))
        self.patch_ack_var = tk.BooleanVar(
            value=getattr(parent, "patch_ack", False))

        ttk.Label(self, text="Local LLM endpoint:").grid(
            row=0, column=0, sticky="w", padx=8, pady=4)
        self.endpoint_var = tk.StringVar(value=cfg.get("endpoint", ""))
        ttk.Entry(self, textvariable=self.endpoint_var, width=50).grid(
            row=0, column=1, padx=8, pady=4)
        ttk.Button(self, text="Refresh models",
                   command=self.refresh_models).grid(
            row=0, column=2, padx=8, pady=4)

        ttk.Label(self, text="Vision model:").grid(
            row=1, column=0, sticky="w", padx=8, pady=4)
        self.vision_var = tk.StringVar(value=cfg.get("vision_model", ""))
        self.vision_box = ttk.Combobox(self, textvariable=self.vision_var,
                                       width=47)
        self.vision_box.grid(row=1, column=1, padx=8, pady=4)

        ttk.Label(self, text="Adjust model:").grid(
            row=2, column=0, sticky="w", padx=8, pady=4)
        self.adjust_var = tk.StringVar(value=cfg.get("adjust_model", ""))
        self.adjust_box = ttk.Combobox(self, textvariable=self.adjust_var,
                                       width=47)
        self.adjust_box.grid(row=2, column=1, padx=8, pady=4)

        acks = ttk.LabelFrame(self, text="UNSAFE gates (per session)")
        acks.grid(row=3, column=0, columnspan=3, padx=8, pady=6,
                  sticky="ew")
        ttk.Checkbutton(acks, text=FREEZE_ACK_COPY,
                        variable=self.freeze_ack_var).grid(
            row=0, column=0, sticky="w", padx=8, pady=4)
        ttk.Checkbutton(acks, text=PATCH_ACK_COPY,
                        variable=self.patch_ack_var).grid(
            row=1, column=0, sticky="w", padx=8, pady=4)

        self.status = ttk.Label(self, text="")
        self.status.grid(row=4, column=0, columnspan=3, padx=8, pady=4)

        btns = ttk.Frame(self)
        btns.grid(row=5, column=0, columnspan=3, pady=8)
        ttk.Button(btns, text="Test", command=self.test).pack(side="left",
                                                              padx=4)
        ttk.Button(btns, text="Save", command=self.save).pack(side="left",
                                                              padx=4)
        self.grab_set()
        self.bind("<Escape>", lambda _e: self.destroy())

    def refresh_models(self):
        self.status.config(text="Loading models…")
        self.update_idletasks()
        try:
            models = config_mod.list_models(self.endpoint_var.get())
        except Exception as exc:
            self.status.config(text=f"Failed: {exc}")
            return
        self.vision_box["values"] = models
        self.adjust_box["values"] = models
        if models and not self.vision_var.get():
            self.vision_var.set(models[0])
        if models and not self.adjust_var.get():
            self.adjust_var.set(models[0])
        if not models:
            self.status.config(text="No models found — is the server running?")
            return
        self.status.config(text=f"{len(models)} models found")

    def test(self):
        try:
            models = config_mod.list_models(self.endpoint_var.get())
            self.status.config(text=f"OK — {len(models)} models")
        except Exception as exc:
            self.status.config(text=f"Failed: {exc}")

    def save(self):
        cfg = {"endpoint": config_mod.normalize_endpoint(
            self.endpoint_var.get()),
            "vision_model": self.vision_var.get().strip(),
            "adjust_model": self.adjust_var.get().strip()}
        ok, err = config_mod.validate_config(cfg)
        if not ok:
            self.status.config(text=err)
            return
        try:
            config_mod.list_models(cfg["endpoint"])
        except Exception as exc:
            self.status.config(text=f"Endpoint unreachable: {exc}")
            return
        config_mod.save_config(cfg)
        self.result = cfg
        self.destroy()


VERIFY_CONFIRM_TEMPLATE = ("Value now shows {observed} "
                           "(expected {expected}). Correct?")
# Story-pinned exact copy (EXPERIENCE.md). default="no" makes Enter = No,
# the safe default, mirroring PreviewDialog's never-consent-by-key rule.


class PreviewDialog(tk.Toplevel):
    """Blocking Write/Cancel preview. Enter cancels (safe default No):
    Write must be clicked explicitly; display-only is not consent."""

    def __init__(self, parent, title, message, ok_label="Write"):
        super().__init__(parent)
        self.title(title)
        self.result = False
        ttk.Label(self, text=message, justify="left", wraplength=460).pack(
            padx=16, pady=(16, 8))
        btns = ttk.Frame(self)
        btns.pack(pady=(0, 12))
        ttk.Button(btns, text="Cancel", command=self.cancel).pack(
            side="left", padx=4)
        ttk.Button(btns, text=ok_label, command=self.approve).pack(
            side="left", padx=4)
        self.grab_set()
        self.bind("<Escape>", lambda _e: self.cancel())
        self.bind("<Return>", lambda _e: self.cancel())
        btns.winfo_children()[0].focus_set()

    def approve(self):
        self.result = True
        self.destroy()

    def cancel(self):
        self.result = False
        self.destroy()


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Vision Trainer (offline games only)")
        self.minsize(900, 700)
        self.geometry("900x700")
        self.cfg = config_mod.load_config()
        self.bridge = ce_client.CEBridge()
        self.state = flow_mod.FlowState(self.bridge, self.cfg)
        self._pending_edits = set()
        self.freeze_ack = False
        self.patch_ack = False
        self._writes_ok = True

        header = ttk.Frame(self)
        header.pack(fill="x", padx=8, pady=4)
        self.header_frame = header
        ttk.Button(header, text="Settings / Update info",
                   command=self.open_settings).pack(side="left")
        ttk.Button(header, text="View Runbook",
                   command=self.view_runbook).pack(side="left", padx=4)
        ttk.Button(header, text="Open Profiles Folder",
                   command=self.open_profiles).pack(side="left", padx=4)
        ttk.Button(header, text="Re-apply profile",
                   command=self.reapply_profile).pack(side="left", padx=4)
        ttk.Button(header, text="Validate profile",
                   command=self.validate_profile).pack(side="left", padx=4)
        ttk.Button(header, text="Export .CT",
                   command=self.export_ct).pack(side="left", padx=4)
        self.protocol("WM_DELETE_WINDOW", self.on_close)

        self.unsafe_banner = tk.Label(
            self, text="⚠️ " + UNSAFE_BANNER_COPY,
            bg="#B45309", fg="#111111", anchor="w", justify="left",
            wraplength=860, padx=8, pady=4)
        # sticky above body grid; sole amber use (text+icon, never color-only)

        self.log = tk.Text(self, height=12, state="disabled",
                             takefocus=False)
        self.log.pack(fill="x", padx=8, pady=4)

        body = ttk.Frame(self)
        body.pack(fill="both", expand=True, padx=8, pady=4)
        canvas_holder = ttk.Frame(body)
        canvas_holder.pack(fill="both", expand=True)
        self._scroll = tk.Scrollbar(canvas_holder, orient="vertical")
        self._canvas = tk.Canvas(canvas_holder, highlightthickness=0,
                                 yscrollcommand=self._scroll.set)
        self._scroll.config(command=self._canvas.yview)
        self._scroll.pack(side="right", fill="y")
        self._canvas.pack(side="left", fill="both", expand=True)
        self._body = ttk.Frame(self._canvas)
        self._canvas_window = self._canvas.create_window(
            (0, 0), window=self._body, anchor="nw")
        self._body.bind("<Configure>",
                        lambda _e: self._canvas.configure(
                            scrollregion=self._canvas.bbox("all")))
        self._canvas.bind("<Configure>",
                          lambda e: self._canvas.itemconfig(
                              self._canvas_window, width=e.width))
        self._canvas.bind_all("<MouseWheel>",
                              lambda e: self._canvas.yview_scroll(
                                  -1 * (e.delta // 120), "units"))
        body = self._body

        ttk.Label(body, text="Game process (name or PID):").grid(
            row=0, column=0, sticky="w")
        self.proc_var = tk.StringVar()
        self.proc_entry = ttk.Entry(body, textvariable=self.proc_var,
                                    width=30)
        self.proc_entry.grid(row=0, column=1, sticky="w")
        ttk.Button(body, text="Attach",
                   command=self.attach).grid(row=0, column=2, padx=4)
        ttk.Button(body, text="Refresh list",
                   command=self.refresh_processes).grid(row=0, column=3)

        self.proc_list = tk.Listbox(body, height=6)
        self.proc_list.grid(row=1, column=0, columnspan=4, sticky="ew",
                            pady=4)
        self.proc_list.bind("<<ListboxSelect>>", self._pick_process)

        ttk.Label(body, text="Window title (for screenshot):").grid(
            row=2, column=0, sticky="w")
        self.title_var = tk.StringVar()
        ttk.Entry(body, textvariable=self.title_var, width=30).grid(
            row=2, column=1, sticky="w")
        ttk.Button(body, text="Capture",
                   command=self.capture).grid(row=2, column=2, padx=4)
        ttk.Button(body, text="Extract values",
                   command=self.extract).grid(row=2, column=3)

        self.values_list = tk.Listbox(body, height=8)
        self.values_list.config(exportselection=False)
        self.values_list.grid(row=3, column=0, columnspan=4, sticky="ew",
                              pady=4)

        ttk.Label(body, text="Edit value:").grid(
            row=4, column=0, sticky="w")
        self.edit_var = tk.StringVar()
        self.edit_entry = ttk.Entry(body, textvariable=self.edit_var,
                                    width=30)
        self.edit_entry.grid(row=4, column=1, sticky="w")
        self.edit_entry.bind("<KeyRelease>", self._on_edit_key)
        self.values_list.bind("<<ListboxSelect>>", self._on_value_select)
        ttk.Button(body, text="Apply", command=self.apply_edit).grid(
            row=4, column=2, padx=4)
        ttk.Button(body, text="Discard", command=self.discard_edit).grid(
            row=4, column=3)
        self.edit_entry.bind("<Return>", lambda _e: self.apply_edit())

        ttk.Label(body, text="Multiplier:").grid(
            row=5, column=0, sticky="w")
        self.mult_var = tk.StringVar(value="100")
        ttk.Entry(body, textvariable=self.mult_var, width=30).grid(
            row=5, column=1, sticky="w")

        self.adjust_btn = ttk.Button(body, text="Adjust selected",
                                     command=self.adjust)
        self.adjust_btn.grid(row=6, column=0, pady=4)
        ttk.Button(body, text="Verify (re-screenshot)",
                   command=self.verify).grid(row=6, column=1)
        ttk.Button(body, text="Yes — confirmed",
                   command=self.confirm_yes).grid(row=6, column=2)
        ttk.Button(body, text="No — refine",
                   command=self.confirm_no).grid(row=6, column=3)

        ttk.Label(body, text="Mode:").grid(row=7, column=0, sticky="w")
        self.mode_var = tk.StringVar(value="one_shot")
        ttk.Combobox(body, textvariable=self.mode_var, width=12,
                     values=["one_shot", "freeze", "display"]).grid(
            row=7, column=1, sticky="w")
        self.freeze_on_btn = ttk.Button(body, text="Freeze ON",
                                          command=self.freeze_on)
        self.freeze_on_btn.grid(row=7, column=2)
        self.freeze_off_btn = ttk.Button(body, text="Freeze OFF",
                                         command=self.freeze_off)
        self.freeze_off_btn.grid(row=7, column=3)
        self.patch_btn = ttk.Button(body,
                                    text="Patch writer (stubborn value)",
                                    command=self.patch_writer)
        self.patch_btn.grid(row=8, column=0, columnspan=2, pady=4)
        ttk.Label(body, text="Factory wishlist (comma):").grid(
            row=9, column=0, sticky="w")
        self.wishlist_var = tk.StringVar(value="health,stamina,money")
        ttk.Entry(body, textvariable=self.wishlist_var, width=30).grid(
            row=9, column=1, sticky="w")
        ttk.Button(body, text="Draft cheats",
                   command=self.draft_cheats).grid(row=9, column=2)
        ttk.Button(body, text="Promote selected draft",
                   command=self.promote_draft).grid(row=9, column=3)
        self.drafts_list = tk.Listbox(body, height=5)
        self.drafts_list.grid(row=10, column=0, columnspan=4, sticky="ew",
                              pady=4)
        ttk.Button(body, text="Disarm UNSAFE",
                   command=self.disarm_unsafe).grid(
            row=11, column=0, columnspan=2, pady=4)
        self._refresh_controls()

        if self.state.stage == "setup":
            self.after(100, self._auto_open_settings)
        if self.state.session_was_unclean():
            self.unsafe_banner.config(
                text="⚠️ Last session ended uncleanly — freeze/patch "
                     "state may persist in the game. Re-attach, "
                     "re-resolve via the anchor ladder, and explicitly "
                     "re-freeze/re-patch before trusting the target.")
            self.unsafe_banner.pack(fill="x", before=self.header_frame)
            self.after(15000, self._hide_recovery_banner)

    def _hide_recovery_banner(self):
        try:
            self.unsafe_banner.config(text="⚠️ " + UNSAFE_BANNER_COPY)
            if self.freeze_ack or self.patch_ack:
                self._refresh_controls()
            else:
                self.unsafe_banner.pack_forget()
        except tk.TclError:
            pass

    def _auto_open_settings(self):
        try:
            if not self.winfo_exists():
                return
        except tk.TclError:
            return
        if self.state.stage != "setup":
            return
        self.open_settings()

    def log_line(self, text):
        self.log.config(state="normal")
        self.log.insert("end", text + "\n")
        self.log.see("end")
        self.log.config(state="disabled")

    def open_settings(self):
        invoker = self.focus_get()
        dlg = SetupDialog(self, config_mod.load_config()
                          or self.cfg or config_mod.default_config())
        self.wait_window(dlg)
        try:
            if invoker and invoker.winfo_exists():
                invoker.focus_set()
            else:
                self.focus_set()
        except tk.TclError:
            pass
        self.freeze_ack = bool(dlg.freeze_ack_var.get())
        self.patch_ack = bool(dlg.patch_ack_var.get())
        self._refresh_controls()
        armed = self.freeze_ack or self.patch_ack
        if armed and dlg.result:
            self.log_line("UNSAFE armed — Freeze/Patch enabled for "
                          "this session.")
        if dlg.result:
            self.cfg = dlg.result
            self.state.config = dlg.result
            self.state.stage = ("process" if not self.state.settings_return
                                else self.state.stage)
            self.state.settings_return = False
            self.log_line("Settings saved.")

    def view_runbook(self):
        path = runbook_mod.resolve_path(
            self.state.process_name or "game")
        if os.path.exists(path):
            os.startfile(path)
        else:
            messagebox.showinfo("Runbook", f"No runbook yet.\n{path}")

    def refresh_processes(self):
        try:
            resp = ce_client.get_process_list(self.bridge)
        except Exception as exc:
            messagebox.showerror("Process list", str(exc))
            return
        self.proc_list.delete(0, "end")
        for p in resp.get("processes", [])[:500]:
            self.proc_list.insert("end", f"{p.get('pid')}  {p.get('name')}")

    def _pick_process(self, _event):
        sel = self.proc_list.curselection()
        if sel:
            self.proc_var.set(self.proc_list.get(sel[0]).split()[0])

    def _set_writes_enabled(self, enabled):
        self._writes_ok = enabled
        self._refresh_controls()

    def _refresh_controls(self):
        writes_ok = self._writes_ok
        freeze_state = "normal" if (writes_ok and self.freeze_ack) \
            else "disabled"
        patch_state = "normal" if (writes_ok and self.patch_ack) \
            else "disabled"
        for btn, state in ((self.adjust_btn,
                            "normal" if writes_ok else "disabled"),
                           (self.freeze_on_btn, freeze_state),
                           (self.freeze_off_btn, freeze_state),
                           (self.patch_btn, patch_state)):
            try:
                btn.config(state=state)
            except tk.TclError:
                pass
        armed = self.freeze_ack or self.patch_ack
        try:
            if armed:
                self.unsafe_banner.pack(fill="x", before=self.header_frame)
                self.freeze_on_btn.config(
                    text="Freeze ON" + ("  🔶 ARMED"
                                        if self.freeze_ack else ""))
                self.patch_btn.config(
                    text="Patch writer (stubborn value)"
                         + ("  🔶 ARMED" if self.patch_ack else ""))
            else:
                self.unsafe_banner.pack_forget()
                self.freeze_on_btn.config(text="Freeze ON")
                self.patch_btn.config(text="Patch writer (stubborn value)")
        except tk.TclError:
            pass

    def disarm_unsafe(self):
        freeze_labels = list(self.state.registry.freezes.keys())
        for label in freeze_labels:
            if self.state.registry.stop_freeze(label, restore=True):
                self.log_line(
                    f"Freeze OFF (restored): {label}")
        self.freeze_ack = False
        self.patch_ack = False
        self._refresh_controls()
        self.log_line("UNSAFE disarmed — Freeze/Patch disabled until "
                      "re-arm in Setup.")

    def attach(self):
        self._set_writes_enabled(True)
        if self.state.attach_process(
                self.proc_var.get().strip(),
                self.title_var.get().strip()):
            self.log_line(f"Attached to PID {self.state.process_id}")
            suggestion = None
            path = runbook_mod.resolve_path(self.state.process_name)
            if os.path.exists(path):
                suggestion = runbook_mod.suggest_recipe(path, "")
            if suggestion:
                self.log_line(suggestion)
        else:
            if self.state.refused:
                messagebox.showerror("Refuse", self.state.last_error)
                self._set_writes_enabled(False)
            else:
                messagebox.showerror(
                    "Attach failed",
                    ATTACH_FAILED_TEMPLATE.format(
                        reason=self.state.last_error))
            try:
                self.proc_entry.focus_set()
                self.proc_entry.selection_range(0, "end")
            except tk.TclError:
                pass

    def _grab_game_rect(self, handle):
        try:
            return ce_client.get_window_rect(self.bridge, handle)
        except Exception as exc:
            rect = screenshot.fullscreen_rect()
            self.log_line(f"Window rect unavailable ({exc}) — falling "
                          f"back to fullscreen {rect['width']}x"
                          f"{rect['height']}.")
            return rect

    def capture(self):
        try:
            found = ce_client.find_game_window(
                self.bridge, self.title_var.get().strip() or None)
            self.state.window_handle = found["handle"]
            rect = self._grab_game_rect(found["handle"])
            b64 = screenshot.capture_game_window(rect)
            self.state.before_b64 = b64
            self.state.window_title = self.title_var.get().strip()
            self.log_line(f"Captured {rect['width']}x{rect['height']} "
                          f"({len(b64)//1024} KB base64)")
        except Exception as exc:
            messagebox.showerror("Capture failed", f"Capture — failed: {exc}")

    def extract(self):
        try:
            values = llm_client.extract_values(
                self.cfg["endpoint"], self.cfg["vision_model"],
                self.state.before_b64)
        except Exception as exc:
            messagebox.showerror("Extract failed", str(exc))
            return
        self.state.values = values
        self._pending_edits = set()
        self.values_list.delete(0, "end")
        for v in values:
            self.values_list.insert("end", self._format_value_row(v))

    def _format_value_row(self, v, pending=None):
        row = (f"{v['label']}: {v['value']} [{v['value_type']}] "
               f"conf={v['confidence']:.2f}")
        if pending:
            row += " — edited (uncommitted)"
        return row

    def _render_value_row(self, sel):
        if sel < 0 or sel >= len(self.state.values):
            return
        v = self.state.values[sel]
        pending = sel in self._pending_edits
        self.values_list.delete(sel)
        self.values_list.insert(
            sel, self._format_value_row(v, pending=pending))
        self.values_list.selection_set(sel)
        self.values_list.activate(sel)

    _INTEGER_TYPES = ("byte", "word", "dword", "qword")

    def _commit_operand(self, raw, value_type_hint=None):
        text = str(raw).strip()
        hint = (value_type_hint or "").lower()
        if hint in self._INTEGER_TYPES:
            try:
                return int(text)
            except ValueError:
                raise ValueError(f"Edit — invalid integer: {text!r}")
        try:
            return int(text)
        except ValueError:
            pass
        value = float(text)
        if value == float("inf") or value == float("-inf") \
                or value != value:
            raise ValueError(f"Edit — invalid number: {text!r}")
        return value

    def apply_edit(self):
        sel = self.values_list.curselection()
        item = self._selected_value()
        if not item:
            messagebox.showinfo("Edit", "Select a value first.")
            return
        raw = self.edit_var.get()
        try:
            parsed = self._commit_operand(raw, item.get("value_type"))
        except ValueError as exc:
            messagebox.showerror("Edit failed", str(exc))
            try:
                self.edit_entry.focus_set()
            except tk.TclError:
                pass
            return
        sel = sel[0]
        item["value"] = parsed
        self._pending_edits.discard(sel)
        self.edit_var.set("")
        self._render_value_row(sel)
        self.log_line(f"Edit applied: {item['label']} = {parsed}")

    def discard_edit(self):
        sel = self.values_list.curselection()
        if not sel:
            return
        sel = sel[0]
        self._pending_edits.discard(sel)
        if sel < len(self.state.values):
            self.edit_var.set(
                str(self.state.values[sel]["value"]))
        self._render_value_row(sel)

    def _on_value_select(self, _event):
        sel = self.values_list.curselection()
        if not sel or not self.state.values:
            return
        sel = sel[0]
        if sel < len(self.state.values):
            self.edit_var.set(str(self.state.values[sel]["value"]))

    def _on_edit_key(self, _event):
        sel = self.values_list.curselection()
        if not sel or not self.state.values:
            return
        sel = sel[0]
        if sel >= len(self.state.values):
            return
        raw = self.edit_var.get()
        try:
            committed = self.state.values[sel]["value"]
            differs = float(raw) != float(committed)
        except ValueError:
            differs = bool(raw.strip())
        if differs:
            self._pending_edits.add(sel)
        else:
            self._pending_edits.discard(sel)
        self._render_value_row(sel)

    def _selected_value(self):
        sel = self.values_list.curselection()
        if not sel or not self.state.values:
            return None
        return self.state.values[sel[0]]

    def _read_multiplier(self):
        raw = self.mult_var.get().strip()
        try:
            value = float(raw)
        except ValueError:
            raise ValueError(
                "Multiplier must be a number from 1 to 1000000.")
        if value < 1 or value > 1000000:
            raise ValueError(
                "Multiplier must be a number from 1 to 1000000.")
        return value

    def _write_preview_confirm(self, details):
        fallback_flag = getattr(self.state, "last_plan_fallback", False)
        lines = [
            f"Address: {details['address']}",
            f"Label: {details['label']}",
            f"Write: {details['observed']} × "
            f"{self.state.last_multiplier} = "
            f"{details['target_value']} "
            f"({details['value_type']}, "
            f"scan_option={details.get('scan_option', 'exact')}"
            + (f", tolerance={details.get('tolerance')}"
               if details.get("tolerance") else "") +
            (", clamped to type max" if details.get("clamped") else "")
            + ")",
        ]
        if fallback_flag:
            lines.append(
                "Adjust model unreachable — using local ×{m} "
                "fallback.".replace("{m}", str(self.state.last_multiplier)))
        lines.append(
            "CE safety-setting status: Query memory region "
            "routines expected disabled (repo policy).")
        dialog = PreviewDialog(
            self, "Write preview",
            "\n".join(lines), ok_label="Write")
        self.wait_window(dialog)
        approved = bool(dialog.result)
        return approved

    def adjust(self):
        item = self._selected_value()
        if not item:
            messagebox.showinfo("Adjust", "Select a value first.")
            return
        try:
            multiplier = self._read_multiplier()
        except ValueError as exc:
            messagebox.showerror("Adjust", str(exc))
            try:
                for child in self._body.winfo_children():
                    if child.widgetName.endswith("entry") and \
                            str(child.cget("textvariable")) == \
                            str(self.mult_var):
                        child.focus_set()
                        break
            except tk.TclError:
                pass
            return
        self.state.last_multiplier = multiplier
        try:
            plan = llm_client.compute_write_plan(
                self.cfg["endpoint"], self.cfg["adjust_model"],
                item["label"], item["value"], item["value_type"],
                multiplier=multiplier)
            self.state.last_plan_fallback = False
        except Exception:
            plan = llm_client.fallback_write_plan(
                item["label"], item["value"], item["value_type"],
                multiplier=multiplier)
            self.state.last_plan_fallback = True
            self.log_line(
                "Adjust model unreachable — local ×100 fallback."
                if multiplier == 100 else
                f"Adjust model unreachable — local ×{multiplier} "
                "fallback.")
        try:
            out = scan_flow.adjust_to_100x(
                self.bridge, item["label"], item["value"],
                plan.get("value_type", item["value_type"]),
                target_value=plan.get("target_value"),
                scan_option=plan.get("scan_option", "exact"),
                tolerance=plan.get("tolerance", 0),
                picker=None, narrow_values=[],
                writer=self._write_preview_confirm)
            out["multiplier"] = multiplier
            out["fallback"] = self.state.last_plan_fallback
            out["clamped"] = plan.get("clamped", False)
            self.state.write_result = out
            self.state.selected = item
            for line in out["trace"]:
                self.log_line(line)
        except scan_flow.WriteCancelled:
            self.state.confirm_no()
            self.log_line(
                "Back to refine: re-capture or re-narrow the scan.")
        except scan_flow.NeedNarrowingValue as exc:
            messagebox.showinfo("Narrow scan",
                                f"{exc}\nChange the value in-game, then use "
                                "Verify to continue narrowing.")
        except scan_flow.ScanError as exc:
            messagebox.showerror("Scan failed", str(exc))

    def verify(self):
        try:
            expected = (self.state.write_result or {}).get("target_value")
            if not self.state.before_b64 or expected is None:
                messagebox.showinfo("Verify", "Adjust a value first.")
                return
            found = ce_client.find_game_window(
                self.bridge, self.title_var.get().strip() or None)
            rect = self._grab_game_rect(found["handle"])
            after = screenshot.capture_game_window(rect)
            self.state.after_b64 = after
            verdict = llm_client.verify_value(
                self.cfg["endpoint"], self.cfg["vision_model"],
                self.state.before_b64, after, expected)
            self.log_line(f"Verify: observed={verdict['observed']} "
                          f"match={verdict['match']}")
            if messagebox.askyesno(
                    "Confirm",
                    VERIFY_CONFIRM_TEMPLATE.format(
                        observed=verdict['observed'],
                        expected=expected),
                    default="no"):
                self.confirm_yes()
            else:
                self.confirm_no()
        except Exception as exc:
            messagebox.showerror("Verify failed", str(exc))

    def confirm_yes(self):
        try:
            path = self.state.confirm_yes()
            self.log_line(f"RUNBOOK updated: {path}")
            messagebox.showinfo("Done", f"RUNBOOK updated:\n{path}")
        except Exception as exc:
            messagebox.showerror("Runbook failed", str(exc))

    def confirm_no(self):
        self.state.confirm_no()
        self.log_line("Back to refine: re-capture or re-narrow the scan.")

    def reapply_profile(self):
        if not self.state.process_id:
            messagebox.showinfo("Re-apply", "Attach to the game first.")
            return
        outcomes = self.state.reapply_profile(
            writer=self._confirm_reapply_write)
        if not outcomes:
            messagebox.showinfo("Re-apply", "No profile cheats yet.")
            return
        written = sum(1 for o in outcomes
                      if o.get("status") in ("written", "frozen"))
        skipped = sum(1 for o in outcomes
                      if o.get("status") == "skipped_user")
        failed = len(outcomes) - written - skipped
        for o in outcomes:
            status = o.get("status")
            if status == "written":
                self.log_line(f"Re-applied {o['label']} @ {o['address']} "
                              f"({o.get('level')}).")
            elif status == "frozen":
                self.log_line(f"Frozen {o['label']} @ {o['address']} "
                              f"(re-apply).")
            elif status == "display_only":
                self.log_line(f"Readout-only {o['label']} @ {o['address']} "
                              "(display mode, no write).")
            elif status == "skipped_user":
                self.log_line(f"Skipped {o['label']} (not confirmed).")
            elif status == "ambiguous":
                self.log_line(f"Ambiguous anchor for {o['label']}: "
                              f"{o.get('error')}")
            else:
                self.log_line(f"Failed {o['label']}: {o.get('error')}")
        self.log_line(f"Re-apply done: {written} written, {skipped} "
                      f"skipped, {failed} failed.")

    def validate_profile(self):
        path = profiles_mod.resolve_path(
            self.state.process_name or "game",
            base_dir=self.state.profiles_dir)
        try:
            report = profiles_mod.validate_profile(path)
        except Exception as exc:
            messagebox.showerror("Validate failed", str(exc))
            return
        lines = [f"Profile: {os.path.basename(path)}",
                 report["summary"]]
        for row in report["cheats"]:
            mark = "PASS" if row["status"] == "pass" else "FAIL"
            detail = "".join(
                "\n  - " + p for p in row["problems"])
            lines.append(f"{mark} {row['label']}" + detail)
        self.log_line(f"Validate profile: {report['summary']} "
                      f"({os.path.basename(path)})")
        messagebox.showinfo("Validate profile", "\n".join(lines))

    def _confirm_reapply_write(self, details):
        lines = [
            f"Label: {details['label']}",
            f"Address: {details['address']}",
            f"Old: {details['old_value']} -> New: {details['new_value']}",
        ]
        dialog = PreviewDialog(
            self, "Re-apply preview",
            "\n".join(lines), ok_label="Write")
        self.wait_window(dialog)
        return bool(dialog.result)

    def freeze_on(self):
        if not self.freeze_ack:
            messagebox.showinfo(
                "Freeze", "Freeze is UNSAFE-gated — arm it in Setup first.")
            return
        result = self.state.write_result or {}
        if not result.get("address"):
            messagebox.showinfo("Freeze", "Adjust a value first.")
            return
        label = result.get("label", "stat")
        address = result.get("address")
        value = result.get("target_value")
        vtype = result.get("value_type", "dword")
        mode = self.mode_var.get()
        if mode == "display":
            self._start_display(label, address, vtype)
            return
        dialog = PreviewDialog(
            self, "Freeze preview",
            f"Freeze {label} @ {address} = {value}\n"
            "Repeatedly writes the target value until you quit cleanly. "
            "Can corrupt saves.", ok_label="Freeze")
        self.wait_window(dialog)
        if not dialog.result:
            return
        self.state.mark_session_active()
        self.state.registry.start_freeze(label, address, value, vtype)
        self.log_line(f"Freeze ON: {label} @ {address} = {value}")

    def _start_display(self, label, address, vtype):
        if not self.state.registry.pollers.get(label):
            import queue as queue_mod
            self._display_queue = getattr(self, "_display_queue", None) \
                or queue_mod.Queue()
            self.state.registry.pollers[label] = \
                freeze_mod.DisplayPoller(
                    self.bridge, address, value_type=vtype,
                    callback=lambda v: self._display_queue.put(
                        (label, v)))
            self.state.registry.pollers[label].start()
            self.log_line(f"Display ON: {label} @ {address}")
            self.after(500, self._drain_display_queue)

    def _drain_display_queue(self):
        import queue as queue_mod
        q = getattr(self, "_display_queue", None)
        if q is None:
            return
        try:
            while True:
                label, value = q.get_nowait()
                self.log_line(f"Display {label} = {value}")
        except queue_mod.Empty:
            pass
        if self.state.registry.pollers:
            self.after(500, self._drain_display_queue)

    def freeze_off(self):
        item = self._selected_value()
        result = self.state.write_result or {}
        label = result.get("label", (item or {}).get("label", "stat"))
        if self.state.registry.pollers.pop(label, None):
            self.log_line(f"Display OFF: {label}")
            return
        if self.state.registry.stop_freeze(label, restore=True):
            self.log_line(f"Freeze OFF (restored): {label}")
        else:
            messagebox.showinfo("Freeze", f"No active freeze for {label}.")

    def patch_writer(self):
        if not self.patch_ack:
            messagebox.showinfo(
                "Patch", "Patch is UNSAFE-gated — arm it in Setup first.")
            return
        result = self.state.write_result or {}
        address = result.get("address")
        if not address:
            messagebox.showinfo("Patch", "Adjust a value first.")
            return
        if not messagebox.askyesno(
                "Patch writer",
                PATCH_CONFIRM_TEMPLATE.format(address=address),
                default="no"):
            return
        try:
            module = (result.get("module_offset", "") or "").split("+")[0]
            out = codepatch_mod.escalate_stubborn_value(
                self.bridge, address,
                result.get("value_type", "dword"), module or "")
        except codepatch_mod.AmbiguousSignature as exc:
            messagebox.showinfo("Patch skipped", str(exc))
            return
        except codepatch_mod.PatchError as exc:
            messagebox.showerror("Patch failed", str(exc))
            return
        if not out.get("patched"):
            messagebox.showinfo(
                "Patch skipped",
                out.get("plan", {}).get("reason", "not patchable"))
            return
        self.state.applied_patches.append(out["patch"])
        self.state.mark_session_active()
        fp = out.get("fingerprint", {})
        self.log_line(f"Patched writer {out['hit']['address']} "
                      f"(sig {fp.get('signature', '')}). "
                      f"Restored automatically on exit.")

    def draft_cheats(self):
        wishlist = [w.strip() for w in self.wishlist_var.get().split(",")
                    if w.strip()]
        drafts, manual = factory_mod.draft_cheats(self.state.values,
                                                  wishlist)
        self.state.drafts = drafts
        path = profiles_mod.draft_path(
            self.state.process_name or "game",
            base_dir=self.state.profiles_dir)
        factory_mod.write_drafts(
            path, self.state.process_name or "game", drafts)
        self.drafts_list.delete(0, "end")
        for d in drafts:
            if d.get("verified"):
                row = f"✅ Verified: {d['label']} ({d['category']}): " \
                      f"{d['look_for']}"
            else:
                row = f"⚠️ Unverified: {d['label']} ({d['category']}): " \
                      f"{d['look_for']}"
            self.drafts_list.insert("end", row)
        for m in manual:
            self.log_line(f"Manual: {m['label']}: {m['reason']}")
        self.log_line(f"Drafts written (replaced): {path}. "
                      f"Verify each in-game before promoting.")

    def promote_draft(self):
        sel = self.drafts_list.curselection()
        if not sel or not getattr(self.state, "drafts", None):
            messagebox.showinfo("Promote", "Draft cheats first.")
            return
        draft = self.state.drafts[sel[0]]
        if not draft.get("verified"):
            messagebox.showinfo(
                "Promote",
                f"{draft['label']} is unverified — verify it in-game first. "
                "Re-run Draft cheats after the values change to refresh.")
            return
        live = profiles_mod.resolve_path(
            self.state.process_name or "game",
            base_dir=self.state.profiles_dir)
        factory_mod.promote_draft(
            live, self.state.process_name or "game", draft)
        self.log_line(f"Promoted {draft['label']} to live profile.")

    def open_profiles(self):
        folder = self.state.profiles_dir
        os.makedirs(folder, exist_ok=True)
        os.startfile(folder)

    def export_ct(self):
        from tkinter import filedialog
        path = profiles_mod.resolve_path(
            self.state.process_name or "game",
            base_dir=self.state.profiles_dir)
        cheats = profiles_mod.list_cheats(path)
        if not cheats:
            messagebox.showinfo("Export .CT", "No profile cheats yet.")
            return
        dest = filedialog.asksaveasfilename(
            defaultextension=".CT", initialfile="cheats.CT",
            filetypes=[("Cheat Table", "*.CT")])
        if not dest:
            return
        entries, skipped = profiles_mod.export_ct_entries(cheats)
        profiles_mod.write_ct_file(dest, cheats)
        msg = f"Exported {len(entries)} entries to {dest}."
        for s in skipped:
            msg += f"\nSkipped {s['label']}: {s['reason']}"
        messagebox.showinfo("Export .CT", msg)

    def on_close(self):
        try:
            results = self.state.shutdown()
            restored = [r for r in results if r.get("restored")]
            failed = [r for r in results if not r.get("restored")]
            if results:
                lines = [f"{'Restored' if r.get('restored') else 'FAILED'}: "
                         f"{r.get('label')}" for r in results]
                title = ("Restore checklist"
                         f" — {len(restored)} restored, "
                         f"{len(failed)} failed")
                messagebox.showinfo(title, "\n".join(lines))
        finally:
            self.destroy()


def main():
    import atexit
    app = App()
    atexit.register(lambda: freeze_mod.restore_on_exit(
        app.bridge, app.state.registry,
        patches=app.state.applied_patches))
    app.mainloop()


if __name__ == "__main__":
    main()
