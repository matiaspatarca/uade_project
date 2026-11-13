# Los Premios — votación por categorías

Sitio estático (HTML + Tailwind + supabase-js) con Supabase de backend. Los alumnos votan una vez por categoría (incluido el "Oro") y al cerrar se abren los "sobres" con confeti.

## Puesta en marcha

1. **Supabase**: creá un proyecto en [supabase.com](https://supabase.com).
2. **SQL**: en *SQL Editor* pegá y corré `schema.sql`. Antes cambiá `CAMBIAME` (contraseña del admin).
3. **Claves**: en *Project Settings → API* copiá `Project URL` y `anon public key` y pegalas en `SUPABASE_URL` / `SUPABASE_ANON_KEY` al principio del script de `index.html` **y** `admin.html`.
4. **GitHub**: subí la carpeta a un repo.
5. **Vercel**: *Add New → Project* → importá el repo → *Deploy* (sin build).

## Compartirlo con tu novia

Pasale dos cosas: la URL de admin (`https://tu-sitio.vercel.app/admin.html`) y la contraseña. Desde ahí ella puede, sin tocar código:

- **Editar categorías y nominados** (nombre, integrantes, descripción, foto por link), agregar y borrar.
- Marcar una categoría como **Oro** (va última y con confeti dorado).
- **Abrir / pausar / cerrar** la votación y ver resultados en vivo.
- Ver y mostrar el **QR** con el link para los alumnos (clic derecho → guardar imagen para proyectarlo o imprimirlo).

Conviene que edite todo *antes* de abrir la votación: si borra un nominado, se borran sus votos.

## Cómo es el evento

1. Los alumnos escanean el QR, ingresan su legajo y votan categoría por categoría (un voto por legajo y categoría, garantizado en la base).
2. Mientras está abierta, los resultados quedan ocultos (solo el admin los ve en vivo).
3. Al cerrar, todos los celulares pasan solos a la pantalla de sobres: cada toque revela al ganador de esa categoría.

## Seguridad

- El cliente solo puede **insertar** votos y solo con la votación abierta; no puede leerlos, modificarlos ni borrarlos.
- Los resultados públicos salen de una función que devuelve datos solo con la votación cerrada. Editar y administrar pasa por funciones que validan la contraseña en el servidor.
- El legajo no se verifica contra un padrón: es un sistema para un evento de facultad, no a prueba de fraude.
