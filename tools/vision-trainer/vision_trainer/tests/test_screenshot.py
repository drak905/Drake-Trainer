"""Failing tests first (RED): screenshot capture/downscale/base64 helpers."""
import base64
import io
import os
import sys
import unittest
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from vision_trainer import screenshot


def make_test_image(width=1920, height=1080, color=(255, 0, 0)):
    from PIL import Image
    return Image.new("RGB", (width, height), color)


class TestDownscale(unittest.TestCase):
    def test_downscale_limits_width(self):
        img = make_test_image(1920, 1080)
        out = screenshot.downscale_image(img, max_width=1280)
        self.assertEqual(out.width, 1280)
        self.assertEqual(out.height, 720)

    def test_small_image_unchanged(self):
        img = make_test_image(800, 600)
        out = screenshot.downscale_image(img, max_width=1280)
        self.assertEqual(out.size, (800, 600))


class TestEncodeDecode(unittest.TestCase):
    def test_encode_produces_base64(self):
        img = make_test_image(320, 200)
        b64 = screenshot.encode_image_base64(img)
        raw = base64.b64decode(b64)
        self.assertTrue(raw[:2] == b"\xff\xd8")

    def test_data_url_prefix(self):
        img = make_test_image(320, 200)
        url = screenshot.image_data_url(img)
        self.assertTrue(url.startswith("data:image/jpeg;base64,"))

    def test_save_thumbnail_roundtrip(self):
        import tempfile
        img = make_test_image(320, 200)
        b64 = screenshot.encode_image_base64(img)
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "before.jpg")
            screenshot.save_thumbnail(b64, path)
            self.assertTrue(os.path.exists(path))
            self.assertGreater(os.path.getsize(path), 0)

    def test_decode_data_url(self):
        img = make_test_image(160, 120)
        url = screenshot.image_data_url(img)
        raw_img = screenshot.decode_data_url(url)
        self.assertEqual(raw_img.size, (160, 120))


class TestCaptureGameWindow(unittest.TestCase):
    def test_capture_uses_rect_and_returns_b64(self):
        img = make_test_image(1920, 1080)
        fake_rect = {"x": 0, "y": 0, "width": 1920, "height": 1080}
        with patch.object(screenshot, "grab_region", return_value=img) as grab:
            b64 = screenshot.capture_game_window(fake_rect)
            grab.assert_called_once()
        raw = base64.b64decode(b64)
        self.assertTrue(raw[:2] == b"\xff\xd8")

    def test_capture_downscales_large_window(self):
        img = make_test_image(2560, 1440)
        fake_rect = {"x": 0, "y": 0, "width": 2560, "height": 1440}
        with patch.object(screenshot, "grab_region", return_value=img):
            b64 = screenshot.capture_game_window(fake_rect, max_width=1280)
        decoded = screenshot.decode_base64_image(b64)
        self.assertLessEqual(decoded.width, 1280)

    def test_capture_rejects_invalid_rect(self):
        with self.assertRaises(ValueError):
            screenshot.capture_game_window({"x": 0, "y": 0})


class TestFullscreenFallback(unittest.TestCase):
    def test_fullscreen_rect_spans_all_monitors(self):
        class FakeCtx:
            monitors = [
                {"left": 0, "top": 0, "width": 3840, "height": 2160},
                {"left": 0, "top": 0, "width": 1920, "height": 1080},
                {"left": 1920, "top": 0, "width": 1920, "height": 1080},
            ]

            def __enter__(self):
                return self

            def __exit__(self, *a):
                return False

        with patch("mss.mss", FakeCtx):
            rect = screenshot.fullscreen_rect()
        self.assertEqual(rect, {"x": 0, "y": 0,
                                 "width": 3840, "height": 2160})

    def test_fullscreen_rect_rejects_no_monitors(self):
        class FakeCtx:
            monitors = []

            def __enter__(self):
                return self

            def __exit__(self, *a):
                return False

        with patch("mss.mss", FakeCtx):
            with self.assertRaises(RuntimeError):
                screenshot.fullscreen_rect()

    def test_capture_works_on_fullscreen_rect(self):
        img = make_test_image(1920, 1080)
        rect = {"x": 0, "y": 0, "width": 1920, "height": 1080}
        with patch.object(screenshot, "grab_region", return_value=img):
            b64 = screenshot.capture_game_window(rect)
        raw = base64.b64decode(b64)
        self.assertTrue(raw[:2] == b"\xff\xd8")


