#!/usr/bin/env python3
# hotspot-oled-dash.py — MortemHive Hotspot: live dashboard for the MMDVM hat OLED.
# v1.6: 'SET CALLSIGN + ID' now also triggers while the DMR Id is still the
#   stock placeholder (1234567) - mirrors hotspot-config-guard's checks.
# v1.5: shows 'SET CALLSIGN + ID' until the unit is configured
#   (pairs with hotspot-config-guard, which holds the transmitter until
#   a real callsign is set in the Pi-Star dashboard).
# v1.4 (MortemHive community edition): callsign + DMR ID are read from /etc/mmdvmhost
#   at startup (configure via the Pi-Star dashboard); splash shows your callsign;
#   greeting genericized. No personal data baked in.
# v1.2 (Nyx, 2026-10-05): idle carousel (status -> wifi -> vitals -> nyx),
#   TGNAMES (TG names in activity line), TX inverted highlight when transmitting,
#   Wi-Fi dBm + SSID, chibi-Nyx mascot (wave on splash, idle on the NYX screen).
# v1.3.1: header badge auto-shrinks (2NET✓ -> 2N✓ -> ✓) so it can never
#   collide with the callsign.
# v1.3: liveness comet — 2 dots rotating in the top-right corner, advancing every
#   0.5s (redraw loop sped to 0.5s for smooth continuous motion; full circle ~3s).
# v1.2.2: fit-aware truncation — activity/Last lines can never collide with the
#   right-side BER/IP (fixes the 'squished' look); longer TG names handled.
# v1.2.1: fix RE_VOICE group indices (IndexError froze the panel on the first voice
#   header); parse log timestamps as UTC (negative age kept it stuck 'live');
#   numeric DMR IDs now resolve to callsigns via DMRIds.dat (TSV, cached).
# v1.1 (Nyx, 2026-10-02): select newest MMDVM/DMRGateway log by mtime (UTC naming).
# Deployed as /usr/local/sbin/hotspot-oled-dash.py, systemd unit hotspot-oled.service.
# Panel class from /etc/mmdvmhost [OLED] Type (3 = SSD1306, 6 = SH1106).
import configparser
import glob
import math
import os
import re
import socket
import subprocess
import sys
import time
from datetime import datetime, timezone

from PIL import Image, ImageDraw, ImageFont
from luma.core.interface.serial import i2c
from luma.oled.device import ssd1306, sh1106

CONFIG = "/etc/mmdvmhost"
LOGDIR = "/var/log/pi-star"
def _read_identity():
    """Callsign + DMR ID from /etc/mmdvmhost [General] (set via the Pi-Star dashboard)."""
    cs, did = "N0CALL", ""
    try:
        cfg = configparser.ConfigParser()
        cfg.read(CONFIG)
        cs = (cfg.get("General", "Callsign", fallback="", raw=True) or "").strip() or "N0CALL"
        did = (cfg.get("General", "Id", fallback="", raw=True) or "").strip()
    except Exception:
        pass
    return cs, did


CALLSIGN, DMR_ID = _read_identity()


def _configured(cs, did):
    """True when a real station identity is set (mirrors hotspot-config-guard)."""
    return cs not in ("", "N0CALL", "MT1998") and did not in ("", "1234567")


CONFIGURED = _configured(CALLSIGN, DMR_ID)

FREQ = "446.5500"
FONT_DIR = "/usr/share/fonts/truetype/dejavu"
IDLE_ROTATE_AFTER = 60
CAROUSEL_PERIOD = 8

TG_NAMES = {
    # BrandMeister
    "91": "Worldwide", "93": "N. America", "3100": "USA", "3112": "Florida",
    "31665": "Mothership", "9990": "Parrot",
    # TGIF (RF uses the 4-prefix form)
    "4003157": "Jax Mesh", "4003158": "N.FL AR", "4003160": "FL Open",
    "40031665": "Mothership", "40023456": "Coast2Coast", "400113": "Worldwide",
    "400110": "N. America", "400130": "SKYWARN", "400103": "TAC 1",
    "400104": "TAC 2", "400105": "TAC 3", "400850": "Panhandle",
    "4009990": "Parrot", "4003100": "USA",
}

RE_MODE = re.compile(r"Mode set to (\w+)")
RE_VOICE = re.compile(r"received (?:RF|network) (?:voice )?header from (\S+) to TG (\S+)")
RE_BER = re.compile(r"BER: ([\d.]+)%(?:, RSSI: (-?\d+))?")

