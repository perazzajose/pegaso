-- ============================================================
-- Pegaso Chuy · esquema demo (Supabase)
-- ============================================================

-- Animales en adopción
create table if not exists public.animales (
  id            uuid primary key default gen_random_uuid(),
  nombre        text not null,
  especie       text not null check (especie in ('Perro','Gato','Otro')),
  sexo          text check (sexo in ('Macho','Hembra')),
  edad_aprox    text,                      -- "2 meses", "3 años"
  tamano        text check (tamano in ('Chico','Mediano','Grande')),
  descripcion   text,
  castrado      boolean default false,
  vacunado      boolean default false,
  estado        text not null default 'En adopción'
                check (estado in ('En adopción','Reservado','Adoptado','En tránsito')),
  fotos         text[] default '{}',       -- URLs públicas (storage)
  destacado     boolean default false,
  creado_en     timestamptz default now(),
  actualizado_en timestamptz default now()
);

-- Solicitudes de adopción (formulario público)
create table if not exists public.solicitudes_adopcion (
  id              uuid primary key default gen_random_uuid(),
  animal_id       uuid references public.animales(id) on delete set null,
  nombre          text not null,
  telefono        text not null,
  email           text,
  localidad       text,
  vivienda        text,          -- casa con patio, apartamento, etc.
  otros_animales  text,
  compra_venta    boolean not null default false,  -- ¿compra o vende animales?
  acepta_seguimiento boolean not null default false,
  mensaje         text,
  estado          text not null default 'Nueva'
                  check (estado in ('Nueva','En revisión','Aprobada','Rechazada')),
  creado_en       timestamptz default now()
);

-- Ofrecimientos de ayuda (voluntarios, tránsito, donaciones en especie)
create table if not exists public.ofrecimientos (
  id         uuid primary key default gen_random_uuid(),
  tipo       text not null check (tipo in ('Voluntariado','Hogar de tránsito','Donación de alimento','Otro')),
  nombre     text not null,
  telefono   text not null,
  mensaje    text,
  creado_en  timestamptz default now()
);

-- Trigger de fecha de actualización
create or replace function public.set_actualizado_en() returns trigger
language plpgsql as $$ begin new.actualizado_en = now(); return new; end $$;
drop trigger if exists trg_animales_upd on public.animales;
create trigger trg_animales_upd before update on public.animales
for each row execute function public.set_actualizado_en();

-- ------------------------------------------------------------
-- Seguridad (RLS)
--   público (anon): ve animales, puede enviar solicitudes/ofrecimientos
--   voluntarios logueados (authenticated): gestionan todo
-- ------------------------------------------------------------
alter table public.animales             enable row level security;
alter table public.solicitudes_adopcion enable row level security;
alter table public.ofrecimientos        enable row level security;

grant select on public.animales to anon, authenticated;
grant insert on public.solicitudes_adopcion, public.ofrecimientos to anon, authenticated;
grant all on public.animales, public.solicitudes_adopcion, public.ofrecimientos to authenticated;

drop policy if exists "animales: lectura pública" on public.animales;
create policy "animales: lectura pública" on public.animales
  for select to anon, authenticated using (true);
drop policy if exists "animales: gestión voluntarios" on public.animales;
create policy "animales: gestión voluntarios" on public.animales
  for all to authenticated using (true) with check (true);

drop policy if exists "solicitudes: enviar" on public.solicitudes_adopcion;
create policy "solicitudes: enviar" on public.solicitudes_adopcion
  for insert to anon, authenticated with check (estado = 'Nueva');
drop policy if exists "solicitudes: gestión voluntarios" on public.solicitudes_adopcion;
create policy "solicitudes: gestión voluntarios" on public.solicitudes_adopcion
  for all to authenticated using (true) with check (true);

drop policy if exists "ofrecimientos: enviar" on public.ofrecimientos;
create policy "ofrecimientos: enviar" on public.ofrecimientos
  for insert to anon, authenticated with check (true);
drop policy if exists "ofrecimientos: gestión voluntarios" on public.ofrecimientos;
create policy "ofrecimientos: gestión voluntarios" on public.ofrecimientos
  for all to authenticated using (true) with check (true);

-- ------------------------------------------------------------
-- Storage: bucket público para fotos
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('fotos', 'fotos', true)
on conflict (id) do nothing;

drop policy if exists "fotos: subir voluntarios" on storage.objects;
create policy "fotos: subir voluntarios" on storage.objects
  for insert to authenticated with check (bucket_id = 'fotos');
drop policy if exists "fotos: borrar voluntarios" on storage.objects;
create policy "fotos: borrar voluntarios" on storage.objects
  for delete to authenticated using (bucket_id = 'fotos');

