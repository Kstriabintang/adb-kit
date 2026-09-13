# Debloat Vivo V21 (V2108) — Funtouch OS / Android 12

Tanggal: 2026-09-12 · Metode: ADB wireless, **tanpa root**, sepenuhnya reversibel.

## Hasil

| | Jumlah |
|---|---|
| Paket aktif sebelum | 327 |
| Paket aktif sesudah | 291 |
| **Dihapus** (`pm uninstall -k --user 0`) | **36** |
| **Dinetralkan** (dikunci Vivo, tak bisa dihapus) | **12** |
| Total ditangani | 48 |

## Cara kerja

**Dihapus** — `pm uninstall -k --user 0` menghapus app untuk user 0. APK tetap ada di
partisi sistem (read-only), jadi bisa dipulihkan kapan saja dan factory reset
mengembalikan semuanya. Tidak membatalkan garansi.

**Dinetralkan** — 12 paket diproteksi Funtouch (`DELETE_FAILED_USER_RESTRICTED`,
`pm suspend`/`disable-user` juga ditolak: *"no root permission"*). Untuk ini dipakai
kombinasi yang efeknya setara untuk menghentikan iklan:

- `appops POST_NOTIFICATION ignore` → tidak bisa kirim notifikasi (sumber iklan utama)
- `appops RUN_IN_BACKGROUND / RUN_ANY_IN_BACKGROUND ignore` → tidak jalan di latar
- `appops WAKE_LOCK / START_FOREGROUND ignore` → tidak bisa membangunkan HP
- `am set-standby-bucket restricted` → dibekukan penjadwal sistem
- `netpolicy restrict-background-blacklist` → data latar diblokir (iklan butuh internet)
- `deviceidle whitelist -<pkg>` → dikeluarkan dari pengecualian hemat baterai

## Yang dihapus (36)

**Sumber iklan Vivo:** browser · game · gamecube · gamewatch · magazine (iklan layar
kunci) · Tips · feedback
**Tracker pihak ketiga:** facebook.appmanager · facebook.services · facebook.system ·
netflix.mediaclient · netflix.partner.activation · baidu.map.location
**Alat engineering/log:** iqoo.engineermode · bsptest · engineercamera ·
fingerprintengineer · wifiengineermode · iqoo.logsystem · bbklog · qti.diagservices ·
qualcomm.qti.modemtestmode
**App jarang dipakai:** FMRadio · easyshare · ewarranty · compass · upnpserver ·
tws.vivotws · desktopstickers · livewallpaper.floatingcloud · livewallpaper.plant ·
widget.cleanspeed · musicwidgetmix · yozo.vivo.office · unionpay · bbk.account

## Yang dinetralkan (12, dikunci Vivo)

appstore · hiboard · assistant (Jovi) · pushservice · website · globalsearch ·
bbkmusic · bbk.cloud · videoeditor · doubleinstance · bbk.theme · imanager

> `com.vivo.assistant` dan `com.vivo.doubleinstance` berjalan dengan **uid 1000 (sistem)**
> sehingga tidak bisa diblokir jaringannya — Android menolaknya demi keamanan sistem.
> Notifikasi & eksekusi latar keduanya tetap berhasil diblokir.

## Sengaja TIDAK disentuh

Komponen inti Funtouch: `abe` `pem` `daemonService` `seclient` `sps` `funtouch.uiengine`
`bbk.lockscreen3` `faceui` `fingerprintui` `goodix` (sensor sidik jari) `epm` `aiengine`
`vivo3rdalgoservice` `share` `smartshot` `audiofx` `upslide` · **`bbk.updater`** (update
keamanan tetap jalan) · seluruh stack Qualcomm/radio · **seluruh aplikasi Google** ·
app utilitas Vivo yang dipakai: Galeri, Catatan, Cuaca, Perekam Suara, Kalkulator, Scanner.

## Memulihkan

```bash
./restore.sh                    # kembalikan semuanya
./restore.sh com.vivo.browser   # kembalikan satu app
./restore.sh --unmute           # hanya batalkan penetralan 12 paket
```

Kalau HP tidak terhubung:
```bash
adb pair <IP>:<PORT-PAIRING> <KODE-6-DIGIT>
adb connect <IP>:<PORT-KONEKSI>
```

Jalur paling aman kalau terjadi apa-apa: **factory reset** mengembalikan 100% app bawaan.

## File

- `lists/batch-a.txt`, `batch-b.txt`, `batch-c.txt` — daftar yang dihapus
- `lists/locked-neutralized.txt` — 12 paket yang dinetralkan
- `backup/` — snapshot daftar paket sebelum & sesudah
- `restore.sh` — skrip pemulihan

## Verifikasi setelah reboot (2026-09-12 20:10)

| Cek | Hasil |
|---|---|
| Boot | ✅ `sys.boot_completed=1`, normal |
| SystemUI / Launcher / Telepon | ✅ jalan |
| `com.vivo.abe`, `com.vivo.pem` | ✅ jalan |
| Sinyal & data seluler | ✅ `IN_SERVICE`, ping 8.8.8.8 → 0% loss |
| Kamera | ✅ 5 sensor terdeteksi |
| Sidik jari (UDFPS) | ✅ `Fingerprint21`, 0 HAL death |
| Wajah (`com.vivo.faceui`) | ✅ utuh |
| FATAL / ANR / ClassNotFound sejak boot | ✅ nol |
| Error terkait paket terhapus | ✅ nol |
| Notifikasi app pengguna (Telegram, IG, Outlook, GMS) | ✅ tidak terpengaruh |
| Penetralan 12 paket | ✅ bertahan (notif mati, latar diblokir, 10 UID data diblokir) |

**Catatan:** `com.google.android.photopicker` dan `com.google.android.signature` muncul
setelah reboot, `com.google.android.nearby.halfsheet` diganti — ini update modul
Google Play system, bukan efek debloat.

**Port ADB nirkabel berubah setiap reboot.** `restore.sh` mendeteksi HP otomatis via
mDNS, jadi tidak perlu tahu portnya. Pairing tersimpan permanen — kode 6 digit hanya
diperlukan sekali.

---

# Tahap 2 — Optimasi jaringan & sisa bloat (2026-09-12)

## Private DNS: AdGuard (DNS-over-TLS)

```
private_dns_mode      = hostname
private_dns_specifier = dns.adguard-dns.com
```

Memblokir iklan & tracker di **level jaringan**, jadi berlaku untuk SEMUA aplikasi —
termasuk 16 paket Vivo terkunci yang tak bisa dihapus. Lalu lintas DNS juga terenkripsi,
sehingga ISP tidak bisa melihat domain yang dikunjungi.

### Latensi terukur dari jaringan ini

| Resolver | Blokir iklan | Latensi |
|---|---|---|
| Cloudflare 1.1.1.1 | ❌ | 21 ms |
| Google 8.8.8.8 | ❌ | 27 ms |
| **AdGuard (dipakai)** | ✅ | **46 ms** |
| ControlD | ✅ | 49 ms |
| Quad9 | malware saja | 78 ms |

AdGuard 25 ms lebih lambat per lookup domain baru (hasilnya di-cache), tetapi setiap
domain iklan yang diblokir membatalkan satu koneksi HTTP penuh (~100–500 ms + kuota).
Secara total, memuat halaman jadi **lebih cepat**, bukan lebih lambat.

### Hasil uji pemblokiran

| Domain | Status |
|---|---|
| doubleclick.net | ✅ diblokir (127.0.0.1) |
| googleadservices.com | ✅ diblokir |
| analytics.google.com | ✅ diblokir |
| googlesyndication.com | ⚠️ lolos — filter default AdGuard sengaja tidak memblokirnya (dipakai untuk konten sah juga) |
| google.com, instagram.com | ✅ normal |

**Telegram diperiksa khusus:** `telegram.org` tidak menjawab ping, tetapi itu karena
server Telegram memfilter ICMP — resolve ke IP asli (149.154.167.99) dan TCP 443
tersambung normal. Bukan efek DNS.

## Tweak yang diterapkan

| Setelan | Dari | Jadi |
|---|---|---|
| `window/transition/animator_animation_scale` | 1.0 | **0.5** (UI lebih gesit) |
| `ble_scan_always_enabled` | 1 | **0** (stop scanning BLE, hemat baterai) |
| `wifi_scan_always_enabled` | 1 | 1 *(sengaja dibiarkan sesuai pilihan)* |
| `network_recommendations_enabled` | 1 | 1 — **gagal diubah**, dikembalikan otomatis oleh sistem/GMS |