# chibi-Nyx sprites (1 = lit pixel). Wave = splash hello, idle = NYX screen.
PET_WAVE = ['..........#............##...................', '.........##.............##..................', '........##..............###.................', '.......###....######....###.................', '.......###..###########.###.................', '.......####################.................', '.......####################.................', '.......#####################................', '....#.#######################...............', '....##########################..............', '.....#########################..............', '....###########################.............', '....##########################..............', '...##########.#####..#########.###..........', '....#########.#####.#############.#.........', '....#######..#.######..########.####........', '.#############.###.####.#####.#...##.......#', '.#....##########...#########.#.#...#.......#', '..#.######.###.....#.#.#######....#.........', '...#..####.###.....###.#########.#..........', '...##.#####.##......##.###########..........', '...#######.............###########..........', '#.#########....#.#.....##########.........#.', '#############........############.........##', '.###############################............', '..##############..##############............', '.################################..........#', '.###############################...........#', '..#.############################............', '.....##########..############...............', '....###########..############...............', '.......########...#########.##..............', '.......########....######.#.................', '......##########....#####...................', '.......##################...................', '.......##################...................', '.......##################...................', '.........################...................', '.......###.############.....................', '...........#......#...#.....................', '...........#...#..#...#.....................', '...........#####..#####.....................', '...........#####..######....................', '...........#####..######....................', '..........######..######....................', '..........######..#######...................', '..........######..#######...................', '..........######..#######...................']
PET_IDLE = ['.........#..............#.........', '........##..............##........', '.......###..............###.......', '.......###...########...###.......', '......####.############.####......', '......######################......', '.......#####################......', '......#######################.....', '...##########################.....', '....##########################....', '....###########################...', '...############################...', '...#################.#########....', '...##########.#####..##########...', '...############################...', '...#######...#.###......#######...', '.#############.###.############.#.', '.#....##########...###.#####......', '..#..#####.###.....###.######..#..', '...#..####.###.....###..####..#...', '...########.##......##.########...', '..########.............#########..', '###########....###.....###########', '#############.......#############.', '..##############################..', '.###############.################.', '.################################.', '.################################.', '..#..########################.....', '.....##########..############.....', '....###########...############....', '.......########....########.......', '.......########....########.......', '......###########...########......', '.......####################.......', '.......####################.......', '.......####################.......', '.........################.#.......', '........##.############.##........', '...........#...#..................', '...........#...#..#...#...........', '...........#####..#####...........', '..........######.######...........', '...........#####.######...........', '..........######.#######..........', '..........######.#######..........', '..........######.#######..........', '..........######..######..........']

try:
    F_HEAD = ImageFont.truetype(os.path.join(FONT_DIR, "DejaVuSans-Bold.ttf"), 13)
    F_BODY = ImageFont.truetype(os.path.join(FONT_DIR, "DejaVuSansMono-Bold.ttf"), 12)
    F_SMALL = ImageFont.truetype(os.path.join(FONT_DIR, "DejaVuSans.ttf"), 10)
    F_BIG = ImageFont.truetype(os.path.join(FONT_DIR, "DejaVuSans-Bold.ttf"), 21)
    F_TITLE = ImageFont.truetype(os.path.join(FONT_DIR, "DejaVuSans-Bold.ttf"), 18)
except Exception:
    F_HEAD = F_BODY = F_SMALL = F_BIG = F_TITLE = ImageFont.load_default()


def rows_to_image(rows):
    w = max(len(r) for r in rows)
    img = Image.new("1", (w, len(rows)), 0)
    px = img.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "#":
                px[x, y] = 1
    return img


def panel_device():
    t = 6
    try:
        cfg = configparser.ConfigParser()
        cfg.read(CONFIG)
        t = cfg.getint("OLED", "Type", fallback=6)
    except Exception:
        pass
    serial = i2c(port=1, address=0x3C)
    if t == 3:
        dev = ssd1306(serial, width=128, height=64)
    else:
        dev = sh1106(serial, width=128, height=64)
    dev.cleanup = lambda: None
    return dev, t


def tail_lines(path, n=80):
    try:
        with open(path, "rb") as f:
            f.seek(0, os.SEEK_END)
            size = f.tell()
            block = min(size, 24000)
            f.seek(size - block)
            data = f.read().decode("utf-8", errors="replace")
        return data.splitlines()[-n:]
    except Exception:
        return []


def newest_log(name):
    files = glob.glob(os.path.join(LOGDIR, name + "-*.log"))
    best, best_t = None, -1.0
    for f in files:
        try:
            t = os.path.getmtime(f)
        except OSError:
            continue
        if t > best_t:
            best, best_t = f, t
    return best


