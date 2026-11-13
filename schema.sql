-- Correr completo en Supabase > SQL Editor

create table categories (
  id      serial primary key,
  name    text not null,
  is_gold boolean not null default false      -- el "Oscar de oro" (se revela al final)
);

create table nominees (
  id          serial primary key,
  category_id int not null references categories(id) on delete cascade,
  name        text not null,
  members     text not null default '',
  description text not null default '',
  image_url   text not null default '',
  unique (id, category_id)
);

create table settings (
  id     int primary key default 1 check (id = 1),
  status text not null default 'pending' check (status in ('pending','open','closed'))
);
insert into settings default values;

create table votes (
  id          bigserial primary key,
  category_id int not null,
  nominee_id  int not null,
  voter       text not null,
  created_at  timestamptz not null default now(),
  unique (category_id, voter),                                   -- un voto por alumno y por categoría
  foreign key (nominee_id, category_id) references nominees(id, category_id) on delete cascade,
  check (voter = lower(trim(voter)) and length(voter) between 3 and 60)
);

-- Contraseña del admin (sin policies: el cliente nunca la puede leer)
create table admin_secret (id int primary key default 1, password text not null);
insert into admin_secret (password) values ('CAMBIAME');   -- <<< CAMBIAR

-- RLS
alter table categories   enable row level security;
alter table nominees     enable row level security;
alter table settings     enable row level security;
alter table votes        enable row level security;
alter table admin_secret enable row level security;

create policy "ver categorias" on categories for select using (true);
create policy "ver nominados"  on nominees   for select using (true);
create policy "ver estado"     on settings   for select using (true);
-- Solo insertar votos y solo con la votación abierta. Sin select/update/delete.
create policy "votar" on votes for insert
  with check (exists (select 1 from settings where status = 'open'));

-- Resultados públicos: solo con la votación cerrada
create function get_results() returns table (category_id int, nominee_id int, votes bigint)
language sql security definer set search_path = public as $$
  select n.category_id, n.id, count(v.id) from nominees n
  left join votes v on v.nominee_id = n.id
  where (select status from settings) = 'closed'
  group by n.id;
$$;

-- ===== Funciones de admin (validan la contraseña en el servidor) =====
create function _check_pw(pw text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if pw is distinct from (select password from admin_secret) then raise exception 'Contraseña incorrecta'; end if;
end $$;

create function admin_results(pw text) returns table (category_id int, nominee_id int, votes bigint)
language plpgsql security definer set search_path = public as $$
begin
  perform _check_pw(pw);
  return query select n.category_id, n.id, count(v.id) from nominees n
    left join votes v on v.nominee_id = n.id group by n.id;
end $$;

create function admin_set_status(pw text, new_status text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _check_pw(pw);
  update settings set status = new_status where id = 1;
end $$;

-- Crea o edita (si trae id) una categoría o un nominado
create function admin_upsert(pw text, tbl text, row jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare rid int := nullif(row->>'id','')::int;
begin
  perform _check_pw(pw);
  if tbl = 'categories' then
    if rid is null then insert into categories (name, is_gold) values (row->>'name', coalesce((row->>'is_gold')::boolean,false));
    else update categories set name = row->>'name', is_gold = coalesce((row->>'is_gold')::boolean,false) where id = rid; end if;
  elsif tbl = 'nominees' then
    if rid is null then insert into nominees (category_id, name, members, description, image_url)
      values ((row->>'category_id')::int, row->>'name', coalesce(row->>'members',''), coalesce(row->>'description',''), coalesce(row->>'image_url',''));
    else update nominees set name = row->>'name', members = coalesce(row->>'members',''),
      description = coalesce(row->>'description',''), image_url = coalesce(row->>'image_url','') where id = rid; end if;
  else raise exception 'Tabla inválida'; end if;
end $$;

create function admin_delete(pw text, tbl text, rid int) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _check_pw(pw);
  if tbl = 'categories' then delete from categories where id = rid;
  elsif tbl = 'nominees' then delete from nominees where id = rid;
  else raise exception 'Tabla inválida'; end if;
end $$;

-- Las funciones _check_pw no deben ser llamables directo
revoke execute on function _check_pw(text) from public, anon, authenticated;

-- Realtime: avisar a los celulares cuando cambia el estado
alter publication supabase_realtime add table settings;

-- Ejemplo (se edita después desde /admin.html)
insert into categories (name, is_gold) values
  ('Mejor cobertura', false), ('Mejor trabajo completo', false), ('Mejor fotografía', false), ('🏆 Oro: Mejor proyecto del año', true);
insert into nominees (category_id, name, members, description, image_url) values
  (1, 'Inundaciones en el Conurbano', 'Lucía Pérez, Martín Gómez', 'Cobertura minuto a minuto desde el territorio.', 'https://picsum.photos/seed/a/600/400'),
  (1, 'Elecciones en vivo',           'Sofía Díaz, Tomás Ruiz',    'Seguimiento de la jornada electoral en 12 horas.',  'https://picsum.photos/seed/b/600/400'),
  (2, 'Crónica de un barrio',         'Camila Sosa',               'Reportaje multimedia de largo aliento.',            'https://picsum.photos/seed/c/600/400'),
  (2, 'Podcast Última Hora',          'Joaquín Vega, Valentina Luna','Serie narrativa sobre el periodismo local.',     'https://picsum.photos/seed/d/600/400'),
  (3, 'Miradas del Sur',              'Nico Herrera',              'Ensayo fotográfico de la costa.',                   'https://picsum.photos/seed/e/600/400'),
  (3, 'Retratos del paro',            'Ana Torres',                'Fotorreportaje de la movilización.',                'https://picsum.photos/seed/f/600/400'),
  (4, 'Crónica de un barrio',         'Camila Sosa',               'Reportaje multimedia de largo aliento.',            'https://picsum.photos/seed/c/600/400'),
  (4, 'Inundaciones en el Conurbano', 'Lucía Pérez, Martín Gómez', 'Cobertura minuto a minuto desde el territorio.',   'https://picsum.photos/seed/a/600/400');