## Bloat tahap 2 (15 paket)

**Dihapus (11):** wapicertmanage (standar WiFi Tiongkok, tak berguna di Indonesia) ·
gsma.rcs · qti.confuridialer · vivo.carrierlocation · gms.location.history ·
partnersetup · printservice.recommendation · ar.lens · projection.gearhead (Android Auto) ·
apps.tachyon (Meet) · vivo.floatingball

**Dikunci Vivo → dinetralkan (4):** ringclip · nightpearl (AOD) · SmartKey · minscreen

> `com.vivo.carrierlocation` = layanan lokasi operator Vivo. Lokasi darurat Android
> memakai Google ELS (di GMS, tidak disentuh), jadi panggilan darurat tetap aman.
> Kembalikan dengan `./restore.sh com.vivo.carrierlocation` bila perlu.

## Ringkasan total

| | Jumlah |
|---|---|
| Paket aktif awal | 327 |
| Paket aktif sekarang | **281** |
| Dihapus | 47 |
| Dinetralkan (dikunci Vivo) | 16 |

## Skrip `network.sh`

```bash
./network.sh status     # lihat setelan sekarang
./network.sh adguard    # DNS pemblokir iklan (aktif sekarang)
./network.sh fast       # Cloudflare 1.1.1.1 - tercepat, tanpa blokir iklan
./network.sh off        # matikan Private DNS
./network.sh test       # uji apakah iklan benar diblokir
./network.sh anim 1.0   # kembalikan animasi normal
```

Kalau ada situs/aplikasi bermasalah setelah DNS aktif: `./network.sh off` — langsung normal.

---

# Tahap 3 — Performa & sisa aplikasi (2026-09-12)

## 120 fps: TIDAK MUNGKIN di HP ini

Panel V2108 maksimal **60 Hz secara fisik**. Bukti langsung dari perangkat:

```
persist.vivo.phone.fps_max   = 60
persist.vivo.phone.panel_type = Amoled
SurfaceFlinger: hanya SATU mode -> {id=0, fps=61.00, 1080x2400}
```

Tidak ada mode 90 Hz maupun 120 Hz di `mSfDisplayModes`. Ini batas hardware — tidak bisa
diubah oleh setelan, root, maupun custom ROM. Klaim "unlock 120fps" untuk perangkat ini
tidak valid.

## Penyebab scroll terasa lelet — hasil pengukuran

Diagnosis awal (kumulatif sejak boot) menunjukkan SystemUI 23,5% janky. Tetapi uji
terkontrol (15 swipe otomatis identik, `dumpsys gfxinfo`) memberi gambaran sebenarnya:

| Metrik | Animasi 0.5 | **Animasi 0** | Perubahan |
|---|---|---|---|
| Janky frames | 0,27% | **0,00%** | hilang |
| Frame time 90th | 18 ms | **12 ms** | **−33%** |
| Frame time 95th | 18 ms | **13 ms** | −28% |
| Frame time 99th | 19 ms | **14 ms** | −26% |
| Missed Vsync | 0 | 0 | — |
| Slow UI thread | 0 | 0 | — |

Anggaran frame 60 Hz adalah 16,7 ms. Sebelumnya 18 ms → **setiap frame telat tipis**,
itulah sumber rasa lelet. Sekarang 12 ms → nyaman di dalam anggaran.

Setelan yang diterapkan: `window/transition/animator_animation_scale = 0`,
`force_hw_ui = 1`.

Sistem terbukti **tidak** kekurangan tenaga: tanpa thermal throttling, tanpa mode hemat
daya, governor `schedutil`, CPU 582%/800% idle, RAM 3,4 GB dari 7,5 GB, wallpaper statis,
tanpa layanan aksesibilitas.

> **Catatan kejujuran metrik:** angka "Number High input latency" tinggi (596) pada uji ini
> tidak bisa dipercaya, karena swipe disuntikkan lewat `adb input` sehingga stempel waktu
> event berbeda dari sentuhan asli. Metrik yang valid adalah janky frames, percentile,
> missed vsync, dan slow UI thread — semuanya bersih.

**Tidak ada setelan sensitivitas sentuh lain** yang bisa diubah via ADB di model ini —
Vivo tidak mengeksposnya (`bbk_smart_touch_setting=0`, tak ada knob touch sample rate).

## Aplikasi tahap 3

| Aplikasi | Status |
|---|---|
| Cuaca (`com.vivo.weather`, `widgetweather`) | ✅ dihapus |
| `com.vivo.weather.provider` | 🔒 dikunci Vivo — hanya penyedia data, tak berguna tanpa app-nya |
| Podcast Google | ✅ dihapus |
| Games (`com.vivo.game`) | ✅ sudah dihapus di tahap 1 |
| Umpan balik (`com.vivo.feedback`) | ✅ sudah dihapus di tahap 1 |
| Vivo Space | ✅ tidak pernah ada di HP ini |
| **V-AppStore (`com.vivo.appstore`)** | ❌ **tidak bisa dihapus** — dikunci Funtouch, hanya bisa dinetralkan |

> **Penting:** aplikasi yang "dinetralkan" **tetap terlihat ikonnya** di laci aplikasi,
> karena tidak benar-benar di-uninstall. Yang hilang adalah kemampuannya: tak bisa kirim
> notifikasi, tak bisa jalan di latar, tak dapat data latar. Menyembunyikan ikonnya
> butuh root (`pm hide`), yang tidak tersedia.

## Mengembalikan animasi

```bash
./network.sh anim 0.5   # sedang (ada animasi, tetap cepat)
./network.sh anim 1.0   # bawaan Android
./network.sh anim 0     # instan (aktif sekarang)
```

---

# Tahap 4 — Audit baterai, jaringan & izin (2026-09-12)

## Mode jaringan: usulan DIBATALKAN setelah diselidiki

Temuan awal: `preferred_network_mode = 33,33` (mode yang menyertakan pencarian 5G/NR),
padahal SoC-nya **Snapdragon 730G** (`ro.board.platform=atoll`) yang **4G-only**.

Penyelidikan lebih lanjut membatalkan usulan ini:

- Kunci yang **benar-benar aktif** adalah `preferred_network_mode1 = 20`
  (LTE/TDSCDMA/GSM/WCDMA) — **sudah tanpa NR**. Yang `33,33` hanya template default.
- Firmware tidak memuat dukungan NR sama sekali (`nrState`/`nr_config` kosong).

**Kesimpulan: tidak ada yang perlu diubah.** Mengubahnya hanya kosmetik dengan risiko
data seluler putus. Setelan tidak disentuh.

## Analisis baterai

| Sumber | mAh | Catatan |
|---|---|---|
| **mobile_radio** | **249** | pemboros #1, di atas layar |
| screen | 179 | 1j 0m layar menyala |
| cpu | 80,5 | |
| UID -5 (cell standby) | 154 | **tidak terkait aplikasi** |

Pemakai per aplikasi:

| UID | mAh | Aplikasi |
|---|---|---|
| 10238 | 85,4 (radio 52,5) | **org.telegram.messenger** |
| 10148 | 87,2 (layar) | com.android.launcher3 |
| 10250 | 41,1 (layar) | com.termux |
| 10230 | 21,9 (kamera) | coaltrack |
| 10165 | 14,9 | com.google.android.gms |

**Penilaian jujur:** 154 mAh dari radio adalah *cell standby* — biaya tetap menjaga HP
terdaftar di jaringan <operator> selama 1j45m. Itu **normal, bukan kerusakan**. Telegram
52,5 mAh radio adalah harga wajar koneksi standby aplikasi chat; membatasinya membuat
pesan telat. Keduanya **bukan masalah yang bisa "diperbaiki"**.

Kondisi lain semuanya sehat: penyimpanan 22 GB / 107 GB (sisa 85 GB), RAM 3,4 dari
7,5 GB, tanpa thermal throttling, governor `schedutil`, SIM slot 2 kosong
(`gsm.sim.state = LOADED,ABSENT`).

## Audit izin — 22 aplikasi pihak-ketiga