_NET_CACHE = {"ip": "0.0.0.0", "online": True, "ip_t": 0.0, "on_t": 0.0}
_WIFI_CACHE = {"dbm": None, "ssid": "?", "t": 0.0}
_VITAL_CACHE = {"temp": "--", "t": 0.0}


def get_net_info():
    now = time.time()
    if now - _NET_CACHE["ip_t"] > 60 or _NET_CACHE["ip"] == "0.0.0.0":
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.settimeout(1)
            s.connect(("1.1.1.1", 53))
            _NET_CACHE["ip"] = s.getsockname()[0]
            s.close()
        except Exception:
            pass
        _NET_CACHE["ip_t"] = now
    if now - _NET_CACHE["on_t"] > 20:
        try:
            r = subprocess.run(["ping", "-c", "1", "-W", "2", "1.1.1.1"],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                               timeout=4)
            _NET_CACHE["online"] = (r.returncode == 0)
        except Exception:
            _NET_CACHE["online"] = False
        _NET_CACHE["on_t"] = now
    return _NET_CACHE["ip"], _NET_CACHE["online"]


def get_wifi():
    now = time.time()
    if now - _WIFI_CACHE["t"] > 60:
        dbm = None
        ssid = "?"
        try:
            with open("/proc/net/wireless") as f:
                for line in f:
                    if line.strip().startswith("wlan0"):
                        parts = line.split()
                        dbm = int(float(parts[3].rstrip(".")))
                        break
        except Exception:
            pass
        try:
            out = subprocess.check_output(["wpa_cli", "-i", "wlan0", "status"],
                                          stderr=subprocess.DEVNULL, timeout=5).decode()
            for line in out.splitlines():
                if line.startswith("ssid="):
                    ssid = line.split("=", 1)[1]
                    break
        except Exception:
            pass
        _WIFI_CACHE.update({"dbm": dbm, "ssid": ssid, "t": now})
    return _WIFI_CACHE["dbm"], _WIFI_CACHE["ssid"]


def get_temp():
    now = time.time()
    if now - _VITAL_CACHE["t"] > 10:
        try:
            out = subprocess.check_output(["vcgencmd", "measure_temp"],
                                          stderr=subprocess.DEVNULL, timeout=5).decode()
            _VITAL_CACHE["temp"] = out.strip().replace("temp=", "").replace("'C", "")
        except Exception:
            pass
        _VITAL_CACHE["t"] = now
    return _VITAL_CACHE["temp"]


def get_uptime():
    try:
        with open("/proc/uptime") as fh:
            seconds = int(float(fh.read().split()[0]))
        days, rem = divmod(seconds, 86400)
        hours, rem = divmod(rem, 3600)
        minutes = rem // 60
        if days:
            return "%dd %dh" % (days, hours)
        return "%dh %dm" % (hours, minutes)
    except Exception:
        return "--"


_SPECIAL = {}  # optional manual ID overrides, e.g. {"1234567": "N0CALL"}
_ID_CACHE = {}


def resolve_id(num):
    """Numeric DMR ID -> callsign via DMRIds.dat (TSV, cached); local overrides win."""
    if not re.fullmatch(r"\d{4,7}", num):
        return None
    if DMR_ID and num == DMR_ID:
        return CALLSIGN
    if num in _SPECIAL:
        return _SPECIAL[num]
    if num in _ID_CACHE:
        return _ID_CACHE[num]
    call = None
    try:
        out = subprocess.run(
            ["grep", "-m1", "^" + num + "\t", "/usr/local/etc/DMRIds.dat"],
            capture_output=True, timeout=5).stdout.decode()
        if out:
            parts = out.strip().split("\t")
            if len(parts) >= 2:
                call = parts[1].strip().upper() or None
    except Exception:
        pass
    _ID_CACHE[num] = call
    return call


