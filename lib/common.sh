#!/usr/bin/env bash
# ============================================================
#  common.sh - fungsi bersama untuk semua modul
# ============================================================
set -uo pipefail

KIT_ROOT="${KIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# ---------- tampilan ----------
c_red=$'\033[31m'; c_grn=$'\033[32m'; c_ylw=$'\033[33m'
c_blu=$'\033[34m'; c_dim=$'\033[2m';  c_off=$'\033[0m'
ok()   { printf '  %s✅%s %s\n' "$c_grn" "$c_off" "$*"; }
warn() { printf '  %s⚠️ %s %s\n' "$c_ylw" "$c_off" "$*"; }
err()  { printf '  %s❌%s %s\n' "$c_red" "$c_off" "$*" >&2; }
info() { printf '  %s•%s  %s\n' "$c_dim" "$c_off" "$*"; }
head1(){ printf '\n%s== %s ==%s\n' "$c_blu" "$*" "$c_off"; }

# ---------- koneksi perangkat ----------
# Perangkat yang sama bisa muncul dua kali (via IP + via mDNS).
# Selalu pilih SATU serial dan ekspor ANDROID_SERIAL.
adb_pick_serial() {
  ANDROID_SERIAL=$(adb devices 2>/dev/null | awk '/[ \t]device$/{print $1; exit}')
  export ANDROID_SERIAL
  [ -n "${ANDROID_SERIAL:-}" ]
}

adb_discover() {   # cari perangkat via mDNS lalu sambungkan
  local t
  for _ in 1 2 3 4 5 6 7 8; do
    t=$(adb mdns services 2>/dev/null | grep '_adb-tls-connect' | awk '{print $3}' | head -1)
    [ -n "${t:-}" ] && { adb connect "$t" >/dev/null 2>&1; sleep 2; }
    adb_pick_serial && return 0
    sleep 3
  done
  return 1
}

require_device() {
  command -v adb >/dev/null || { err "adb tidak ditemukan. Pasang android-platform-tools."; exit 1; }
  adb_pick_serial && return 0
  info "Mencari perangkat..."
  adb_discover && { ok "Terhubung: $ANDROID_SERIAL"; return 0; }
  err "Tidak ada perangkat."
  cat <<'MSG'
     Di HP: Setelan > Sistem > Opsi pengembang > Debugging nirkabel > ON
     Pertama kali:  adb pair <IP>:<PORT-PAIRING> <KODE-6-DIGIT>
     Lalu:          adb connect <IP>:<PORT-KONEKSI>
     Atau jalankan: ./adb-kit.sh connect
MSG
  exit 1
}

# ---------- pembungkus adb ----------
# PENTING: `adb shell` menyerap stdin di dalam loop -> selalu </dev/null
sh_()  { adb shell "$@" </dev/null 2>/dev/null | tr -d '\r'; }
sh_e() { adb shell "$@" </dev/null 2>&1  | tr -d '\r'; }

getprop_() { sh_ "getprop $1"; }
gset()  { sh_ "settings get $1 $2"; }        # ns key
pset()  { adb shell settings put "$1" "$2" "$3" </dev/null >/dev/null 2>&1; }

pkg_installed() { sh_ "pm list packages $1" | grep -qx "package:$1"; }

# ---------- identitas perangkat ----------
device_brand() { getprop_ ro.product.brand | tr '[:upper:]' '[:lower:]'; }
device_model() { getprop_ ro.product.model; }
device_slug()  { printf '%s-%s' "$(device_brand)" "$(device_model)" | tr ' /' '--'; }
device_dir()   { printf '%s/devices/%s' "$KIT_ROOT" "$(device_slug)"; }

# ---------- pemilihan profil ----------
# Cocokkan brand ke profiles/*.conf, jatuh ke generic bila tak ada.
pick_profile() {
  local want="${1:-}" brand; brand=$(device_brand)
  if [ -n "$want" ]; then
    [ -f "$KIT_ROOT/profiles/$want.conf" ] && { echo "$KIT_ROOT/profiles/$want.conf"; return; }
    err "Profil '$want' tidak ada."; exit 1
  fi
  local p
  for p in "$KIT_ROOT"/profiles/*.conf; do
    [ -f "$p" ] || continue
    # baris: # brands: vivo iqoo
    if grep -qiE "^# *brands:.*\b${brand}\b" "$p"; then echo "$p"; return; fi
  done
  echo "$KIT_ROOT/profiles/generic.conf"
}

# ---------- keselamatan ----------
# uid 1000 = sistem. JANGAN blacklist jaringannya: Android menolak, dan
# mencobanya berisiko memutus data seluruh sistem.
SYSTEM_UID=1000
pkg_uid() { sh_ "dumpsys package $1 | grep -m1 userId=" | tr -d ' ' | sed 's/.*userId=//'; }

confirm() {  # confirm "pertanyaan"  -> 0 bila pengguna mengetik YA
  local a; printf '  %s [ketik YA untuk lanjut]: ' "$1"; read -r a
  [ "$a" = "YA" ]
}
