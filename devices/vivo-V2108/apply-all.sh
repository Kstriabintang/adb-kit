#!/bin/bash
# ============================================================
#  TERAPKAN ULANG SEMUA OPTIMASI - Vivo V21 (V2108)
#
#  Jalankan setelah: factory reset, update sistem, atau kapan pun
#  kamu curiga ada setelan yang balik sendiri.
#
#    ./apply-all.sh          -> terapkan semuanya
#    ./apply-all.sh cek      -> hanya periksa, tidak mengubah apa pun
# ============================================================
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:-terapkan}"

# ---------- sambung ----------
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
[ -n "${ANDROID_SERIAL:-}" ] || {
  echo "HP tidak terhubung. Nyalakan Debugging nirkabel lalu ulangi."; exit 1; }
echo "Terhubung: $ANDROID_SERIAL"
echo ""

sh() { adb shell "$@" </dev/null 2>/dev/null | tr -d '\r'; }
g()  { adb shell settings get global "$1" </dev/null 2>/dev/null | tr -d '\r'; }
gs() { adb shell settings get system "$1" </dev/null 2>/dev/null | tr -d '\r'; }
ge() { adb shell settings get secure "$1" </dev/null 2>/dev/null | tr -d '\r'; }

# ---------- 1. paket ----------
echo "== 1. Paket bawaan =="
hapus_ok=0; hapus_skip=0; netral=0
for p in $(cat "$DIR"/lists/batch-*.txt 2>/dev/null | grep -v '^$' | sort -u); do
  grep -qx "$p" "$DIR/lists/locked-neutralized.txt" 2>/dev/null && continue
  sh "pm list packages $p" | grep -qx "package:$p" || { hapus_skip=$((hapus_skip+1)); continue; }
  if [ "$MODE" = "cek" ]; then
    echo "  [cek] perlu dihapus: $p"; hapus_ok=$((hapus_ok+1)); continue
  fi
  out=$(adb shell pm uninstall -k --user 0 "$p" </dev/null 2>&1 | tr -d '\r')
  case "$out" in
    *Success*) echo "  dihapus: $p"; hapus_ok=$((hapus_ok+1)) ;;
    *) echo "  GAGAL  : $p ($(echo "$out" | head -1))" ;;
  esac
done
echo "  -> dihapus/perlu: $hapus_ok | sudah bersih: $hapus_skip"

# ---------- 2. netralkan yang dikunci ----------
echo ""
echo "== 2. Netralkan paket terkunci Vivo =="
while read -r p; do
  [ -z "$p" ] && continue
  sh "pm list packages $p" | grep -qx "package:$p" || continue
  if [ "$MODE" = "cek" ]; then
    n=$(sh "cmd appops get $p POST_NOTIFICATION" | grep -c ignore)
    [ "$n" = "1" ] || echo "  [cek] penetralan lepas: $p"
    continue
  fi
  for op in RUN_ANY_IN_BACKGROUND RUN_IN_BACKGROUND POST_NOTIFICATION WAKE_LOCK START_FOREGROUND; do
    adb shell cmd appops set "$p" $op ignore </dev/null >/dev/null 2>&1
  done
  adb shell am set-standby-bucket "$p" restricted </dev/null >/dev/null 2>&1
  u=$(sh "dumpsys package $p | grep -m1 userId=" | tr -d ' ' | sed 's/.*userId=//')
  # uid 1000 = sistem: JANGAN blacklist jaringannya (Android menolak & bisa merusak)
  if [ -n "$u" ] && [ "$u" != "1000" ]; then
    adb shell cmd netpolicy add restrict-background-blacklist "$u" </dev/null >/dev/null 2>&1
  fi
  adb shell dumpsys deviceidle whitelist "-$p" </dev/null >/dev/null 2>&1
  adb shell am force-stop "$p" </dev/null >/dev/null 2>&1
  netral=$((netral+1))
