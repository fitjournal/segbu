-- =====================================================================
-- RESET TOTAL — hapus semua tabel aplikasi, lalu jalankan schema.sql lagi.
-- HANYA untuk proyek yang belum berisi data sungguhan.
-- Akun di Authentication TIDAK ikut terhapus (hapus manual bila perlu).
-- =====================================================================

drop table if exists public.session_attendance cascade;
drop table if exists public.group_sessions     cascade;
drop table if exists public.daily_status       cascade;
drop table if exists public.habit_logs         cascade;
drop table if exists public.meals              cascade;
drop table if exists public.body_metrics       cascade;
drop table if exists public.session_sets       cascade;
drop table if exists public.workout_sessions   cascade;
drop table if exists public.daily_logs         cascade;
drop table if exists public.user_programs      cascade;
drop table if exists public.tracks_music       cascade;
drop table if exists public.module_items       cascade;
drop table if exists public.modules            cascade;
drop table if exists public.program_items      cascade;
drop table if exists public.program_days       cascade;
drop table if exists public.programs           cascade;
drop table if exists public.exercises          cascade;
drop table if exists public.muscles            cascade;
drop table if exists public.movement_patterns  cascade;
drop table if exists public.health_screening   cascade;
drop table if exists public.consent_log        cascade;
drop table if exists public.memberships        cascade;
drop table if exists public.token_groups       cascade;
drop table if exists public.profiles           cascade;

drop function if exists public.redeem_token(text)   cascade;
drop function if exists public.cek_token(text)      cascade;
drop function if exists public.is_group_mate(uuid)  cascade;
drop function if exists public.is_admin()           cascade;
drop trigger  if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user()    cascade;