| Aplikasi | Izin sensitif |
|---|---|
| org.telegram.messenger | Kamera, Kontak, Status telepon, **Log panggilan** |
| coaltrack *(app sendiri)* | Lokasi presisi, Kamera |
| com.axis.net *(operator XL)* | Lokasi presisi, Status telepon |
| com.twofasapp | Kamera *(scan QR)* |
| com.midi.siminfo | Status telepon |
| com.microsoft.emmx | Lokasi presisi |
| com.instagram.android | Kamera |
| com.anthropic.claude | Mikrofon |

**Hasil: bersih.** Tidak ada app dengan **lokasi latar belakang**, tidak ada yang bisa
membaca **SMS**. `app.source.getcontact` — aplikasi caller-ID yang biasanya rakus izin —
memegang **nol** izin sensitif. Satu-satunya yang tidak lazim: Telegram memegang izin
log panggilan.

## Pembersihan tahap 4

Dihapus (4): `doubletimezoneclock` · `timerwidget` · `widget.gallery` · `video.floating`
Dinetralkan (1): `weather.provider` (dikunci Vivo)

## Status akhir

| | |
|---|---|
| Paket aktif | **274** (dari 327 awal) |
| Dihapus | 54 |
| Dinetralkan | 17 |
| Crash | 0 |
| Private DNS | AdGuard aktif |
| Animasi | 0 (frame 12 ms) |

> **Catatan:** skala animasi pernah kembali sendiri ke 1.0 tanpa reboot — kemungkinan
> direset mode performa/baterai Vivo. Kalau scroll terasa melambat lagi, cek dengan
> `./network.sh status` dan set ulang `./network.sh anim 0`.

---

# Tahap 5 — Design system, wallpaper & kamera (2026-09-12)

## Design system yang diterapkan

| Aspek | Dari | Jadi |
|---|---|---|
| Gaya tema Material You | TONAL_SPOT | **MONOCHROMATIC** |
| Warna aksen | `#1A73E8` (biru Google) | **`#8A8A8A`** (netral) |
| Kepadatan layar | 440 dpi | **420 dpi** |
| Font sistem | sans-serif | **Noto Serif** |
| Area gesture back | `gestural` | **`gestural_wide_back`** |
| Dark mode | — | sudah aktif ✅ |

Pilihan monokrom bukan sekadar selera: di panel **AMOLED**, piksel hitam benar-benar
**mati** (tidak menyala), jadi palet gelap-netral menghemat baterai secara nyata —
sejalan dengan tujuan "ringan & clean".

### Catatan teknis: font harus lewat JSON tema

Mengaktifkan font dengan `cmd overlay enable com.android.theme.font.notoserifsource`
**tidak bertahan** — perubahan `theme_customization_overlay_packages` menimpanya kembali
ke `[ ]`. Cara yang benar adalah menyertakan font di dalam JSON tema itu sendiri:

```json
{"android.theme.customization.font":"com.android.theme.font.notoserifsource",
 "android.theme.customization.theme_style":"MONOCHROMATIC",
 "android.theme.customization.accent_color":"8A8A8A", ...}
```

Diverifikasi stabil setelah 15 detik.

## Wallpaper — dibuat khusus, bukan diunduh

`cmd wallpaper` di Android 12 menjawab *"No shell command implementation"*, jadi wallpaper
**tidak bisa dipasang lewat ADB**. Yang dilakukan: 4 wallpaper dibuat dari nol dengan
penulis PNG **stdlib Python murni** (tanpa PIL/numpy — keduanya tidak tersedia),
grayscale 8-bit, 1080×2400, lalu dikirim ke `/sdcard/Pictures/Wallpapers/`.

| Nama | Ukuran | Desain |
|---|---|---|
| `amoled-void.png` | 71 KB | cahaya radial sangat halus di hitam murni |
| `amoled-horizon.png` | 48 KB | pita gradien lembut di bawah layar |
| `amoled-contour.png` | 82 KB | cincin topografi tipis |
| `amoled-dotgrid.png` | 3 KB | kisi titik halus yang memudar |

Versi pertama mengalami **banding** (cincin tangga pada gradien) — khas gradien halus di
8-bit. Diperbaiki dengan **dithering matriks Bayer 8×8** sebelum kuantisasi.

**Pasang:** Galeri → pilih wallpaper → ⋮ → *Setel sebagai wallpaper*.

## Kamera — GCam/LMC

### Perangkatmu SANGAT cocok

Kelima kamera melaporkan `android.info.supportedHardwareLevel = 3` yaitu
**Camera2 API LEVEL_3** — tingkat tertinggi. Kapabilitas: `RAW`, `MANUAL_SENSOR`,
`BURST_CAPTURE`, `MANUAL_POST_PROCESSING`, `YUV_REPROCESSING`, `PRIVATE_REPROCESSING`.

Banyak Vivo terkunci di LEGACY dan GCam gagal total di sana. **Punyamu tidak.**

Sensor: 4608×3456 (utama) · 3984×2740 · 3264×2448 · 1600×1200 · 4608×3456 (depan).

### Yang TIDAK bisa dilakukan dari sini

APK GCam/LMC tidak ada di Play Store — distribusinya lewat Google Drive/forum/Telegram
yang **tidak bisa diverifikasi keasliannya**. Memasang biner tak terverifikasi yang
meminta izin kamera + mikrofon + penyimpanan adalah risiko nyata, jadi APK-nya **harus
kamu unduh sendiri** dari sumber yang kamu percaya.

> Catatan: **Google Photos adalah galeri, bukan kamera** — sudah terpasang
> (`com.google.android.apps.photos`). Aplikasi kameranya bernama **Google Camera (GCam)**;
> **LMC 8.4** adalah mod dari GCam.

### Urutan aman (dipaksakan oleh skrip)

```bash
./camera-setup.sh status                 # cek kondisi
./camera-setup.sh pasang ~/Downloads/LMC_8.4.apk
#   -> pasang + beri 5 izin + buka otomatis untuk diuji
#   -> UJI JEPRET DI HP DULU
./camera-setup.sh config ~/Downloads/config.xml   # opsional, kirim config LMC
./camera-setup.sh jadikan-default        # baru hapus kamera bawaan (minta ketik "YA")
./camera-setup.sh balikkan               # kembalikan kamera bawaan kapan saja
```

Kamera bawaan **sengaja dihapus paling akhir**. Kalau dihapus lebih dulu dan GCam
bermasalah, perangkat tidak punya kamera sama sekali. Skrip menolak menghapus bawaan
sebelum GCam terdeteksi terpasang.

Setelah bawaan dihapus, GCam menjadi **satu-satunya** penangan
`android.media.action.IMAGE_CAPTURE` — sehingga otomatis jadi default untuk semua
aplikasi lain. Itulah cara "menjadikan default" tanpa root.

---

# Tahap 6 — Koreksi font & tema (2026-09-12)

## Font Noto Serif dibatalkan

Diterapkan di tahap 5, dinilai jelek oleh pengguna, **dikembalikan ke sans-serif bawaan**.
Verifikasi: `[ ] com.android.theme.font.notoserifsource`.

Catatan: ini memang satu-satunya alternatif font di ROM ini, dan sudah diperingatkan di
muka bahwa font berkait umumnya kurang cocok untuk UI ponsel. Mengganti tipografi sistem
ke font lain **butuh root**.

## Tema MONOCHROMATIC: diterima sistem, diabaikan Funtouch

Pengguna melaporkan tema tidak terlihat berubah. **Benar.** Pembuktian:

- Setelan tersimpan: `theme_style = MONOCHROMATIC`, `accent_color = 8A8A8A`
- Overlay Monet aktif: `[x] com.android.systemui:accent`, `[x] com.android.systemui:neutral`
- Screenshot layar kunci: warna aksen sistem **tidak berubah**

**Sebabnya:** Funtouch OS memakai mesin tema Vivo sendiri (`com.funtouch.uiengine`,
`com.bbk.theme`), bukan Material You AOSP. Framework menerima dan menerapkan overlay,
tetapi SystemUI Vivo tidak membacanya. Ini **batas ROM**, bukan kesalahan setelan, dan
tidak bisa ditembus tanpa root.

### Yang BISA mengubah tampilan di Funtouch

| Cara | Status |
|---|---|
| Dark mode | ✅ sudah aktif (terbukti di screenshot: kartu notifikasi gelap) |
| Kepadatan layar 420 dpi | ✅ aktif |
| Wallpaper | ⏳ 4 file sudah di HP, **belum dipasang pengguna** |
| **Vivo i Theme** (`com.bbk.theme`) | ✅ **masih bisa dibuka** — diverifikasi `mFocusedApp=com.bbk.theme/.Theme` |

