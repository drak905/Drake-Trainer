"""Screenshot helpers: capture game window, downscale, Base64 encode."""

import base64
import io

MAX_WIDTH_DEFAULT = 1280
JPEG_QUALITY = 85

# PrintWindow flag that renders the window's own surface even when occluded.
PW_RENDERFULLCONTENT = 2


def _pil():
    from PIL import Image
    return Image


def _win32():
    try:
        import win32gui
        import win32ui
        import win32con  # noqa: F401 (kept for future flag use)
    except ImportError as exc:
        raise RuntimeError(
            "native window capture needs Windows + pywin32") from exc
    return win32gui, win32ui, win32con


def ensure_dpi_aware():
    try:
        import ctypes
        try:
            ctypes.windll.shcore.SetProcessDpiAwareness(2)
        except Exception:
            ctypes.windll.user32.SetProcessDPIAware()
    except Exception:
        pass


def downscale_image(image, max_width=MAX_WIDTH_DEFAULT):
    if image.width <= max_width:
        return image
    ratio = max_width / float(image.width)
    new_size = (max_width, int(image.height * ratio))
    return image.resize(new_size)


def encode_image_base64(image, quality=JPEG_QUALITY):
    buf = io.BytesIO()
    image.convert("RGB").save(buf, format="JPEG", quality=quality)
    return base64.b64encode(buf.getvalue()).decode("ascii")


def decode_base64_image(b64):
    Image = _pil()
    raw = base64.b64decode(b64)
    return Image.open(io.BytesIO(raw)).convert("RGB")


def image_data_url(image, quality=JPEG_QUALITY):
    return "data:image/jpeg;base64," + encode_image_base64(image, quality)


def decode_data_url(url):
    prefix = "data:image/jpeg;base64,"
    b64 = url[len(prefix):] if url.startswith(prefix) else url
    return decode_base64_image(b64)


def save_thumbnail(b64, path):
    raw = base64.b64decode(b64)
    with open(path, "wb") as f:
        f.write(raw)
    return path


def grab_region(rect):
    import mss
    with mss.mss() as sct:
        monitor = {
            "left": int(rect["x"]),
            "top": int(rect["y"]),
            "width": int(rect["width"]),
            "height": int(rect["height"]),
        }
        shot = sct.grab(monitor)
    Image = _pil()
    return Image.frombytes("RGB", shot.size, shot.rgb)


def fullscreen_rect():
    """Full virtual-screen rect: mss monitors[0] spans all displays, so a
    game on a secondary monitor is still inside the capture area."""
    import mss
    with mss.mss() as sct:
        monitors = sct.monitors
        if not monitors:
            raise RuntimeError("no display monitors available for capture")
        mon = monitors[0]
    return {"x": mon["left"], "y": mon["top"],
            "width": mon["width"], "height": mon["height"]}


def capture_game_window(rect, max_width=MAX_WIDTH_DEFAULT):
    for key in ("x", "y", "width", "height"):
        if key not in rect:
            raise ValueError(f"rect missing '{key}'")
    if rect["width"] <= 0 or rect["height"] <= 0:
        raise ValueError("rect must have positive width/height")
    image = grab_region(rect)
    image = downscale_image(image, max_width=max_width)
    return encode_image_base64(image)


def find_window_handle(title_substring):
    """Find a visible top-level window by title substring (case-insensitive).

    Returns {"hwnd", "handle" (hex), "title"}. Native replacement for the
    CE find_window/get_window_rect round-trip, which hangs on some builds.
    """
    win32gui, _, _ = _win32()
    needle = (title_substring or "").strip().lower()
    if not needle:
        raise ValueError("title_substring is required")
    hits = []

    def _collect(hwnd, _extra):
        if not win32gui.IsWindowVisible(hwnd):
            return
        text = win32gui.GetWindowText(hwnd) or ""
        if needle in text.lower():
            hits.append((hwnd, text))

    win32gui.EnumWindows(_collect, None)
    if not hits:
        raise LookupError(
            f"no visible window matching {title_substring!r}")
    hwnd, title = hits[0]
    return {"hwnd": hwnd, "handle": hex(hwnd), "title": title}


def client_rect(hwnd):
    """Client-area rect of a window in screen pixels (no title bar/border)."""
    win32gui, _, _ = _win32()
    ensure_dpi_aware()
    _left, _top, right, bottom = win32gui.GetClientRect(hwnd)
    x, y = win32gui.ClientToScreen(hwnd, (0, 0))
    width, height = right - _left, bottom - _top
    if width <= 0 or height <= 0:
        raise ValueError("window client area is empty (minimized?)")
    return {"x": x, "y": y, "width": width, "height": height}