-- ------------------------------------------------------------
-- Datos de demo (se borran cuando carguen los reales)
-- ------------------------------------------------------------
insert into public.animales (nombre, especie, sexo, edad_aprox, tamano, descripcion, castrado, vacunado, estado, fotos, destacado) values
('Luna',   'Perro','Hembra','2 años',  'Mediano','Cariñosa y tranquila. Se lleva bien con otros perros. Ideal para familia.', true,  true, 'En adopción', array['https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=800&q=70'], true),
('Toto',   'Perro','Macho', '4 meses', 'Chico',  'Cachorro juguetón rescatado en la rambla. Muy sociable con niños.',       false, true, 'En adopción', array['https://images.unsplash.com/photo-1587300003388-59208cc962cb?w=800&q=70'], true),
('Michi',  'Gato', 'Macho', '1 año',   'Chico',  'Gato independiente pero mimoso. Usa bandeja sanitaria.',                  true,  true, 'En adopción', array['https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=800&q=70'], true),
('Negra',  'Perro','Hembra','6 años',  'Grande', 'Adulta, muy guardiana y fiel. Busca un hogar con patio.',                 true,  true, 'En adopción', array['https://images.unsplash.com/photo-1561037404-61cd46aa615b?w=800&q=70'], false),
('Pelusa', 'Gato', 'Hembra','3 meses', 'Chico',  'Gatita tricolor, curiosa y juguetona.',                                   false, true, 'Reservado',   array['https://images.unsplash.com/photo-1574158622682-e40e69881006?w=800&q=70'], false),
('Rocky',  'Perro','Macho', '3 años',  'Grande', 'Rescatado en mal estado, hoy recuperado y lleno de energía.',             true,  true, 'Adoptado',    array['https://images.unsplash.com/photo-1518717758536-85ae29035b6d?w=800&q=70'], false);

-- ============================================================
-- Parte 2: solo voluntarios autorizados pueden gestionar
-- ============================================================
create table if not exists public.voluntarios (
  user_id uuid primary key references auth.users(id) on delete cascade,
  nombre text,
  creado_en timestamptz default now()
);
alter table public.voluntarios enable row level security;
grant select on public.voluntarios to authenticated;

create or replace function public.es_voluntario() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.voluntarios v where v.user_id = auth.uid());
$$;
grant execute on function public.es_voluntario() to anon, authenticated;

drop policy if exists "voluntarios: verse a si mismo" on public.voluntarios;
create policy "voluntarios: verse a si mismo" on public.voluntarios for select to authenticated using (user_id = auth.uid());

drop policy if exists "animales: gestión voluntarios" on public.animales;
create policy "animales: gestión voluntarios" on public.animales for all to authenticated using (public.es_voluntario()) with check (public.es_voluntario());
drop policy if exists "solicitudes: gestión voluntarios" on public.solicitudes_adopcion;
create policy "solicitudes: gestión voluntarios" on public.solicitudes_adopcion for all to authenticated using (public.es_voluntario()) with check (public.es_voluntario());
drop policy if exists "ofrecimientos: gestión voluntarios" on public.ofrecimientos;
create policy "ofrecimientos: gestión voluntarios" on public.ofrecimientos for all to authenticated using (public.es_voluntario()) with check (public.es_voluntario());
drop policy if exists "fotos: subir voluntarios" on storage.objects;
create policy "fotos: subir voluntarios" on storage.objects for insert to authenticated with check (bucket_id = 'fotos' and public.es_voluntario());
drop policy if exists "fotos: borrar voluntarios" on storage.objects;
create policy "fotos: borrar voluntarios" on storage.objects for delete to authenticated using (bucket_id = 'fotos' and public.es_voluntario());

-- ============================================================
-- Parte 3: veterinarias (mapa, horarios y turno)
-- horario: "Lu-Vi 09:00-12:00,15:00-19:00; Sá 09:00-13:00"  o  "24h"
-- ============================================================
create table if not exists public.veterinarias (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  direccion text,
  telefono text,
  lat double precision not null,
  lng double precision not null,
  horario text,
  urgencias boolean default false,
  de_turno_hasta timestamptz,
  activa boolean default true,
  creado_en timestamptz default now()
);
alter table public.veterinarias enable row level security;
grant select on public.veterinarias to anon, authenticated;
grant all on public.veterinarias to authenticated;
create policy "veterinarias: lectura pública" on public.veterinarias for select to anon, authenticated using (activa or public.es_voluntario());
create policy "veterinarias: gestión voluntarios" on public.veterinarias for all to authenticated using (public.es_voluntario()) with check (public.es_voluntario());
