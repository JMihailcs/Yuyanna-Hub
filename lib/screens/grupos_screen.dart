import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../database/sqlite_helper.dart';
import '../models/convocatoria.dart';
import '../models/grupo.dart';
import '../models/invitacion_grupo.dart';
import '../models/miembro_resumen.dart';
import '../models/solicitud_ingreso.dart';
import '../models/usuario.dart';
import '../services/grupo_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/selector_usuario.dart';
import 'crear_grupo_screen.dart';
import 'mis_grupos_screen.dart';

class GruposScreen extends StatefulWidget {
  const GruposScreen({super.key, required this.convocatoria});

  final Convocatoria convocatoria;

  @override
  State<GruposScreen> createState() => _GruposScreenState();
}

class _GruposScreenState extends State<GruposScreen> {
  final GrupoService _grupoService = GrupoService();
  late Future<_VistaGrupos> _vistaFuture;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _vistaFuture = _cargar();
  }

  Future<_VistaGrupos> _cargar() async {
    final Usuario? usuario = await LocalSessionManager.getUser();
    final List<Grupo> grupos = await _grupoService.getGruposPorConvocatoria(
      widget.convocatoria.id,
      usuarioId: usuario?.id,
    );

    Map<String, InvitacionGrupo> invitaciones = <String, InvitacionGrupo>{};
    Set<String> solicitadas = <String>{};
    final Map<String, List<SolicitudIngreso>> solicitudes =
        <String, List<SolicitudIngreso>>{};
    List<Usuario> directorio = <Usuario>[];

    if (usuario != null) {
      final List<InvitacionGrupo> pendientes =
          await _grupoService.getInvitacionesParaUsuario(usuario);
      invitaciones = <String, InvitacionGrupo>{
        for (final InvitacionGrupo i in pendientes) i.grupoId: i,
      };
      solicitadas = await _grupoService.getGruposSolicitadosPor(usuario.id);
      for (final Grupo g in grupos) {
        if (g.esLider(usuario.id)) {
          solicitudes[g.id] = await _grupoService.getSolicitudesDeGrupo(g.id);
        }
      }
      directorio = await _grupoService.getUsuarios();
    }

    return _VistaGrupos(
      usuario: usuario,
      grupos: grupos,
      invitacionesPorGrupo: invitaciones,
      gruposSolicitados: solicitadas,
      solicitudesPorGrupo: solicitudes,
      directorio: directorio,
    );
  }

  Future<void> _refresh() async {
    final Future<_VistaGrupos> nextFuture = _cargar();
    setState(() => _vistaFuture = nextFuture);
    await nextFuture;
  }

  Future<void> _crearGrupo() async {
    final bool? creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) =>
            CrearGrupoScreen(convocatoria: widget.convocatoria),
      ),
    );
    if (creado == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _verMisGrupos() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const MisGruposScreen(),
      ),
    );
    if (mounted) {
      await _refresh();
    }
  }

  Future<void> _ejecutar(Future<void> Function() accion) async {
    setState(() => _procesando = true);
    try {
      await accion();
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _procesando = false);
        await _refresh();
      }
    }
  }

  Future<void> _solicitarIngreso(Grupo grupo, Usuario usuario) {
    return _ejecutar(() async {
      await _grupoService.solicitarIngreso(grupoId: grupo.id, usuario: usuario);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Solicitud enviada al líder de "${grupo.nombre}".',
            ),
          ),
        );
      }
    });
  }

  Future<void> _unirsePorInvitacion(InvitacionGrupo invitacion) {
    return _ejecutar(() async {
      final Grupo grupo = await _grupoService.aceptarInvitacion(invitacion.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('¡Te uniste a "${grupo.nombre}"!')),
        );
      }
    });
  }

  Future<void> _publicar(Grupo grupo, Usuario usuario) {
    return _ejecutar(() async {
      final ResultadoPublicacion resultado = await _grupoService.publicarGrupo(
        grupoId: grupo.id,
        usuarioSesion: usuario,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resultado.invitaciones.isEmpty
                  ? '"${grupo.nombre}" publicado. No hubo perfiles '
                      'coincidentes para notificar.'
                  : '"${grupo.nombre}" publicado. Notificamos a los '
                      '${resultado.invitaciones.length} mejores perfiles.',
            ),
          ),
        );
      }
    });
  }

  Future<void> _agregarMiembro(Grupo grupo, _VistaGrupos vista) async {
    final Usuario? elegido = await mostrarSelectorUsuario(
      context,
      usuarios: vista.directorio,
      excluirIds:
          grupo.miembros.map<String>((MiembroResumen m) => m.id).toSet(),
    );
    if (elegido == null || !mounted) {
      return;
    }
    await _ejecutar(() async {
      await _grupoService.agregarMiembro(grupoId: grupo.id, usuario: elegido);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${elegido.nombre} ahora integra "${grupo.nombre}".',
            ),
          ),
        );
      }
    });
  }

  Future<void> _responderSolicitud(SolicitudIngreso solicitud, bool aceptar) {
    return _ejecutar(() async {
      await _grupoService.responderSolicitud(
        solicitudId: solicitud.id,
        aceptar: aceptar,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              aceptar
                  ? '${solicitud.usuario.nombre} fue aceptado en el grupo.'
                  : 'Solicitud de ${solicitud.usuario.nombre} rechazada.',
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color tipoColor = TipoConvocatoria.textColor(widget.convocatoria.tipo);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grupos'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Mis grupos',
            icon: const Icon(Icons.folder_outlined),
            onPressed: _verMisGrupos,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearGrupo,
        icon: const Icon(Icons.add),
        label: const Text('Crear grupo'),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _ConvocatoriaSummary(
              convocatoria: widget.convocatoria,
              tipoColor: tipoColor,
            ),
            Expanded(
              child: FutureBuilder<_VistaGrupos>(
                future: _vistaFuture,
                builder: (
                  BuildContext context,
                  AsyncSnapshot<_VistaGrupos> snapshot,
                ) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.red),
                        ),
                      ),
                    );
                  }

                  final _VistaGrupos vista = snapshot.data!;
                  if (vista.grupos.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(Icons.group_off_outlined,
                                color: AppColors.inkSecondary, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'Todavía no hay grupos para esta convocatoria.',
                              textAlign: TextAlign.center,
                              style: AppTypography.ui(
                                  color: AppColors.inkSecondary),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _refresh,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: AppColors.red,
                    backgroundColor: AppColors.surface,
                    onRefresh: _refresh,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: vista.grupos.length,
                      itemBuilder: (BuildContext context, int index) {
                        final Grupo grupo = vista.grupos[index];
                        return _GrupoCard(
                          grupo: grupo,
                          accentColor: tipoColor,
                          usuario: vista.usuario,
                          invitacion: vista.invitacionesPorGrupo[grupo.id],
                          solicitudEnviada:
                              vista.gruposSolicitados.contains(grupo.id),
                          solicitudes: vista.solicitudesPorGrupo[grupo.id] ??
                              const <SolicitudIngreso>[],
                          procesando: _procesando,
                          onSolicitar: (Usuario u) =>
                              _solicitarIngreso(grupo, u),
                          onUnirsePorInvitacion: _unirsePorInvitacion,
                          onPublicar: (Usuario u) => _publicar(grupo, u),
                          onAgregarMiembro: () =>
                              _agregarMiembro(grupo, vista),
                          onResponderSolicitud: _responderSolicitud,
                        )
                            .animate()
                            .fadeIn(
                                delay: (index * 50).ms, duration: 300.ms)
                            .slideY(begin: 0.1, end: 0);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VistaGrupos {
  const _VistaGrupos({
    required this.usuario,
    required this.grupos,
    required this.invitacionesPorGrupo,
    required this.gruposSolicitados,
    required this.solicitudesPorGrupo,
    required this.directorio,
  });

  final Usuario? usuario;
  final List<Grupo> grupos;
  final Map<String, InvitacionGrupo> invitacionesPorGrupo;
  final Set<String> gruposSolicitados;
  final Map<String, List<SolicitudIngreso>> solicitudesPorGrupo;
  final List<Usuario> directorio;
}

class _ConvocatoriaSummary extends StatelessWidget {
  const _ConvocatoriaSummary({
    required this.convocatoria,
    required this.tipoColor,
  });

  final Convocatoria convocatoria;
  final Color tipoColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 5,
            height: 46,
            decoration: BoxDecoration(
              gradient: TipoConvocatoria.gradient(convocatoria.tipo),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  convocatoria.tipo.toUpperCase(),
                  style: AppTypography.ui(
                    size: 11,
                    weight: FontWeight.w700,
                    color: tipoColor,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  convocatoria.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.display(size: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cierra: ${convocatoria.fechaCierre}',
                  style: AppTypography.ui(
                      size: 12, color: AppColors.inkSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GrupoCard extends StatelessWidget {
  const _GrupoCard({
    required this.grupo,
    required this.accentColor,
    required this.usuario,
    required this.invitacion,
    required this.solicitudEnviada,
    required this.solicitudes,
    required this.procesando,
    required this.onSolicitar,
    required this.onUnirsePorInvitacion,
    required this.onPublicar,
    required this.onAgregarMiembro,
    required this.onResponderSolicitud,
  });

  final Grupo grupo;
  final Color accentColor;
  final Usuario? usuario;
  final InvitacionGrupo? invitacion;
  final bool solicitudEnviada;
  final List<SolicitudIngreso> solicitudes;
  final bool procesando;
  final ValueChanged<Usuario> onSolicitar;
  final ValueChanged<InvitacionGrupo> onUnirsePorInvitacion;
  final ValueChanged<Usuario> onPublicar;
  final VoidCallback onAgregarMiembro;
  final void Function(SolicitudIngreso, bool) onResponderSolicitud;

  bool get _esLider => usuario != null && grupo.esLider(usuario!.id);
  bool get _esMiembro => usuario != null && grupo.esMiembro(usuario!.id);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  grupo.nombre,
                  style: AppTypography.display(size: 17),
                ),
              ),
              _StatusPill(grupo: grupo),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              const Icon(Icons.person_outline,
                  size: 14, color: AppColors.inkSecondary),
              const SizedBox(width: 4),
              Text(
                'Líder: ${grupo.liderNombre}',
                style: AppTypography.ui(
                    size: 12, color: AppColors.inkSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            grupo.descripcion,
            style: AppTypography.ui(
                size: 13, color: AppColors.inkSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Icon(Icons.groups_outlined, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Text(
                '${grupo.integrantes}/${grupo.capacidadMax} integrantes',
                style: AppTypography.ui(
                    size: 12.5, weight: FontWeight.w600, color: AppColors.ink),
              ),
              const SizedBox(width: 10),
              if (grupo.abierto && grupo.tienePlazas)
                Text(
                  '· ${grupo.plazasDisponibles} libre(s)',
                  style: AppTypography.ui(size: 12, color: accentColor),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            grupo.miembros
                .map<String>((MiembroResumen m) => m.nombre)
                .join(' · '),
            style: AppTypography.ui(size: 11.5, color: AppColors.inkSecondary),
          ),
          if (grupo.habilidadesBuscadas.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: grupo.habilidadesBuscadas
                  .map<Widget>(
                    (String h) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: accentColor.withValues(alpha: 0.30)),
                      ),
                      child: Text(
                        h,
                        style: AppTypography.ui(
                          size: 11.5,
                          weight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (_esLider && solicitudes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            _SolicitudesPanel(
              solicitudes: solicitudes,
              procesando: procesando,
              onResponder: onResponderSolicitud,
            ),
          ],
          const SizedBox(height: 14),
          _buildAcciones(context),
        ],
      ),
    );
  }

  Widget _buildAcciones(BuildContext context) {
    if (_esLider) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          OutlinedButton.icon(
            onPressed: (procesando || !grupo.tienePlazas)
                ? null
                : onAgregarMiembro,
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
            label: const Text('Agregar'),
          ),
          if (grupo.esBorrador) ...<Widget>[
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: procesando ? null : () => onPublicar(usuario!),
              icon: const Icon(Icons.campaign_outlined, size: 18),
              label: const Text('Publicar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      );
    }

    if (_esMiembro) {
      return Align(
        alignment: Alignment.centerRight,
        child: Text(
          'Ya integras este grupo',
          style: AppTypography.ui(
            size: 12.5,
            weight: FontWeight.w600,
            color: AppColors.blue,
          ),
        ),
      );
    }

    final bool hayCupo = grupo.abierto && grupo.tienePlazas;

    if (invitacion != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            'La app te invitó por tu perfil',
            style: AppTypography.ui(
              size: 11.5,
              color: AppColors.gold,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          ElevatedButton.icon(
            onPressed: (procesando || !hayCupo)
                ? null
                : () => onUnirsePorInvitacion(invitacion!),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: Text(hayCupo ? 'Unirme' : 'Sin cupo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.white,
              minimumSize: const Size(120, 42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      );
    }

    final String etiqueta;
    final bool habilitado;
    if (!hayCupo) {
      etiqueta = 'Sin cupo';
      habilitado = false;
    } else if (solicitudEnviada) {
      etiqueta = 'Solicitud enviada';
      habilitado = false;
    } else {
      etiqueta = 'Solicitar unirme';
      habilitado = !procesando;
    }

    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton.icon(
        onPressed: habilitado
            ? () {
                if (usuario == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Inicia sesión para solicitar unirte.'),
                    ),
                  );
                  return;
                }
                onSolicitar(usuario!);
              }
            : null,
        icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
        label: Text(etiqueta),
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(120, 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _SolicitudesPanel extends StatelessWidget {
  const _SolicitudesPanel({
    required this.solicitudes,
    required this.procesando,
    required this.onResponder,
  });

  final List<SolicitudIngreso> solicitudes;
  final bool procesando;
  final void Function(SolicitudIngreso, bool) onResponder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'SOLICITUDES PENDIENTES (${solicitudes.length})',
            style: AppTypography.ui(
              size: 11,
              weight: FontWeight.w700,
              color: AppColors.inkSecondary,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          for (final SolicitudIngreso solicitud in solicitudes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          solicitud.usuario.nombre,
                          style: AppTypography.ui(
                            size: 13,
                            weight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          solicitud.usuario.habilidades.join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.ui(
                            size: 11.5,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: procesando
                        ? null
                        : () => onResponder(solicitud, false),
                    tooltip: 'Rechazar',
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.red, size: 22),
                  ),
                  IconButton(
                    onPressed: procesando
                        ? null
                        : () => onResponder(solicitud, true),
                    tooltip: 'Aceptar',
                    icon: const Icon(Icons.check_circle_outline,
                        color: AppColors.blue, size: 22),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.grupo});

  final Grupo grupo;

  @override
  Widget build(BuildContext context) {
    final String etiqueta;
    final Color color;
    if (grupo.esBorrador) {
      etiqueta = 'BORRADOR';
      color = AppColors.gold;
    } else if (grupo.abierto) {
      etiqueta = 'ABIERTO';
      color = AppColors.blue;
    } else {
      etiqueta = 'CERRADO';
      color = AppColors.red;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        etiqueta,
        style: AppTypography.ui(
          size: 10,
          weight: FontWeight.w700,
          color: color,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
