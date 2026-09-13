#!/bin/bash
# ============================================================
#  RESTORE DARURAT - Vivo V21 (V2108)
#  Mengembalikan aplikasi yang dihapus & dinetralkan.
#
#  Pakai:
#    ./restore.sh                      -> kembalikan SEMUA
#    ./restore.sh com.vivo.browser     -> kembalikan satu paket
#    ./restore.sh --unmute             -> hanya batalkan penetralan (12 paket terkunci)
# ============================================================
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

# Port ADB nirkabel berubah tiap reboot -> cari HP otomatis via mDNS.
if ! adb devices | grep -qE '\sdevice$'; then
  echo "Mencari HP di jaringan..."
  for i in 1 2 3 4 5 6 7 8 9 10; do
    TARGET=$(adb mdns services 2>/dev/null | grep '_adb-tls-connect' | awk '{print $3}' | head -1)
    if [ -n "${TARGET:-}" ]; then
      adb connect "$TARGET" >/dev/null 2>&1
      sleep 2
      adb devices | grep -qE '\sdevice$' && { echo "Terhubung: $TARGET"; break; }
    fi
    sleep 3
  done
fi

if ! adb devices | grep -qE '\sdevice$'; then
  echo "HP tidak terhubung."
  echo "Nyalakan: Setelan > Sistem > Opsi pengembang > Debugging nirkabel"
  echo "Lalu jalankan ulang skrip ini (pairing sudah tersimpan, tak perlu kode lagi)."
  echo "Manual:  adb connect <IP>:<PORT-KONEKSI>"
  exit 1
fi
# HP yang sama bisa muncul 2x (via IP + via mDNS) -> pilih satu serial saja.
ANDROID_SERIAL=$(adb devices 2>/dev/null | awk '/[ \t]device$/{print $1; exit}')
export ANDROID_SERIAL
[ -n "${ANDROID_SERIAL:-}" ] || { echo "Tidak ada HP terhubung."; exit 1; }

restore_one() {
  printf '  %-42s ' "$1"
  out=$(adb shell cmd package install-existing "$1" </dev/null 2>&1 | tr -d '\r')
  case "$out" in
    *installed*) echo "OK dipulihkan" ;;
    *)           echo "GAGAL: $(echo "$out" | head -1)" ;;
  esac
}

unmute_one() {
  printf '  %-42s ' "$1"
  for op in RUN_ANY_IN_BACKGROUND RUN_IN_BACKGROUND POST_NOTIFICATION WAKE_LOCK START_FOREGROUND; do
    adb shell cmd appops set "$1" $op allow </dev/null >/dev/null 2>&1
  done
  adb shell am set-standby-bucket "$1" active </dev/null >/dev/null 2>&1
  u=$(adb shell "dumpsys package $1 | grep -m1 userId=" </dev/null 2>/dev/null | tr -d '\r ' | sed 's/.*userId=//')
  [ -n "$u" ] && adb shell cmd netpolicy remove restrict-background-blacklist "$u" </dev/null >/dev/null 2>&1
  adb shell dumpsys deviceidle whitelist "+$1" </dev/null >/dev/null 2>&1
  echo "OK diaktifkan kembali"
}

if [ "${1:-}" = "--unmute" ]; then
  echo "Membatalkan penetralan 12 paket terkunci..."
  while read -r p; do [ -n "$p" ] && unmute_one "$p"; done < "$DIR/lists/locked-neutralized.txt"
  echo "Selesai. Reboot: adb reboot"
  exit 0
fi

if [ $# -gt 0 ]; then
  for p in "$@"; do restore_one "$p"; unmute_one "$p"; done
  exit 0
fi

echo "== Memulihkan paket yang DIHAPUS =="
cat "$DIR"/lists/batch-a.txt "$DIR"/lists/batch-b.txt "$DIR"/lists/batch-c.txt \
  | grep -v '^$' | while read -r p; do restore_one "$p"; done

echo ""
echo "== Membatalkan penetralan paket TERKUNCI =="
while read -r p; do [ -n "$p" ] && unmute_one "$p"; done < "$DIR/lists/locked-neutralized.txt"

echo ""
echo "Selesai. Reboot HP:  adb reboot"
