#!/usr/bin/env bash
# Periksa kesehatan + deteksi regresi setelah reboot/update.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
require_device
DIR="$(device_dir)"

head1 "Kesehatan sistem"
for p in com.android.systemui com.android.phone; do
  printf '  %-28s %s\n' "$p" "$(sh_ "pidof $p >/dev/null && echo jalan || echo MATI")"
done
L=$(sh_ "cmd shortcut get-default-launcher" | grep -oE 'ComponentInfo\{[^/]+' | sed 's/ComponentInfo{//')
printf '  %-28s %s\n' "launcher" "${L:-?}"
printf '  %-28s %s\n' "crash sejak boot" "$(sh_ "logcat -d -b crash -t 400 | grep -cE 'FATAL|ANR in'")"
sh_ "dumpsys telephony.registry | grep -m1 -oE 'mVoiceRegState=[0-9]\([A-Z_]+\)'" | sed 's/^/  sinyal: /'
sh_ "ping -c 2 -W 3 -q 8.8.8.8 | tail -1" | sed 's/^/  internet: /'

head1 "Regresi paket"
if [ -f "$DIR/removed.txt" ]; then
  back=0
  while read -r p; do
    [ -z "$p" ] && continue
    pkg_installed "$p" && { warn "KEMBALI: $p"; back=$((back+1)); }
  done < "$DIR/removed.txt"
  [ "$back" -eq 0 ] && ok "$(grep -c . "$DIR/removed.txt") paket tetap terhapus"
else info "belum ada catatan — jalankan debloat dulu"; fi

head1 "Regresi penetralan"
if [ -f "$DIR/neutralized.txt" ]; then
  loose=0
  while read -r p; do
    [ -z "$p" ] && continue
    pkg_installed "$p" || continue
    [ "$(sh_ "cmd appops get $p POST_NOTIFICATION" | grep -c ignore)" = "1" ] || { warn "lepas: $p"; loose=$((loose+1)); }
  done < "$DIR/neutralized.txt"
  [ "$loose" -eq 0 ] && ok "semua penetralan utuh"
  [ "$loose" -gt 0 ] && info "perbaiki dengan: ./adb-kit.sh debloat"
fi
