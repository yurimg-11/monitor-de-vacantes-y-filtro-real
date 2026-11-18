# Brújula · Monitor de vacantes

App web con PostgreSQL de Supabase, inicio de sesión, perfiles privados de habilidades, vacantes públicas y lista de guardados por cuenta. El porcentaje se calcula comparando las habilidades requeridas de cada vacante con las que la persona agrega a su perfil. La app no consulta portales automáticamente; las vacantes se importan desde `/admin`.

## 1. Crear la base Supabase

1. Crea un proyecto en [Supabase](https://supabase.com/dashboard).
2. En **SQL Editor**, ejecuta el archivo `supabase/schema.sql` completo.
3. En **Authentication → URL Configuration**, agrega la URL de tu app en **Site URL** y Redirect URLs.
4. En **Project Settings → API**, copia Project URL, anon/publishable key y service_role/secret key.
5. En Authentication, configura el proveedor Email y el correo de confirmación según cómo quieras permitir el registro.

El esquema da lectura pública a las vacantes. Cada usuario solo puede leer o actualizar su propio perfil y vacantes guardadas (políticas RLS). La clave `service_role` solo se configura en el servidor; no la publiques ni la pegues en el navegador.

## 2. Ejecutar localmente

Necesitas Node.js 20 o posterior.

```powershell
npm install
$env:SUPABASE_URL = "https://TU-PROYECTO.supabase.co"
$env:SUPABASE_ANON_KEY = "TU_ANON_KEY"
$env:SUPABASE_SERVICE_ROLE_KEY = "TU_SERVICE_ROLE_KEY"
$env:ADMIN_KEY = "elige-una-clave-larga"
npm start
```

Abre `http://localhost:3000`. Regístrate/inicia sesión en **Entrar** y añade tus habilidades en **Mi perfil**. Para importar vacantes, abre `http://localhost:3000/admin` e introduce el `ADMIN_KEY`.

## 3. Publicar en Render

1. Sube el contenido de esta carpeta a un repositorio Git.
2. En Render, crea un Blueprint desde el repositorio y confirma `render.yaml`.
3. En las variables de entorno del servicio, configura `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` y un `ADMIN_KEY` secreto.
4. En Supabase, añade la URL pública asignada por Render a **Site URL** y Redirect URLs.
5. Abre el sitio y carga vacantes en `/admin`.

## Cargar vacantes

El formulario `/admin` recibe una vacante o un arreglo JSON. Ejemplo:

```json
[{"title":"Diseñador UX","company":"Empresa","place":"México · Remoto","mode":"Remoto","salary":"$40,000 MXN","skills":["Figma","Accesibilidad"],"source":"Feed autorizado","verified":true,"desc":"Requisitos del puesto","url":"https://empresa.example/jobs/123"}]
```

Dos ofertas con el mismo título, empresa y ubicación se actualizan en vez de duplicarse. Las marcas de verificación, fuente y detalles los proporciona quien importa la oferta; la app no valida por su cuenta que la empresa o vacante sean legítimas. La carga automática desde portales requiere integrar fuentes o feeds con permiso de uso.
