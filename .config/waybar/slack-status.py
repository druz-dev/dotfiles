#!/usr/bin/env python3
"""
Slack notification indicator for Waybar (Hyprland).

Snap-confined Slack publishes a StatusNotifierItem (tray icon) only when a
StatusNotifier *watcher* exists at the moment Slack starts. Hyprland runs no
tray host, so this script *is* the watcher+host: it owns
org.kde.StatusNotifierWatcher, lets Slack register, then reads Slack's tray
icon pixmap and classifies it:

    rest      (plain logo)        -> hidden
    unread    (blue dot)          -> purple   "other" activity
    highlight (red badge)         -> red      mention / DM ("tag or personal")

It prints one Waybar JSON line (return-type "json") on every state change.

Modes:
    (default)    long-running Waybar exec, emits JSON on change
    --inspect    log raw Slack item state to stderr (debugging)
    --selftest   classify the three bundled Slack tray .ico assets and exit
    activate     click handler: raise/focus Slack via the tray item's Activate
"""
import json
import os
import sys

STATE_FILE = os.path.join(
    os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "waybar-slack.json")

# ---- classification (pure, unit-testable) --------------------------------

RED = "#FF0033"      # mention / DM     -> matches the bar's "muted/alert" red
PURPLE = "#A290F1"   # other unread     -> matches the bar's active-bar purple


def classify_rgba(width, height, pixels):
    """pixels: bytes in ARGB32 network (big-endian) order, len == w*h*4.

    Returns 'highlight' | 'unread' | 'rest'.
    """
    red = blue = 0
    n = width * height
    for i in range(n):
        a = pixels[i * 4 + 0]
        r = pixels[i * 4 + 1]
        g = pixels[i * 4 + 2]
        b = pixels[i * 4 + 3]
        if a < 40:
            continue
        if r > 150 and g < 110 and b < 110:
            red += 1
        elif b > 140 and b > r + 30 and g < b:
            blue += 1
    # Thresholds scaled well below the ~15 red / ~98 blue expected at 22x22.
    if red >= 4:
        return "highlight"
    if blue >= 10:
        return "unread"
    return "rest"


def render(state):
    """state -> Waybar JSON dict."""
    if state == "highlight":
        return {"text": "<span foreground='%s'>Slack</span>" % RED,
                "tooltip": "Slack: mention or direct message",
                "class": "mention"}
    if state == "unread":
        return {"text": "<span foreground='%s'>Slack</span>" % PURPLE,
                "tooltip": "Slack: unread activity",
                "class": "unread"}
    return {"text": "", "tooltip": "Slack: no notifications", "class": "none"}


# ---- self test -----------------------------------------------------------

def selftest():
    from PIL import Image
    import glob
    base = ("/snap/slack/*/usr/lib/slack/resources/app.asar.unpacked/"
            "dist/resources/slack-taskbar-%s.ico")
    expect = {"rest": "rest", "unread": "unread", "highlight": "highlight"}
    ok = True
    for name, want in expect.items():
        f = glob.glob(base % name)[0]
        im = Image.open(f).convert("RGBA").resize((22, 22))
        # PIL gives RGBA bytes; repack to ARGB to match SNI ordering.
        rgba = im.tobytes()
        argb = bytearray(len(rgba))
        for i in range(22 * 22):
            r, g, b, a = rgba[i*4:i*4+4]
            argb[i*4+0] = a
            argb[i*4+1] = r
            argb[i*4+2] = g
            argb[i*4+3] = b
        got = classify_rgba(22, 22, bytes(argb))
        mark = "ok" if got == want else "FAIL"
        if got != want:
            ok = False
        print(f"{name:10s} -> {got:10s} (want {want}) [{mark}]")
    sys.exit(0 if ok else 1)


# ---- live watcher --------------------------------------------------------

