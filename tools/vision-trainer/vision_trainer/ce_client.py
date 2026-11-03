"""CE bridge client: pipe/TCP framing + thin command helpers.

Reuses the wire protocol from MCP_Server/mcp_cheatengine.py
(4-byte LE length prefix + UTF-8 JSON-RPC) without importing the MCP stack.
"""

import json
import os
import struct

PIPE_NAME = r"\\.\pipe\CE_MCP_Bridge_v99"
MAX_RESPONSE_BYTES = 32 * 1024 * 1024
DEFAULT_TCP_HOST = "127.0.0.1"
DEFAULT_TCP_PORT = 9876


def build_frame(method, params, req_id=1):
    request = {"jsonrpc": "2.0", "method": method,
               "params": params or {}, "id": req_id}
    body = json.dumps(request).encode("utf-8")
    return struct.pack("<I", len(body)) + body


def parse_frame(frame):
    if len(frame) < 4:
        raise ConnectionError("truncated response header")
    (length,) = struct.unpack("<I", frame[:4])
    if length > MAX_RESPONSE_BYTES:
        raise ConnectionError(f"Response too large: {length} bytes")
    body = frame[4:4 + length]
    try:
        envelope = json.loads(body.decode("utf-8"))
    except ValueError as exc:
        raise ConnectionError("Invalid JSON received from CE") from exc
    if "error" in envelope:
        return {"success": False, "error": str(envelope["error"])}
    if "result" in envelope:
        result = envelope["result"]
        if isinstance(result, dict):
            return result
        return {"success": True, "result": result}
    return envelope


class CEBridge:
    def __init__(self, transport=None, host=None, port=None,
                 sender=None, timeout=30):
        transport = (transport or os.environ.get("CE_MCP_TRANSPORT")
                     or "pipe").lower()
        self.transport = {"named_pipe": "pipe", "named-pipe": "pipe",
                          "np": "pipe", "socket": "tcp"}.get(transport,
                                                            transport)
        self.host = host or os.environ.get("CE_MCP_HOST", DEFAULT_TCP_HOST)
        raw_port = port or os.environ.get("CE_MCP_PORT", DEFAULT_TCP_PORT)
        self.port = int(raw_port)
        self.timeout = timeout
        self._sender = sender
        self._handle = None

    def send_command(self, method, params=None):
        if self._sender is not None:
            return self._sender(method, params or {})
        if self.transport == "tcp":
            return self._send_tcp(method, params or {})
        return self._send_pipe(method, params or {})

    def _send_pipe(self, method, params):
        try:
            import win32file
            import pywintypes
        except ImportError as exc:
            raise RuntimeError(
                "Named pipe transport needs Windows + pywin32") from exc
        if self._handle is None:
            try:
                self._handle = win32file.CreateFile(
                    PIPE_NAME,
                    win32file.GENERIC_READ | win32file.GENERIC_WRITE,
                    0, None, win32file.OPEN_EXISTING, 0, None)
            except pywintypes.error as exc:
                raise ConnectionError(f"CE pipe unreachable: {exc}") from exc
        import time
        frame = build_frame(method, params, int(time.time() * 1000))
        try:
            win32file.WriteFile(self._handle, frame)
            _rc, header = win32file.ReadFile(self._handle, 4)
            (length,) = struct.unpack("<I", header)
            if length > MAX_RESPONSE_BYTES:
                raise ConnectionError(f"Response too large: {length}")
            _rc, body = win32file.ReadFile(self._handle, length)
            return parse_frame(header + body)
        except Exception as exc:
            try:
                win32file.CloseHandle(self._handle)
            except Exception:
                pass
            self._handle = None
            raise ConnectionError(f"Pipe exchange failed: {exc}") from exc

    def _send_tcp(self, method, params):
        import socket
        import time
        frame = build_frame(method, params, int(time.time() * 1000))
        sock = socket.create_connection((self.host, self.port),
                                        timeout=self.timeout)
        try:
            sock.sendall(frame)
            header = _read_exact(sock, 4)
            (length,) = struct.unpack("<I", header)
            if length > MAX_RESPONSE_BYTES:
                raise ConnectionError(f"Response too large: {length}")
            body = _read_exact(sock, length)
            return parse_frame(header + body)
        finally:
            sock.close()


def _read_exact(sock, size):
    chunks = b""
    while len(chunks) < size:
        part = sock.recv(size - len(chunks))
        if not part:
            raise ConnectionError("connection closed by relay")
        chunks += part
    return chunks


def _require_success(resp, what):
    if not isinstance(resp, dict) or not resp.get("success"):
        err = resp.get("error", "unknown") if isinstance(resp, dict) else resp
        raise ValueError(f"{what} failed: {err}")
    return resp


