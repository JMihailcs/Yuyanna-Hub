import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yuyanna_hub/models/grupo.dart';
import 'package:yuyanna_hub/models/invitacion_grupo.dart';
import 'package:yuyanna_hub/models/usuario.dart';
import 'package:yuyanna_hub/services/auth_service.dart';
import 'package:yuyanna_hub/services/grupo_service.dart';

/// Prueba de extremo a extremo del camino REAL de la app: los perfiles se
/// crean con [AuthService.registrar] (que es quien escribe en `usuarios`),
/// no sembrados a mano, para detectar cualquier desajuste entre lo que el
/// registro guarda y lo que el motor de emparejamiento lee.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<Usuario> registrar(
    FakeFirebaseFirestore db, {
    required String nombre,
    required List<String> habilidades,
    required int semestre,
  }) {
    return AuthService(auth: MockFirebaseAuth(), firestore: db).registrar(
      nombre: nombre,
      correo: '${nombre.toLowerCase()}@unsaac.edu.pe',
      habilidades: habilidades,
      password: 'secreto123',
      escuelaProfesional: 'Ingeniería Informática',
      semestre: semestre,
    );
  }

  test('registrarse, publicar un grupo y recibir la invitación en la bandeja',
      () async {
    final FakeFirebaseFirestore db = FakeFirebaseFirestore();

    final Usuario ana = await registrar(
      db,
      nombre: 'Ana',
      habilidades: <String>['Flutter', 'Firebase'],
      semestre: 7,
    );
    await registrar(
      db,
      nombre: 'Beto',
      habilidades: <String>['Contabilidad'],
      semestre: 5,
    );
    final Usuario lider = await registrar(
      db,
      nombre: 'Lider',
      habilidades: <String>['Pitch'],
      semestre: 8,
    );

    final GrupoService grupos = GrupoService(firestore: db);

    // El registro deja los tres perfiles en el directorio que alimenta el
    // emparejamiento.
    expect((await grupos.getUsuarios()).length, 3);

    final Grupo grupo = await grupos.crearGrupo(
      convocatoriaId: 'CV-1',
      nombre: 'EcoTurix',
      descripcion: 'Equipo de prueba para el emparejamiento.',
      lider: lider,
      capacidadMax: 4,
      habilidadesBuscadas: <String>['Flutter'],
    );

    final ResultadoPublicacion resultado = await grupos.publicarGrupo(
      grupoId: grupo.id,
      usuarioSesion: lider,
    );

    // Solo Ana cubre "Flutter": Beto no coincide y el líder ya es miembro.
    expect(resultado.invitaciones.length, 1);
    expect(resultado.invitaciones.single.usuario.id, ana.id);

    // Ana ve la invitación en su bandeja (lo que lee NotificacionesScreen).
    final List<InvitacionGrupo> bandeja =
        await grupos.getInvitacionesParaUsuario(ana);
    expect(bandeja.length, 1);
    expect(bandeja.single.grupoNombre, 'EcoTurix');
  });

  test('un grupo publicado sin habilidades buscadas no notifica a nadie',
      () async {
    final FakeFirebaseFirestore db = FakeFirebaseFirestore();
    await registrar(
      db,
      nombre: 'Ana',
      habilidades: <String>['Flutter'],
      semestre: 7,
    );
    final Usuario lider = await registrar(
      db,
      nombre: 'Lider',
      habilidades: <String>['Pitch'],
      semestre: 8,
    );

    final GrupoService grupos = GrupoService(firestore: db);
    final Grupo grupo = await grupos.crearGrupo(
      convocatoriaId: 'CV-1',
      nombre: 'Sin habilidades',
      descripcion: 'El líder no declaró qué habilidades le faltan.',
      lider: lider,
      capacidadMax: 4,
      habilidadesBuscadas: <String>[],
    );

    final ResultadoPublicacion resultado =
        await grupos.publicarGrupo(grupoId: grupo.id, usuarioSesion: lider);

    expect(resultado.invitaciones, isEmpty);
  });

  test('un grupo en borrador no genera ninguna invitación', () async {
    final FakeFirebaseFirestore db = FakeFirebaseFirestore();
    final Usuario ana = await registrar(
      db,
      nombre: 'Ana',
      habilidades: <String>['Flutter'],
      semestre: 7,
    );
    final Usuario lider = await registrar(
      db,
      nombre: 'Lider',
      habilidades: <String>['Pitch'],
      semestre: 8,
    );

    final GrupoService grupos = GrupoService(firestore: db);
    await grupos.crearGrupo(
      convocatoriaId: 'CV-1',
      nombre: 'Borrador',
      descripcion: 'Creado pero nunca publicado por el líder.',
      lider: lider,
      capacidadMax: 4,
      habilidadesBuscadas: <String>['Flutter'],
    );

    // Sin publicarGrupo, Ana no recibe nada aunque coincida perfectamente.
    expect(await grupos.getInvitacionesParaUsuario(ana), isEmpty);
  });
}