class TestNativeWindowCapture(unittest.TestCase):
    def _fake_win32(self, print_bits=None, print_ok=True):
        from PIL import Image  # noqa: F401 (ensures PIL present)

        class FakeBitmap:
            def CreateCompatibleBitmap(self, _dc, _w, _h):
                return None

            def GetInfo(self):
                return {"bmWidth": 100, "bmHeight": 60}

            def GetBitmapBits(self, _as_str):
                return (print_bits if print_bits is not None
                        else b"\x10\x20\x30\x00" * (100 * 60))

            def GetHandle(self):
                return 1

        class FakeDC:
            def CreateCompatibleDC(self):
                return self

            def GetSafeHdc(self):
                return 7

            def SelectObject(self, _obj):
                return None

            def DeleteDC(self):
                return None

        class FakeGui:
            def __init__(self):
                self.print_calls = []

            def IsWindowVisible(self, _hwnd):
                return True

            def GetWindowText(self, hwnd):
                return {0x501: "Astral Ascent"}.get(hwnd, "Other")

            def EnumWindows(self, cb, extra):
                for hwnd in (0x501, 0x502):
                    cb(hwnd, extra)

            def GetClientRect(self, _hwnd):
                return (0, 0, 100, 60)

            def ClientToScreen(self, _hwnd, _pt):
                return (10, 20)

            def GetWindowRect(self, _hwnd):
                return (10, 20, 110, 80)

            def GetWindowDC(self, _hwnd):
                return 5

            def PrintWindow(self, hwnd, _hdc, _flags):
                self.print_calls.append(hwnd)
                return 1 if print_ok else 0

            def DeleteObject(self, _handle):
                return None

            def ReleaseDC(self, _hwnd, _dc):
                return None

        class FakeUi:
            def CreateDCFromHandle(self, _handle):
                return FakeDC()

            def CreateBitmap(self):
                return FakeBitmap()

        gui = FakeGui()
        return (gui, FakeUi(), object())

    def test_find_window_handle_matches_case_insensitive(self):
        with patch.object(screenshot, "_win32",
                          return_value=self._fake_win32()):
            found = screenshot.find_window_handle("astral ascent")
        self.assertEqual(found["hwnd"], 0x501)
        self.assertEqual(found["handle"], hex(0x501))

    def test_find_window_handle_missing_raises(self):
        with patch.object(screenshot, "_win32",
                          return_value=self._fake_win32()):
            with self.assertRaises(LookupError):
                screenshot.find_window_handle("no such game")

    def test_find_window_handle_rejects_blank(self):
        with self.assertRaises(ValueError):
            screenshot.find_window_handle("   ")

    def test_client_rect_uses_screen_origin(self):
        with patch.object(screenshot, "_win32",
                          return_value=self._fake_win32()):
            rect = screenshot.client_rect(0x501)
        self.assertEqual(rect, {"x": 10, "y": 20,
                               "width": 100, "height": 60})

    def test_capture_window_handle_png_via_printwindow(self):
        with patch.object(screenshot, "_win32",
                          return_value=self._fake_win32()):
            with patch.object(screenshot, "_print_window",
                              return_value=1):
                shot = screenshot.capture_window_handle(0x501)
        self.assertEqual(shot["format"], "png")
        self.assertEqual(shot["method"], "printwindow")
        raw = base64.b64decode(shot["image_b64"])
        self.assertTrue(raw[:8] == b"\x89PNG\r\n\x1a\n")

    def test_capture_falls_back_to_mss_on_blank(self):
        img = make_test_image(100, 60)
        win32 = self._fake_win32(
            print_bits=b"\x00\x00\x00\x00" * (100 * 60))
        with patch.object(screenshot, "_win32", return_value=win32):
            with patch.object(screenshot, "_print_window",
                              return_value=1):
                with patch.object(screenshot, "grab_region",
                                  return_value=img) as grab:
                    shot = screenshot.capture_window_handle(0x501)
        self.assertEqual(shot["method"], "mss-fallback")
        grab.assert_called_once()

    def test_capture_top_fraction_crops(self):
        with patch.object(screenshot, "_win32",
                          return_value=self._fake_win32()):
            with patch.object(screenshot, "_print_window",
                              return_value=1):
                shot = screenshot.capture_window_handle(
                    0x501, max_width=100, top_fraction=0.5)
        decoded = screenshot.decode_base64_image(
            shot["image_b64"])
        self.assertEqual(decoded.size, (100, 30))

    def test_read_visible_stats_composes(self):
        with patch.object(screenshot, "find_window_handle",
                          return_value={"hwnd": 0x501,
                                        "handle": "0x501",
                                        "title": "Astral Ascent"}):
            with patch.object(screenshot, "capture_window_handle",
                              return_value={"image_b64": "AAA",
                                            "format": "png",
                                            "rect": {"x": 0, "y": 0,
                                                     "width": 1,
                                                     "height": 1},
                                            "method": "printwindow"}):
                with patch("vision_trainer.llm_client."
                           "extract_values_auto",
                           return_value={"values": [{"label": "hp",
                                                     "value": 90}],
                                         "strict_shape": False}) as ext:
                    out = screenshot.read_visible_stats(
                        "http://e/v1", "m", "astral")
        self.assertEqual(out["title"], "Astral Ascent")
        self.assertEqual(out["values"][0]["value"], 90)
        self.assertFalse(out["strict_shape"])
        ext.assert_called_once()


if __name__ == "__main__":
    unittest.main()