> Penetralan tahap 1 hanya memblokir **notifikasi & eksekusi latar** paket terkunci.
> Aplikasinya tetap berfungsi penuh saat dibuka manual. Jadi i Theme — mesin tema asli
> Funtouch — tetap bisa dipakai untuk mengganti tema, ikon, dan font ala Vivo.

## Iklan yang lolos: web push, bukan aplikasi

Screenshot menangkap notifikasi *"MyLowe's Rewards — Save $10 for your home this fall"*
dari Microsoft Edge. Pemeriksaan `dumpsys notification` menunjukkan
`tag=p#https://outlook.live.com` — ini **web push dari situs**, bukan iklan aplikasi
Edge, jadi tidak tertangkap pemblokiran DNS maupun appops.

`cmd notification` tidak menyediakan perintah blokir per-kanal, sehingga **tidak bisa
diblokir lewat ADB**. Perbaikannya di HP:

> **Edge → ⋯ → Setelan → Izin situs → Notifikasi → blokir `outlook.live.com`**

## Pembatasan latar tambahan

`com.google.android.apps.wellbeing` (Digital Wellbeing) dan
`com.google.android.apps.nbu.files` (Files by Google) terdeteksi jalan di latar tanpa
kebutuhan nyata → `RUN_IN_BACKGROUND`/`RUN_ANY_IN_BACKGROUND`/`WAKE_LOCK` = ignore,
standby bucket = restricted. Tidak dihapus, hanya dibatasi.

## Penilaian jujur: sisa ruang optimasi sudah tipis

| Aspek | Kondisi |
|---|---|
| RAM | 7,7 GB total, **5,0 GB tersedia** — bukan hambatan |
| Paket | 274 (dari 327) |
| Animasi | 0 — frame 12 ms, jank 0% |
| DNS | AdGuard aktif |
| Thermal / hemat daya | tidak ada throttling |

**Membatasi jumlah proses latar sengaja TIDAK dilakukan** — dengan 5 GB RAM bebas, itu
justru merugikan (aplikasi terus dimuat ulang) tanpa manfaat.

---

# Tahap 7 — Ketahanan: restart vs factory reset (2026-09-12)

## Apa yang bertahan setelah RESTART?

Diverifikasi langsung (HP sudah reboot di tengah sesi):

| Hal | Bertahan? |
|---|---|
| 54 paket yang dihapus | ✅ **semua tetap hilang, 0 kembali** |
| Penetralan 15 dari 17 paket terkunci | ✅ bertahan |
| `com.vivo.assistant`, `com.vivo.doubleinstance` | ⚠️ **lepas** — keduanya uid 1000 (sistem), Android mereset appops-nya |
| Private DNS, `force_hw_ui`, `ble_scan` | ✅ bertahan |
| Skala animasi | ⚠️ pernah balik ke 1.0 sekali |

## Apa yang terjadi setelah FACTORY RESET?

**Semuanya kembali, 100%.** Ini konsekuensi langsung dari metode yang dipakai:
`pm uninstall -k --user 0` **tidak pernah menghapus APK** dari partisi sistem —
hanya mencabutnya untuk user 0. Factory reset membuat user 0 baru, sehingga seluruh
54 paket muncul lagi.

Itu justru **sifat pengamannya** (tanpa root, tanpa batal garansi, selalu bisa dipulihkan),
tetapi berarti perlu cara cepat menerapkan ulang.

> Setelah factory reset, **pairing ADB juga hilang** — perlu pairing ulang dengan kode
> 6 digit baru dari Opsi pengembang sebelum skrip bisa dipakai.

## `apply-all.sh` — terapkan ulang semuanya

```bash
./apply-all.sh cek      # hanya periksa, TIDAK mengubah apa pun
./apply-all.sh          # terapkan semuanya
```

Menerapkan ulang seluruh hasil sesi ini dalam satu perintah:

1. Hapus 54 paket (melewati yang sudah bersih)
2. Netralkan 17 paket terkunci Vivo (appops, standby bucket, netpolicy, deviceidle)
3. Setelan: DNS AdGuard, animasi 0, `force_hw_ui`, BLE scan off, density 420, gesture back lebar
4. Batasi latar: Digital Wellbeing, Files by Google

Skrip bersifat **idempoten** — aman dijalankan berkali-kali, hanya mengubah yang belum sesuai.

### Pengaman yang ditanam di skrip

Paket ber-**uid 1000 (sistem)** sengaja **dilewati** saat `netpolicy add
restrict-background-blacklist`. Pada tahap 1, mencoba mem-blacklist uid 1000 akan
memblokir data latar seluruh sistem — Android menolaknya demi keamanan, tetapi
skrip tetap tidak boleh mencobanya.

### Hasil uji mode cek

```
== 1. Paket bawaan ==      -> dihapus/perlu: 0 | sudah bersih: 54
== 2. Netralkan ==         (semua utuh)
== 3. Setelan sistem ==    9/9 ok
== 4. Pembatasan latar ==  2/2 ok
Paket aktif : 274
```

## Temuan keamanan

| | |
|---|---|
| Patch keamanan | **2023-10-01** — ~3 tahun tertinggal |
| Base build | `SP1A.210812.003` (Android 12, Agustus 2021) |
| Enkripsi | ✅ `encrypted` |
| Play Protect | ✅ aktif |
| Sumber tak dikenal | ⚠️ diizinkan (`install_non_market_apps=1`) |
| Debugging nirkabel | ⚠️ **menyala** (`adb_wifi_enabled=1`) |

Vivo sudah berhenti mengirim update keamanan untuk perangkat ini. Tidak bisa diperbaiki,
hanya dimitigasi: Play Protect aktif, DNS pemblokir aktif, dan **matikan debugging
nirkabel setelah selesai** — port ADB terbuka di jaringan adalah permukaan serangan nyata,
apalagi di perangkat yang tidak lagi ditambal.

## Kesehatan baterai

```
health      : GOOD
kapasitas   : 3924 mAh (desain 4000 mAh)
suhu        : 32,0 °C   voltase: 4041 mV
```

Bagus untuk perangkat 2021. *Cycle count* tidak terbaca tanpa root, jadi persentase
degradasi presisi tidak bisa dipastikan.

---

# Tahap 8 — Bedah penyimpanan (2026-09-12)

## Rincian 22 GB

| Kategori | Ukuran |
|---|---|
| App (APK) | 6,44 GB |
| Data aplikasi | 7,27 GB |
| **Cache** | **1,30 GB** |
| Foto | 26 MB |
| Video / Audio / Download | 0 |

`/sdcard` hanya berisi ~220 MB (Android 158 MB, Download 44 MB, DCIM 12 MB) —
jadi hampir seluruh pemakaian ada di `/data`, yang tidak terbaca per-folder tanpa root.
Dipakai `dumpsys diskstats` sebagai gantinya.

### 10 pemakai terbesar

| Aplikasi | Total | APK | Data |
|---|---|---|---|
| com.termux | 3,22 GB | 70 MB | **3,15 GB** |
| com.zhiliaoapp.musically (TikTok) | 1,86 GB | 789 MB | 1,09 GB |
| com.google.android.gms | 753 MB | 305 MB | 448 MB |
| com.google.android.apps.photos | 751 MB | 231 MB | 520 MB |
| com.android.chrome | 591 MB | 235 MB | 355 MB |
| com.instagram.android | 522 MB | 398 MB | 124 MB |
| com.microsoft.emmx | 450 MB | 332 MB | 118 MB |
| com.bbk.theme | 353 MB | 94 MB | 260 MB |
| com.android.vending | 324 MB | 156 MB | 167 MB |
| app.source.getcontact | 265 MB | 265 MB | 0 |

## Cache dibersihkan: 1,43 GB

`pm trim-caches 128G` — aman, hanya membuang berkas sementara, **tidak** menghapus
data atau sesi login.

| | Sebelum | Sesudah |
|---|---|---|
| Data-Free | 89.163.244 K | **90.660.320 K** |
| `df` terpakai | 22 G | **21 G** |
| `df` tersedia | 85 G | **86 G** |

> Catatan metrik: `App Cache Size` di `dumpsys diskstats` **tetap** menampilkan
> 1.297.413.120 setelah pembersihan — angka itu statistik yang dihitung berkala, bukan
> real-time. Ukuran yang valid adalah `Data-Free` / `df`, dan keduanya naik ~1,43 GB.

