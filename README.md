# ONG Pegaso Chuy · sitio de adopciones

Sitio donado por [ConectaTuMundo](https://conectatumundo.net) a la ONG Pegaso Chuy.

- **Sitio público** (`index.html`): animales en adopción, solicitud de adopción, cómo ayudar, finales felices.
- **Panel de voluntarios** (`admin.html`): cargar animales con foto desde el celular, cambiar estados, ver solicitudes y ofrecimientos.
- **Backend**: Supabase (Postgres + Storage + Auth). Esquema y políticas en `supabase-schema.sql`.
- **Configuración**: todo lo propio de la ONG está en `config.js`.

## Dar de alta un voluntario
1. Supabase → Authentication → Users → *Add user* (email + contraseña, marcar "Auto confirm").
2. SQL Editor:
   ```sql
   insert into public.voluntarios (user_id, nombre)
   select id, 'Nombre' from auth.users where email = 'voluntario@ejemplo.com';
   ```

## Mantenimiento
`.github/workflows/keep-alive.yml` consulta la base cada 3 días para que el plan gratis no se pause.
