"""Opt-in live tests: need harness + CE bridge. Skipped otherwise.

Run: pytest vision_trainer/tests/test_harness_live.py -m live
"""
import os
import subprocess
import sys
import time

import pytest

pytestmark = pytest.mark.live

HARNESS = os.path.join(os.path.dirname(__file__), "..", "harness",
                       "target.py")


def _ce_reachable():
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))
    try:
        from vision_trainer import ce_client
        bridge = ce_client.CEBridge()
        ce_client.ping(bridge)
        return True
    except Exception:
        return False


@pytest.fixture()
def harness():
    proc = subprocess.Popen([sys.executable, HARNESS],
                            stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE, text=True)
    time.sleep(0.3)
    yield proc
    try:
        proc.stdin.write("QUIT\n")
        proc.stdin.flush()
    except Exception:
        pass
    proc.terminate()


def _ask(proc, cmd):
    proc.stdin.write(cmd + "\n")
    proc.stdin.flush()
    return proc.stdout.readline().strip()


def test_harness_protocol(harness):
    assert _ask(harness, "GET gold").startswith("OK 5000")
    assert _ask(harness, "SET gold 500000").startswith("OK")
    assert _ask(harness, "GET gold") == "OK 500000"


def test_harness_drain_and_hold(harness):
    _ask(harness, "SET gold 5000")
    _ask(harness, "DRAIN")
    time.sleep(0.5)
    first = _ask(harness, "GET gold")
    assert first.startswith("OK ")
    assert int(first.split()[1]) < 5000
    _ask(harness, "HOLD")


def test_freeze_holds_against_drain(harness):
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))
    from vision_trainer import freeze as freeze_mod

    class StubBridge:
        def __init__(self):
            self.value = 5000

        def send_command(self, method, params=None):
            if method == "read_integer":
                return {"success": True, "value": self.value}
            if method == "write_integer":
                self.value = (params or {}).get("value", self.value)
                harness.stdin.write(f"SET gold {self.value}\n")
                harness.stdin.flush()
                harness.stdout.readline()
                return {"success": True}
            return {"success": True}

    bridge = StubBridge()
    worker = freeze_mod.FreezeWorker(bridge, "0xFAKE", 500000, "dword",
                                     interval=0.02)
    worker.start()
    time.sleep(0.1)
    worker.stop()
    assert _ask(harness, "GET gold") == "OK 500000"
    worker.restore()


def test_scan_freeze_watch_needs_ce():
    if not _ce_reachable():
        pytest.skip("CE bridge unreachable; harness-only checks ran above")
