#!/usr/bin/env bash
# Hapus paket dari profil. Yang dikunci OEM otomatis dinetralkan.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
require_device
DIR="$(device_dir)"; mkdir -p "$DIR"
PROFILE="$(pick_profile "${1:-}")"
# shellcheck disable=SC1090
source "$PROFILE"

head1 "Debloat — profil $(basename "$PROFILE" .conf)"
todo=(); for p in ${REMOVE:-}; do pkg_installed "$p" && todo+=("$p"); done
[ ${#todo[@]} -eq 0 ] && { ok "Tidak ada yang perlu dihapus."; exit 0; }

info "${#todo[@]} paket akan dihapus untuk pengguna ini."
info "APK tetap di partisi sistem — bisa dipulihkan, factory reset mengembalikan semua."
confirm "Lanjutkan?" || { info "Dibatalkan."; exit 0; }

: > "$DIR/removed.txt"; : > "$DIR/neutralized.txt"
n_ok=0; n_lock=0; n_fail=0
for p in "${todo[@]}"; do
  out=$(adb shell pm uninstall -k --user 0 "$p" </dev/null 2>&1 | tr -d '\r')
  case "$out" in
    *Success*)         printf '  ✅ %-44s dihapus\n' "$p"; echo "$p" >> "$DIR/removed.txt"; n_ok=$((n_ok+1)) ;;
    *USER_RESTRICTED*) printf '  🔒 %-44s dikunci OEM → dinetralkan\n' "$p"
                       echo "$p" >> "$DIR/neutralized.txt"; n_lock=$((n_lock+1)) ;;
    *)                 printf '  ❌ %-44s %s\n' "$p" "$(echo "$out" | head -1)"; n_fail=$((n_fail+1)) ;;
  esac
done

if [ "$n_lock" -gt 0 ]; then
  head1 "Netralkan $n_lock paket terkunci"
  info "OEM melarang uninstall/disable. Kemampuannya yang dimatikan, bukan paketnya."
  while read -r p; do
    [ -z "$p" ] && continue
    for op in RUN_ANY_IN_BACKGROUND RUN_IN_BACKGROUND POST_NOTIFICATION WAKE_LOCK START_FOREGROUND; do
      adb shell cmd appops set "$p" $op ignore </dev/null >/dev/null 2>&1
    done
    adb shell am set-standby-bucket "$p" restricted </dev/null >/dev/null 2>&1
    u=$(pkg_uid "$p")
    # uid sistem TIDAK boleh di-blacklist jaringan
    if [ -n "$u" ] && [ "$u" != "$SYSTEM_UID" ]; then
      adb shell cmd netpolicy add restrict-background-blacklist "$u" </dev/null >/dev/null 2>&1
    fi
    adb shell dumpsys deviceidle whitelist "-$p" </dev/null >/dev/null 2>&1
    adb shell am force-stop "$p" </dev/null >/dev/null 2>&1
    nb=$(sh_ "cmd appops get $p POST_NOTIFICATION" | grep -c ignore)
    printf '  🔇 %-40s uid=%-7s notif-mati=%s\n' "$p" "${u:-?}" "$([ "$nb" = 1 ] && echo ya || echo TIDAK)"
  done < "$DIR/neutralized.txt"
fi

head1 "Ringkasan"
ok "dihapus: $n_ok | dinetralkan: $n_lock | gagal: $n_fail"
info "paket aktif sekarang: $(sh_ 'pm list packages' | wc -l | tr -d ' ')"