done < "$DIR/lists/locked-neutralized.txt"
[ "$MODE" = "cek" ] || echo "  -> dinetralkan: $netral"

# ---------- 3. setelan ----------
echo ""
echo "== 3. Setelan sistem =="
set_g() {  # kunci nilai label
  cur=$(g "$1")
  if [ "$cur" = "$2" ]; then echo "  ok      $3 = $2"; return; fi
  if [ "$MODE" = "cek" ]; then echo "  [cek]   $3: $cur -> seharusnya $2"; return; fi
  adb shell settings put global "$1" "$2" </dev/null >/dev/null 2>&1
  echo "  diset   $3 = $2 (sebelumnya: $cur)"
}
set_g private_dns_specifier dns.adguard-dns.com "DNS AdGuard"
set_g private_dns_mode      hostname            "DNS mode"
set_g window_animation_scale     0 "Animasi window"
set_g transition_animation_scale 0 "Animasi transisi"
set_g animator_duration_scale    0 "Animasi animator"
set_g force_hw_ui                1 "Render GPU paksa"
set_g ble_scan_always_enabled    0 "BLE scan"

set_s() {  # kunci nilai label  (namespace system)
  cur=$(gs "$1")
  if [ "$cur" = "$2" ]; then echo "  ok      $3 = $2"; return; fi
  if [ "$MODE" = "cek" ]; then echo "  [cek]   $3: $cur -> seharusnya $2"; return; fi
  adb shell settings put system "$1" "$2" </dev/null >/dev/null 2>&1
  echo "  diset   $3 = $2 (sebelumnya: $cur)"
}
# Panel Jovi Home (layar kiri) - paketnya dikunci Vivo, tapi panelnya punya saklar ini
set_s hiboard_enabled 0 "Panel Jovi Home"

set_e() {  # kunci nilai label  (namespace secure)
  cur=$(ge "$1")
  if [ "$cur" = "$2" ]; then echo "  ok      $3 = $2"; return; fi
  if [ "$MODE" = "cek" ]; then echo "  [cek]   $3: $cur -> seharusnya $2"; return; fi
  adb shell settings put secure "$1" "$2" </dev/null >/dev/null 2>&1
  echo "  diset   $3 = $2 (sebelumnya: $cur)"
}
# Iklan & rekomendasi di layar Pencarian Global + folder promosi di home screen
set_e vivo_recommended_status 0 "Rekomendasi Vivo"
set_e com_vivo_appstore_desktopfolder_desktopfoldernewappactivity_show  0 "Folder promosi app"
set_e com_vivo_appstore_desktopfolder_desktopfoldernewgameactivity_show 0 "Folder promosi game"
set_g upload_apk_enable 0 "Telemetri unggah APK"
set_g HAS_PUSH_NOTIFI_BOOT_APPSTORE 0 "Push AppStore saat boot"
set_s setting_vivo_store_enhance 0 "Peningkatan vivo Store"
set_s vivo_mood_picture_setting_enable 0 "Gambar mood layar kunci"

# JSON perlu quoting khusus agar tanda kutipnya sampai ke perangkat
APPSTORE_JSON='{"personal_recommend_switch_state":"0"}'
if [ "$(ge key_appstore_switch_state)" = "$APPSTORE_JSON" ]; then
  echo "  ok      Rekomendasi personal AppStore = mati"
elif [ "$MODE" = "cek" ]; then
  echo "  [cek]   Rekomendasi personal AppStore masih aktif"
else
  adb shell settings put secure key_appstore_switch_state "'$APPSTORE_JSON'" </dev/null >/dev/null 2>&1
  echo "  diset   Rekomendasi personal AppStore = mati"
fi

# Vivo Push tidak boleh membaca notifikasi (bank, OTP, WhatsApp, dll)
if adb shell settings get secure enabled_notification_listeners </dev/null 2>/dev/null | tr -d '\r' | grep -q vivo.pushservice; then
  if [ "$MODE" = "cek" ]; then
    echo "  [cek]   Vivo Push MASIH bisa membaca notifikasi"
  else
    adb shell "cmd notification disallow_listener com.vivo.pushservice/com.vivo.push.util.NotificationMonitor" </dev/null >/dev/null 2>&1
    echo "  diset   Akses baca-notifikasi Vivo Push dicabut"
  fi