def parse_state():
    st = {"mode": "?", "tg": None, "last": None, "raw_last": None, "live": False, "age": 999,
          "ber": None, "rssi": None, "net": "-", "ip_last": "?", "online": True}
    p = newest_log("MMDVM")
    lines = tail_lines(p, 140) if p else []
    now = time.time()
    for ln in lines:
        try:
            m = RE_MODE.search(ln)
            if m:
                st["mode"] = m.group(1)
            m = RE_VOICE.search(ln)
            if m:
                st["tg"] = m.group(2)
                st["raw_last"] = m.group(1)
                st["last"] = resolve_id(m.group(1)) or m.group(1)
                ts = re.search(r"(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)", ln)
                if ts:
                    t = datetime.strptime(ts.group(1), "%Y-%m-%d %H:%M:%S").replace(
                        tzinfo=timezone.utc).timestamp()
                    st["age"] = now - t
                st["live"] = st["age"] <= 4.5
            m = RE_BER.search(ln)
            if m:
                st["ber"] = m.group(1)
                st["rssi"] = m.group(2)
        except Exception:
            continue
    gwf = newest_log("DMRGateway")
    gw = tail_lines(gwf, 80) if gwf else []
    nets = []
    for ln in gw:
        m = re.search(r"([\w.+-]+), Logged into the master successfully", ln)
        if m and m.group(1) not in nets:
            nets.append(m.group(1))
    st["net"] = "%dNET✓" % len(nets) if nets else "-"
    ip, online = get_net_info()
    st["ip_last"] = ip.split(".")[-1]
    st["online"] = online
    return st


def tg_label(tg):
    return TG_NAMES.get(tg, "TG " + tg)


def fit_badge(d, left_end, right):
    """Shrink the header badge (2NET✓ -> 2N✓ -> ✓) until it clears the callsign."""
    cands = [right]
    if "NET" in right:
        cands.append(right.replace("NET", "N"))
    cands.append(right[-1])
    for c in cands:
        if 108 - d.textlength(c, font=F_HEAD) - left_end >= 8:
            return c
    return cands[-1]


def header(d, left, right):
    d.rectangle([0, 0, 127, 15], fill=1)
    d.text((3, 1), left, font=F_HEAD, fill=0)
    right = fit_badge(d, 3 + d.textlength(left, font=F_HEAD), right)
    rw = d.textlength(right, font=F_HEAD)
    d.text((108 - rw, 1), right, font=F_HEAD, fill=0)


def draw_comet(d, ink):
    """Two-dot liveness comet, top-right corner, advancing every 0.5s."""
    phase = int(time.time() * 2) % 6
    head, tail = phase, (phase + 1) % 6
    for k in (head, tail):
        ang = math.radians(k * 60 - 90)
        cx = int(round(117.5 + 5 * math.cos(ang)))
        cy = int(round(7.5 + 5 * math.sin(ang)))
        if k == head:
            d.rectangle([cx - 1, cy - 1, cx, cy], fill=ink)
        else:
            d.rectangle([cx, cy, cx, cy], fill=ink)


def _fit(d, prefix, tail, budget_px):
    """Trim `tail` until prefix+tail fits within budget_px at F_BODY."""
    while tail and d.textlength(prefix + tail, font=F_BODY) > budget_px:
        tail = tail[:-1]
    return prefix + tail


