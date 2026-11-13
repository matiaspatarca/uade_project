-- Correr completo en Supabase > SQL Editor

create table categories (
  id      serial primary key,
  name    text not null,
  is_gold boolean not null default false      -- el "Oro" (se revela al final)
);

-- Cada equipo se carga UNA vez y compite en todas las categorías
create table teams (
  id          serial primary key,
  name        text not null,
  members     text not null default '',
  description text not null default '',
  image_url   text not null default ''
);

create table settings (
  id     int primary key default 1 check (id = 1),
  status text not null default 'pending' check (status in ('pending','open','closed')),
  revealed int not null default 0                     -- cuántos premios ya se revelaron en la ceremonia
);
insert into settings default values;

create table votes (
  id          bigserial primary key,
  category_id int not null references categories(id) on delete cascade,
  team_id     int not null references teams(id) on delete cascade,
  voter       text not null,
  created_at  timestamptz not null default now(),
  unique (category_id, voter),                       -- un voto por alumno y por categoría
  check (voter = lower(trim(voter)) and length(voter) between 3 and 60)
);

-- Contraseña del admin (sin policies: el cliente nunca la puede leer)
create table admin_secret (id int primary key default 1, password text not null);
insert into admin_secret (password) values ('CAMBIAME');   -- <<< CAMBIAR

alter table categories   enable row level security;
alter table teams        enable row level security;
alter table settings     enable row level security;
alter table votes        enable row level security;
alter table admin_secret enable row level security;

create policy "ver categorias" on categories for select using (true);
create policy "ver equipos"    on teams      for select using (true);
create policy "ver estado"     on settings   for select using (true);
-- Solo insertar votos y solo con la votación abierta. Sin select/update/delete.
create policy "votar" on votes for insert
  with check (exists (select 1 from settings where status = 'open'));

-- Resultados públicos: solo con la votación cerrada y solo de los premios ya revelados
create function get_results() returns table (category_id int, team_id int, votes bigint)
language sql security definer set search_path = public as $$
  with ord as (select id, row_number() over (order by is_gold, id) rn from categories)
  select c.id, t.id, count(v.id)
  from categories c join ord on ord.id = c.id cross join teams t
  left join votes v on v.category_id = c.id and v.team_id = t.id
  where (select status from settings) = 'closed' and ord.rn <= (select revealed from settings)
  group by c.id, t.id;
$$;

-- ===== Funciones de admin (validan la contraseña en el servidor) =====
create function _check_pw(pw text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if pw is distinct from (select password from admin_secret) then raise exception 'Contraseña incorrecta'; end if;
end $$;

create function admin_results(pw text) returns table (category_id int, team_id int, votes bigint)
language plpgsql security definer set search_path = public as $$
begin
  perform _check_pw(pw);
  return query select c.id, t.id, count(v.id) from categories c cross join teams t
    left join votes v on v.category_id = c.id and v.team_id = t.id group by c.id, t.id;
end $$;

create function admin_set_status(pw text, new_status text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _check_pw(pw);
  update settings set status = new_status, revealed = 0 where id = 1;
end $$;

-- Ceremonia: el admin va revelando premio por premio
create function admin_set_revealed(pw text, n int) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _check_pw(pw);
  update settings set revealed = greatest(0, n) where id = 1;
end $$;

-- Crea o edita (si trae id) una categoría o un equipo
create function admin_upsert(pw text, tbl text, payload jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare rid int := nullif(payload->>'id','')::int;
begin
  perform _check_pw(pw);
  if tbl = 'categories' then
    if rid is null then insert into categories (name, is_gold) values (payload->>'name', coalesce((payload->>'is_gold')::boolean,false));
    else update categories set name = payload->>'name', is_gold = coalesce((payload->>'is_gold')::boolean,false) where id = rid; end if;
  elsif tbl = 'teams' then
    if rid is null then insert into teams (name, members, description, image_url)
      values (payload->>'name', coalesce(payload->>'members',''), coalesce(payload->>'description',''), coalesce(payload->>'image_url',''));
    else update teams set name = payload->>'name', members = coalesce(payload->>'members',''),
      description = coalesce(payload->>'description',''), image_url = coalesce(payload->>'image_url','') where id = rid; end if;
  else raise exception 'Tabla inválida'; end if;
end $$;

create function admin_delete(pw text, tbl text, rid int) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _check_pw(pw);
  if tbl = 'categories' then delete from categories where id = rid;
  elsif tbl = 'teams' then delete from teams where id = rid;
  else raise exception 'Tabla inválida'; end if;
end $$;

revoke execute on function _check_pw(text) from public, anon, authenticated;

-- Realtime: avisar a los celulares cuando cambia el estado
alter publication supabase_realtime add table settings;

-- Categorías (se editan después desde /admin.html)
insert into categories (name, is_gold) values
  ('Mayor creatividad', false),
  ('Mejor adaptación al formato', false),
  ('Mejor criterio estético y visual', false),
  ('Historia más novedosa', false),
  ('🏆 Oro: Mejor producción periodística integral', true);

-- Equipos de ejemplo (se reemplazan desde el admin)
insert into teams (name, members, description, image_url) values
  ('Equipo 1', 'Integrantes del grupo', 'Descripción corta del proyecto.', 'https://picsum.photos/seed/t1/600/400'),
  ('Equipo 2', 'Integrantes del grupo', 'Descripción corta del proyecto.', 'https://picsum.photos/seed/t2/600/400'),
  ('Equipo 3', 'Integrantes del grupo', 'Descripción corta del proyecto.', 'https://picsum.photos/seed/t3/600/400');
