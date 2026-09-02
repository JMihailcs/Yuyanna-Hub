# Yuyanna Hub

Aplicación Flutter para estudiantes de la **UNSAAC** (Universidad Nacional de San
Antonio Abad del Cusco): un feed de *convocatorias* —hackatones, incubación,
pre incubación— y un motor que ayuda a **formar equipos** para postular a ellas.

Cuando un líder publica un grupo declarando qué habilidades le faltan, el sistema
recorre el directorio real de estudiantes, puntúa a cada candidato e invita
automáticamente a los mejores perfiles. Nadie tiene que buscar compañeros a mano.

## Qué hace

- **Feed vertical** de convocatorias al estilo TikTok, con imagen o video a
  pantalla completa.
- **Registro y perfil** con escuela profesional, semestre y habilidades.
- **Formación de equipos**: crear grupo → declarar el déficit de habilidades →
  publicar → el motor invita a los diez mejores perfiles.
- **Bandeja de invitaciones**: el invitado se une con un toque, sin esperar al
  líder.
- **Solicitudes de ingreso** para quien quiere entrar a un grupo que no lo
  invitó; las resuelve el líder.
- **Cierre en cascada**: al llenarse el cupo el grupo se cierra y las
  invitaciones y solicitudes pendientes se expiran o rechazan solas.
- **Panel de administración** para publicar convocatorias y gestionar roles.

## El motor de emparejamiento

Para cada candidato *u* y grupo *g*:

```
Score(u, g) = 10 · |habilidades coincidentes| + min(semestre(u), 9)
```

El desempate por semestre está acotado a 9, estrictamente menor que los 10 puntos
que vale una habilidad, así que **cubrir el déficit siempre domina a la
antigüedad**: un estudiante de primer ciclo con dos habilidades coincidentes
supera a uno de décimo con una sola. La comparación de habilidades tolera tildes,
mayúsculas y variantes por contención («Flutter» ≈ «flutter/dart»).

Solo se invita a quien tenga al menos una coincidencia; si no hay ninguna, no se
envía nada y la app lo dice explícitamente.

## Stack

| Capa | Tecnología |
|---|---|
| Cliente | Flutter (Dart SDK `^3.11.4`), Android y web |
| Autenticación | Firebase Authentication (correo/contraseña) |
| Base de datos | Cloud Firestore (plan gratuito *Spark*) |
| Media | Cloudflare Worker + R2 |
| Estado y rutas | `setState` y `Navigator` — sin paquetes de estado ni de ruteo |

Sin generación de código, sin `build_runner`. Los modelos son clases inmutables
con `fromJson`/`toJson` escritos a mano.

## Puesta en marcha

```sh
flutter pub get
flutter run              # o: flutter run -d chrome
```

Para conectar tu propio proyecto Firebase, reemplazá `lib/firebase_options.dart`
y `android/app/google-services.json` con los que genere `flutterfire configure`,
y desplegá las reglas:

```sh
firebase deploy --only firestore:rules
```

El primer administrador se auto-aprovisiona: el correo listado en
`esFundador()` dentro de `firestore.rules` —que debe coincidir con
`AdminService.correosFundadores`— obtiene su documento en `admins/{uid}` al
entrar por primera vez. Desde el panel puede promover a otros.

Para la subida de imágenes y videos, ver [`cloudflare/README.md`](cloudflare/README.md).

## Pruebas

```sh
flutter test                 # 15 pruebas
flutter analyze              # sin observaciones
```

Las pruebas corren contra `fake_cloud_firestore` y `firebase_auth_mocks`, así que
verifican el comportamiento real de los servicios —consultas y escrituras
incluidas— sin tocar la base de datos de producción ni requerir conexión.
`test/diagnostico_matching_test.dart` recorre el camino completo de la
aplicación: alta con `AuthService.registrar`, creación y publicación del grupo, y
lectura de la bandeja de invitaciones.

## Estructura

```
lib/
  models/      Clases inmutables (Usuario, Convocatoria, Grupo, ...)
  services/    Firebase: auth, convocatorias, grupos, admin, media
  screens/     Pantallas (StatefulWidget + setState)
  widgets/     UI compartida
  theme/       Colores, tipografía y tema Material 3
  database/    Caché de sesión sobre shared_preferences
cloudflare/    Worker de subida y entrega de media (R2)
docs/          Modelo de datos e informe final
firestore.rules
```

## Seguridad

- **Subidas de media**: el Worker exige el *ID token* de Firebase del usuario,
  verifica la firma RS256 contra las claves públicas de Google y comprueba su rol
  en `admins/{uid}`. No hay secretos compartidos embebidos en la app.
- **Claves de Firebase**: las `apiKey` de `lib/firebase_options.dart` y de
  `google-services.json` son identificadores públicos de cliente, no
  credenciales. El control de acceso vive en `firestore.rules`. Conviene
  restringirlas por dominio y por firma de la app en Google Cloud Console.
- **Trade-off conocido**: la lógica de equipos corre en el cliente y escribe
  documentos de otros usuarios (al llenarse un grupo expira invitaciones ajenas),
  así que `firestore.rules` permite escritura autenticada sobre `grupos`,
  `invitaciones` y `solicitudes`. Es una concesión del plan gratuito: la
  corrección es mover esas operaciones a Cloud Functions al migrar a Blaze.

## Documentación

- [`docs/Informe_Final/main.pdf`](docs/Informe_Final/main.pdf) — informe
  completo: requerimientos, arquitectura, modelo de datos, motor de
  emparejamiento, pruebas, trazabilidad y limitaciones.
- [`docs/DB/`](docs/DB) — modelo de datos.

## Estado

Piloto funcional. Las limitaciones principales están documentadas en el §10 del
informe; la más visible para el usuario es que **no hay notificaciones push**: el
plan gratuito de Firebase no incluye Cloud Functions ni FCM, así que el único
aviso de una invitación es el contador dentro de la aplicación.