def _print_window(hwnd, hdc, flags):
    """PrintWindow via ctypes (pywin32 never wrapped it). Patch point."""
    import ctypes
    return ctypes.windll.user32.PrintWindow(hwnd, hdc, flags)


def grab_printwindow(hwnd):
    """Render a window's own surface via PrintWindow (works when occluded).

    Raises ValueError on a blank frame so callers can fall back to mss.
    """
    win32gui, win32ui, _win32con = _win32()
    ensure_dpi_aware()
    del _win32con
    left, top, right, bottom = win32gui.GetWindowRect(hwnd)
    width, height = right - left, bottom - top
    if width <= 0 or height <= 0:
        raise ValueError("window rect is empty (minimized?)")
    hwnd_dc = win32gui.GetWindowDC(hwnd)
    mfc_dc = win32ui.CreateDCFromHandle(hwnd_dc)
    save_dc = mfc_dc.CreateCompatibleDC()
    bitmap = win32ui.CreateBitmap()
    bitmap.CreateCompatibleBitmap(mfc_dc, width, height)
    save_dc.SelectObject(bitmap)
    try:
        rendered = _print_window(hwnd, save_dc.GetSafeHdc(),
                                 PW_RENDERFULLCONTENT)
        if not rendered:
            rendered = _print_window(hwnd, save_dc.GetSafeHdc(), 1)
        if not rendered:
            raise RuntimeError("PrintWindow refused the window")
        info = bitmap.GetInfo()
        bits = bitmap.GetBitmapBits(True)
        Image = _pil()
        image = Image.frombuffer(
            "RGB", (info["bmWidth"], info["bmHeight"]),
            bits, "raw", "BGRX", 0, 1)
        if image.getbbox() is None:
            raise ValueError("PrintWindow returned a blank frame")
        return image.copy()
    finally:
        win32gui.DeleteObject(bitmap.GetHandle())
        save_dc.DeleteDC()
        mfc_dc.DeleteDC()
        win32gui.ReleaseDC(hwnd, hwnd_dc)


def encode_image_base64_png(image):
    buf = io.BytesIO()
    image.convert("RGB").save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode("ascii")


def capture_window_handle(hwnd, max_width=MAX_WIDTH_DEFAULT,
                          top_fraction=None):
    """Capture a window by handle: PrintWindow first, mss region fallback.

    Crops to the client area and optionally to the top fraction (HUD strip).
    Returns {"image_b64", "format", "rect", "method"}; b64 is PNG.
    """
    rect = client_rect(hwnd)
    method = "printwindow"
    try:
        win_left, win_top, _, _ = _win32()[0].GetWindowRect(hwnd)
        image = grab_printwindow(hwnd)
        image = image.crop((rect["x"] - win_left, rect["y"] - win_top,
                            rect["x"] - win_left + rect["width"],
                            rect["y"] - win_top + rect["height"]))
    except (ValueError, RuntimeError):
        image = grab_region(rect)
        method = "mss-fallback"
    if top_fraction is not None:
        if not 0 < top_fraction <= 1:
            raise ValueError("top_fraction must be in (0, 1]")
        image = image.crop((0, 0, image.width,
                            int(image.height * top_fraction)))
    image = downscale_image(image, max_width=max_width)
    return {"image_b64": encode_image_base64_png(image),
            "format": "png", "rect": rect, "method": method}


def read_visible_stats(endpoint, vision_model, title_substring,
                       max_width=MAX_WIDTH_DEFAULT, top_fraction=None,
                       min_confidence=0.0):
    """One call: find window -> capture -> vision extract -> values list.

    Returns {"hwnd", "title", "rect", "method", "image_b64",
    "values", "strict_shape"}. Raises the underlying LookupError /
    ValueError when the window is missing or the model gives no stats.
    """
    from . import llm_client as _llm_client
    found = find_window_handle(title_substring)
    shot = capture_window_handle(found["hwnd"], max_width=max_width,
                                 top_fraction=top_fraction)
    auto = _llm_client.extract_values_auto(
        endpoint, vision_model, shot["image_b64"],
        min_confidence=min_confidence)
    return {"hwnd": found["hwnd"], "title": found["title"],
            "rect": shot["rect"], "method": shot["method"],
            "image_b64": shot["image_b64"], "values": auto["values"],
            "strict_shape": auto["strict_shape"]}
