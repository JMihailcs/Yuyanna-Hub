import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yuyanna_hub/models/grupo.dart';
import 'package:yuyanna_hub/models/invitacion_grupo.dart';
import 'package:yuyanna_hub/models/solicitud_ingreso.dart';
import 'package:yuyanna_hub/models/usuario.dart';
import 'package:yuyanna_hub/services/grupo_service.dart';

Usuario _usuario(
  String id,
  String nombre,
  List<String> habilidades, {
  int semestre = 5,
}) {
  return Usuario(
    id: id,
    nombre: nombre,
    correo: '$id@unsaac.edu.pe',
    escuelaProfesional: 'Ingeniería Informática',
    semestre: semestre,
    habilidades: habilidades,
  );
}

Future<void> _seedUsuarios(
  FakeFirebaseFirestore db,
  List<Usuario> usuarios,
) async {
  for (final Usuario u in usuarios) {
    await db.collection('usuarios').doc(u.id).set(u.toJson());
  }
}

void main() {
  late FakeFirebaseFirestore db;
  late GrupoService api;

  setUp(() {
    db = FakeFirebaseFirestore();
    api = GrupoService(firestore: db);
  });

  group('Flujo de grupos: borrador → publicación → matching', () {
    test('el grupo se crea como borrador con el líder y los iniciales',
        () async {
      final Usuario lider = _usuario('T-001', 'Líder Test', <String>[]);
      final Usuario inicial =
          _usuario('T-002', 'Amiga Test', <String>['Figma']);

      final Grupo grupo = await api.crearGrupo(
        convocatoriaId: 'CV-001',
        nombre: 'Equipo Test Borrador',
        descripcion: 'Grupo para pruebas.',
        lider: lider,
        capacidadMax: 4,
        habilidadesBuscadas: <String>['Figma'],
        miembrosIniciales: <Usuario>[inicial],
      );

      expect(grupo.estado, EstadoGrupo.borrador);
      expect(grupo.esLider(lider.id), isTrue);
      expect(grupo.esMiembro(inicial.id), isTrue);
      expect(grupo.integrantes, 2);
    });

    test(
        'al publicar se notifica solo a perfiles coincidentes, '
        'ordenados por puntaje y sin superar el máximo', () async {
      // Directorio de candidatos reales en Firestore.
      await _seedUsuarios(db, <Usuario>[
        _usuario('C-A', 'Dos matches', <String>['Figma', 'Python']),
        _usuario('C-B', 'Un match', <String>['Figma']),
        _usuario('C-C', 'Sin match', <String>['Contabilidad']),
      ]);

      final Usuario lider = _usuario('T-010', 'Líder Match', <String>[]);
      final Grupo grupo = await api.crearGrupo(
        convocatoriaId: 'CV-001',
        nombre: 'Equipo Test Matching',
        descripcion: 'Grupo para pruebas de matching.',
        lider: lider,
        capacidadMax: 4,
        habilidadesBuscadas: <String>['Figma', 'Python'],
      );

      final ResultadoPublicacion resultado = await api.publicarGrupo(
        grupoId: grupo.id,
        usuarioSesion: _usuario('T-011', 'Sesión Test', <String>['Figma']),
      );

      expect(resultado.grupo.estado, EstadoGrupo.publicado);
      expect(resultado.invitaciones, isNotEmpty);
      expect(
        resultado.invitaciones.length,
        lessThanOrEqualTo(GrupoService.maxInvitaciones),
      );
      // Todos los invitados coinciden en algo y ninguno es miembro.
      for (final InvitacionGrupo inv in resultado.invitaciones) {
        expect(inv.habilidadesCoincidentes, isNotEmpty);
        expect(resultado.grupo.esMiembro(inv.usuario.id), isFalse);
        expect(inv.estado, EstadoInvitacion.pendiente);
      }
      // El perfil sin coincidencias no fue invitado.
      expect(
        resultado.invitaciones.any((InvitacionGrupo i) => i.usuario.id == 'C-C'),
        isFalse,
      );
      // Orden descendente por puntuación.
      for (int i = 1; i < resultado.invitaciones.length; i++) {
        expect(
          resultado.invitaciones[i - 1].puntuacion,
          greaterThanOrEqualTo(resultado.invitaciones[i].puntuacion),
        );
      }
      // El usuario de sesión con habilidad coincidente fue notificado.
      expect(
        resultado.invitaciones
            .any((InvitacionGrupo i) => i.usuario.id == 'T-011'),
        isTrue,
      );
    });

    test('un invitado se une automáticamente al aceptar', () async {
      final Usuario lider = _usuario('T-020', 'Líder Invita', <String>[]);
      final Usuario invitado =
          _usuario('T-021', 'Invitado Test', <String>['Kotlin Multiplatform']);

      final Grupo grupo = await api.crearGrupo(
        convocatoriaId: 'CV-001',
        nombre: 'Equipo Test Invitación',
        descripcion: 'Grupo para pruebas de invitación.',
        lider: lider,
        capacidadMax: 3,
        habilidadesBuscadas: <String>['Kotlin Multiplatform'],
      );
      final ResultadoPublicacion resultado = await api.publicarGrupo(
        grupoId: grupo.id,
        usuarioSesion: invitado,
      );

      final InvitacionGrupo invitacion = resultado.invitaciones.firstWhere(
        (InvitacionGrupo i) => i.usuario.id == invitado.id,
      );
      final Grupo actualizado = await api.aceptarInvitacion(invitacion.id);

      expect(actualizado.esMiembro(invitado.id), isTrue);
      final List<InvitacionGrupo> pendientes =
          await api.getInvitacionesParaUsuario(invitado);
      expect(
        pendientes.any((InvitacionGrupo i) => i.id == invitacion.id),
        isFalse,
      );
    });

    test(
        'sin invitación no hay ingreso automático: la solicitud queda '
        'pendiente hasta que el líder la acepta', () async {
      final Usuario lider = _usuario('T-030', 'Líder Aprueba', <String>[]);
      final Usuario aspirante =
          _usuario('T-031', 'Aspirante Test', <String>[]);

      final Grupo grupo = await api.crearGrupo(
        convocatoriaId: 'CV-001',
        nombre: 'Equipo Test Solicitud',
        descripcion: 'Grupo para pruebas de solicitud.',
        lider: lider,
        capacidadMax: 3,
        habilidadesBuscadas: <String>['Figma'],
      );
      await api.publicarGrupo(grupoId: grupo.id);

      final SolicitudIngreso solicitud = await api.solicitarIngreso(
        grupoId: grupo.id,
        usuario: aspirante,
      );

      // Solicitar no lo convierte en miembro.
      List<Grupo> grupos = await api.getGruposPorConvocatoria('CV-001');
      Grupo recargado = grupos.firstWhere((Grupo g) => g.id == grupo.id);
      expect(recargado.esMiembro(aspirante.id), isFalse);
      expect(solicitud.estado, EstadoSolicitud.pendiente);

      // El líder acepta y recién ahí entra.
      final Grupo trasAceptar = await api.responderSolicitud(
        solicitudId: solicitud.id,
        aceptar: true,
      );
      expect(trasAceptar.esMiembro(aspirante.id), isTrue);

      grupos = await api.getGruposPorConvocatoria('CV-001');
      recargado = grupos.firstWhere((Grupo g) => g.id == grupo.id);
      expect(recargado.esMiembro(aspirante.id), isTrue);
    });

    test('al llenarse el cupo, el grupo se cierra y las invitaciones '
        'pendientes expiran', () async {
      final Usuario lider = _usuario('T-040', 'Líder Lleno', <String>[]);
      final Usuario invitadoA =
          _usuario('T-041', 'Invitado A', <String>['Rust embebido']);
      final Usuario invitadoB =
          _usuario('T-042', 'Invitado B', <String>['Rust embebido']);
      // Ambos están en el directorio, así que ambos son invitados al publicar.
      await _seedUsuarios(db, <Usuario>[invitadoA, invitadoB]);

      final Grupo grupo = await api.crearGrupo(
        convocatoriaId: 'CV-001',
        nombre: 'Equipo Test Cupo',
        descripcion: 'Grupo para pruebas de cupo.',
        lider: lider,
        capacidadMax: 2,
        habilidadesBuscadas: <String>['Rust embebido'],
      );

      final ResultadoPublicacion resultado =
          await api.publicarGrupo(grupoId: grupo.id);
      final InvitacionGrupo invitacionA = resultado.invitaciones
          .firstWhere((InvitacionGrupo i) => i.usuario.id == invitadoA.id);
      final InvitacionGrupo invitacionB = resultado.invitaciones
          .firstWhere((InvitacionGrupo i) => i.usuario.id == invitadoB.id);

      final Grupo lleno = await api.aceptarInvitacion(invitacionA.id);
      expect(lleno.tienePlazas, isFalse);
      expect(lleno.abierto, isFalse);

      // La invitación de B ya no sirve: el cupo se llenó.
      expect(
        () => api.aceptarInvitacion(invitacionB.id),
        throwsStateError,
      );
    });
  });
}