## Penilaian: penyimpanan bukan masalah

86 GB kosong dari 107 GB (20% terpakai). Pemakai terbesar adalah **Termux 3,22 GB** —
itu paket yang dipasang pengguna sendiri di dalam Termux, bukan sampah. TikTok 1,86 GB
wajar untuk aplikasi video.

APK dari 54 paket yang dihapus **tidak** memakan ruang `/data` — APK-nya berada di
partisi sistem read-only, dan itulah sebabnya semuanya bisa dipulihkan kapan saja.

**Tidak ada lagi yang layak dikorek di penyimpanan.**

---

# Tahap 9 — Mematikan panel Jovi Home (2026-09-13)

## Masalah

Panel **Jovi Home** (layar geser-kiri) menampilkan rekomendasi konten: video YouTube,
"Popular Today", kartu saran. Paketnya `com.vivo.hiboard` sudah dinetralkan di tahap 1
(notifikasi + latar belakang diblokir), tetapi **panelnya tetap muncul** karena Vivo
mengunci paket ini dari penghapusan:

```
pm uninstall -k --user 0 com.vivo.hiboard
  -> Failure [DELETE_FAILED_USER_RESTRICTED]   (dicoba ulang, tetap ditolak)
```

## Solusi: saklar tersembunyi di namespace `system`

Penelusuran `settings list system` menemukan kuncinya:

```bash
settings put system hiboard_enabled 0
```

Diverifikasi stabil di `0` pada tiga pemeriksaan selama 20 detik. Launcher di-force-stop
agar memuat ulang.

### Diverifikasi visual: BERHASIL

Setelah pengguna membuka kunci layar, pengujian diulang:

- Dua kali `input swipe` ke kanan dari home screen → fokus **tetap**
  `com.android.launcher3/.Launcher`, tidak pernah berpindah ke `com.vivo.hiboard`
- Screenshot menunjukkan **indikator halaman tinggal satu titik** — tidak ada lagi
  panel di sebelah kiri

### Prosesnya tetap hidup, tapi sudah tak berdaya

`am force-stop com.vivo.hiboard` → proses **hidup lagi dalam 5 detik** dan tetap hidup
setelah 20 detik. Ini layanan sistem persisten Funtouch; mematikannya secara permanen
butuh root. Namun seluruh penetralan tetap utuh:

| Pembatasan | Status |
|---|---|
| Panel layar kiri | ✅ mati (`hiboard_enabled=0`) |
| `POST_NOTIFICATION` | ✅ `ignore` |
| `RUN_ANY_IN_BACKGROUND` | ✅ `ignore` |
| Data latar belakang | ✅ diblokir (uid 10149) |

Jadi prosesnya berjalan tanpa bisa menampilkan panel, mengirim notifikasi, bekerja di
latar, maupun memakai data.

### Temuan sampingan: ikon mati di home screen

Screenshot memperlihatkan ikon **"Umpan Balik"**. Paketnya (`com.vivo.feedback`) sudah
benar-benar terhapus sejak tahap 1 — yang tersisa hanyalah **pintasan kosong** di
launcher. Dihapus dengan tahan-lama pada ikonnya.

Setelan ini ditambahkan ke `apply-all.sh` (fungsi `set_s` untuk namespace `system`)
sehingga ikut dipulihkan setelah factory reset.

## Aplikasi Google: tidak disentuh

Permintaan "google hapus saja" diklarifikasi terlebih dahulu karena menghapus GMS +
Play Store akan mematikan push FCM (Instagram/Telegram/Outlook berhenti berbunyi),
menghilangkan kemampuan memasang/memperbarui aplikasi, dan membuat banyak aplikasi
force-close.

Klarifikasi pengguna: yang mengganggu hanyalah panel Jovi Home. **Seluruh aplikasi
Google tetap utuh.**

---

# Tahap 10 — Diagnosis jaringan lambat (2026-09-13)

## Keluhan

Unduhan dan jaringan terasa lelet.

## Metodologi: ukur, jangan menebak

### 1. Kondisi WiFi

```
SSID           : <SSID-disensor>
Frequency      : 2412 MHz   -> band 2,4 GHz channel 1
Wi-Fi standard : 4          -> 802.11n
Tx / Rx link   : 72 / 65 Mbps
RSSI           : -49 dBm    -> sinyal BAGUS
Flags          : [WPA-PSK-TKIP+CCMP][WPA2-PSK-TKIP+CCMP]
```

Pindai jaringan sekitar: **tidak ada SSID 5 GHz** — router hanya 2,4 GHz.

### 2. Throughput internet nyata

| Perangkat | Kecepatan |
|---|---|
| Vivo V21 | **3,3 Mbps** (0,39 MB/s, unduh 25 MB / 58,6 s) |
| MacBook (WiFi sama) | **4,9 Mbps** |

Rincian waktu curl dari HP: DNS **0,068 s**, connect 0,101 s, TLS 0,524 s.
→ **DNS bukan penyebabnya**; AdGuard tidak memperlambat apa pun.

### 3. Uji penentu: throughput LAN

`adb push` / `adb pull` berkas 20 MB melewati router yang sama:

| Arah | Kecepatan |
|---|---|
| Mac → HP | 3,2 MB/s = **25,6 Mbps** |
| HP → Mac | 3,6 MB/s = **28,8 Mbps** |

## Kesimpulan

| Komponen | Vonis |
|---|---|
| HP Vivo V21 | ✅ **bukan penyebab** — hanya memakai 5% kapasitas link-nya |
| WiFi / router | ✅ **sehat** — mengantar 26–29 Mbps di jaringan lokal |
| DNS / AdGuard | ✅ **bukan penyebab** — resolusi 68 ms |
| **Jalur internet ISP** | ❌ **INI HAMBATANNYA** — hanya 3–5 Mbps |

Jaringan lokal **6–8× lebih cepat** daripada internet. Tidak ada optimasi di sisi ponsel
yang bisa memperbaiki jalur internet yang hanya 3–5 Mbps.

## Yang bisa dilakukan

1. **Uji data seluler XL.** LTE di Indonesia umumnya 10–30 Mbps — berpotensi beberapa
   kali lebih cepat daripada WiFi 3–5 Mbps ini. *(Tidak bisa diuji dari sini: mengikat
   `curl --interface rmnet_data1` gagal — Android memakai routing berbasis fwmark;
   menguji berarti mematikan WiFi, yang memutus ADB.)*
2. **Cek paket langganan ISP** — apakah 3–5 Mbps memang yang dibayar?
3. **Ganti keamanan router ke WPA2-AES saja** (matikan TKIP & WPA1). Ini soal
   **keamanan**, bukan kecepatan — LAN sudah terbukti 26–29 Mbps, jadi TKIP tidak
   sedang membatasi throughput di sini.
4. **Router 5 GHz** hanya berguna bila jalur internet dinaikkan; saat ini WiFi bukan
   hambatannya.

---

# Tahap 11 — Membersihkan layar Pencarian Global (2026-09-13)

## Masalah

Layar geser-bawah (`com.vivo.globalsearch`) penuh iklan dan lambat saat di-scroll:
aplikasi promosi berbayar (ShopeePay, SeaBank, Vita Mahjong, TeraBox — semuanya dengan
panah unduh), tab "Ask AI" berisi 9 prompt, tab "Aplikasi Populer" dan "Saran",
feed berita Tribunnews, serta riwayat pencarian yang menumpuk.

Paketnya dikunci Vivo (`DELETE_FAILED_USER_RESTRICTED`), sama seperti Jovi Home.

## Saklar tersembunyi yang ditemukan

Penelusuran `settings list {system,secure,global}` menemukan lima saklar:

| Namespace | Kunci | Dari | Jadi |
|---|---|---|---|
| secure | `vivo_recommended_status` | 1 | **0** |
| secure | `key_appstore_switch_state` | `personal_recommend_switch_state:"1"` | **`"0"`** |
| secure | `com_vivo_appstore_desktopfolder_desktopfoldernewappactivity_show` | 1 | **0** |
| secure | `com_vivo_appstore_desktopfolder_desktopfoldernewgameactivity_show` | 1 | **0** |
| global | `upload_apk_enable` | 1 | **0** |

Dua saklar `desktopfolder` itu yang membuat V-AppStore mendorong **folder aplikasi dan
game promosi langsung ke home screen**.