def draw_status(dev, st):
    img = Image.new("1", (128, 64), 0)
    d = ImageDraw.Draw(img)
    header(d, CALLSIGN, st["net"])
    draw_comet(d, 0)
    if not CONFIGURED:
        d.text((3, 19), "SET CALLSIGN + ID", font=F_BODY, fill=1)
    elif st["live"] and st["last"] and st["tg"]:
        if st["last"] == CALLSIGN or st["raw_last"] == DMR_ID:
            line = _fit(d, "TX → ", tg_label(st["tg"]), 121)
            d.rectangle([0, 17, 127, 32], fill=1)
            d.text((3, 19), line, font=F_BODY, fill=0)
        else:
            line = _fit(d, "● " + st["last"][:8] + " → ", tg_label(st["tg"]), 121)
            d.text((3, 19), line, font=F_BODY, fill=1)
    elif st["tg"]:
        line = _fit(d, "Last on ", tg_label(st["tg"]), 121)
        d.text((3, 19), line, font=F_BODY, fill=1)
    else:
        d.text((3, 19), "Listening…", font=F_BODY, fill=1)
    if st["ber"] is not None:
        r = str(st["ber"])[:4] + "%"
    else:
        r = "." + st["ip_last"] if st["ip_last"] != "?" else ""
    budget = 121
    if r:
        rw = d.textlength(r, font=F_BODY)
        d.text((124 - rw, 34), r, font=F_BODY, fill=1)
        budget = 121 - rw - 4
    lh = "Last: " + (st["last"][:8] if st["last"] else FREQ + " MHz")
    if st["last"] and st["age"] >= 60:
        lh2 = lh + " %dm" % int(st["age"] // 60)
        if d.textlength(lh2, font=F_BODY) <= budget:
            lh = lh2
    while d.textlength(lh, font=F_BODY) > budget and len(lh) > 6:
        lh = lh[:-1]
    d.text((3, 34), lh, font=F_BODY, fill=1)
    d.line([0, 50, 127, 50], fill=1)
    icon = "NET✓" if st["online"] else "NET✗"
    d.text((3, 52), icon + " " + st["mode"], font=F_SMALL, fill=1)
    clk = datetime.now().strftime("%-I:%M%p")
    cw = d.textlength(clk, font=F_SMALL)
    d.text((124 - cw, 52), clk, font=F_SMALL, fill=1)
    dev.display(img)


def draw_wifi(dev, st):
    img = Image.new("1", (128, 64), 0)
    d = ImageDraw.Draw(img)
    dbm, ssid = get_wifi()
    header(d, "WI-FI", st["net"])
    draw_comet(d, 0)
    txt = (str(dbm) + " dBm") if dbm is not None else "no signal?"
    tw = d.textlength(txt, font=F_BIG)
    d.text(((128 - tw) // 2, 20), txt, font=F_BIG, fill=1)
    d.text((3, 44), "SSID " + ssid[:18], font=F_SMALL, fill=1)
    ip, _ = get_net_info()
    iw = d.textlength(ip, font=F_SMALL)
    d.text((124 - iw, 54), ip, font=F_SMALL, fill=1)
    dev.display(img)


def draw_vitals(dev, st):
    img = Image.new("1", (128, 64), 0)
    d = ImageDraw.Draw(img)
    header(d, "SYSTEM", st["net"])
    draw_comet(d, 0)
    d.text((3, 20), "TEMP  " + get_temp() + "C", font=F_BODY, fill=1)
    d.text((3, 34), "UP    " + get_uptime(), font=F_BODY, fill=1)
    try:
        la = "%.2f" % os.getloadavg()[0]
    except Exception:
        la = "--"
    d.text((3, 48), "LOAD  " + la, font=F_BODY, fill=1)
    dev.display(img)


def draw_nyx(dev, st, pet_idle):
    img = Image.new("1", (128, 64), 0)
    d = ImageDraw.Draw(img)
    draw_comet(d, 1)
    img.paste(pet_idle, (4, 8), pet_idle)
    x = 4 + pet_idle.width + 8
    d.text((x, 4), "NYX", font=F_BIG, fill=1)
    d.text((x, 30), "online", font=F_SMALL, fill=1)
    d.text((x, 42), "hi friend ♥", font=F_SMALL, fill=1)
    d.text((x, 54), datetime.now().strftime("%-I:%M%p"), font=F_SMALL, fill=1)
    dev.display(img)


def splash(dev, pet_wave):
    img = Image.new("1", (128, 64), 0)
    d = ImageDraw.Draw(img)
    img.paste(pet_wave, (2, 6), pet_wave)
    x = 2 + pet_wave.width + 6
    d.text((x, 4), CALLSIGN[:8], font=F_TITLE, fill=1)
    d.text((x, 26), "HOTSPOT", font=F_HEAD, fill=1)
    d.text((x, 42), "dash v1.6", font=F_SMALL, fill=1)
    d.text((x, 53), "by nyx ♥", font=F_SMALL, fill=1)
    dev.display(img)
    time.sleep(2.5)


def main():
    dev, t = None, None
    for _ in range(30):
        try:
            dev, t = panel_device()
            break
        except Exception as e:
            print("panel init retry:", e, flush=True)
            time.sleep(3)
    if dev is None:
        sys.exit("no panel")
    print("panel ready (type %s)" % t, flush=True)
    pet_wave = rows_to_image(PET_WAVE)
    pet_idle = rows_to_image(PET_IDLE)
    splash(dev, pet_wave)
    car = {"last_activity": time.time(), "idx": 1, "flip": time.time(), "rotating": False}
    while True:
        try:
            st = parse_state()
            now = time.time()
            if st["live"]:
                car["last_activity"] = now
                car["rotating"] = False
                car["idx"] = 1
                screen = 0
            elif now - car["last_activity"] > IDLE_ROTATE_AFTER:
                if not car["rotating"]:
                    car["rotating"] = True
                    car["flip"] = now
                    car["idx"] = 1
                elif now - car["flip"] > CAROUSEL_PERIOD:
                    car["flip"] = now
                    car["idx"] = (car["idx"] + 1) % 4
                screen = car["idx"]
            else:
                screen = 0
            if screen == 0:
                draw_status(dev, st)
            elif screen == 1:
                draw_wifi(dev, st)
            elif screen == 2:
                draw_vitals(dev, st)
            else:
                draw_nyx(dev, st, pet_idle)
        except Exception as e:
            print("render error:", e, flush=True)
        time.sleep(0.5)


if __name__ == "__main__":
    main()
