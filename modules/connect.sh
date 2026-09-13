#!/usr/bin/env bash
# Pairing & koneksi nirkabel.  Pakai: adb-kit connect [IP:PORT KODE]
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

head1 "Koneksi nirkabel"
if [ $# -ge 2 ]; then
  info "Pairing ke $1 ..."
  adb pair "$1" "$2" || { err "Pairing gagal. Kode kedaluwarsa? Buka ulang dialog di HP."; exit 1; }
fi
if adb_pick_serial; then ok "Sudah terhubung: $ANDROID_SERIAL"; else
  info "Menelusuri jaringan (mDNS)..."
  adb_discover && ok "Terhubung: $ANDROID_SERIAL" || {
    err "Tidak ketemu."
    echo "     Pastikan Mac dan HP di WiFi yang sama, dan Debugging nirkabel menyala."
    echo "     Pairing pertama kali:  ./adb-kit.sh connect <IP>:<PORT-PAIRING> <KODE>"
    exit 1; }
fi
printf '  %-16s %s\n' "Brand"  "$(device_brand)"
printf '  %-16s %s\n' "Model"  "$(device_model)"
printf '  %-16s Android %s (SDK %s)\n' "OS" "$(getprop_ ro.build.version.release)" "$(getprop_ ro.build.version.sdk)"
printf '  %-16s %s\n' "Patch"  "$(getprop_ ro.build.version.security_patch)"
printf '  %-16s %s\n' "Profil" "$(basename "$(pick_profile)" .conf)"
