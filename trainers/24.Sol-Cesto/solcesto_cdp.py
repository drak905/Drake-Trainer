#!/usr/bin/env python3
"""
Minimal zero-dependency Chrome DevTools Protocol client for Sol Cesto
(Construct 3 game running inside WebView2).

Requires the game to be launched with a debugging port:

    $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS="--remote-debugging-port=9222"
    & "E:\\EpicGames\\SolCesto\\SolCesto.exe"

Usage:
    python solcesto_cdp.py targets            # list debuggable targets
    python solcesto_cdp.py eval "1+1"         # evaluate JS in the game page
    python solcesto_cdp.py probe              # look for the Construct 3 runtime

Implements just enough of RFC 6455 (client-side, text frames, no
extensions) to talk to CDP without installing websocket-client.
"""

import base64
import json
import os
import socket
import struct
import sys
import urllib.request

HOST = os.environ.get("CDP_HOST", "127.0.0.1")
PORT = int(os.environ.get("CDP_PORT", "9222"))


# ---------------------------------------------------------------- HTTP side

def http_targets():
    """Return the CDP target list via the /json endpoint."""
    url = f"http://{HOST}:{PORT}/json"
    with urllib.request.urlopen(url, timeout=5) as resp:
        return json.load(resp)


def pick_page_target(targets):
    """Choose the most likely game page target."""
    pages = [t for t in targets if t.get("type") == "page"]
    if not pages:
        return None
    # Prefer a target that looks like the Construct 3 game rather than about:blank
    for t in pages:
        url = (t.get("url") or "").lower()
        if url and not url.startswith("about:"):
            return t
    return pages[0]


# ----------------------------------------------------------- WebSocket side

class WebSocket:
    """Tiny client-side WebSocket for CDP. Text frames only."""

    def __init__(self, ws_url, timeout=10):
        if not ws_url.startswith("ws://"):
            raise ValueError(f"only ws:// supported, got {ws_url!r}")
        rest = ws_url[len("ws://"):]
        hostport, _, path = rest.partition("/")
        path = "/" + path
        host, _, port = hostport.partition(":")
        port = int(port or 80)

        self.sock = socket.create_connection((host, port), timeout=timeout)
        self._handshake(host, port, path)
        self._buf = b""

    def _handshake(self, host, port, path):
        key = base64.b64encode(os.urandom(16)).decode()
        req = (
            f"GET {path} HTTP/1.1\r\n"
            f"Host: {host}:{port}\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            "Sec-WebSocket-Version: 13\r\n"
            "\r\n"
        )
        self.sock.sendall(req.encode())

        # Read until end of headers
        data = b""
        while b"\r\n\r\n" not in data:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise ConnectionError("connection closed during handshake")
            data += chunk
        head, _, tail = data.partition(b"\r\n\r\n")
        status = head.split(b"\r\n", 1)[0].decode(errors="replace")
        if "101" not in status:
            raise ConnectionError(f"handshake failed: {status}")
        self._pending = tail

    # -- framing ---------------------------------------------------------

    def send(self, text):
        payload = text.encode()
        header = bytearray()
        header.append(0x81)  # FIN + text opcode
        mask = os.urandom(4)
        n = len(payload)
        if n < 126:
            header.append(0x80 | n)
        elif n < 65536:
            header.append(0x80 | 126)
            header += struct.pack(">H", n)
        else:
            header.append(0x80 | 127)
            header += struct.pack(">Q", n)
        header += mask
        masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        self.sock.sendall(bytes(header) + masked)

    def _read(self, n):
        while len(self._pending) < n:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise ConnectionError("connection closed")
            self._pending += chunk
        out, self._pending = self._pending[:n], self._pending[n:]
        return out

    def recv(self):
        """Receive one text message, skipping control frames."""
        while True:
            b0, b1 = self._read(2)
            opcode = b0 & 0x0F
            masked = b1 & 0x80
            length = b1 & 0x7F
            if length == 126:
                length = struct.unpack(">H", self._read(2))[0]
            elif length == 127:
                length = struct.unpack(">Q", self._read(8))[0]
            mask = self._read(4) if masked else None
            payload = self._read(length) if length else b""
            if mask:
                payload = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))

            if opcode == 0x1:              # text
                return payload.decode(errors="replace")
            if opcode == 0x8:              # close
                raise ConnectionError("server closed the websocket")
            if opcode == 0x9:              # ping -> pong
                self.sock.sendall(b"\x8a\x80" + os.urandom(4))
            # else: continuation/binary/pong -> ignore

    def close(self):
        try:
            self.sock.sendall(b"\x88\x80" + os.urandom(4))
        except OSError:
            pass
        self.sock.close()


