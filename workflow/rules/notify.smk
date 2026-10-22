# Optional Telegram notifications on workflow start / success / failure.
# Enabled by `notify: {telegram: true}` in config/config.yaml; needs the
# TG_BOT_TOKEN and TG_CHAT_ID environment variables (never commit them —
# export them in your shell or keep them in an untracked .env).
import html
import os
import urllib.error
import urllib.parse
import urllib.request
from collections import deque


def _tail(path, n=15, max_chars=3500):
    try:
        with open(path, errors="replace") as f:
            text = "".join(deque(f, maxlen=n)).rstrip()
    except Exception as e:
        return f"(unable to read the log file: {e})"
    return text[-max_chars:]


def _send(text, parse_mode=None):
    payload = {"chat_id": os.environ["TG_CHAT_ID"], "text": text}
    if parse_mode:
        payload["parse_mode"] = parse_mode
    req = urllib.request.Request(
        f"https://api.telegram.org/bot{os.environ['TG_BOT_TOKEN']}/sendMessage",
        data=urllib.parse.urlencode(payload).encode(),
    )
    urllib.request.urlopen(req, timeout=10)


def notify(text, plain_fallback=None):
    if not (os.environ.get("TG_BOT_TOKEN") and os.environ.get("TG_CHAT_ID")):
        print("notify: TG_BOT_TOKEN / TG_CHAT_ID not set, skipping Telegram message")
        return
    try:
        _send(text, "HTML")
    except urllib.error.HTTPError as e:
        print(f"Telegram HTTP {e.code}: {e.read().decode()}")
        if plain_fallback:
            try:
                _send(plain_fallback[:4000])
            except Exception as e2:
                print(f"Telegram fallback failed: {e2}")
    except Exception as e:
        print(f"Telegram notify failed: {e}")


PROJECT = os.path.basename(os.getcwd())


onstart:
    notify(f"🚀 <b>{html.escape(PROJECT)}</b>: workflow started")


onsuccess:
    notify(f"✅ <b>{html.escape(PROJECT)}</b>: workflow finished successfully")


onerror:
    tail = _tail(log[0]) if log else "(log is unavailable)"
    notify(
        f"❌ <b>{html.escape(PROJECT)}</b>: workflow failed\n<pre>{html.escape(tail)}</pre>",
        plain_fallback=f"{PROJECT}: workflow failed\n{tail}",
    )
