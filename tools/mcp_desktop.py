"""Windows desktop control over stdio MCP: screenshot capture plus mouse and keyboard input."""

import base64
import io

import mss
import pyautogui
from mcp.server.mcpserver import MCPServer
from mcp.types import ImageContent, TextContent
from PIL import Image as PILImage

pyautogui.FAILSAFE = True
pyautogui.PAUSE = 0.05

MAX_RETURN_WIDTH = 1600

server = MCPServer("desktop")


def capture_png(region=None):
    """Grab the screen (or a region) and encode it as PNG.

    region, if given, is [x, y, w, h] in real screen coordinates; otherwise the
    full virtual desktop (mss's monitor 0, spanning every physical monitor) is
    captured. Downscales proportionally with LANCZOS when wider than
    MAX_RETURN_WIDTH.

    Returns (png_bytes, orig_w, orig_h, out_w, out_h) where orig_* are always
    the pre-downscale dimensions and out_* are the dimensions actually encoded.
    """
    with mss.MSS() as sct:
        if region is not None:
            x, y, w, h = region
            monitor = {"left": x, "top": y, "width": w, "height": h}
        else:
            monitor = sct.monitors[0]
        shot = sct.grab(monitor)

    img = PILImage.frombytes("RGB", shot.size, shot.rgb)
    orig_w, orig_h = img.size

    out_w, out_h = orig_w, orig_h
    if orig_w > MAX_RETURN_WIDTH:
        scale = MAX_RETURN_WIDTH / orig_w
        out_w = MAX_RETURN_WIDTH
        out_h = max(1, round(orig_h * scale))
        img = img.resize((out_w, out_h), PILImage.Resampling.LANCZOS)

    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue(), orig_w, orig_h, out_w, out_h


def _dimensions_text(orig_w, orig_h, out_w, out_h):
    if (out_w, out_h) == (orig_w, orig_h):
        return f"{orig_w}x{orig_h}"
    scale = out_w / orig_w
    return (
        f"{orig_w}x{orig_h} (returned at {out_w}x{out_h}, scale {scale:.4f} "
        f"— multiply image coords by {1 / scale:.4g} for click coords)"
    )


@server.tool(structured_output=False)
def screenshot(region: list[int] | None = None) -> list:
    """Capture the full virtual desktop, or a [x, y, w, h] region, as a PNG image."""
    try:
        png_bytes, orig_w, orig_h, out_w, out_h = capture_png(region)
    except Exception as exc:
        return [TextContent(type="text", text=f"Error: {exc}")]
    return [
        TextContent(type="text", text=_dimensions_text(orig_w, orig_h, out_w, out_h)),
        ImageContent(type="image", data=base64.b64encode(png_bytes).decode("ascii"), mime_type="image/png"),
    ]


@server.tool(structured_output=False)
def click(x: int, y: int, button: str = "left") -> str:
    """Move the mouse to (x, y) and click the given button."""
    try:
        pyautogui.moveTo(x, y)
        pyautogui.click(button=button)
        return f"Clicked {button} at ({x}, {y})"
    except Exception as exc:
        return f"Error: {exc}"


@server.tool(structured_output=False)
def double_click(x: int, y: int) -> str:
    """Move the mouse to (x, y) and double-click."""
    try:
        pyautogui.moveTo(x, y)
        pyautogui.doubleClick()
        return f"Double-clicked at ({x}, {y})"
    except Exception as exc:
        return f"Error: {exc}"


@server.tool(structured_output=False)
def move(x: int, y: int) -> str:
    """Move the mouse to (x, y)."""
    try:
        pyautogui.moveTo(x, y)
        return f"Moved to ({x}, {y})"
    except Exception as exc:
        return f"Error: {exc}"


@server.tool(structured_output=False)
def drag(x1: int, y1: int, x2: int, y2: int, duration: float = 0.3) -> str:
    """Press the mouse at (x1, y1), drag to (x2, y2) over duration seconds, and release."""
    try:
        pyautogui.moveTo(x1, y1)
        pyautogui.mouseDown()
        try:
            pyautogui.moveTo(x2, y2, duration=duration)
        finally:
            pyautogui.mouseUp()
        return f"Dragged from ({x1}, {y1}) to ({x2}, {y2})"
    except Exception as exc:
        return f"Error: {exc}"


@server.tool(structured_output=False)
def type_text(text: str) -> str:
    """Type text at the current input focus."""
    try:
        pyautogui.write(text, interval=0.02)
        return f"Typed {len(text)} characters"
    except Exception as exc:
        return f"Error: {exc}"


@server.tool(structured_output=False)
def key(keys: list[str]) -> str:
    """Press a single key, or hold a chord across several keys, e.g. ['ctrl', 'c']."""
    try:
        if len(keys) == 1:
            pyautogui.press(keys[0])
        else:
            pyautogui.hotkey(*keys)
        return f"Pressed {'+'.join(keys)}"
    except Exception as exc:
        return f"Error: {exc}"


@server.tool(structured_output=False)
def scroll(x: int, y: int, clicks: int) -> str:
    """Move the mouse to (x, y) and scroll by clicks (positive scrolls up, negative down)."""
    try:
        pyautogui.moveTo(x, y)
        pyautogui.scroll(clicks)
        return f"Scrolled {clicks} at ({x}, {y})"
    except Exception as exc:
        return f"Error: {exc}"


if __name__ == "__main__":
    server.run()
