-- =====================================================================
-- APLIKASI LATIHAN MULTI-USER — SKEMA DATABASE
-- Jalankan di Supabase SQL Editor. AMAN dijalankan berulang kali —
-- tabel, policy, dan indeks yang sudah ada tidak akan menimbulkan error.
-- Region proyek: Singapore
-- =====================================================================

create extension if not exists pgcrypto;

-- =====================================================================
-- 1. IDENTITAS & AKSES
-- =====================================================================

create table if not exists public.profiles (
  id                    uuid primary key references auth.users on delete cascade,
  nama                  text,
  gender                text check (gender in ('pria','wanita','lainnya')),
  tanggal_lahir         date,
  tinggi_cm             numeric(5,1),
  level                 text check (level in ('easy','medium','pro')) default 'easy',
  alat_dimiliki         text[] default '{}',
  hari_per_minggu       smallint default 3,
  menit_per_sesi        smallint default 25,
  waktu_latihan         text,
  tujuan_utama          text,
  tujuan_tambahan       text[] default '{}',
  bahasa                text default 'id' check (bahasa in ('id','en')),
  role                  text default 'user' check (role in ('user','admin')),
  -- izin (default MATI, wajib dinyalakan sendiri oleh pengguna)
  izin_admin_ringkasan  boolean default false,
  izin_admin_detail     boolean default false,
  izin_grup_status      boolean default true,
  onboarding_selesai    boolean default false,
  created_at            timestamptz default now(),
  updated_at            timestamptz default now()
);

create table if not exists public.token_groups (
  id             uuid primary key default gen_random_uuid(),
  kode           text unique not null,
  nama_group     text not null,
  max_seats      smallint not null default 8 check (max_seats between 1 and 8),
  periode_bulan  smallint check (periode_bulan in (1,6,12)),  -- null = unlimited
  mulai_pada     timestamptz,           -- diisi saat anggota PERTAMA menukar kode
  berakhir_pada  timestamptz,           -- dihitung dari mulai_pada + periode
  status         text default 'aktif' check (status in ('aktif','ditutup','dicabut')),
  dibuat_oleh    uuid references auth.users,
  catatan        text,
  created_at     timestamptz default now()
);

create table if not exists public.memberships (
  id            uuid primary key default gen_random_uuid(),
  group_id      uuid not null references public.token_groups on delete cascade,
  user_id       uuid not null references auth.users on delete cascade,
  ditukar_pada  timestamptz default now(),
  status        text default 'aktif' check (status in ('aktif','kedaluwarsa','dicabut')),
  unique (group_id, user_id)
);

create table if not exists public.consent_log (
  id          bigserial primary key,
  user_id     uuid not null references auth.users on delete cascade,
  jenis_izin  text not null,
  nilai       boolean not null,
  diubah_pada timestamptz default now()
);

create table if not exists public.health_screening (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references auth.users on delete cascade,
  jawaban            jsonb not null,
  ada_flag_merah     boolean not null default false,
  disetujui_pengguna boolean not null default false,
  versi_disclaimer   text,
  tanggal_isi        timestamptz default now()
);

-- =====================================================================
-- 2. KONTEN (sama untuk semua pengguna — hanya admin yang boleh menulis)
--    Semua kolom teks dwibahasa: {"id": "...", "en": "..."}
-- =====================================================================

create table if not exists public.movement_patterns (
  id    text primary key,              -- 'squat','hinge','push_h','push_v','pull_h','core'
  nama  jsonb not null
);

create table if not exists public.muscles (
  id           text primary key,       -- 'gluteus-maximus'
  nama         jsonb not null,
  nama_latin   text,
  kelompok     text not null,          -- 'gluteus','paha-depan', dst — nama file mask
  tampil_di    text check (tampil_di in ('depan','belakang','keduanya')) default 'keduanya',
  otot_dalam   boolean default false   -- true = tidak diwarnai di peta
);

