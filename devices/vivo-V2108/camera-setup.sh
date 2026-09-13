#!/bin/bash
# ============================================================
#  Pasang GCam/LMC dengan urutan AMAN - Vivo V21 (V2108)
#
#    ./camera-setup.sh pasang <file.apk>   -> pasang + beri izin + uji
#    ./camera-setup.sh config <file.xml>   -> kirim config LMC/GCam ke HP
#    ./camera-setup.sh jadikan-default     -> hapus kamera bawaan (SETELAH GCam diuji!)
#    ./camera-setup.sh balikkan            -> kembalikan kamera bawaan
#    ./camera-setup.sh status              -> lihat kondisi sekarang
# ============================================================
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
STOCK=com.android.camera

if ! adb devices 2>/dev/null | grep -qE '[ 	]device$'; then
  echo "Mencari HP..."
  for i in 1 2 3 4 5 6 7 8; do
    T=$(adb mdns services 2>/dev/null | grep '_adb-tls-connect' | awk '{print $3}' | head -1)
    [ -n "${T:-}" ] && { adb connect "$T" >/dev/null 2>&1; sleep 2; }
    adb devices 2>/dev/null | grep -qE '[ 	]device$' && break
    sleep 3
  done
fi
ANDROID_SERIAL=$(adb devices 2>/dev/null | awk '/[ \t]device$/{print $1; exit}')
export ANDROID_SERIAL
[ -n "${ANDROID_SERIAL:-}" ] || { echo "HP tidak terhubung."; exit 1; }

gcam_pkg() {
  adb shell "pm list packages" </dev/null 2>/dev/null | tr -d '\r' | sed 's/^package://' \
    | grep -iE 'googlecamera|GoogleCamera|com\.google\.android\.GoogleCamera' | head -1
}

case "${1:-status}" in
  pasang)
    APK="${2:-}"
    [ -f "$APK" ] || { echo "Berkas APK tidak ditemukan: $APK"; exit 1; }
    echo "Memasang $(basename "$APK")..."
    out=$(adb install -r -g "$APK" 2>&1 | tr -d '\r')
    echo "$out" | tail -3
    echo "$out" | grep -q Success || { echo "GAGAL dipasang. Kamera bawaan TIDAK disentuh."; exit 1; }
    P=$(gcam_pkg)
    [ -n "$P" ] || { echo "Terpasang tapi nama paket tidak dikenali - cek manual."; exit 1; }
    echo "Paket: $P"
    for perm in CAMERA RECORD_AUDIO ACCESS_FINE_LOCATION READ_EXTERNAL_STORAGE WRITE_EXTERNAL_STORAGE; do
      adb shell pm grant "$P" android.permission.$perm </dev/null >/dev/null 2>&1
    done
    echo "Izin diberikan. Membuka GCam untuk diuji..."
    adb shell monkey -p "$P" -c android.intent.category.LAUNCHER 1 </dev/null >/dev/null 2>&1
    echo ""
    echo "SEKARANG UJI DI HP: buka kamera, jepret foto, cek hasilnya."
    echo "Kalau MULUS -> ./camera-setup.sh jadikan-default"
    echo "Kalau BERMASALAH -> jangan lanjut; kamera bawaan masih utuh."
    ;;

  config)
    CFG="${2:-}"
    [ -f "$CFG" ] || { echo "Berkas config tidak ditemukan: $CFG"; exit 1; }
    for d in /sdcard/LMC8.4 /sdcard/GCam/Configs7 /sdcard/GCam/Configs; do
      adb shell mkdir -p "$d" </dev/null >/dev/null 2>&1
      adb push "$CFG" "$d/" </dev/null 2>&1 | tail -1
    done
    echo "Config dikirim ke semua folder umum. Muat lewat GCam:"
    echo "  ketuk 2x area kosong di bawah tombol shutter -> pilih config -> Restore"
    ;;

  jadikan-default)
    P=$(gcam_pkg)
    [ -n "$P" ] || { echo "GCam belum terpasang. Jalankan 'pasang' dulu."; exit 1; }
    echo "GCam terdeteksi: $P"
    printf "Hapus kamera bawaan (%s)? APK tetap di sistem & bisa dibalikkan. [ketik YA]: " "$STOCK"
    read -r ans
    [ "$ans" = "YA" ] || { echo "Dibatalkan."; exit 0; }
    out=$(adb shell pm uninstall -k --user 0 "$STOCK" </dev/null 2>&1 | tr -d '\r')
    case "$out" in
      *Success*) echo "Kamera bawaan dihapus. GCam kini satu-satunya penangan intent kamera." ;;
      *USER_RESTRICTED*) echo "Dikunci Vivo - tidak bisa dihapus. GCam tetap bisa dipakai manual." ; exit 1 ;;
      *) echo "Gagal: $out"; exit 1 ;;
    esac
    echo "Penangan intent 'ambil foto' sekarang:"
    adb shell "cmd package resolve-activity -a android.media.action.IMAGE_CAPTURE" </dev/null 2>/dev/null | tr -d '\r' | grep packageName | head -1
    ;;

  balikkan)
    echo "Mengembalikan kamera bawaan..."
    adb shell cmd package install-existing "$STOCK" </dev/null 2>&1 | tr -d '\r'
    ;;

  status|*)
    echo "Kamera bawaan ($STOCK):"
    adb shell "pm list packages $STOCK" </dev/null 2>/dev/null | tr -d '\r' | grep -q . \
      && echo "  TERPASANG" || echo "  sudah dihapus"
    P=$(gcam_pkg); echo "GCam: ${P:-belum terpasang}"
    echo "Penangan intent kamera:"
    adb shell "cmd package resolve-activity -a android.media.action.IMAGE_CAPTURE" </dev/null 2>/dev/null | tr -d '\r' | grep packageName | head -1 | sed 's/^/  /'
    echo "Camera2 level (3 = LEVEL_3, terbaik):"
    adb shell "dumpsys media.camera | grep -A1 'supportedHardwareLevel' | grep -oE '\[[0-9] \]' | head -1" </dev/null 2>/dev/null | tr -d '\r' | sed 's/^/  /'
    ;;
esac
