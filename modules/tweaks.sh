#!/usr/bin/env bash
# Terapkan setelan dari profil.  --check = hanya periksa.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
require_device
MODE=apply; [ "${1:-}" = "--check" ] && { MODE=check; shift; }
PROFILE="$(pick_profile "${1:-}")"
# shellcheck disable=SC1090
source "$PROFILE"

head1 "Setelan — profil $(basename "$PROFILE" .conf)$([ $MODE = check ] && echo '  (mode periksa)')"
# SETTINGS berisi baris: "ns key nilai  # label"
printf '%s\n' "${SETTINGS:-}" | while read -r ns key val rest; do
  [ -z "${ns:-}" ] && continue
  label=$(printf '%s' "$rest" | sed 's/^# *//')
  cur=$(gset "$ns" "$key")
  if [ "$cur" = "$val" ]; then
    printf '  ok      %-34s = %s\n' "${label:-$key}" "$val"
  elif [ "$MODE" = check ]; then
    printf '  %s[cek]%s   %-34s : %s → seharusnya %s\n' "$c_ylw" "$c_off" "${label:-$key}" "$cur" "$val"
  else
    pset "$ns" "$key" "$val"
    now=$(gset "$ns" "$key")
    if [ "$now" = "$val" ]; then printf '  diset   %-34s = %s (dari: %s)\n' "${label:-$key}" "$val" "$cur"
    else printf '  %sGAGAL%s   %-34s tetap %s — kemungkinan dikunci sistem\n' "$c_red" "$c_off" "${label:-$key}" "$now"; fi
  fi
done

if [ -n "${DENSITY:-}" ]; then
  cur=$(sh_ "wm density" | grep -oE 'Override density: [0-9]+' | grep -oE '[0-9]+')
  if [ "${cur:-}" = "$DENSITY" ]; then printf '  ok      %-34s = %s\n' "Kepadatan layar" "$DENSITY"
  elif [ "$MODE" = check ]; then printf '  %s[cek]%s   %-34s : %s → %s\n' "$c_ylw" "$c_off" "Kepadatan layar" "${cur:-bawaan}" "$DENSITY"
  else adb shell wm density "$DENSITY" </dev/null >/dev/null 2>&1; printf '  diset   %-34s = %s\n' "Kepadatan layar" "$DENSITY"; fi
fi

if [ -n "${NOTIF_LISTENER_DENY:-}" ]; then
  head1 "Cabut akses baca-notifikasi"
  for comp in ${NOTIF_LISTENER_DENY}; do
    if gset secure enabled_notification_listeners | grep -q "${comp%%/*}"; then
      if [ "$MODE" = check ]; then warn "$comp MASIH bisa membaca notifikasi"
      else adb shell "cmd notification disallow_listener $comp" </dev/null >/dev/null 2>&1; ok "dicabut: $comp"; fi
    else ok "sudah dicabut: ${comp%%/*}"; fi
  done
fi