# ------------------------------------------------------------------- CDP

class CDP:
    def __init__(self, ws_url):
        self.ws = WebSocket(ws_url)
        self._id = 0

    def call(self, method, params=None, session_id=None):
        self._id += 1
        msg_id = self._id
        msg = {
            "id": msg_id,
            "method": method,
            "params": params or {},
        }
        if session_id:
            msg["sessionId"] = session_id
        self.ws.send(json.dumps(msg))
        # CDP interleaves events with responses; wait for our id.
        while True:
            reply = json.loads(self.ws.recv())
            if reply.get("id") == msg_id:
                if "error" in reply:
                    raise RuntimeError(reply["error"])
                return reply.get("result", {})

    def evaluate(self, expression, session_id=None):
        """Evaluate JS and return a plain Python value."""
        res = self.call("Runtime.evaluate", {
            "expression": expression,
            "returnByValue": True,
            "awaitPromise": True,
        }, session_id=session_id)
        if res.get("exceptionDetails"):
            desc = res["exceptionDetails"].get("text", "exception")
            details = res["exceptionDetails"].get("exception", {})
            raise RuntimeError(f"{desc}: {details.get('description', '')}")
        return res.get("result", {}).get("value")

    def close(self):
        self.ws.close()


def connect():
    targets = http_targets()
    target = pick_page_target(targets)
    if not target:
        raise SystemExit("No 'page' target found. Is the game running with --remote-debugging-port?")
    return CDP(target["webSocketDebuggerUrl"]), target


# ------------------------------------------------------------- entrypoints

# JS that hunts for the Construct 3 runtime object in the page.
PROBE_JS = r"""
(() => {
  const out = { globals: [], found: null, keys: [] };
  const cands = ["c3_runtimeInterface", "cr_getC3Runtime", "C3", "c3", "runtime"];
  for (const name of cands) {
    if (typeof window[name] !== "undefined") out.globals.push(name);
  }
  // Construct 3 exposes the runtime through the runtimeInterface in most exports
  let rt = null;
  try {
    const ri = window.c3_runtimeInterface;
    if (ri) rt = ri._localRuntime || ri.GetLocalRuntime?.() || null;
  } catch (e) {}
  if (!rt && window.runtime) rt = window.runtime;
  if (rt) {
    out.found = true;
    out.keys = Object.keys(rt).slice(0, 60);
    try {
      const ev = rt._eventSheetManager || rt.GetEventSheetManager?.();
      if (ev) {
        const vars = ev._allGlobalVars || ev.GetAllGlobalVariables?.() || [];
        out.globalVars = vars.map(v => ({
          name: v._name ?? v.GetName?.(),
          value: v._value ?? v.GetValue?.(),
        }));
      }
    } catch (e) { out.varError = String(e); }
  } else {
    out.found = false;
    out.windowKeys = Object.keys(window).filter(k => /c3|construct|runtime/i.test(k));
  }
  return JSON.stringify(out);
})()
"""


