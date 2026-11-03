"""Freeze / display workers + restore-on-exit.

Force-kill caveat (Apprentice lesson): cleanup only runs on normal quit.
If this process is killed, frozen values / patches stay until re-attach
or game restart.
"""

import random
import threading
import time


class FreezeWorker:
    def __init__(self, bridge, address, value, value_type="dword",
                 interval=0.25):
        self.bridge = bridge
        self.address = address
        self.value = value
        self.value_type = value_type
        self.interval = interval
        self.original_value = None
        self.running = False
        self._thread = None
        self._stop = threading.Event()

    def _capture_original(self):
        try:
            resp = self.bridge.send_command("read_integer", {
                "address": self.address, "type": self.value_type})
            if resp.get("success"):
                self.original_value = resp.get("value")
        except Exception:
            pass

    def _loop(self):
        while not self._stop.wait(
                self.interval + random.uniform(0, self.interval * 0.2)):
            try:
                self.bridge.send_command("write_integer", {
                    "address": self.address, "value": self.value,
                    "type": self.value_type})
            except Exception:
                pass

    def start(self):
        if self.running:
            return self
        if self.original_value is None:
            self._capture_original()
        self._stop.clear()
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._thread.start()
        self.running = True
        return self

    def stop(self):
        if not self.running and self._thread is None:
            return
        self._stop.set()
        self.running = False

    def restore(self):
        self.stop()
        if self.original_value is None:
            return False
        try:
            resp = self.bridge.send_command("write_integer", {
                "address": self.address, "value": self.original_value,
                "type": self.value_type})
            return bool(resp.get("success"))
        except Exception:
            return False


class DisplayPoller:
    def __init__(self, bridge, address, value_type="dword", callback=None,
                 interval=0.5):
        self.bridge = bridge
        self.address = address
        self.value_type = value_type
        self.callback = callback or (lambda v: None)
        self.interval = interval
        self.running = False
        self._thread = None
        self._stop = threading.Event()

    def _loop(self):
        while not self._stop.wait(self.interval):
            try:
                resp = self.bridge.send_command("read_integer", {
                    "address": self.address, "type": self.value_type})
                if resp.get("success"):
                    self.callback(resp.get("value"))
            except Exception:
                pass

    def start(self):
        if self.running:
            return self
        self._stop.clear()
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._thread.start()
        self.running = True
        return self

    def stop(self):
        if self._thread is None and not self.running:
            return
        self._stop.set()
        self.running = False


class WorkerRegistry:
    def __init__(self, bridge):
        self.bridge = bridge
        self.freezes = {}
        self.pollers = {}

    def start_freeze(self, label, address, value, value_type="dword",
                     interval=0.25):
        existing = self.freezes.get(label)
        if existing is not None:
            return existing
        worker = FreezeWorker(self.bridge, address, value, value_type,
                              interval=interval)
        self.freezes[label] = worker
        worker.start()
        return worker

    def stop_freeze(self, label, restore=True):
        worker = self.freezes.pop(label, None)
        if worker is None:
            return False
        if restore:
            return worker.restore()
        worker.stop()
        return True

    def restore_all(self):
        for label in list(self.freezes):
            self.stop_freeze(label, restore=True)
        for label, poller in list(self.pollers.items()):
            poller.stop()
        self.pollers.clear()


def restore_on_exit(bridge, registry, patches=None):
    if registry is not None:
        try:
            registry.restore_all()
        except Exception:
            pass
    for patch in patches or []:
        try:
            bridge.send_command("write_memory", {
                "address": patch.get("address"),
                "bytes": list(patch.get("original_bytes", []))})
        except Exception:
            pass
    try:
        bridge.send_command("clear_all_breakpoints")
    except Exception:
        pass
