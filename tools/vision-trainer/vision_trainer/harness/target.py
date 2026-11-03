"""Dummy target harness: known values for opt-in live tests.

Run: python vision_trainer/harness/target.py [--port PORT]
Protocol (one line in, one line out on stdout):
  GET <name>      -> OK <value>
  SET <name> <v>  -> OK <value>
  DRAIN           -> OK draining (counter thread decrements gold)
  HOLD            -> OK holding (stop drain)
  QUIT            -> OK bye (exit)

Fields: gold (int, drains when draining), hp (int), mana (float),
ammo (int), chain_ptr (echoes base+offsets for anchor tests).
Requires a live CE bridge to be useful; the pytest live tests spawn this
process and skip if CE is unreachable.
"""
import sys
import threading
import time

FIELDS = {"gold": 5000, "hp": 100, "mana": 75.5, "ammo": 30}
CHAIN = {"base": "game.exe+0x1000", "offsets": [0x20, 0x8]}

_draining = False
_lock = threading.Lock()


def _drain_loop():
    while True:
        time.sleep(0.2)
        with _lock:
            if _draining and FIELDS["gold"] > 0:
                FIELDS["gold"] -= 1


threading.Thread(target=_drain_loop, daemon=True).start()

for raw in sys.stdin:
    parts = raw.strip().split()
    if not parts:
        continue
    cmd = parts[0].upper()
    if cmd == "GET" and len(parts) == 2:
        name = parts[1]
        if name == "chain_ptr":
            print(f"OK {CHAIN['base']}+{CHAIN['offsets']}", flush=True)
        elif name in FIELDS:
            with _lock:
                print(f"OK {FIELDS[name]}", flush=True)
        else:
            print("ERR unknown field", flush=True)
    elif cmd == "SET" and len(parts) == 3:
        name, val = parts[1], parts[2]
        if name in FIELDS:
            with _lock:
                FIELDS[name] = type(FIELDS[name])(float(val))
            print(f"OK {FIELDS[name]}", flush=True)
        else:
            print("ERR unknown field", flush=True)
    elif cmd == "DRAIN":
        with _lock:
            globals()["_draining"] = True
        print("OK draining", flush=True)
    elif cmd == "HOLD":
        with _lock:
            globals()["_draining"] = False
        print("OK holding", flush=True)
    elif cmd == "QUIT":
        print("OK bye", flush=True)
        break
    else:
        print("ERR bad command", flush=True)