create table if not exists public.exercises (
  id               text primary key,   -- slug: 'glute-bridge' (JANGAN diubah setelah aset dibuat)
  pattern_id       text references public.movement_patterns,
  nama             jsonb not null,
  level            text check (level in ('easy','medium','hard')) not null,
  alat_dibutuhkan  text[] default '{}',
  otot_primer      text[] default '{}',
  otot_sekunder    text[] default '{}',
  otot_dalam_teks  jsonb,
  cara_melakukan   jsonb,              -- {"id":["langkah 1",...], "en":[...]}
  kesalahan_umum   jsonb,
  kenapa_penting   jsonb,
  kontraindikasi   text[] default '{}',-- 'lutut','punggung-bawah','bahu'
  sudut_pandang    text default 'samping',
  status_aset      text default 'belum' check (status_aset in ('belum','draft','final')),
  urutan           smallint default 0
);

create table if not exists public.programs (
  id            text primary key,
  nama          jsonb not null,
  deskripsi     jsonb,
  level         text check (level in ('easy','medium','pro')) not null,
  gender_target text check (gender_target in ('pria','wanita','semua')) default 'semua',
  usia_min      smallint,
  usia_max      smallint,
  durasi_minggu smallint default 12
);

create table if not exists public.program_days (
  id         uuid primary key default gen_random_uuid(),
  program_id text references public.programs on delete cascade,
  minggu     smallint not null,
  hari       smallint not null check (hari between 1 and 7),
  tipe       text check (tipe in ('latihan','cardio','ringan','rest')) not null,
  label      jsonb,
  unique (program_id, minggu, hari)
);

create table if not exists public.program_items (
  id              uuid primary key default gen_random_uuid(),
  day_id          uuid references public.program_days on delete cascade,
  pattern_id      text references public.movement_patterns,
  exercise_id     text references public.exercises,   -- opsional: kunci ke gerakan tertentu
  set_count       smallint not null,
  rep_text        text not null,                      -- '8-10', '30 detik'
  istirahat_detik smallint default 75,
  urutan          smallint default 0
);

create table if not exists public.modules (
  id                text primary key,
  nama              jsonb not null,
  deskripsi_jujur   jsonb,             -- kalimat jujur soal spot reduction
  gender_disarankan text check (gender_disarankan in ('pria','wanita','semua')) default 'semua',
  usia_min          smallint
);

create table if not exists public.module_items (
  id          uuid primary key default gen_random_uuid(),
  module_id   text references public.modules on delete cascade,
  exercise_id text references public.exercises,
  set_count   smallint default 2,
  rep_text    text default '10-12',
  urutan      smallint default 0
);

create table if not exists public.tracks_music (
  id            uuid primary key default gen_random_uuid(),
  judul         text not null,
  bpm           smallint,
  segmen        text check (segmen in ('pemanasan','kekuatan','istirahat','jalan','cardio','pendinginan')),
  durasi_detik  smallint,
  instrumental  boolean default true,
  url_file      text,
  sumber        text default 'suno',
  aktif         boolean default true
);

-- =====================================================================
-- 3. DATA PRIBADI (RLS: hanya pemiliknya)
--    Semua id dibuat di PERANGKAT (uuid) supaya bisa dicatat offline.
-- =====================================================================

create table if not exists public.user_programs (
  id            uuid primary key,
  user_id       uuid not null references auth.users on delete cascade,
  program_id    text references public.programs,
  tanggal_mulai date not null,
  status        text default 'aktif' check (status in ('aktif','selesai','berhenti')),
  updated_at    timestamptz default now()
);

create table if not exists public.daily_logs (
  id               uuid primary key,
  user_id          uuid not null references auth.users on delete cascade,
  tanggal          date not null,
  langkah          integer,
  tidur_mulai      time,
  tidur_selesai    time,
  tidur_jam        numeric(3,1),
  terbangun_malam  boolean,
  catatan          text,
  updated_at       timestamptz default now(),
  unique (user_id, tanggal)
);

create table if not exists public.workout_sessions (
  id             uuid primary key,
  user_id        uuid not null references auth.users on delete cascade,
  tanggal        date not null,
  program_day_id uuid references public.program_days,
  label          text,
  selesai        boolean default false,
  durasi_menit   smallint,
  updated_at     timestamptz default now()
);

