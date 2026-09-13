#!/usr/bin/env bash
# ============================================================
#  adb-kit — toolkit debloat & optimasi Android tanpa root
#  https://github.com/  (lihat README.md)
# ============================================================
set -uo pipefail
export KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
M="$KIT_ROOT/modules"

usage() {
cat <<'USAGE'
adb-kit — debloat & optimasi Android tanpa root, lewat ADB nirkabel

  ./adb-kit.sh connect [IP:PORT KODE]   sambungkan HP (pairing bila diberi argumen)
  ./adb-kit.sh scan    [profil]         profilkan perangkat + usulkan kandidat bloat
  ./adb-kit.sh debloat [profil]         hapus bloat (yang dikunci OEM dinetralkan)
  ./adb-kit.sh debloat --with-optional  sertakan tier opsional (pilihan pribadi)
  ./adb-kit.sh tweaks  [profil]         terapkan setelan (DNS, animasi, anti-iklan)
  ./adb-kit.sh check   [profil]         periksa setelan TANPA mengubah apa pun
  ./adb-kit.sh doctor                   kesehatan sistem + deteksi regresi
  ./adb-kit.sh restore <paket...>       pulihkan paket tertentu
  ./adb-kit.sh restore --all            pulihkan semuanya
  ./adb-kit.sh restore --unmute         batalkan penetralan saja
  ./adb-kit.sh profiles                 daftar profil tersedia

ALUR PERTAMA KALI
  1. Di HP: Setelan > Sistem > Opsi pengembang > Debugging nirkabel > ON
  2. Tap "Sematkan perangkat dengan kode sematan" -> catat IP:PORT dan KODE
  3. ./adb-kit.sh connect 192.168.1.5:41234 123456
  4. ./adb-kit.sh scan
  5. ./adb-kit.sh debloat && ./adb-kit.sh tweaks

SETELAH REBOOT
  Sebagian setelan dikembalikan sistem. Jalankan:
  ./adb-kit.sh doctor     lalu   ./adb-kit.sh debloat && ./adb-kit.sh tweaks

CATATAN KESELAMATAN
  Penghapusan memakai `pm uninstall -k --user 0` — APK TETAP di partisi sistem.
  Semua bisa dipulihkan, dan factory reset mengembalikan 100% aplikasi bawaan.
  Tanpa root, tanpa unlock bootloader, garansi tidak batal.
USAGE
}

case "${1:-}" in
  connect)  shift; bash "$M/connect.sh" "$@" ;;
  scan)     shift; bash "$M/scan.sh" "$@" ;;
  debloat)  shift; bash "$M/debloat.sh" "$@" ;;
  tweaks)   shift; bash "$M/tweaks.sh" "$@" ;;
  check)    shift; bash "$M/tweaks.sh" --check "$@" ;;
  doctor)   shift; bash "$M/doctor.sh" "$@" ;;
  restore)  shift; bash "$M/restore.sh" "$@" ;;
  profiles) for p in "$KIT_ROOT"/profiles/*.conf; do
              printf '  %-22s %s\n' "$(basename "$p" .conf)" \
                "$(grep -m1 '^# brands:' "$p" | sed 's/^# brands: *//')"
            done ;;
  ""|-h|--help|help) usage ;;
  *) echo "Perintah tidak dikenal: $1"; echo; usage; exit 1 ;;
esac
