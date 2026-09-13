#!/usr/bin/env bash
# Profilkan perangkat: simpan snapshot & usulkan kandidat bloat.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
require_device
DIR="$(device_dir)"; mkdir -p "$DIR/backup"
TS=$(date +%Y%m%d-%H%M%S)

head1 "Perangkat"
printf '  %-14s %s %s\n' "Perangkat" "$(device_brand)" "$(device_model)"
printf '  %-14s Android %s (SDK %s), patch %s\n' "OS" \
  "$(getprop_ ro.build.version.release)" "$(getprop_ ro.build.version.sdk)" "$(getprop_ ro.build.version.security_patch)"
printf '  %-14s %s\n' "Chipset" "$(getprop_ ro.board.platform)"
printf '  %-14s %s\n' "ABI" "$(getprop_ ro.product.cpu.abi)"
sh_ "grep -E 'MemTotal|MemAvailable' /proc/meminfo" | sed 's/^/  /'
sh_ "df -h /data/user/0 | tail -1" | awk '{print "  Penyimpanan    "$3" / "$2" terpakai, "$4" bebas"}'

head1 "Layar"
sh_ "dumpsys SurfaceFlinger | grep -oE 'refreshRate=[0-9.]+fps' | sort -u" | sed 's/^/  /'
info "hanya satu nilai = refresh rate tetap (tidak bisa dinaikkan)"

head1 "Snapshot paket"
sh_ "pm list packages"    | sed 's/^package://' | sort > "$DIR/backup/enabled-$TS.txt"
sh_ "pm list packages -u" | sed 's/^package://' | sort > "$DIR/backup/all-$TS.txt"
sh_ "pm list packages -3" | sed 's/^package://' | sort > "$DIR/backup/third-$TS.txt"
ok "aktif: $(grep -c . "$DIR/backup/enabled-$TS.txt")  |  pihak-ketiga: $(grep -c . "$DIR/backup/third-$TS.txt")"
info "tersimpan di ${DIR#"$KIT_ROOT"/}/backup/"

PROFILE="$(pick_profile "${1:-}")"
head1 "Kandidat dari profil: $(basename "$PROFILE" .conf)"
# shellcheck disable=SC1090
source "$PROFILE"
n_rm=0; n_miss=0
: > "$DIR/candidates.txt"
for p in ${REMOVE:-}; do
  if pkg_installed "$p"; then echo "$p" >> "$DIR/candidates.txt"; n_rm=$((n_rm+1)); else n_miss=$((n_miss+1)); fi
done
ok "$n_rm kandidat terpasang  (${n_miss} tidak ada di perangkat ini)"
if [ -n "${REMOVE_OPTIONAL:-}" ]; then
  n_opt=0; for p in ${REMOVE_OPTIONAL}; do pkg_installed "$p" && n_opt=$((n_opt+1)); done
  info "$n_opt kandidat OPSIONAL (pilihan pribadi) — pakai: debloat --with-optional"
fi
[ "$n_rm" -gt 0 ] && sed 's/^/    /' "$DIR/candidates.txt" | head -40

head1 "Sisa paket OEM yang BELUM dikenali profil"
info "tinjau manual — bisa jadi bloat baru yang layak ditambahkan ke profil"
BRAND=$(device_brand)
grep -iE "$BRAND|${OEM_PATTERN:-zzz_nomatch}" "$DIR/backup/enabled-$TS.txt" 2>/dev/null \
  | grep -vxF -f "$DIR/candidates.txt" 2>/dev/null | head -30 | sed 's/^/    /' || true

echo ""
info "Langkah berikutnya:  ./adb-kit.sh debloat   (akan minta konfirmasi)"