create table if not exists public.session_sets (
  id          uuid primary key,
  session_id  uuid not null references public.workout_sessions on delete cascade,
  user_id     uuid not null references auth.users on delete cascade,
  exercise_id text references public.exercises,
  set_ke      smallint not null,
  beban_kg    numeric(5,1),
  rep         smallint,
  selesai     boolean default false,
  updated_at  timestamptz default now()
);

create table if not exists public.body_metrics (
  id               uuid primary key,
  user_id          uuid not null references auth.users on delete cascade,
  tanggal          date not null,
  berat_kg         numeric(5,1),
  lingkar_perut    numeric(5,1),
  lingkar_pinggang numeric(5,1),
  lingkar_pinggul  numeric(5,1),
  lingkar_dada     numeric(5,1),
  lingkar_lengan   numeric(5,1),
  lingkar_paha     numeric(5,1),
  lingkar_betis    numeric(5,1),
  updated_at       timestamptz default now(),
  unique (user_id, tanggal)
);

create table if not exists public.meals (
  id             uuid primary key,
  user_id        uuid not null references auth.users on delete cascade,
  tanggal        date not null,
  jam            time,
  deskripsi      text,
  porsi          text check (porsi in ('kecil','sedang','normal','banyak')),
  perkiraan_kkal integer,
  updated_at     timestamptz default now()
);

create table if not exists public.habit_logs (
  id         uuid primary key,
  user_id    uuid not null references auth.users on delete cascade,
  tanggal    date not null,
  tipe       text not null,        -- 'rokok','alkohol', atau custom
  jumlah     numeric(8,1),
  satuan     text,
  updated_at timestamptz default now()
);

-- Status ringkas untuk dibagikan ke teman satu grup.
-- Sengaja tabel TERPISAH: hanya berisi status, bukan isi catatan.
create table if not exists public.daily_status (
  id                    uuid primary key,
  user_id               uuid not null references auth.users on delete cascade,
  tanggal               date not null,
  latihan_selesai       boolean default false,
  makan_tercatat        boolean default false,
  langkah_target_capai  boolean default false,
  updated_at            timestamptz default now(),
  unique (user_id, tanggal)
);

-- =====================================================================
-- 4. GRUP: sesi bersama & kehadiran
-- =====================================================================

create table if not exists public.group_sessions (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid references public.token_groups on delete cascade,
  tanggal     date not null,
  jam         time not null,
  judul       text,
  room_url    text,
  dibuat_oleh uuid references auth.users
);

create table if not exists public.session_attendance (
  id                uuid primary key default gen_random_uuid(),
  group_session_id  uuid references public.group_sessions on delete cascade,
  user_id           uuid references auth.users on delete cascade,
  hadir             boolean default false,
  durasi_menit      smallint,
  unique (group_session_id, user_id)
);

-- =====================================================================
-- 5. FUNGSI BANTU
-- =====================================================================

-- Profil dibuat otomatis saat pengguna mendaftar
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, nama)
  values (new.id, coalesce(new.raw_user_meta_data->>'nama', ''));
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Apakah pengguna ini admin?
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

-- Apakah target berada di grup yang sama dengan saya?
create or replace function public.is_group_mate(target uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.memberships m1
    join public.memberships m2 on m1.group_id = m2.group_id
    where m1.user_id = auth.uid()
      and m2.user_id = target
      and m1.status = 'aktif' and m2.status = 'aktif'
  );
$$;