else
  echo "  ok      Vivo Push tidak bisa baca notifikasi"
fi

# Pencarian Global tidak butuh izin sensitif (dipakai untuk iklan bertarget)
if [ "$MODE" != "cek" ]; then
  for perm in ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION ACCESS_BACKGROUND_LOCATION \
              READ_CONTACTS READ_PHONE_STATE READ_CALENDAR RECORD_AUDIO CAMERA; do
    adb shell pm revoke com.vivo.globalsearch android.permission.$perm </dev/null >/dev/null 2>&1
  done
  echo "  diset   Izin sensitif Pencarian Global dicabut"
fi

# CATATAN: feed berita di layar Pencarian Global dimatikan lewat tombol tersembunyi
# di dalam APLIKASI (disimpan di mmkv-nya sendiri, bukan di Android settings),
# sehingga TIDAK bisa dipulihkan otomatis oleh skrip ini.
if [ "$MODE" != "cek" ]; then
  echo ""
  echo "  !! LANGKAH MANUAL: kalau feed berita muncul lagi di layar pencarian"
  echo "     (geser-bawah dari home screen), ketuk tombol tersembunyi di"
  echo "     POJOK KANAN BAWAH layar itu untuk mematikan konten."
fi

d=$(sh "wm density" | grep -o 'Override density: [0-9]*' | grep -o '[0-9]*')
if [ "${d:-}" = "420" ]; then echo "  ok      Density = 420"
elif [ "$MODE" = "cek" ]; then echo "  [cek]   Density: ${d:-440} -> seharusnya 420"
else adb shell wm density 420 </dev/null >/dev/null 2>&1; echo "  diset   Density = 420"; fi

nb=$(sh "cmd overlay list android | grep '\[x\].*navbar'")
case "$nb" in
  *gestural_wide_back*) echo "  ok      Gesture back = lebar" ;;
  *) if [ "$MODE" = "cek" ]; then echo "  [cek]   Gesture back belum lebar"
     else adb shell "cmd overlay enable-exclusive com.android.internal.systemui.navbar.gestural_wide_back" </dev/null >/dev/null 2>&1
          echo "  diset   Gesture back = lebar"; fi ;;
esac

# ---------- 4. batasi latar app ringan ----------
echo ""
echo "== 4. Pembatasan latar belakang =="
for p in com.google.android.apps.wellbeing com.google.android.apps.nbu.files; do
  sh "pm list packages $p" | grep -qx "package:$p" || continue
  if [ "$MODE" = "cek" ]; then
    n=$(sh "cmd appops get $p RUN_ANY_IN_BACKGROUND" | grep -c ignore)
    [ "$n" = "1" ] && echo "  ok      $p" || echo "  [cek]   belum dibatasi: $p"
    continue
  fi
  for op in RUN_ANY_IN_BACKGROUND RUN_IN_BACKGROUND WAKE_LOCK; do
    adb shell cmd appops set "$p" $op ignore </dev/null >/dev/null 2>&1
  done
  adb shell am set-standby-bucket "$p" restricted </dev/null >/dev/null 2>&1
  echo "  dibatasi $p"
done

# ---------- ringkasan ----------
echo ""
echo "== Ringkasan =="
echo "  Paket aktif : $(sh 'pm list packages' | wc -l | tr -d ' ')"
echo "  DNS         : $(g private_dns_specifier)"
echo "  Animasi     : $(g window_animation_scale)"
echo "  Density     : $(sh 'wm density' | grep -o 'Override.*')"
[ "$MODE" = "cek" ] && echo "" && echo "(mode CEK - tidak ada yang diubah. Jalankan tanpa argumen untuk menerapkan.)"
