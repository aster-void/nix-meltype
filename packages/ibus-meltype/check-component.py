# 専用の ibus-daemon (IBUS_COMPONENT_PATH でこのパッケージの component だけを読ませたもの) で Meltype を選び、
# daemon が <exec> のラッパーからエンジンを起動して、入力欄にかなを出せるかを確かめる。
# upstream の test_daemon.py はエンジンを手で起動して動的に登録するが、動的に登録したエンジンは
# InputContext.SetEngine でしか選べず、ibus 1.5.31 以降はその SetEngine が use-global-engine (常に有効) で拒否されるので通らない
import sys
import time

import gi

gi.require_version("IBus", "1.0")
from gi.repository import GLib, IBus

IBus.init()
bus = IBus.Bus()
if not bus.is_connected():
    sys.exit("IBus につながらない")

context = bus.create_input_context("meltype-component-check")
context.set_capabilities(IBus.Capabilite.PREEDIT_TEXT | IBus.Capabilite.FOCUS)
preedit = []
context.connect("update-preedit-text", lambda _ctx, text, *_: preedit.append(text.get_text()))
context.focus_in()

if not bus.set_global_engine("meltype"):
    sys.exit("set_global_engine(meltype) が失敗した")


def pump(seconds):
    end = time.monotonic() + seconds
    main = GLib.MainContext.default()
    while time.monotonic() < end:
        main.iteration(False)
        time.sleep(0.01)


pump(1)
for ch in "ka":
    context.process_key_event(ord(ch), 0, 0)
    pump(0.5)

engine = bus.get_global_engine()
print("engine:", engine and engine.get_name(), "preedit:", preedit)
if engine is None or engine.get_name() != "meltype":
    sys.exit("global engine が meltype になっていない")
if "か" not in "".join(preedit):
    sys.exit("ka を送っても「か」が preedit に出ない")