-- Tukar kode token grup. Dipanggil sekali setelah pengguna mendaftar.
create or replace function public.redeem_token(p_kode text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  g public.token_groups%rowtype;
  terpakai int;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'error', 'belum_login');
  end if;

  select * into g from public.token_groups where upper(kode) = upper(p_kode);
  if not found then
    return jsonb_build_object('ok', false, 'error', 'kode_tidak_ditemukan');
  end if;
  if g.status <> 'aktif' then
    return jsonb_build_object('ok', false, 'error', 'kode_tidak_aktif');
  end if;
  if g.berakhir_pada is not null and g.berakhir_pada < now() then
    return jsonb_build_object('ok', false, 'error', 'periode_habis');
  end if;

  if exists (select 1 from public.memberships where group_id = g.id and user_id = auth.uid()) then
    return jsonb_build_object('ok', true, 'group_id', g.id, 'catatan', 'sudah_anggota');
  end if;

  select count(*) into terpakai
    from public.memberships where group_id = g.id and status = 'aktif';
  if terpakai >= g.max_seats then
    return jsonb_build_object('ok', false, 'error', 'seat_penuh');
  end if;

  -- Anggota pertama memulai jam mundur periode grup
  if g.mulai_pada is null then
    update public.token_groups
       set mulai_pada = now(),
           berakhir_pada = case when g.periode_bulan is null
                                then null
                                else now() + (g.periode_bulan || ' months')::interval end
     where id = g.id
    returning * into g;
  end if;

  insert into public.memberships (group_id, user_id) values (g.id, auth.uid());

  return jsonb_build_object(
    'ok', true,
    'group_id', g.id,
    'nama_group', g.nama_group,
    'berakhir_pada', g.berakhir_pada,
    'sisa_seat', g.max_seats - terpakai - 1
  );
end; $$;

-- Cek sisa masa berlaku sebelum mendaftar (dipanggil tanpa login)
create or replace function public.cek_token(p_kode text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare g public.token_groups%rowtype; terpakai int;
begin
  select * into g from public.token_groups where upper(kode) = upper(p_kode);
  if not found then return jsonb_build_object('ok', false, 'error', 'kode_tidak_ditemukan'); end if;
  if g.status <> 'aktif' then return jsonb_build_object('ok', false, 'error', 'kode_tidak_aktif'); end if;
  select count(*) into terpakai from public.memberships where group_id = g.id and status = 'aktif';
  return jsonb_build_object(
    'ok', terpakai < g.max_seats,
    'nama_group', g.nama_group,
    'sisa_seat', g.max_seats - terpakai,
    'berakhir_pada', g.berakhir_pada,
    'periode_bulan', g.periode_bulan
  );
end; $$;

grant execute on function public.cek_token(text) to anon, authenticated;
grant execute on function public.redeem_token(text) to authenticated;

-- =====================================================================
-- 6. ROW LEVEL SECURITY
--    Dinyalakan di SEMUA tabel. Tanpa ini, siapa pun dengan anon key
--    bisa membaca seluruh isi tabel.
-- =====================================================================

-- Hapus policy lama supaya skrip ini aman dijalankan berulang kali
do $$
declare r record;
begin
  for r in select schemaname, tablename, policyname
           from pg_policies where schemaname = 'public'
  loop
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

alter table public.profiles          enable row level security;
alter table public.token_groups      enable row level security;
alter table public.memberships       enable row level security;
alter table public.consent_log       enable row level security;
alter table public.health_screening  enable row level security;
alter table public.movement_patterns enable row level security;
alter table public.muscles           enable row level security;
alter table public.exercises         enable row level security;
alter table public.programs          enable row level security;
alter table public.program_days      enable row level security;
alter table public.program_items     enable row level security;
alter table public.modules           enable row level security;
alter table public.module_items      enable row level security;
alter table public.tracks_music      enable row level security;
alter table public.user_programs     enable row level security;
alter table public.daily_logs        enable row level security;
alter table public.workout_sessions  enable row level security;
alter table public.session_sets      enable row level security;
alter table public.body_metrics      enable row level security;
alter table public.meals             enable row level security;
alter table public.habit_logs        enable row level security;
alter table public.daily_status      enable row level security;
alter table public.group_sessions    enable row level security;
alter table public.session_attendance enable row level security;

-- --- PROFIL ---
create policy "profil: lihat milik sendiri" on public.profiles
  for select using (id = auth.uid());
create policy "profil: ubah milik sendiri" on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());
-- Diperlukan karena aplikasi memakai upsert: kalau baris profil belum ada
-- (mis. akun dibuat sebelum trigger aktif), aplikasi membuatnya sendiri.
create policy "profil: buat milik sendiri" on public.profiles
  for insert to authenticated with check (id = auth.uid());
create policy "profil: admin lihat yang mengizinkan" on public.profiles
  for select using (public.is_admin() and izin_admin_ringkasan = true);
