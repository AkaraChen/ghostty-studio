#!/usr/bin/env python3
import base64
import json
import os
import pathlib
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request

WEBDRIVER = "http://127.0.0.1:4444"


def request(method, path, payload=None):
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(
        WEBDRIVER + path,
        data=data,
        method=method,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=30) as response:
        decoded = json.loads(response.read().decode() or "{}")
    if decoded.get("value") and isinstance(decoded["value"], dict) and decoded["value"].get("error"):
        raise RuntimeError(decoded["value"])
    return decoded.get("value")


def wait_until(description, predicate, timeout=60):
    deadline = time.monotonic() + timeout
    last_error = None
    while time.monotonic() < deadline:
        try:
            value = predicate()
            if value:
                return value
        except Exception as error:  # transient WebDriver and renderer states
            last_error = error
        time.sleep(0.25)
    raise RuntimeError(f"timed out waiting for {description}: {last_error}")


def accept_native_dialog(title, accepted):
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        result = subprocess.run(
            ["xdotool", "search", "--name", title],
            capture_output=True,
            text=True,
            check=False,
        )
        for window_id in result.stdout.split():
            geometry = subprocess.run(
                ["xdotool", "getwindowgeometry", "--shell", window_id],
                capture_output=True,
                text=True,
                check=False,
            ).stdout
            values = dict(
                line.split("=", 1) for line in geometry.splitlines() if "=" in line
            )
            width = int(values.get("WIDTH", "400"))
            height = int(values.get("HEIGHT", "180"))
            subprocess.run(
                [
                    "xdotool",
                    "mousemove",
                    "--window",
                    window_id,
                    str(max(10, width - 70)),
                    str(max(10, height - 30)),
                    "click",
                    "1",
                ],
                check=False,
            )
            accepted.set()
            return
        time.sleep(0.2)


def main():
    application = str(pathlib.Path(sys.argv[1]).resolve())
    config_path = pathlib.Path(sys.argv[2])
    original = pathlib.Path(sys.argv[3]).read_bytes()
    changed = original.replace(b"font-size = 13", b"font-size = 14")
    driver = subprocess.Popen(["tauri-driver"], stdout=sys.stdout, stderr=sys.stderr)
    session_id = None

    try:
        wait_until("tauri-driver", lambda: request("GET", "/status"), timeout=30)
        session = request(
            "POST",
            "/session",
            {
                "capabilities": {
                    "alwaysMatch": {
                        "browserName": "wry",
                        "tauri:options": {"application": application},
                    }
                }
            },
        )
        session_id = session["sessionId"]

        def execute(script, args=None):
            return request(
                "POST",
                f"/session/{session_id}/execute/sync",
                {"script": script, "args": args or []},
            )

        def body_text():
            return execute("return document.body.innerText") or ""

        def click_text(selector, text):
            return execute(
                """
                const element = [...document.querySelectorAll(arguments[0])]
                  .find((candidate) => candidate.textContent.trim().includes(arguments[1]) && !candidate.disabled);
                if (!element) return false;
                element.click();
                return true;
                """,
                [selector, text],
            )

        def set_input(selector, value):
            return execute(
                """
                const input = document.querySelector(arguments[0]);
                if (!input || input.disabled) return false;
                const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
                setter.call(input, arguments[1]);
                input.dispatchEvent(new Event('input', { bubbles: true }));
                return true;
                """,
                [selector, value],
            )

        wait_until(
            "real Ghostty workspace",
            lambda: "配置编辑器" in body_text() and "Ghostty 1.3.1" in body_text(),
            timeout=90,
        )

        screenshot = request("GET", f"/session/{session_id}/screenshot")
        screenshot_path = pathlib.Path("/tmp/t3-render.png")
        screenshot_path.write_bytes(base64.b64decode(screenshot))
        visual = subprocess.check_output(
            ["convert", str(screenshot_path), "-format", "%k %[fx:standard_deviation]", "info:"],
            text=True,
        ).split()
        if int(visual[0]) < 100 or float(visual[1]) < 0.05:
            raise RuntimeError(f"rendered content lacks visual variance: {visual}")

        wait_until("My Config navigation", lambda: click_text("button", "我的配置"))
        wait_until(
            "configured macOS-only read-only notice",
            lambda: "仅适用于 macOS；当前 Linux 平台只读" in body_text(),
        )
        read_only_value = execute(
            """
            const input = [...document.querySelectorAll('input:disabled')]
              .find((candidate) => candidate.value === 'native');
            return input ? input.value : null;
            """
        )
        if read_only_value != "native":
            raise RuntimeError("configured macOS-only value was not rendered read-only")

        if not set_input('input[aria-label="搜索设置"]', "font-size"):
            raise RuntimeError("search input is unavailable")
        wait_until(
            "font-size editor",
            lambda: execute("return document.querySelector('input[type=number]:not([disabled])')?.value") == "13",
        )
        if not set_input("input[type=number]:not([disabled])", "14"):
            raise RuntimeError("font-size input is unavailable")
        wait_until("draft state", lambda: "1 项修改尚未保存" in body_text())

        if not click_text("button", "检查并保存"):
            raise RuntimeError("review button is unavailable")
        wait_until("real Ghostty validation", lambda: "Ghostty 验证通过" in body_text(), timeout=60)

        accepted = threading.Event()
        threading.Thread(
            target=accept_native_dialog,
            args=("写入配置", accepted),
            daemon=True,
        ).start()
        if not click_text("button", "保存到 Ghostty"):
            raise RuntimeError("save button is unavailable")
        wait_until("native write confirmation", accepted.is_set, timeout=30)
        wait_until("applied config", lambda: config_path.read_bytes() == changed, timeout=60)
        if b"macos-titlebar-style = native" not in config_path.read_bytes():
            raise RuntimeError("platform-filtered setting changed during apply")

        wait_until("utility menu", lambda: click_text("summary", "工具与恢复"))
        wait_until("history action", lambda: click_text("button", "历史与恢复"))
        wait_until("snapshot history", lambda: "快照历史" in body_text())
        wait_until("restore action", lambda: click_text("button", "恢复"))
        wait_until("restore confirmation", lambda: "恢复这个快照？" in body_text())

        restored = threading.Event()
        threading.Thread(
            target=accept_native_dialog,
            args=("恢复快照", restored),
            daemon=True,
        ).start()
        if not click_text("button", "确认恢复"):
            raise RuntimeError("confirm restore button is unavailable")
        wait_until("native restore confirmation", restored.is_set, timeout=30)
        wait_until("restored config", lambda: config_path.read_bytes() == original, timeout=60)

        print(
            "T3 full loop: real Ghostty 1.3.1; AppImage WebDriver render; "
            "isolated HOME; validate/apply/snapshot/restore; filtered key byte-preserved"
        )
    finally:
        if session_id:
            try:
                request("DELETE", f"/session/{session_id}")
            except Exception:
                pass
        driver.terminate()
        try:
            driver.wait(timeout=10)
        except subprocess.TimeoutExpired:
            driver.kill()


if __name__ == "__main__":
    main()
