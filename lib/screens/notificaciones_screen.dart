import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../database/sqlite_helper.dart';
import '../models/invitacion_grupo.dart';
import '../models/usuario.dart';
import '../services/grupo_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Bandeja de invitaciones: las "notificaciones" que recibe un usuario
/// cuando un grupo publicado busca su perfil. Desde aquí puede unirse
/// automáticamente o rechazar.
class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final GrupoService _grupoService = GrupoService();
  late Future<_Bandeja> _bandejaFuture;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _bandejaFuture = _cargar();
  }

  Future<_Bandeja> _cargar() async {
    final Usuario? usuario = await LocalSessionManager.getUser();
    if (usuario == null) {
      return const _Bandeja(usuario: null, invitaciones: <InvitacionGrupo>[]);
    }
    final List<InvitacionGrupo> invitaciones =
        await _grupoService.getInvitacionesParaUsuario(usuario);
    return _Bandeja(usuario: usuario, invitaciones: invitaciones);
  }

  void _refresh() {
    setState(() => _bandejaFuture = _cargar());
  }

  Future<void> _aceptar(InvitacionGrupo invitacion) async {
    setState(() => _procesando = true);
    try {
      final grupo = await _grupoService.aceptarInvitacion(invitacion.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('¡Te uniste a "${grupo.nombre}"!')),
      );
    } on StateError catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) {
        setState(() => _procesando = false);
        _refresh();
      }
    }
  }

  Future<void> _rechazar(InvitacionGrupo invitacion) async {
    setState(() => _procesando = true);
    await _grupoService.rechazarInvitacion(invitacion.id);
    if (!mounted) {
      return;
    }
    setState(() => _procesando = false);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: SafeArea(
        child: FutureBuilder<_Bandeja>(
          future: _bandejaFuture,
          builder: (BuildContext context, AsyncSnapshot<_Bandeja> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.red),
                  ),
                ),
              );
            }

            final _Bandeja bandeja = snapshot.data!;
            if (bandeja.usuario == null) {
              return _EstadoVacio(
                icon: Icons.lock_outline,
                mensaje: 'Inicia sesión para recibir invitaciones.',
              );
            }
            if (bandeja.invitaciones.isEmpty) {
              return _EstadoVacio(
                icon: Icons.notifications_off_outlined,
                mensaje: 'No tienes invitaciones pendientes.\n'
                    'Cuando un grupo publicado busque tu perfil, '
                    'te avisaremos aquí.',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: bandeja.invitaciones.length,
              itemBuilder: (BuildContext context, int index) {
                final InvitacionGrupo invitacion =
                    bandeja.invitaciones[index];
                return _InvitacionCard(
                  invitacion: invitacion,
                  deshabilitada: _procesando,
                  onUnirse: () => _aceptar(invitacion),
                  onRechazar: () => _rechazar(invitacion),
                )
                    .animate()
                    .fadeIn(delay: (index * 60).ms, duration: 300.ms)
                    .slideY(begin: 0.1, end: 0);
              },
            );
          },
        ),
      ),
    );
  }
}

class _InvitacionCard extends StatelessWidget {
  const _InvitacionCard({
    required this.invitacion,
    required this.deshabilitada,
    required this.onUnirse,
    required this.onRechazar,
  });

  final InvitacionGrupo invitacion;
  final bool deshabilitada;
  final VoidCallback onUnirse;
  final VoidCallback onRechazar;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppGradients.primaryButton,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Te invitaron a "${invitacion.grupoNombre}"',
                      style: AppTypography.display(size: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tu perfil está entre los mejores para este grupo '
                      '(puntaje ${invitacion.puntuacion}).',
                      style: AppTypography.ui(
                        size: 12.5,
                        color: AppColors.inkSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (invitacion.habilidadesCoincidentes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: invitacion.habilidadesCoincidentes
                  .map<Widget>(
                    (String h) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        h,
                        style: AppTypography.ui(
                          size: 11.5,
                          weight: FontWeight.w600,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: deshabilitada ? null : onRechazar,
                child: Text(
                  'Rechazar',
                  style: AppTypography.ui(
                    weight: FontWeight.w600,
                    color: AppColors.inkSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: deshabilitada ? null : onUnirse,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Unirme'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(120, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({required this.icon, required this.mensaje});

  final IconData icon;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: AppColors.inkSecondary, size: 48),
            const SizedBox(height: 12),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: AppTypography.ui(color: AppColors.inkSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bandeja {
  const _Bandeja({required this.usuario, required this.invitaciones});

  final Usuario? usuario;
  final List<InvitacionGrupo> invitaciones;
}