# Generic probe that works in BOTH window and worker scopes. Construct 3
# exports in "worker mode" keep the runtime (and all global variables) inside
# a Web Worker, so window-only probing finds nothing.
WORKER_PROBE_JS = r"""
(() => {
  const g = globalThis;
  const out = { scope: (typeof window === "undefined" ? "worker" : "window"),
                keys: [], candidates: [], globalVars: null, errors: [] };

  const names = Object.getOwnPropertyNames(g);
  out.keys = names.filter(k => /c3|construct|runtime/i.test(k)).slice(0, 80);

  const isRuntime = (o) => {
    if (!o || typeof o !== "object") return false;
    try {
      return ("_eventSheetManager" in o) ||
             (typeof o.GetEventSheetManager === "function");
    } catch (e) { return false; }
  };

  for (const k of names) {
    let v;
    try { v = g[k]; } catch (e) { continue; }
    if (isRuntime(v)) out.candidates.push(k);
    if (v && typeof v === "object") {
      for (const sub of ["_localRuntime", "runtime", "_runtime", "_c3Runtime"]) {
        try { if (isRuntime(v[sub])) out.candidates.push(k + "." + sub); }
        catch (e) {}
      }
    }
  }

  const resolve = (path) => path.split(".").reduce((o, k) => (o ? o[k] : undefined), g);

  if (out.candidates.length) {
    try {
      const rt = resolve(out.candidates[0]);
      const esm = rt._eventSheetManager ||
                  (rt.GetEventSheetManager && rt.GetEventSheetManager());
      let vars = [];
      if (esm) {
        vars = esm._allGlobalVars ||
               (esm.GetAllGlobalVariables && esm.GetAllGlobalVariables()) || [];
      }
      out.globalVars = Array.from(vars).map(v => ({
        name:  (v._name  !== undefined) ? v._name  : (v.GetName  && v.GetName()),
        value: (v._value !== undefined) ? v._value : (v.GetValue && v.GetValue()),
      }));
    } catch (e) { out.errors.push(String(e)); }
  }
  return JSON.stringify(out);
})()
"""


def probe_all():
    """Probe every target (page and workers) for the Construct 3 runtime."""
    for t in http_targets():
        ws_url = t.get("webSocketDebuggerUrl")
        if not ws_url:
            continue
        label = f"[{t.get('type')}] {t.get('title') or ''} {t.get('url') or ''}".strip()
        print(f"\n=== {label}")
        try:
            cdp = CDP(ws_url)
        except Exception as e:
            print(f"    connect failed: {e}")
            continue
        try:
            # Dedicated workers won't answer Runtime.evaluate until the domain
            # is enabled, and a worker paused at startup must be released with
            # runIfWaitingForDebugger or every call blocks forever.
            for setup in ("Runtime.enable", "Runtime.runIfWaitingForDebugger"):
                try:
                    cdp.call(setup)
                except Exception as e:
                    print(f"    {setup}: {e}")
            raw = cdp.evaluate(WORKER_PROBE_JS)
            try:
                info = json.loads(raw)
            except Exception:
                print(f"    raw: {raw}")
                continue
            print(f"    scope:      {info.get('scope')}")
            print(f"    candidates: {info.get('candidates')}")
            print(f"    keys:       {info.get('keys')}")
            if info.get("errors"):
                print(f"    errors:     {info['errors']}")
            gv = info.get("globalVars")
            if gv:
                print(f"    GLOBAL VARIABLES ({len(gv)}):")
                for v in gv:
                    print(f"      {v.get('name')!r} = {v.get('value')!r}")
        except Exception as e:
            print(f"    eval failed: {e}")
        finally:
            cdp.close()
    return 0


def eval_in(ws_url, expression):
    cdp = CDP(ws_url)
    try:
        return cdp.evaluate(expression)
    finally:
        cdp.close()


def browser_ws():
    """Return the browser-level WebSocket URL from /json/version."""
    url = f"http://{HOST}:{PORT}/json/version"
    with urllib.request.urlopen(url, timeout=5) as resp:
        return json.load(resp)["webSocketDebuggerUrl"]


