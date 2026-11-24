# Brújula · Monitor de vacantes

App web con PostgreSQL de Supabase, inicio de sesión, perfiles privados de habilidades, vacantes públicas y lista de guardados por cuenta. El porcentaje se calcula comparando las habilidades requeridas de cada vacante con las que la persona agrega a su perfil. La app no consulta portales automáticamente; las vacantes se importan desde `/admin`.

## 1. Crear la base Supabase

1. Crea un proyecto en [Supabase](https://supabase.com/dashboard).
2. En **SQL Editor**, ejecuta el archivo `supabase/schema.sql` completo.
3. En **Authentication > URL Configuration**, deja **Site URL** en `https://monitor-de-vacantes-y-filtro-real.onrender.com` y agrega esa URL a **Redirect URLs** para que los enlaces de autenticación regresen al sitio publicado, nunca a localhost.
4. En **Project Settings → API**, copia Project URL, anon/publishable key y service_role/secret key.
5. En **Authentication > Sign In / Providers > Email**, desactiva **Confirm email** para permitir el acceso inmediatamente después del registro. Esto también marca la dirección como verificada sin comprobar que la persona controla ese correo; es solo para pruebas.

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
3. En las variables de entorno del servicio, configura `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `AUTH_REDIRECT_URL=https://monitor-de-vacantes-y-filtro-real.onrender.com` y un `ADMIN_KEY` secreto.
4. Confirma que **Site URL** y Redirect URLs en Supabase usan la URL publica de Render (no localhost).
5. Abre el sitio y carga vacantes en `/admin`.

## Cargar vacantes

El formulario `/admin` recibe una vacante o un arreglo JSON. Ejemplo:

```json
[{"title":"Diseñador UX","company":"Empresa","place":"México · Remoto","mode":"Remoto","salary":"$40,000 MXN","skills":["Figma","Accesibilidad"],"source":"Feed autorizado","verified":true,"desc":"Requisitos del puesto","url":"https://empresa.example/jobs/123"}]
```

Dos ofertas con el mismo título, empresa y ubicación se actualizan en vez de duplicarse. Las marcas de verificación, fuente y detalles los proporciona quien importa la oferta; la app no valida por su cuenta que la empresa o vacante sean legítimas. La carga automática desde portales requiere integrar fuentes o feeds con permiso de uso.


## Flujo de empleo y empresas

- Candidatos: crear cuenta, cargar CV privado, agregar habilidades, guardar empleos y postularse desde la ficha. La empresa solo puede abrir el CV despues de recibir una postulacion.
- Empresas: abre `/empresas`, inicia sesion, registra la empresa y, una vez verificada, envia vacantes para revision.
- Moderacion: abre `/admin`, ingresa `ADMIN_KEY`, verifica empresas y aprueba o rechaza vacantes. Solo vacantes publicadas aparecen en Explorar empleos.
- Ejecuta de nuevo el archivo completo `supabase/schema.sql` en SQL Editor para crear las tablas y politicas nuevas.
- No hay feeds automaticos de OCC o LinkedIn conectados. Las vacantes de empresas se publican desde el portal despues de revision; otras fuentes requieren una integracion autorizada.

## Verificacion, contratacion y notificaciones

La verificacion de empresas se hace manualmente en `/admin`: se consulta razon social y FME en el RPC/SIGER, y se guarda una nota de revision. El correo corporativo confirmado que coincide con el dominio del sitio es una comprobacion adicional. No se ejecutan consultas pagadas. Los candidatos reciben notificaciones dentro de Brujula cuando RR. HH. cambia el estado de su postulacion o cierra la vacante. Al marcar como contratadas tantas personas como plazas indicadas, la vacante se cierra y deja de aparecer en busquedas. RR. HH. puede solicitar reactivarla desde `/empresas`; vuelve a revision antes de publicarse. Las notificaciones son dentro de la app, no por correo.

Para empresas en Mexico, `/empresas` pide razon social, FME, sitio y correo corporativo confirmado con el mismo dominio. `/admin` abre la consulta oficial del Registro Publico de Comercio (SIGER); el equipo consulta manualmente la razon social y el FME en el RPC/SIGER desde `/admin`, anota el resultado y aprueba. No se conecta ni se cobra ninguna API de verificacion. La existencia registral se valida manualmente; el correo corporativo confirmado es una comprobacion adicional.