`upload_apk_enable` adalah telemetri: perangkat mengunggah informasi APK terpasang.

## Temuan privasi: Vivo Push membaca semua notifikasi

`settings get secure enabled_notification_listeners` mengungkap:

```
com.android.launcher3/...NotificationListener
com.vivo.pushservice/com.vivo.push.util.NotificationMonitor   <-- ini
```

Sebagai *notification listener*, `com.vivo.pushservice` dapat **membaca isi setiap
notifikasi** — termasuk pesan WhatsApp, notifikasi bank, dan kode OTP.

Dicabut dengan:
```bash
cmd notification disallow_listener com.vivo.pushservice/com.vivo.push.util.NotificationMonitor
```

Tersisa hanya listener milik launcher, yang memang diperlukan untuk badge angka.

## Riwayat & izin

- `pm clear com.vivo.globalsearch` → **riwayat pencarian terhapus**
- Seluruh izin sensitif dicabut (`ACCESS_*_LOCATION`, `READ_CONTACTS`,
  `READ_PHONE_STATE`, `READ_CALENDAR`, `RECORD_AUDIO`, `CAMERA`) → kini **nol izin**

`pm clear` memicu dialog izin susulan (lokasi, kalender); semuanya ditolak.

## Hasil (diverifikasi screenshot)

| Elemen | Sebelum | Sesudah |
|---|---|---|
| Aplikasi promosi berbayar | ShopeePay, SeaBank, Vita Mahjong, TeraBox | ✅ hilang |
| Tab "Ask AI" + 9 prompt | ada | ✅ hilang |
| Tab "Aplikasi Populer" / "Saran" | ada | ✅ hilang |
| Feed berita Tribunnews | ada | ✅ hilang |
| Riwayat pencarian | menumpuk | ✅ kosong |
| Izin sensitif | lokasi dll. | ✅ nol |

Yang tersisa hanya "Saran aplikasi" berisi aplikasi milik pengguna sendiri
(Tema, Gmail, Telegram, Play Store, TikTok, Pengaturan, vivo Store, Claude, Termux, Chrome).

> Muncul banner **"Nikmati fitur lengkap"** yang meminta mengaktifkan akses Penyimpanan
> dan telepon. Itu akibat pencabutan izin — tutup dengan tombol **✕**, jangan tekan
> "Aktifkan sekarang".

Seluruh saklar ditambahkan ke `apply-all.sh` (fungsi `set_e` untuk namespace `secure`,
plus penanganan JSON dan pencabutan listener/izin). Uji mode cek: **16/16 setelan ok**.

---

# Tahap 12 — Feed berita di Pencarian Global (2026-09-13)

## Koreksi tahap 11

Di tahap 11 disimpulkan feed berita sudah hilang. **Itu keliru** — screenshot diambil
sebelum feed sempat dimuat dari jaringan. Pengguna mengirim bukti bahwa tab "Saran"
berisi Tribunnews masih ada.

## Jalan buntu yang dicoba

| Pendekatan | Hasil |
|---|---|
| `cmd netpolicy` blokir internet penuh | ❌ hanya tersedia pembatasan **latar**; feed dimuat di foreground |
| Blokir per-IP | ❌ IP di balik CDN (Cloudflare `172.65.90.64`, Google Cloud `35.244.165.134`) — memblokirnya berisiko memutus layanan lain |
| `am start` ke halaman setelan | ❌ `SettingHomePageContentActivity` **tidak exported**: `SecurityException ... not exported from uid 10121` |
| Cari saklar di `settings list` | ❌ tidak ada kunci untuk feed |

## Yang berhasil: membaca hierarki UI

`uiautomator dump` mengungkap elemen yang tidak terlihat jelas di layar:

```
id=content_setting_layout   bounds=[540,2207][1027,2280]   clickable=true
id=iv_close                 bounds=[932,346][995,409]      clickable=true
```

`content_setting_layout` adalah tombol tersembunyi di **pojok kanan bawah** layar
pencarian. `iv_close` menutup banner "Nikmati fitur lengkap".

Keduanya diketuk lewat `input tap`.

## Verifikasi (dua kali, tidak mengulang kesalahan tahap 11)

Pemeriksaan pertama ditunggu **20 detik** agar feed punya waktu memuat, lalu diulang
setelah `am force-stop` + buka ulang dari nol:

```
Teks di layar: TikTok | Saran aplikasi | Telegram | Tema | Gmail |
               Google Play Store | Pengaturan | Termux | ChatGPT |
               V-Appstore | YouTube | Keyboard

Item berita : 0
Iklan app   : 0
Tab Ask AI  : tidak ada
```

## Batas yang perlu diketahui

Setelan ini **tidak tersimpan di Android settings** — tidak ada kunci baru yang muncul
di `settings list {system,secure,global}` setelahnya. Kemungkinan disimpan di
`com.vivo.globalsearch.mmkvprovider` (penyimpanan internal aplikasi).

Konsekuensinya:

- ✅ Bertahan pada penggunaan normal dan reboot
- ⚠️ **Akan kembali** bila `pm clear com.vivo.globalsearch` dijalankan, atau setelah
  factory reset
- ⚠️ **Tidak bisa dipulihkan otomatis** oleh `apply-all.sh` — skrip hanya mencetak
  pengingat langkah manualnya

> Jujur: tidak dapat dipastikan apakah yang mematikan feed adalah ketukan pada
> `content_setting_layout`, atau `vivo_recommended_status=0` yang baru berlaku setelah
> `force-stop`. Yang pasti: hasilnya terverifikasi hilang pada dua pengujian terpisah.

---

# Tahap 13 — Regresi setelah reboot & audit iklan lanjutan (2026-09-13)

## `apply-all.sh cek` membuktikan nilainya

Setelah pengguna me-reboot perangkat, pemeriksaan menemukan **4 hal kembali sendiri**:

| Yang kembali | Bukti |
|---|---|
| **Netflix terpasang lagi** | paket 274 → 276 |
| `upload_apk_enable` | 0 → **1** |
| **Vivo Push dapat membaca notifikasi lagi** | muncul kembali di `enabled_notification_listeners` |
| Gesture back lebar | kembali ke `gestural` |

Semua diperbaiki dengan satu kali `./apply-all.sh`.

> Ke-54 paket yang dihapus **tetap hilang** — hanya Netflix yang dipulihkan sistem.
> `com.mobile.legends` yang muncul adalah aplikasi yang dipasang pengguna sendiri.

Ini menjawab pertanyaan "kalau restart HP, kembali lagi?": **sebagian besar bertahan,
tetapi beberapa hal memang dikembalikan oleh sistem.** Jalankan `./apply-all.sh cek`
sesekali setelah reboot.

## Tiga saklar iklan baru ditemukan

| Namespace | Kunci | Dari | Jadi |
|---|---|---|---|
| global | **`HAS_PUSH_NOTIFI_BOOT_APPSTORE`** | 1 | **0** |
| system | `setting_vivo_store_enhance` | 1 | **0** |
| system | `vivo_mood_picture_setting_enable` | 1 | **0** |

`HAS_PUSH_NOTIFI_BOOT_APPSTORE` membuat V-AppStore mengirim notifikasi push **setiap
kali perangkat menyala**.

Total setelan yang dipantau `apply-all.sh` kini **19**, semuanya ok.

## Analisis waktu boot

`dumpsys package r` pada `BOOT_COMPLETED`, disaring ke paket yang benar-benar terpasang:

- **120 paket** berjalan saat boot
- **43** di antaranya non-sistem

Sebagian besar sisanya adalah komponen sistem (`com.android.*`, `com.google.android.*`,
Qualcomm/radio) yang **tidak boleh** disentuh.

Kandidat pihak-ketiga yang tidak butuh jalan saat boot: `com.mobile.legends`,
`com.pinterest`, `com.zhiliaoapp.musically`, `com.microsoft.emmx`, `com.openai.chatgpt`,
`app.source.getcontact`, `com.twofasapp`.

> Membatasi mereka mempercepat boot, tetapi **menunda notifikasi** aplikasi tersebut —
> itu trade-off milik pengguna, bukan keputusan otomatis.

## Sapu bersih terakhir: layar sistem lain

Teknik `uiautomator dump` diterapkan ke empat permukaan sistem:

| Layar | Teks | Dugaan iklan |
|---|---|---|
| Panel notifikasi / quick settings | 12 | 0 *(1 false positive: indikator kuota "22,86MB hari ini")* |
| Aplikasi Pengaturan | 11 | 0 *(1 false positive: deskripsi Smart Lock)* |
| Aplikasi terkini (recents) | 12 | **0** |
| Home screen | 12 | **0** |

## Audit jalur iklan tersembunyi

| Izin | Hasil |
|---|---|
| `SYSTEM_ALERT_WINDOW` (tampil di atas app lain — jalur iklan pop-up) | **hanya `com.android.dialer`** — sah, untuk layar telepon masuk |
| `INSTALL_SHORTCUT` (pasang pintasan diam-diam) | **nol aplikasi** |
| `GET_USAGE_STATS` (pelacakan kebiasaan pemakaian) | **nol aplikasi** |

Tidak ada aplikasi yang dapat memunculkan iklan pop-up, menanam pintasan, atau melacak
kebiasaan pemakaian.

## Keputusan pengguna: boot tidak dibatasi

Ditawarkan membatasi aplikasi pihak-ketiga yang jalan saat boot (Mobile Legends, TikTok,
Pinterest, Edge, ChatGPT, Getcontact, 2FAS) untuk mempercepat restart.
**Pengguna memilih tidak membatasi apa pun** agar notifikasi tetap utuh.

---

# Tahap 14 — Pencarian optimasi tersisa: hasilnya nihil (2026-09-13)

Empat area terakhir diperiksa. **Semuanya sudah optimal** — tidak ada yang perlu diubah.
Dicatat di sini agar tidak diperiksa ulang di kemudian hari.

| Area | Temuan | Vonis |
|---|---|---|
| **Swap / zRAM** | `SwapTotal 4 GB`, **`SwapFree 4 GB`** — tak pernah terpakai, `zram_enabled=1` | ✅ RAM tidak pernah kehabisan; zram berguna sebagai cadangan, mematikannya sia-sia |
| **Alarm / wakeup** | networkstack 13, GMS 9, sisanya 1–4 | ✅ tak ada aplikasi yang menghajar perangkat |
| **Hotword "Ok Google"** | `com.google.android.googlequicksearchbox` **nonaktif** & tidak berjalan; `assistant` dan `voice_interaction_service` kosong | ✅ tidak ada deteksi suara latar yang menguras baterai |
| **Performa scroll** | jank **0,00%**, 90th **12 ms**, 95th 13 ms, 99th 14 ms, missed vsync **0**, slow UI thread **0** | ✅ optimal untuk panel 60 Hz (anggaran 16,7 ms) |

## Kesimpulan

Perangkat sudah mencapai batas praktis optimasi tanpa root:

- Frame time **12 ms** pada anggaran 16,7 ms — masih tersisa 28% margin
- RAM tidak pernah menyentuh swap
- Tidak ada wakelock, overlay, pelacak penggunaan, atau pemicu boot yang abnormal
- Seluruh permukaan iklan Funtouch yang dapat dijangkau tanpa root sudah dimatikan

Sisa hambatan yang **tidak bisa diperbaiki dari sisi perangkat lunak**:

1. Panel **60 Hz** secara fisik (`persist.vivo.phone.fps_max=60`)
2. Jalur internet ISP **3–5 Mbps** (LAN terbukti 26–29 Mbps)
3. Patch keamanan berhenti di **2023-10-01**

Yang tersisa hanyalah **perawatan**, bukan optimasi: jalankan `./apply-all.sh cek`
setelah setiap reboot, karena sistem terbukti mengembalikan sebagian setelan.

---

# Tahap 15 — AI lokal di perangkat (2026-09-13)

## Kemampuan perangkat: sangat mendukung

```
arm64-v8a, 8 core, big core 2,32 GHz
Features: fp asimd aes pmull sha1 sha2 crc32 atomics fphp asimdhp cpuid asimdrdm lrcpc dcpop asimddp
RAM tersedia: 4,46 GB   |   Penyimpanan bebas: 86 GB
```

**`asimddp`** (ARM dot-product SDOT/UDOT) adalah kunci — instruksi inilah yang dipakai
llama.cpp untuk inferensi int8 terkuantisasi. Banyak perangkat sekelas ini tidak
memilikinya; perangkat ini punya, sehingga inferensi berjalan beberapa kali lebih cepat.
`fphp`/`asimdhp` menambah dukungan FP16.

## Yang dipasang

**PocketPal AI** (`com.pocketpalai`, LLM Ventures) dari Play Store — antarmuka chat,
open source, menjalankan model GGUF sepenuhnya offline. Ada pembelian dalam aplikasi,
tetapi fungsi inti gratis.

**Model: Gemma 3 1B** (806 MB) — dipilih sebagai yang paling ringan namun tetap layak
untuk pemakaian harian; dukungan multibahasa Google membantu Bahasa Indonesia.

Pilihan lain yang tersedia di aplikasi: SmolLM3 3B (1,81 GB) · LFM2 2.6B (1,56 GB) ·
Qwen3 1.7B (1,28 GB) · LFM2.5 1.2B (731 MB) · LFM2-VL 1.6B (1,26 GB) · Bonsai 8B (1,16 GB).

> Kecepatan unduh terukur **0,35 MB/s (2,8 Mbps)** dengan ETA 37 menit — konsisten dengan
> batas ISP 3–5 Mbps yang diukur di tahap 10, bukan keterbatasan perangkat.

## Asisten sistem

Pemeriksaan `cmd package query-services -a android.service.voice.VoiceInteractionService`:

| Aplikasi | Bisa jadi asisten sistem? |
|---|---|
| `com.anthropic.claude` | ✅ ya |
| `com.openai.chatgpt` | ✅ ya |
| **`com.pocketpalai`** | ❌ **tidak** — hanya punya `MainActivity`, tidak mendaftarkan `VoiceInteractionService` |

**PocketPal tidak dapat dijadikan asisten sistem.** Itu batas aplikasinya, bukan
perangkatnya. Slot asisten sebelumnya kosong, lalu diisi:

```
assistant                 = com.anthropic.claude/.bell.assist.ClaudeVoiceInteractionService
voice_interaction_service = com.anthropic.claude/.bell.assist.ClaudeVoiceInteractionService
```

AI lokal tetap dibuka lewat ikon aplikasi.

## Konteks sistem untuk AI

`konteks-hp.txt` (266 kata, ~354 token — muat di jendela konteks model kecil) berisi
ringkasan padat perangkat: spesifikasi, apa yang sudah dioptimasi, batasan yang tidak
bisa diperbaiki, dan cara perawatan.

Tersimpan di:
- MacBook: `MY GITHUB/VIVO V21/konteks-hp.txt`
- HP: `/sdcard/Documents/konteks-hp.txt`

Tempelkan isinya ke **System Prompt** di PocketPal agar AI lokal memahami perangkat ini
saat ditanya.

## Ekspektasi kinerja yang jujur

| Model | Perkiraan kecepatan |
|---|---|
| Gemma 3 1B | ~15–20 token/detik |
| Qwen3 1.7B | ~10–12 token/detik |
| Model 3B | ~4–6 token/detik (menunggu 30–60 detik per paragraf) |

Model 1–3B **jauh lebih lemah** daripada Claude/ChatGPT. Cocok untuk tanya-jawab
sederhana, ringkasan, dan penulisan ulang — bukan penalaran rumit atau coding.
Keunggulannya: berjalan tanpa internet, gratis, dan data tidak meninggalkan perangkat.

## Hasil akhir: AI lokal aktif & sadar-perangkat

**Terpasang dan terverifikasi:**

| Komponen | Status |
|---|---|
| PocketPal AI | ✅ terpasang dari Play Store |
| Gemma 3 1B (799,53 MB) | ✅ terunduh & termuat — `Native Heap 1,16 GB` |
| System prompt konteks HP | ✅ terpasang & **terbukti bekerja** |
| Claude sebagai asisten sistem | ✅ slot terisi |

**Kinerja terukur** (dilaporkan PocketPal sendiri):

| Uji | Hasil |
|---|---|
| Tanpa system prompt | **10,18 token/detik**, 98 ms/token, TTFT 1.435 ms |
| Dengan system prompt | **10,59 token/detik**, 94 ms/token, TTFT 5.203 ms |

> Perkiraan awal 15–20 token/detik **terlalu optimistis** — aktualnya ~10. TTFT naik
> dari 1,4 detik ke 5,2 detik karena system prompt harus diproses lebih dulu setiap
> percakapan baru; setelah itu kecepatan per-token tidak berubah.