def ping(bridge):
    return _require_success(bridge.send_command("ping"), "ping")


def get_process_list(bridge):
    return _require_success(bridge.send_command("get_process_list"),
                            "get_process_list")


def open_process(bridge, process_id_or_name):
    return _require_success(
        bridge.send_command("open_process",
                            {"process_id_or_name": str(process_id_or_name)}),
        "open_process")


def get_opened_process_id(bridge):
    resp = bridge.send_command("get_opened_process_id")
    if not resp.get("success"):
        raise RuntimeError(f"no process attached: {resp.get('error')}")
    return resp


def validate_attached(bridge, expected_pid):
    resp = get_opened_process_id(bridge)
    if int(resp.get("process_id", -1)) != int(expected_pid):
        raise RuntimeError(
            f"attached PID {resp.get('process_id')} != expected {expected_pid}")
    return int(resp["process_id"])


def resolve_process_selection(processes, selection):
    text = str(selection).strip()
    if text.isdigit():
        for p in processes:
            if int(p.get("pid", -1)) == int(text):
                return int(text)
        raise LookupError(f"PID {text} not in process list")
    lowered = text.lower()
    for p in processes:
        if str(p.get("name", "")).lower() == lowered:
            return int(p["pid"])
    raise LookupError(f"process {text!r} not in process list")


def find_game_window(bridge, title=None, class_name=None):
    params = {}
    if title:
        params["title"] = title
    if class_name:
        params["class_name"] = class_name
    resp = bridge.send_command("find_window", params)
    if not resp.get("success"):
        raise LookupError(f"window not found: {resp.get('error')}")
    return resp


def get_window_rect(bridge, handle):
    return _require_success(
        bridge.send_command("get_window_rect", {"handle": handle}),
        "get_window_rect")


def scan_all(bridge, value, value_type="dword", protection="+W-C",
             scan_option="exact", value2=None):
    params = {"value": str(value), "type": value_type,
              "protection": protection, "scan_option": scan_option}
    if value2 is not None:
        params["value2"] = str(value2)
    return _require_success(bridge.send_command("scan_all", params),
                            "scan_all")


def get_scan_results(bridge, offset=0, limit=100):
    return _require_success(
        bridge.send_command("get_scan_results",
                            {"offset": offset, "limit": limit}),
        "get_scan_results")


def next_scan(bridge, value=None, scan_type="exact", value2=None):
    params = {"scan_type": scan_type}
    if value is not None:
        params["value"] = str(value)
    if value2 is not None:
        params["value2"] = str(value2)
    return _require_success(bridge.send_command("next_scan", params),
                            "next_scan")


def read_integer(bridge, address, value_type="dword"):
    return _require_success(
        bridge.send_command("read_integer",
                            {"address": address, "type": value_type}),
        "read_integer")


def write_integer(bridge, address, value, value_type="dword"):
    params = {"address": address, "value": value, "type": value_type}
    return _require_success(bridge.send_command("write_integer", params),
                            "write_integer")


def get_address_info(bridge, address):
    return bridge.send_command("get_address_info", {"address": address})


def set_data_breakpoint(bridge, address, access_type="w", size=4,
                        bp_id=None):
    params = {"address": address, "access_type": access_type, "size": size}
    if bp_id:
        params["id"] = bp_id
    return _require_success(bridge.send_command("set_data_breakpoint",
                                                params),
                            "set_data_breakpoint")


def get_breakpoint_hits(bridge, bp_id=None, clear=True, limit=100):
    params = {"clear": clear, "limit": limit}
    if bp_id:
        params["id"] = bp_id
    return _require_success(bridge.send_command("get_breakpoint_hits",
                                                params),
                            "get_breakpoint_hits")


def remove_breakpoint(bridge, bp_id):
    return _require_success(bridge.send_command("remove_breakpoint",
                                                {"id": bp_id}),
                            "remove_breakpoint")


def disassemble(bridge, address, count=20):
    return _require_success(
        bridge.send_command("disassemble",
                            {"address": address, "count": count}),
        "disassemble")


def generate_signature(bridge, address):
    return _require_success(
        bridge.send_command("generate_signature", {"address": address}),
        "generate_signature")


def aob_scan_module_unique(bridge, pattern, module_name):
    return _require_success(
        bridge.send_command("aob_scan_module_unique",
                            {"pattern": pattern,
                             "module_name": module_name}),
        "aob_scan_module_unique")


def read_memory(bridge, address, size=256):
    return _require_success(
        bridge.send_command("read_memory",
                            {"address": address, "size": size}),
        "read_memory")


def write_memory(bridge, address, data):
    return _require_success(
        bridge.send_command("write_memory",
                            {"address": address, "bytes": list(data)}),
        "write_memory")