def run(inspect=False):
    import dbus
    import dbus.service
    import dbus.mainloop.glib
    from gi.repository import GLib

    WATCHER_BUS = "org.kde.StatusNotifierWatcher"
    WATCHER_PATH = "/StatusNotifierWatcher"
    WATCHER_IFACE = "org.kde.StatusNotifierWatcher"
    ITEM_IFACE = "org.kde.StatusNotifierItem"
    PROPS_IFACE = "org.freedesktop.DBus.Properties"

    def log(*a):
        print(*a, file=sys.stderr, flush=True)

    class Watcher(dbus.service.Object):
        def __init__(self, bus):
            self.bus = bus
            self.items = {}
            bus.request_name(WATCHER_BUS, dbus.bus.NAME_FLAG_DO_NOT_QUEUE)
            super().__init__(bus, WATCHER_PATH)
            self.on_item = None

        @dbus.service.method(WATCHER_IFACE, in_signature="s",
                             sender_keyword="sender")
        def RegisterStatusNotifierItem(self, service, sender=None):
            if service.startswith("/"):
                busname, path = sender, service
            else:
                busname, path = service, "/StatusNotifierItem"
            self.items[busname + path] = (busname, path)
            self.StatusNotifierItemRegistered(busname + path)
            if self.on_item:
                self.on_item(busname, path)

        @dbus.service.method(WATCHER_IFACE, in_signature="s",
                             sender_keyword="sender")
        def RegisterStatusNotifierHost(self, service, sender=None):
            self.StatusNotifierHostRegistered()

        @dbus.service.signal(WATCHER_IFACE, signature="s")
        def StatusNotifierItemRegistered(self, service):
            pass

        @dbus.service.signal(WATCHER_IFACE, signature="s")
        def StatusNotifierItemUnregistered(self, service):
            pass

        @dbus.service.signal(WATCHER_IFACE, signature="")
        def StatusNotifierHostRegistered(self):
            pass

        @dbus.service.method(PROPS_IFACE, in_signature="ss", out_signature="v")
        def Get(self, iface, prop):
            return self.GetAll(iface).get(prop, "")

        @dbus.service.method(PROPS_IFACE, in_signature="s",
                             out_signature="a{sv}")
        def GetAll(self, iface):
            return {
                "RegisteredStatusNotifierItems":
                    dbus.Array(list(self.items), signature="s"),
                "IsStatusNotifierHostRegistered": dbus.Boolean(True),
                "ProtocolVersion": dbus.Int32(0),
            }

    def emit(payload):
        line = json.dumps(payload)
        # File (read by the Waybar module) survives Waybar reloads; stdout is
        # convenient when this script is used directly as a module exec.
        try:
            tmp = STATE_FILE + ".tmp"
            with open(tmp, "w") as f:
                f.write(line)
            os.replace(tmp, STATE_FILE)
        except Exception as e:
            log("[emit]", e)
        print(line, flush=True)

    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    watcher = Watcher(bus)
    state = {"busname": None, "path": None, "last": None}

    def best_pixmap(props):
        arr = props.get("IconPixmap")
        if not arr:
            return None
        # pick the largest frame
        w, h, data = max(arr, key=lambda f: int(f[0]) * int(f[1]))
        return int(w), int(h), bytes(bytearray(int(b) & 0xff for b in data))

    def refresh(*_):
        if not state["busname"]:
            return
        try:
            obj = bus.get_object(state["busname"], state["path"])
            props = dbus.Interface(obj, PROPS_IFACE).GetAll(ITEM_IFACE)
        except Exception as e:
            log("[read]", e)
            return
        pm = best_pixmap(props)
        st = classify_rgba(*pm) if pm else "rest"
        if inspect:
            tip = props.get("ToolTip")
            title = str(tip[2]) if tip else ""
            log("[slack] status=%s class=%s tip=%r" %
                (props.get("Status"), st, title))
            return
        if st != state["last"]:
            state["last"] = st
            emit(render(st))

    def on_item(busname, path):
        try:
            obj = bus.get_object(busname, path)
            props = dbus.Interface(obj, PROPS_IFACE).GetAll(ITEM_IFACE)
        except Exception as e:
            log("[on_item]", e)
            return
        ident = (str(props.get("Id") or "") + str(props.get("Title") or "")).lower()
        if "slack" not in ident:
            return
        state["busname"], state["path"] = busname, path
        for sig in ("NewIcon", "NewStatus", "NewAttentionIcon",
                    "NewOverlayIcon", "NewToolTip", "NewTitle"):
            bus.add_signal_receiver(refresh, signal_name=sig,
                                    dbus_interface=ITEM_IFACE,
                                    bus_name=busname, path=path)
        refresh()

    watcher.on_item = on_item
    watcher.StatusNotifierHostRegistered()
    if not inspect:
        emit(render("rest"))
    log("[watcher] running")
    GLib.MainLoop().run()


def activate():
    """Click handler: tell Slack's tray item to raise/focus its window."""
    import dbus
    bus = dbus.SessionBus()
    watcher = bus.get_object("org.kde.StatusNotifierWatcher",
                             "/StatusNotifierWatcher")
    items = dbus.Interface(watcher, "org.freedesktop.DBus.Properties").Get(
        "org.kde.StatusNotifierWatcher", "RegisteredStatusNotifierItems")
    for entry in items:
        entry = str(entry)
        i = entry.find("/")
        busname, path = entry[:i], entry[i:]
        try:
            obj = bus.get_object(busname, path)
            ident = str(dbus.Interface(obj, "org.freedesktop.DBus.Properties")
                        .Get("org.kde.StatusNotifierItem", "Id")).lower()
            if "slack" in ident:
                dbus.Interface(obj, "org.kde.StatusNotifierItem").Activate(0, 0)
                return
        except Exception:
            continue


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        selftest()
    elif "activate" in sys.argv:
        activate()
    else:
        run(inspect="--inspect" in sys.argv)