**Bukti kesadaran konteks:**

Pertanyaan: *"Berapa Hz layar HP ini dan bisakah jadi 120Hz?"*
Jawaban: *"Layar HP Vivo V21 Anda memiliki layar 1080x2400 AMOLED dengan refresh rate
tetap 60Hz."*

Model mengenali merek, resolusi, dan batas 60 Hz perangkat — sesuai system prompt.

**Uji kualitas bahasa** — pertanyaan *"Apa itu AMOLED? Jawab 2 kalimat."*:

> *"AMOLED adalah teknologi tampilan yang menggunakan banyak warna dan menawarkan warna
> yang lebih cerah dan lebih hidup dibandingkan layar LCD tradisional. AMOLED juga
> dikenal karena efisiensi daya yang lebih baik, yang berarti baterai bertahan lebih lama."*

Bahasa Indonesia wajar, jawaban benar, panjang sesuai instruksi.

## Jalur alternatif yang lebih cepat (belum dikerjakan)

| Pengungkit | Efek |
|---|---|
| Model lebih kecil (`Qwen2.5-0.5B` ~400 MB via tombol +) | ~30 token/detik, tapi jawaban lebih dangkal |
| `LFM2.5 1.2B` (731 MB) | dirancang Liquid AI khusus perangkat edge |
| **Termux + llama.cpp** | kontrol penuh thread & kuantisasi (Q4_0 + ARM repacking memanfaatkan `asimddp`) — pengungkit terbesar |

**Untuk AI yang benar-benar "tertanam"** (belum dikerjakan): `llama-server` di Termux
membuka UI chat bawaan di `localhost:8080`, dibuka Chrome, lalu *Tambahkan ke layar utama*
menjadikannya ikon aplikasi. Dengan **Termux:Boot** (perlu dipasang terpisah) server
berjalan otomatis saat perangkat menyala. Server ini juga membuka API kompatibel OpenAI
sehingga aplikasi atau skrip lain dapat memanggilnya.

---

# Tahap 16 — Membuat AI lokal lebih cerdas (2026-09-13)

## Tiga pengungkit yang dicoba

### 1. Parameter generasi — disetel ke profil faktual

| Parameter | Bawaan | Jadi | Alasan |
|---|---|---|---|
| Temperature | 0,7 | **0,35** | mengurangi kreativitas liar, menaikkan konsistensi |
| Top K | 40 | **20** | membuang pilihan kata berpeluang rendah |
| Top P | 0,95 | **0,9** | inti distribusi lebih ketat |
| Min P | 0,05 | 0,05 | dibiarkan |

### 2. System prompt ditulis ulang

Prompt lama hanya berisi fakta perangkat. Prompt baru menambahkan enam aturan perilaku:
berpikir langkah demi langkah untuk soal rumit, langsung ke inti tanpa pengulangan,
**mengakui saat tidak tahu dan dilarang mengarang fakta/angka/tanggal/nama**, bertanya
balik bila pertanyaan ambigu, panjang jawaban menyesuaikan panjang pertanyaan, dan
memakai penomoran untuk daftar.

### 3. Uji penalaran — dan hasilnya jujur: GAGAL

Pertanyaan: *"Baterai HP ini 4000mAh. Layar memakai 179mAh per jam. Berapa jam layar
bisa menyala? Tunjukkan hitungannya."*

Jawaban Gemma 3 1B:

```
Langkah 1: Hitung penurunan daya baterai per jam.
Langkah 2: Hitung penurunan daya baterai dalam jam.
Jawaban: 4000mAh * 0.54 = 2160 mAh
Jam layar yang bisa menyala adalah 2160 mAh.
```

Jawaban benar: **4000 ÷ 179 = 22,3 jam**.

Model mengarang faktor `0.54`, **mengalikan padahal harus membagi**, dan menjawab dalam
satuan mAh padahal yang ditanya jam.

## Kesimpulan yang penting

| Aspek | Berubah? |
|---|---|
| Struktur jawaban | ✅ membaik — muncul "Langkah 1 / Langkah 2" |
| Keringkasan & format | ✅ membaik |
| Instruksi anti-mengarang | ✅ terpasang |
| **Kemampuan menalar** | ❌ **tidak berubah** |
| TTFT | ⚠️ 5,2 → **10,7 detik** (prompt lebih panjang) |
| Kecepatan | ⚠️ 10,59 → **8,82 token/detik** |

**Prompt engineering memperbaiki BENTUK jawaban — struktur, nada, keringkasan,
kejujuran — tetapi tidak dapat menambahkan kemampuan menalar yang tidak ada di dalam
model.** Model 1B terlalu kecil untuk aritmatika yang andal, seberapa pun baiknya
instruksi yang diberikan.

Biaya prompt panjang juga nyata: TTFT dua kali lipat dan throughput turun ~17%.

## Langkah berikutnya: Qwen3 1.7B

Diunduh sebagai pembanding — model penalaran dengan mode *thinking* (PocketPal memang
menyediakan toggle **"Reasoning model"** di Model Settings untuk model jenis ini).

Kecepatan unduh terukur **0,66 MB/s (5,3 Mbps)**, ETA 31 menit — lebih cepat daripada
0,35 MB/s saat mengunduh Gemma, menunjukkan jalur ISP memang berfluktuasi 3–5 Mbps.

Uji pembanding memakai soal yang sama akan dilaporkan apa adanya, termasuk bila
ternyata tidak lebih baik.

## Perbandingan langsung: Gemma 3 1B vs Qwen3 1.7B

Soal identik: *"Baterai 4000mAh, layar pakai 179mAh per jam. Berapa jam?"*
Jawaban benar: **4000 ÷ 179 = 22,35 jam**

### Gemma 3 1B (806 MB)

```
Langkah 1: Hitung penurunan daya baterai per jam.
Langkah 2: Hitung penurunan daya baterai dalam jam.
Jawaban: 4000mAh * 0.54 = 2160 mAh
Jam layar yang bisa menyala adalah 2160 mAh.
```

❌ **Salah total** — mengarang faktor `0.54`, mengalikan alih-alih membagi, salah satuan.

### Qwen3 1.7B (1,28 GB)

Memunculkan kotak **Reasoning** (mode *thinking*), isinya antara lain:

```
So dividing the total battery capacity by the consumption rate gives
the number of hours. Yes, that makes sense.
So the answer is 4000 / 179 = 22.35 hours.
...it's about 22.35 hours, but in most cases, it's rounded to 22 hours.
```

✅ **Benar** — pembagian tepat, hasil 22,35 jam, dan menjelaskan pembulatannya.

### Ringkasan perbandingan

| | Gemma 3 1B | Qwen3 1.7B |
|---|---|---|
| Ukuran | 806 MB | 1,28 GB |
| RAM saat dimuat | 1,19 GB | **1,53 GB** |
| Kecepatan | ~8,8–10,6 token/detik | lebih lambat |
| Aritmatika | ❌ salah | ✅ **benar** |
| Mode *thinking* | tidak ada | ✅ ada |
| Waktu jawab soal ini | ~45 detik | **>3 menit, masih berpikir** |

## Kesimpulan jujur

**Qwen3 1.7B jelas lebih pintar** — perbedaannya bukan samar, melainkan benar vs salah total
pada soal yang sama.

Tetapi mode *thinking*-nya **bertele-tele**: model terus meragukan jawabannya sendiri dan
setelah 3 menit belum mengeluarkan jawaban final, meski hasil hitungannya sudah benar sejak
awal. Ini perilaku umum mode reasoning pada model berukuran kecil. Penalarannya juga
berlangsung dalam Bahasa Inggris meskipun pertanyaannya Bahasa Indonesia.

> Tombol **Think** tersedia di kolom input untuk mematikan mode ini. Upaya mematikannya
> lewat `input tap` **tidak berhasil** — kotak Reasoning tetap muncul. Perlu dimatikan
> manual oleh pengguna.

## Rekomendasi pemakaian

| Kebutuhan | Model |
|---|---|
| Obrolan harian, tanya cepat, ringkasan | **Gemma 3 1B** — gesit, cukup |
| Hitungan, logika, analisis yang harus benar | **Qwen3 1.7B** — lebih lambat tapi akurat |

Keduanya sudah terpasang dan dapat ditukar kapan saja lewat tombol **Load/Offload** di
layar Models. Hanya satu model boleh termuat pada satu waktu.
