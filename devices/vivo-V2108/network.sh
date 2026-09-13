#!/bin/bash
# ============================================================
#  Pengelola DNS & tweak jaringan - Vivo V21
#    ./network.sh status     -> lihat setelan sekarang
#    ./network.sh adguard    -> DNS pemblokir iklan (default)
#    ./network.sh fast       -> Cloudflare 1.1.1.1 (tercepat, tanpa blokir)
#    ./network.sh off        -> matikan Private DNS (kembali ke DNS operator)
#    ./network.sh test       -> uji apakah iklan benar diblokir
#    ./network.sh anim 1.0   -> kembalikan animasi normal (0.5 = cepat)
# ============================================================
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

if ! adb devices 2>/dev/null | grep -qE '\sdevice$'; then
  echo "Mencari HP..."
  for i in 1 2 3 4 5 6 7 8; do
    T=$(adb mdns services 2>/dev/null | grep '_adb-tls-connect' | awk '{print $3}' | head -1)
    [ -n "${T:-}" ] && { adb connect "$T" >/dev/null 2>&1; sleep 2; }
    adb devices 2>/dev/null | grep -qE '\sdevice$' && break
    sleep 3
  done
fi
adb devices 2>/dev/null | grep -qE '\sdevice$' || {
  echo "HP tidak terhubung. Nyalakan Debugging nirkabel di HP lalu ulangi."; exit 1; }

# HP yang sama bisa muncul 2x (via IP + via mDNS) -> pilih satu serial saja.
ANDROID_SERIAL=$(adb devices 2>/dev/null | awk '/[ \t]device$/{print $1; exit}')
export ANDROID_SERIAL
[ -n "${ANDROID_SERIAL:-}" ] || { echo "Tidak ada HP terhubung."; exit 1; }

g() { adb shell settings get global "$1" </dev/null 2>/dev/null | tr -d '\r'; }
s() { adb shell settings put global "$1" "$2" </dev/null >/dev/null 2>&1; }

case "${1:-status}" in
  adguard)
    s private_dns_specifier dns.adguard-dns.com; s private_dns_mode hostname
    echo "Private DNS -> AdGuard (blokir iklan + tracker, terenkripsi)" ;;
  fast)
    s private_dns_specifier one.one.one.one; s private_dns_mode hostname
    echo "Private DNS -> Cloudflare 1.1.1.1 (tercepat, TANPA blokir iklan)" ;;
  off)
    s private_dns_mode off
    echo "Private DNS dimatikan (pakai DNS operator, tidak terenkripsi)" ;;
  anim)
    v="${2:-1.0}"
    for k in window_animation_scale transition_animation_scale animator_duration_scale; do s "$k" "$v"; done
    echo "Animasi -> $v" ;;
  test)
    echo "Uji pemblokiran iklan (127.0.0.1 / 0.0.0.0 = DIBLOKIR):"
    for d in doubleclick.net googleadservices.com analytics.google.com googlesyndication.com; do
      ip=$(adb shell "ping -c 1 -W 3 $d" </dev/null 2>&1 | tr -d '\r' | head -1 | sed 's/^[^(]*(\([^)]*\)).*/\1/')
      case "$ip" in
        127.0.0.1|0.0.0.0) st="DIBLOKIR" ;;
        *)                 st="lolos ($ip)" ;;
      esac
      printf '  %-26s %s\n' "$d" "$st"
    done
    echo "Uji situs normal tetap jalan:"
    for d in google.com instagram.com; do
      ip=$(adb shell "ping -c 1 -W 3 $d" </dev/null 2>&1 | tr -d '\r' | head -1 | sed 's/^[^(]*(\([^)]*\)).*/\1/')
      printf '  %-26s %s\n' "$d" "$ip"
    done ;;
  status|*)
    echo "Private DNS mode      : $(g private_dns_mode)"
    echo "Private DNS server    : $(g private_dns_specifier)"
    echo "Animasi (window)      : $(g window_animation_scale)"
    echo "Animasi (transition)  : $(g transition_animation_scale)"
    echo "Animasi (animator)    : $(g animator_duration_scale)"
    echo "WiFi scan selalu ON   : $(g wifi_scan_always_enabled)"
    echo "BLE scan selalu ON    : $(g ble_scan_always_enabled)" ;;
esac
