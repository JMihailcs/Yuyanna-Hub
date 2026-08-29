# Subida de media a Cloudflare R2 (Worker)

La app sube imágenes/videos a este **Worker**, que los guarda en un bucket **R2**
y devuelve una URL pública que sirve el propio Worker. Así las llaves de R2 nunca
viven en la app.

```
App --archivo--> Worker (/upload) --> R2
App <---URL------ Worker
Feed <--bytes--- Worker (/file/<clave>)
```

## Pasos (una sola vez)

1. **Activa R2** en el panel de Cloudflare (dashboard → R2). Puede pedir agregar
   un método de pago para activarlo, pero el uso queda **gratis** dentro del free
   tier (10 GB almacenamiento, egress $0).

2. **Crea el bucket** llamado `yuyanna-media` (dashboard → R2 → *Create bucket*).
   Si usas otro nombre, cámbialo en `wrangler.toml`.

3. **Instala wrangler y entra:**
   ```fish
   npm install -g wrangler
   wrangler login
   ```

4. **Despliega el Worker** (desde esta carpeta `cloudflare/`):
   ```fish
   cd cloudflare
   wrangler deploy
   ```
   No hay ningún secreto que cargar. El único ajuste es
   `FIREBASE_PROJECT_ID` en `wrangler.toml`, que es un identificador público.
   Al terminar te da la URL del Worker, ej:
   `https://yuyanna-uploads.tu-subdominio.workers.dev`

5. **Configura la app** en `lib/services/media_upload_service.dart` →
   `MediaConfig.workerUrl` = la URL del Worker (sin barra final).

6. Reinicia la app (`R` en flutter run). Inicia sesión con una cuenta que tenga
   documento en `admins/{uid}`; al crear un evento, el botón de subir ya
   funciona. Con una cuenta sin rol admin el Worker responde 403.

## Notas

- **Tamaño**: el body de un request a Workers está limitado (~100 MB). Para el
  piloto usa clips cortos; la app ya limita el video a 2 min.
- **Seguridad**: `/upload` exige `Authorization: Bearer <idToken de Firebase>`.
  El Worker verifica la firma RS256 contra las claves **públicas** de Google
  (`securetoken@system.gserviceaccount.com`), comprueba `aud`, `iss` y vigencia,
  y luego consulta `admins/{uid}` en Firestore con el token del propio usuario
  —la misma condición que `tieneRolAdmin()` en `firestore.rules`—. No hay
  secreto compartido: no queda nada extraíble del APK ni del bundle web, y
  quitarle el rol a alguien le corta el acceso al bucket de inmediato.
- **Lectura**: `GET /file/<clave>` sigue siendo público, porque el feed muestra
  el material a cualquier estudiante.
- **Android/cámara**: subir desde galería no necesita permisos; para la **cámara**
  agrega en `android/app/src/main/AndroidManifest.xml`:
  `<uses-permission android:name="android.permission.CAMERA"/>`.