create policy "profil: teman grup lihat yang mengizinkan" on public.profiles
  for select using (izin_grup_status = true and public.is_group_mate(id));

-- --- KONTEN: semua pengguna login boleh baca, hanya admin boleh tulis ---
do $$
declare t text;
begin
  foreach t in array array['movement_patterns','muscles','exercises','programs',
                           'program_days','program_items','modules','module_items','tracks_music']
  loop
    execute format('create policy "konten: baca" on public.%I for select to authenticated using (true);', t);
    execute format('create policy "konten: tulis admin" on public.%I for all to authenticated using (public.is_admin()) with check (public.is_admin());', t);
  end loop;
end $$;

-- --- DATA PRIBADI: hanya pemiliknya ---
do $$
declare t text;
begin
  foreach t in array array['user_programs','daily_logs','workout_sessions','session_sets',
                           'body_metrics','meals','habit_logs']
  loop
    execute format('create policy "pribadi: semua operasi" on public.%I for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());', t);
  end loop;
end $$;

-- Admin boleh melihat log latihan HANYA jika pengguna memberi izin detail.
create policy "sesi: admin lihat bila diizinkan" on public.workout_sessions
  for select using (
    public.is_admin() and exists (
      select 1 from public.profiles p
      where p.id = workout_sessions.user_id and p.izin_admin_detail = true)
  );
create policy "set: admin lihat bila diizinkan" on public.session_sets
  for select using (
    public.is_admin() and exists (
      select 1 from public.profiles p
      where p.id = session_sets.user_id and p.izin_admin_detail = true)
  );

-- CATATAN PENTING: health_screening TIDAK punya policy admin sama sekali.
-- Jawaban skrining kesehatan tidak pernah bisa dibaca siapa pun selain pemiliknya.
create policy "skrining: milik sendiri" on public.health_screening
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "consent: milik sendiri" on public.consent_log
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- --- STATUS HARIAN: pemilik + teman grup yang diizinkan ---
create policy "status: milik sendiri" on public.daily_status
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "status: teman grup" on public.daily_status
  for select to authenticated using (
    public.is_group_mate(user_id) and exists (
      select 1 from public.profiles p
      where p.id = daily_status.user_id and p.izin_grup_status = true)
  );

-- --- GRUP ---
create policy "grup: anggota lihat grupnya" on public.token_groups
  for select to authenticated using (
    exists (select 1 from public.memberships m
            where m.group_id = token_groups.id and m.user_id = auth.uid())
    or public.is_admin()
  );
create policy "grup: admin kelola" on public.token_groups
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "membership: lihat milik sendiri & se-grup" on public.memberships
  for select to authenticated using (user_id = auth.uid() or public.is_group_mate(user_id));
create policy "membership: admin kelola" on public.memberships
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "sesi grup: anggota" on public.group_sessions
  for select to authenticated using (
    exists (select 1 from public.memberships m
            where m.group_id = group_sessions.group_id and m.user_id = auth.uid())
  );
create policy "sesi grup: admin kelola" on public.group_sessions
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "kehadiran: milik sendiri" on public.session_attendance
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "kehadiran: teman grup lihat" on public.session_attendance
  for select to authenticated using (public.is_group_mate(user_id));

-- =====================================================================
-- 7. INDEKS
-- =====================================================================
create index if not exists idx_daily_logs_user on public.daily_logs (user_id, tanggal desc);
create index if not exists idx_sessions_user on public.workout_sessions (user_id, tanggal desc);
create index if not exists idx_sets_session on public.session_sets (session_id);
create index if not exists idx_metrics_user on public.body_metrics (user_id, tanggal desc);
create index if not exists idx_meals_user on public.meals (user_id, tanggal desc);
create index if not exists idx_habits_user on public.habit_logs (user_id, tanggal desc);
create index if not exists idx_status_user on public.daily_status (user_id, tanggal desc);
create index if not exists idx_memb_user on public.memberships (user_id);
create index if not exists idx_memb_group on public.memberships (group_id);
create index if not exists idx_ex_pattern on public.exercises (pattern_id, level);

