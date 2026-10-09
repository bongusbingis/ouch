"""Grab the OUCH lobby Studio window to a PNG for owner review.

Foregrounds the window inside this process (focus flips back to the IDE between
tool calls), waits for the compositor, then captures the window rectangle with mss.

usage: python tools/capture_studio.py <output.png> [--title OUCH!] [--crop-top N]
"""

import argparse
import ctypes
import ctypes.wintypes as w
import sys
import time

import mss
import mss.tools


def find_window(prefix: str):
    user32 = ctypes.windll.user32
    found = []

    @ctypes.WINFUNCTYPE(ctypes.c_bool, w.HWND, w.LPARAM)
    def callback(hwnd, _lparam):
        length = user32.GetWindowTextLengthW(hwnd)
        if length and user32.IsWindowVisible(hwnd):
            buffer = ctypes.create_unicode_buffer(length + 1)
            user32.GetWindowTextW(hwnd, buffer, length + 1)
            if buffer.value.startswith(prefix) and "Roblox Studio" in buffer.value:
                found.append(hwnd)
        return True

    user32.EnumWindows(callback, 0)
    return found[0] if found else None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("output")
    parser.add_argument("--title", default="OUCH!")
    parser.add_argument("--crop-top", type=int, default=0)
    args = parser.parse_args()

    user32 = ctypes.windll.user32
    hwnd = find_window(args.title)
    if hwnd is None:
        print("window not found", file=sys.stderr)
        return 1
    user32.ShowWindow(hwnd, 3)
    user32.keybd_event(0x12, 0, 0, 0)
    user32.keybd_event(0x12, 0, 2, 0)
    user32.SetForegroundWindow(hwnd)
    time.sleep(0.6)
    rect = w.RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(rect))
    region = {
        "left": rect.left,
        "top": rect.top + args.crop_top,
        "width": rect.right - rect.left,
        "height": rect.bottom - rect.top - args.crop_top,
    }
    with mss.mss() as sct:
        image = sct.grab(region)
        mss.tools.to_png(image.rgb, image.size, output=args.output)
    print(args.output, image.size)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
