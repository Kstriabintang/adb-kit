#!/usr/bin/env bash
# Pulihkan paket.  restore [paket...]  |  restore --all  |  restore --unmute
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
require_device
DIR="$(device_dir)"

unmute_one() {
  for op in RUN_ANY_IN_BACKGROUND RUN_IN_BACKGROUND POST_NOTIFICATION WAKE_LOCK START_FOREGROUND; do
    adb shell cmd appops set "$1" $op allow </dev/null >/dev/null 2>&1
  done
  adb shell am set-standby-bucket "$1" active </dev/null >/dev/null 2>&1
  u=$(pkg_uid "$1")
  [ -n "$u" ] && adb shell cmd netpolicy remove restrict-background-blacklist "$u" </dev/null >/dev/null 2>&1
  printf '  🔊 %-44s dipulihkan kemampuannya\n' "$1"
}
restore_one() {
  printf '  %-44s ' "$1"
  out=$(adb shell cmd package install-existing "$1" </dev/null 2>&1 | tr -d '\r')
  case "$out" in *installed*) echo "✅ dipulihkan";; *) echo "❌ $(echo "$out" | head -1)";; esac
}

case "${1:-}" in
  --unmute)
    head1 "Batalkan penetralan"
    [ -f "$DIR/neutralized.txt" ] || { err "Tidak ada catatan di ${DIR#"$KIT_ROOT"/}"; exit 1; }
    while read -r p; do [ -n "$p" ] && unmute_one "$p"; done < "$DIR/neutralized.txt" ;;
  --all)
    head1 "Pulihkan SEMUA"
    info "Ini mengembalikan seluruh bloat yang pernah dihapus."
    confirm "Yakin?" || exit 0
    [ -f "$DIR/removed.txt" ] && while read -r p; do [ -n "$p" ] && restore_one "$p"; done < "$DIR/removed.txt"
    [ -f "$DIR/neutralized.txt" ] && while read -r p; do [ -n "$p" ] && unmute_one "$p"; done < "$DIR/neutralized.txt"
    echo; info "Reboot disarankan: adb reboot" ;;
  "" ) err "Pakai: restore <paket...> | --all | --unmute"; exit 1 ;;
  *  ) head1 "Pulihkan paket terpilih"; for p in "$@"; do restore_one "$p"; unmute_one "$p"; done ;;
esac