def browser_probe(expression=None, want_types=("worker", "page", "shared_worker",
                                              "service_worker", "iframe")):
    """
    Attach to every target through the BROWSER endpoint using flat sessions.

    Dedicated workers refuse direct /devtools/page/<id> connections, so the only
    reliable route is Target.attachToTarget(flatten=True) from the browser
    target and then routing Runtime.evaluate with a sessionId.
    """
    expr = expression or WORKER_PROBE_JS
    cdp = CDP(browser_ws())
    results = []
    try:
        targets = cdp.call("Target.getTargets").get("targetInfos", [])
        for t in targets:
            ttype = t.get("type")
            if ttype not in want_types:
                continue
            label = f"[{ttype}] {t.get('title') or ''} {t.get('url') or ''}".strip()
            print(f"\n=== {label}")
            try:
                sess = cdp.call("Target.attachToTarget", {
                    "targetId": t["targetId"], "flatten": True,
                }).get("sessionId")
            except Exception as e:
                print(f"    attach failed: {e}")
                continue
            try:
                cdp.call("Runtime.enable", session_id=sess)
            except Exception:
                pass
            try:
                cdp.call("Runtime.runIfWaitingForDebugger", session_id=sess)
            except Exception:
                pass
            try:
                raw = cdp.evaluate(expr, session_id=sess)
            except Exception as e:
                print(f"    eval failed: {e}")
                continue

            if expression:
                print(f"    {raw}")
                results.append(raw)
                continue

            try:
                info = json.loads(raw)
            except Exception:
                print(f"    raw: {raw}")
                continue
            print(f"    scope:      {info.get('scope')}")
            print(f"    candidates: {info.get('candidates')}")
            if info.get("keys"):
                print(f"    keys:       {info['keys'][:25]}")
            if info.get("errors"):
                print(f"    errors:     {info['errors']}")
            gv = info.get("globalVars")
            if gv:
                print(f"    GLOBAL VARIABLES ({len(gv)}):")
                for v in gv:
                    print(f"      {v.get('name')!r} = {v.get('value')!r}")
            results.append(info)
    finally:
        cdp.close()
    return results


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1

    cmd = argv[1]

    if cmd == "eval-file":
        # eval-file <path>  -- evaluate JS read from a file on the PAGE target.
        # Avoids all shell-quoting problems with complex JavaScript.
        if len(argv) < 3:
            print("usage: eval-file <path.js>", file=sys.stderr)
            return 2
        with open(argv[2], "r", encoding="utf-8") as fh:
            js = fh.read()
        cdp, target = connect()
        try:
            print(cdp.evaluate(js))
        finally:
            cdp.close()
        return 0

    if cmd == "beval-file":
        # beval-file <path>  -- evaluate JS from a file on EVERY target
        # (page + workers) via the browser endpoint.
        if len(argv) < 3:
            print("usage: beval-file <path.js>", file=sys.stderr)
            return 2
        with open(argv[2], "r", encoding="utf-8") as fh:
            js = fh.read()
        browser_probe(expression=js)
        return 0

    if cmd == "bprobe":
        browser_probe()
        return 0

    if cmd == "beval":
        if len(argv) < 3:
            print('usage: beval "<javascript>"', file=sys.stderr)
            return 2
        browser_probe(expression=argv[2])
        return 0

    if cmd == "probe-all":
        return probe_all()

    if cmd == "eval-ws":
        # eval-ws <ws_url> "<js>"  -- evaluate against a specific target
        if len(argv) < 4:
            print('usage: eval-ws <ws_url> "<javascript>"', file=sys.stderr)
            return 2
        print(eval_in(argv[2], argv[3]))
        return 0

    if cmd == "targets":
        for t in http_targets():
            print(f"[{t.get('type')}] {t.get('title')!r}")
            print(f"    url: {t.get('url')}")
            print(f"    ws:  {t.get('webSocketDebuggerUrl')}")
        return 0

    cdp, target = connect()
    try:
        print(f"# connected to: {target.get('title')!r}  {target.get('url')}", file=sys.stderr)
        if cmd == "eval":
            if len(argv) < 3:
                print("usage: eval \"<javascript>\"", file=sys.stderr)
                return 2
            print(cdp.evaluate(argv[2]))
        elif cmd == "probe":
            raw = cdp.evaluate(PROBE_JS)
            try:
                print(json.dumps(json.loads(raw), indent=2))
            except Exception:
                print(raw)
        else:
            print(f"unknown command: {cmd}", file=sys.stderr)
            return 2
    finally:
        cdp.close()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
