# SegBu — Your Daily Fit Journal

**Tahap 1: Fondasi** · repo `fitjournal/segbu` · tayang di https://fitjournal.github.io/segbu/

Single-file HTML + Supabase + GitHub Pages. Offline-first, dwibahasa (ID/EN).

## Isi

| File | Fungsi |
|---|---|
| `reset.sql` | Hapus semua tabel — untuk mulai bersih dari nol |
| `seed-exercises.sql` | 14 gerakan inti — cara melakukan, kesalahan umum, otot |
| `schema.sql` | Seluruh tabel, RLS, fungsi token, data awal otot & pola gerakan |
| `index.html` | Aplikasi: masuk/daftar, token grup, onboarding, skrining, antrean offline |
| `sw.js` | Service worker — kerangka & aset tersimpan supaya bisa dibuka offline |
| `manifest.json` | PWA: bisa dipasang ke home screen dengan ikon sendiri |
| `icon-180.png`, `icon-512.png` | Ikon sementara — ganti kapan saja |

## Langkah pasang

### 1. Supabase

> **Skrip aman dijalankan berulang.** Kalau muncul error seperti
> `relation "profiles" already exists`, artinya skema sudah pernah jalan sebagian.
> Cukup jalankan ulang `schema.sql` versi terbaru — tabel & policy yang sudah ada dilewati.
> Kalau ingin benar-benar mulai bersih, jalankan `reset.sql` lebih dulu (hanya untuk
> proyek yang belum berisi data sungguhan).

1. Buat proyek baru, **region Singapore**.
2. SQL Editor → tempel seluruh isi `schema.sql` → Run.
3. Authentication → Providers → Email: aktif.
   Untuk uji coba, matikan "Confirm email" supaya tidak perlu verifikasi tiap kali.
4. Settings → API → salin **Project URL** dan **anon public key**.

> Jangan pernah menyalin `service_role` key ke dalam `index.html`.
> Key itu melewati semua RLS dan membuka seluruh database.

### 2. Aplikasi

Buka `index.html`, isi dua baris di awal `<script type="module">`:

```js
const SUPABASE_URL      = "https://xxxxx.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOi...";
```

### 3. Jadikan diri Anda admin

Setelah mendaftar akun pertama, jalankan di SQL Editor:

```sql
update public.profiles set role = 'admin'
where id = (select id from auth.users where email = 'email-anda@contoh.com');
```

### 4. Buat token grup pertama

```sql
insert into public.token_groups (kode, nama_group, max_seats, periode_bulan, catatan)
values ('ARCELIO-01', 'Keluarga Arcelio', 8, 12, 'grup pertama');
-- periode_bulan: 1, 6, 12, atau NULL untuk tanpa batas
```

Jam mundur periode **baru mulai** saat anggota pertama menukar kode.

### 5. GitHub Pages

```bash
git init
git add .
git commit -m "fondasi: auth, token grup, onboarding, skrining, offline"
git branch -M main
git remote add origin https://github.com/fitjournal/segbu.git
git push -u origin main
```

Settings → Pages → Source: `Deploy from a branch` → `main` / `/ (root)` → Save.
Tunggu 1–2 menit, lalu buka **https://fitjournal.github.io/segbu/**

### 6. Daftarkan URL di Supabase

Authentication → URL Configuration:

- **Site URL**: `https://fitjournal.github.io/segbu/`
- **Redirect URLs**: tambahkan `https://fitjournal.github.io/segbu/**`

Tanpa ini, tautan konfirmasi email dan reset kata sandi akan mengarah ke
`localhost` dan gagal dibuka.

> Service worker & PWA **wajib HTTPS**. GitHub Pages sudah HTTPS.
> Membuka file lewat `file://` tidak akan menjalankan service worker.

## Yang sudah jalan

- Daftar dengan kode grup — sisa kursi & tanggal berakhir ditampilkan **sebelum** mendaftar
- Maksimal 8 kursi per grup; periode mulai dari anggota pertama
- Onboarding 5 langkah + skrining kesehatan (adaptasi PAR-Q)
- Penetapan level otomatis (easy/medium/pro) dengan aturan keras:
  - flag merah → tidak bisa mulai di Pro
  - belum pernah olahraga → selalu mulai easy
  - usia 60+ → tidak bisa mulai di Pro
  - hamil / <6 bulan pascamelahirkan → **program tidak diberikan**, diarahkan ke tenaga medis
- Persetujuan risiko wajib dicentang, tercatat dengan versi disclaimer
- Tiga sakelar izin privasi, semua **default mati** kecuali status grup, tercatat di `consent_log`
- Antrean offline (IndexedDB) — tulis lokal dulu, kirim saat online, indikator status terlihat
- Dwibahasa ID/EN, bisa diganti kapan saja

## Catatan keamanan yang sudah dikunci di skema

- RLS aktif di **semua** tabel
- `health_screening` **tidak punya policy admin sama sekali** — jawaban skrining tidak bisa
  dibaca siapa pun selain pemiliknya, apa pun pengaturan izin
- Admin hanya bisa melihat profil & log latihan pengguna yang **menyalakan izin sendiri**
- Teman satu grup hanya bisa membaca tabel `daily_status` (centang selesai/tidak),
  bukan `meals`, `daily_logs`, atau `habit_logs`

## Tahap 2 — sudah jalan

Setelah `schema.sql`, jalankan juga **`seed-exercises.sql`** (14 gerakan inti).

- **Hari Ini** — jadwal otomatis dari tanggal mulai + hari/minggu Anda (Latihan A/B, ringan, cardio, istirahat)
- Centang per set, beban per gerakan, popup cara melakukan + kesalahan umum
- Langkah, jam tidur & bangun (durasi otomatis), terbangun tengah malam
- Catatan makan dengan porsi Kecil/Sedang/Normal/Banyak
- Pelacak kebiasaan **opsional**, mati secara default
- **Progres** — berat & lingkar tubuh, tren berat, statistik mingguan, riwayat, salin ringkasan
- **Atur** — tanggal mulai program, izin privasi, modul, tema, status sinkron

Semua penulisan lewat antrean offline: tulis lokal dulu, kirim saat online.

## Berikutnya (Tahap 3)

Pustaka gerakan & program dipindah dari kode ke database, peta otot, modul fokus,
serta lapisan grup (status disiplin, sesi bersama).
