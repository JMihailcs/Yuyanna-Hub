import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../database/sqlite_helper.dart';
import '../models/usuario.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'editar_perfil_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final AdminService _adminService = AdminService();
  late Future<Usuario?> _usuarioFuture;
  late Future<RolAdmin?> _rolFuture;

  @override
  void initState() {
    super.initState();
    _usuarioFuture = LocalSessionManager.getUser();
    _rolFuture = _cargarRol();
  }

  Future<RolAdmin?> _cargarRol() async {
    final Usuario? usuario = await LocalSessionManager.getUser();
    if (usuario == null) {
      return null;
    }
    // Bootstrap también aquí: evita la carrera con el Home y garantiza que,
    // si es fundador, su doc admin exista antes de consultar el rol.
    await _adminService.asegurarAdminFundador(usuario);
    return _adminService.rolDe(usuario.id);
  }

  String _initials(String nombre) {
    final List<String> parts = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Future<void> _editarPerfil(Usuario usuario) async {
    final Usuario? actualizado = await Navigator.of(context).push<Usuario>(
      MaterialPageRoute<Usuario>(
        builder: (BuildContext context) =>
            EditarPerfilScreen(usuario: usuario),
      ),
    );
    if (actualizado == null || !mounted) {
      return;
    }
    setState(() {
      _usuarioFuture = Future<Usuario?>.value(actualizado);
      _rolFuture = _cargarRol();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Perfil actualizado.'),
      ),
    );
  }

  Future<void> _logout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Cerrar sesión', style: AppTypography.display(size: 20)),
          content: Text(
            '¿Quieres salir de tu cuenta? Tendrás que ingresar de nuevo.',
            style: AppTypography.ui(size: 14, color: AppColors.inkSecondary),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancelar',
                style: AppTypography.ui(
                    size: 14, color: AppColors.inkSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cerrar sesión'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) {
      return;
    }

    await _authService.cerrarSesion();

    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const LoginScreen(),
      ),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Usuario?>(
      future: _usuarioFuture,
      builder: (BuildContext context, AsyncSnapshot<Usuario?> snapshot) {
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

        final Usuario? usuario = snapshot.data;
        if (usuario == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.person_off_outlined,
                      color: AppColors.inkSecondary, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Aún no tenemos tus datos en este dispositivo.\n'
                    'Inicia sesión o regístrate para verlos aquí.',
                    textAlign: TextAlign.center,
                    style: AppTypography.ui(color: AppColors.inkSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Volver al login'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: <Widget>[
            _ProfileHeader(
              initials: _initials(usuario.nombre),
              nombre: usuario.nombre,
              correo: usuario.correo,
              esUnsaac: usuario.esUnsaac,
            ),
            const SizedBox(height: 14),
            FutureBuilder<RolAdmin?>(
              future: _rolFuture,
              builder:
                  (BuildContext context, AsyncSnapshot<RolAdmin?> snapshot) {
                final RolAdmin? rol = snapshot.data;
                if (rol == null) {
                  return const SizedBox.shrink();
                }
                final Color color =
                    rol == RolAdmin.admin ? AppColors.red : AppColors.blue;
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.shield_outlined, size: 15, color: color),
                        const SizedBox(width: 6),
                        Text(
                          rol.etiqueta,
                          style: AppTypography.ui(
                            size: 12,
                            weight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () => _editarPerfil(usuario),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Editar perfil'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.blue,
                minimumSize: const Size.fromHeight(46),
                side: BorderSide(color: AppColors.blue.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: AppTypography.ui(size: 14, weight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 14),
            if ((usuario.ocupacion != null && usuario.ocupacion!.isNotEmpty) ||
                (usuario.escuelaProfesional != null &&
                    usuario.escuelaProfesional!.isNotEmpty) ||
                usuario.semestre != null) ...<Widget>[
              const _SectionTitle(label: 'Información'),
              const SizedBox(height: 10),
              if (usuario.ocupacion != null &&
                  usuario.ocupacion!.isNotEmpty) ...<Widget>[
                _InfoTile(
                  icon: Icons.badge_outlined,
                  label: 'Ocupación',
                  value: usuario.ocupacion!,
                  accent: AppColors.red,
                ),
                const SizedBox(height: 10),
              ],
              if (usuario.escuelaProfesional != null &&
                  usuario.escuelaProfesional!.isNotEmpty) ...<Widget>[
                _InfoTile(
                  icon: Icons.school_outlined,
                  label: 'Escuela profesional',
                  value: usuario.escuelaProfesional!,
                  accent: AppColors.blue,
                ),
                const SizedBox(height: 10),
              ],
              if (usuario.semestre != null) ...<Widget>[
                _InfoTile(
                  icon: Icons.calendar_view_month_outlined,
                  label: 'Semestre actual',
                  value: '${usuario.semestre}.º semestre',
                  accent: AppColors.gold,
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 14),
            ],
            const _SectionTitle(label: 'Habilidades'),
            const SizedBox(height: 10),
            if (usuario.habilidades.isEmpty)
              Text(
                'Aún no agregaste habilidades.',
                style: AppTypography.ui(color: AppColors.inkSecondary),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: usuario.habilidades
                    .map<Widget>(
                      (String h) => Chip(
                        label: Text(h),
                        labelStyle:
                            AppTypography.ui(size: 13, color: AppColors.ink),
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.line),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.red,
                minimumSize: const Size.fromHeight(50),
                side: BorderSide(color: AppColors.red.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: AppTypography.ui(size: 14, weight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                'ID: ${usuario.id}',
                style: AppTypography.ui(size: 11, color: AppColors.inkSecondary)
                    .copyWith(
                        color: AppColors.inkSecondary.withValues(alpha: 0.7)),
              ),
            ),
          ],
        )
            .animate()
            .fadeIn(duration: 350.ms)
            .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.initials,
    required this.nombre,
    required this.correo,
    required this.esUnsaac,
  });

  final String initials;
  final String nombre;
  final String correo;
  final bool esUnsaac;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.primaryButton,
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.redDeep.withValues(alpha: 0.25),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.18),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6), width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: AppTypography.display(
                size: 24,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.display(
                    size: 20,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  correo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.ui(
                    size: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                if (esUnsaac) ...<Widget>[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.goldFill,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.verified_rounded,
                          size: 13,
                          color: AppColors.ink,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Estudiante UNSAAC',
                          style: AppTypography.ui(
                            size: 11,
                            weight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppTypography.ui(
        size: 12,
        weight: FontWeight.w700,
        color: AppColors.inkSecondary,
        letterSpacing: 1.4,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: AppTypography.ui(
                      size: 11.5, color: AppColors.inkSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.ui(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
