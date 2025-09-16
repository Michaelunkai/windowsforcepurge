from pynput import mouse
import pyautogui
from PIL import Image
import win32clipboard
import io
import time

click_times = []
TRIPLE_CLICK_TIME = 1.0  # seconds

def send_to_clipboard(image: Image.Image):
    output = io.BytesIO()
    image.convert("RGB").save(output, "BMP")
    data = output.getvalue()[14:]  # Remove BMP header
    output.close()

    win32clipboard.OpenClipboard()
    win32clipboard.EmptyClipboard()
    win32clipboard.SetClipboardData(win32clipboard.CF_DIB, data)
    win32clipboard.CloseClipboard()

def on_click(x, y, button, pressed):
    if pressed and button == mouse.Button.middle:
        global click_times
        now = time.time()
        click_times = [t for t in click_times if now - t < TRIPLE_CLICK_TIME]
        click_times.append(now)

        if len(click_times) == 3:
            print("[✓] Triple middle-click detected! Taking screenshot...")
            screenshot = pyautogui.screenshot()
            send_to_clipboard(screenshot)
            print("[✓] Screenshot copied to clipboard.\n")
            click_times = []

with mouse.Listener(on_click=on_click) as listener:
    print("📷 Listening for triple MIDDLE-click to take screenshot and copy to clipboard...")
    listener.join()
