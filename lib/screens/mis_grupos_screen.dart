import 'package:flutter/material.dart';

import '../database/sqlite_helper.dart';
import '../models/convocatoria.dart';
import '../models/grupo.dart';
import '../models/usuario.dart';
import '../services/convocatoria_service.dart';
import '../services/grupo_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'grupos_screen.dart';

/// Lista los grupos donde el usuario es líder (borradores y publicados) y le
/// permite **publicar** un borrador o abrir la gestión completa del grupo.
class MisGruposScreen extends StatefulWidget {
  const MisGruposScreen({super.key});

  @override
  State<MisGruposScreen> createState() => _MisGruposScreenState();
}

class _MisGruposScreenState extends State<MisGruposScreen> {
  final GrupoService _grupoService = GrupoService();
  final ConvocatoriaService _convocatoriaService = ConvocatoriaService();
  late Future<_Vista> _future;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _future = _cargar();
  }

  Future<_Vista> _cargar() async {
    final Usuario? usuario = await LocalSessionManager.getUser();
    if (usuario == null) {
      return const _Vista(usuario: null, grupos: <Grupo>[], convocatorias: {});
    }
    final List<Grupo> grupos =
        await _grupoService.getGruposDeLider(usuario.id);
    final List<Convocatoria> convocatorias =
        await _convocatoriaService.getConvocatoriasActivas();
    // Borradores primero, luego por nombre.
    grupos.sort((Grupo a, Grupo b) {
      if (a.esBorrador != b.esBorrador) {
        return a.esBorrador ? -1 : 1;
      }
      return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
    });
    return _Vista(
      usuario: usuario,
      grupos: grupos,
      convocatorias: <String, Convocatoria>{
        for (final Convocatoria c in convocatorias) c.id: c,
      },
    );
  }

  Future<void> _recargar() async {
    final Future<_Vista> next = _cargar();
    setState(() => _future = next);
    await next;
  }

  Future<void> _publicar(Grupo grupo, Usuario usuario) async {
    setState(() => _procesando = true);
    try {
      final ResultadoPublicacion resultado =
          await _grupoService.publicarGrupo(
        grupoId: grupo.id,
        usuarioSesion: usuario,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
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
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _procesando = false);
        await _recargar();
      }
    }
  }

  Future<void> _abrirGestion(Convocatoria convocatoria) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            GruposScreen(convocatoria: convocatoria),
      ),
    );
    if (mounted) {
      await _recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis grupos')),
      body: SafeArea(
        child: FutureBuilder<_Vista>(
          future: _future,
          builder: (BuildContext context, AsyncSnapshot<_Vista> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _Mensaje(
                texto: 'No pudimos cargar tus grupos.\n${snapshot.error}',
                onReintentar: _recargar,
              );
            }
            final _Vista vista = snapshot.requireData;
            if (vista.usuario == null) {
              return const _Mensaje(
                texto: 'Inicia sesión para ver los grupos que lideras.',
              );
            }
            if (vista.grupos.isEmpty) {
              return _Mensaje(
                texto: 'Aún no creaste grupos. Cuando crees uno, aparecerá '
                    'aquí para que lo publiques cuando quieras.',
                onReintentar: _recargar,
              );
            }
            return RefreshIndicator(
              color: AppColors.red,
              onRefresh: _recargar,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: vista.grupos.length,
                itemBuilder: (BuildContext context, int i) {
                  final Grupo grupo = vista.grupos[i];
                  return _MiGrupoCard(
                    grupo: grupo,
                    convocatoria: vista.convocatorias[grupo.convocatoriaId],
                    procesando: _procesando,
                    onPublicar: () => _publicar(grupo, vista.usuario!),
                    onGestionar: (Convocatoria c) => _abrirGestion(c),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Vista {
  const _Vista({
    required this.usuario,
    required this.grupos,
    required this.convocatorias,
  });

  final Usuario? usuario;
  final List<Grupo> grupos;
  final Map<String, Convocatoria> convocatorias;
}

class _MiGrupoCard extends StatelessWidget {
  const _MiGrupoCard({
    required this.grupo,
    required this.convocatoria,
    required this.procesando,
    required this.onPublicar,
    required this.onGestionar,
  });

  final Grupo grupo;
  final Convocatoria? convocatoria;
  final bool procesando;
  final VoidCallback onPublicar;
  final ValueChanged<Convocatoria> onGestionar;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(grupo.nombre,
                    style: AppTypography.display(size: 17)),
              ),
              _EstadoPill(grupo: grupo),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            convocatoria?.titulo ?? 'Convocatoria no disponible',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.ui(size: 12.5, color: AppColors.inkSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              const Icon(Icons.groups_outlined,
                  size: 16, color: AppColors.blue),
              const SizedBox(width: 6),
              Text(
                '${grupo.integrantes}/${grupo.capacidadMax} integrantes',
                style: AppTypography.ui(
                    size: 12.5, weight: FontWeight.w600, color: AppColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              if (convocatoria != null)
                OutlinedButton.icon(
                  onPressed:
                      procesando ? null : () => onGestionar(convocatoria!),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Gestionar'),
                ),
              if (grupo.esBorrador) ...<Widget>[
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: procesando ? null : onPublicar,
                  icon: const Icon(Icons.campaign_outlined, size: 18),
                  label: const Text('Publicar'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _EstadoPill extends StatelessWidget {
  const _EstadoPill({required this.grupo});

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

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.texto, this.onReintentar});

  final String texto;
  final Future<void> Function()? onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.groups_2_outlined,
                color: AppColors.inkSecondary, size: 48),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: AppTypography.ui(color: AppColors.inkSecondary),
            ),
            if (onReintentar != null) ...<Widget>[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onReintentar,
                icon: const Icon(Icons.refresh),
                label: const Text('Recargar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