-- =====================================================================
-- 8. DATA AWAL — pola gerakan & otot
-- =====================================================================

insert into public.movement_patterns (id, nama) values
 ('squat',   '{"id":"Squat","en":"Squat"}'),
 ('hinge',   '{"id":"Hip Hinge","en":"Hip Hinge"}'),
 ('push_h',  '{"id":"Dorong Horizontal","en":"Horizontal Push"}'),
 ('push_v',  '{"id":"Dorong Vertikal","en":"Vertical Push"}'),
 ('pull_h',  '{"id":"Tarik Horizontal","en":"Horizontal Pull"}'),
 ('pull_v',  '{"id":"Tarik Vertikal","en":"Vertical Pull"}'),
 ('core',    '{"id":"Inti Tubuh","en":"Core"}'),
 ('arms',    '{"id":"Lengan","en":"Arms"}'),
 ('glute',   '{"id":"Bokong & Pinggul","en":"Glutes & Hips"}'),
 ('calf',    '{"id":"Betis","en":"Calves"}'),
 ('mobility','{"id":"Mobilitas","en":"Mobility"}')
on conflict (id) do nothing;

insert into public.muscles (id, nama, nama_latin, kelompok, tampil_di, otot_dalam) values
 ('dada',            '{"id":"Dada","en":"Chest"}',                 'Pectoralis major','dada','depan',false),
 ('bahu',            '{"id":"Bahu","en":"Shoulders"}',             'Deltoid','bahu','depan',false),
 ('bahu-belakang',   '{"id":"Bahu Belakang","en":"Rear Shoulders"}','Deltoid posterior','bahu-belakang','belakang',false),
 ('lengan-depan',    '{"id":"Bisep & Lengan Bawah","en":"Biceps & Forearms"}','Biceps brachii','lengan-depan','depan',false),
 ('lengan-belakang', '{"id":"Trisep","en":"Triceps"}',             'Triceps brachii','lengan-belakang','belakang',false),
 ('perut-atas',      '{"id":"Perut (penekanan atas)","en":"Abs (upper emphasis)"}','Rectus abdominis','perut-atas','depan',false),
 ('perut-bawah',     '{"id":"Perut (penekanan bawah)","en":"Abs (lower emphasis)"}','Rectus abdominis','perut-bawah','depan',false),
 ('obliq',           '{"id":"Perut Samping","en":"Obliques"}',     'Obliquus','obliq','depan',false),
 ('trapezius',       '{"id":"Trapezius","en":"Trapezius"}',        'Trapezius','trapezius','keduanya',false),
 ('punggung-atas',   '{"id":"Punggung Atas","en":"Upper Back"}',   'Rhomboid, Teres','punggung-atas','belakang',false),
 ('punggung-tengah', '{"id":"Punggung Tengah","en":"Mid Back"}',   'Latissimus dorsi','punggung-tengah','belakang',false),
 ('gluteus',         '{"id":"Bokong","en":"Glutes"}',              'Gluteus maximus','gluteus','belakang',false),
 ('paha-depan',      '{"id":"Paha Depan","en":"Quadriceps"}',      'Quadriceps femoris','paha-depan','depan',false),
 ('paha-dalam',      '{"id":"Paha Dalam","en":"Adductors"}',       'Adductor','paha-dalam','depan',false),
 ('paha-belakang',   '{"id":"Paha Belakang","en":"Hamstrings"}',   'Hamstrings','paha-belakang','belakang',false),
 ('betis-depan',     '{"id":"Tulang Kering","en":"Shins"}',        'Tibialis anterior','betis-depan','depan',false),
 ('betis-belakang',  '{"id":"Betis","en":"Calves"}',               'Gastrocnemius, Soleus','betis-belakang','belakang',false),
 ('leher',           '{"id":"Leher","en":"Neck"}',                 'Sternocleidomastoid','leher','depan',false),
 ('transversus',     '{"id":"Perut Dalam","en":"Deep Core"}',      'Transversus abdominis','-','depan',true),
 ('erector',         '{"id":"Punggung Bawah","en":"Lower Back"}',  'Erector spinae','punggung-tengah','belakang',false)
on conflict (id) do nothing;
