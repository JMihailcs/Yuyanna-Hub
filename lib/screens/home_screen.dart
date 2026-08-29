import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:video_player/video_player.dart';

import '../database/sqlite_helper.dart';
import '../models/convocatoria.dart';
import '../models/usuario.dart';
import '../services/admin_service.dart';
import '../services/convocatoria_service.dart';
import '../services/grupo_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/hub_glyph.dart';
import '../widgets/menu_widget.dart';
import 'admin_panel_screen.dart';
import 'crear_convocatoria_screen.dart';
import 'grupos_screen.dart';
import 'notificaciones_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GrupoService _grupoService = GrupoService();
  final ConvocatoriaService _convocatoriaService = ConvocatoriaService();
  final AdminService _adminService = AdminService();
  late Future<List<Convocatoria>> _convocatoriasFuture;
  late Future<Usuario?> _usuarioFuture;
  int _currentIndex = 0;
  int _paginaFeed = 0;
  // Modo inmersivo del feed: doble-tap oculta los overlays y deja solo la
  // imagen; otro doble-tap los devuelve. Se reinicia al cambiar de página.
  bool _soloImagen = false;

  late Future<int> _invitacionesCountFuture;
  RolAdmin? _rol;

  /// Cualquier rol admin (completo o Paqarina) puede publicar eventos.
  bool get _puedePublicar => _rol != null;

  @override
  void initState() {
    super.initState();
    _convocatoriasFuture = _convocatoriaService.getConvocatoriasActivas();
    _usuarioFuture = LocalSessionManager.getUser();
    _invitacionesCountFuture = _contarInvitaciones();
    _cargarRol().then((RolAdmin? r) {
      if (mounted && r != _rol) {
        setState(() => _rol = r);
      }
    });
  }

  Future<RolAdmin?> _cargarRol() async {
    final Usuario? usuario = await LocalSessionManager.getUser();
    if (usuario == null) {
      return null;
    }
    // Bootstrap: si es fundador y aún no es admin, se crea su rol aquí.
    await _adminService.asegurarAdminFundador(usuario);
    return _adminService.rolDe(usuario.id);
  }

  Future<void> _publicarEvento() async {
    final bool? creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => const CrearConvocatoriaScreen(),
      ),
    );
    if (creado == true && mounted) {
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Evento publicado.'),
          ),
        );
      }
    }
  }

  Future<int> _contarInvitaciones() async {
    final Usuario? usuario = await LocalSessionManager.getUser();
    if (usuario == null) {
      return 0;
    }
    final List<dynamic> invitaciones = await _grupoService
        .getInvitacionesParaUsuario(usuario);
    return invitaciones.length;
  }

  Future<void> _abrirNotificaciones() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const NotificacionesScreen(),
      ),
    );
    if (mounted) {
      setState(() => _invitacionesCountFuture = _contarInvitaciones());
    }
  }

  Future<void> _refresh() async {
    final Future<List<Convocatoria>> nextFuture = _convocatoriaService
        .getConvocatoriasActivas();
    // Actualizar el feed también revalida la bandeja: es el único gesto que
    // tiene el usuario para enterarse de invitaciones nuevas sin reiniciar.
    final Future<int> nextCount = _contarInvitaciones();
    setState(() {
      _convocatoriasFuture = nextFuture;
      _invitacionesCountFuture = nextCount;
      _paginaFeed = 0;
    });
    await Future.wait<Object?>(<Future<Object?>>[nextFuture, nextCount]);
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) {
      return;
    }
    setState(() => _currentIndex = index);
  }

  void _openGrupos(Convocatoria convocatoria) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            GruposScreen(convocatoria: convocatoria),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentIndex == 0 ? AppColors.ink : AppColors.paper,
      body: IndexedStack(
        index: _currentIndex,
        children: <Widget>[
          _buildFeedTab(),
          if (_rol == RolAdmin.admin) const AdminPanelScreen(),
          const SafeArea(child: ProfileScreen()),
        ],
      ),
      bottomNavigationBar: MenuWidget(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        mostrarAdmin: _rol == RolAdmin.admin,
      ),
    );
  }

  Widget _buildFeedTab() {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: AppColors.ink,
        child: FutureBuilder<List<Convocatoria>>(
          future: _convocatoriasFuture,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<Convocatoria>> snapshot,
              ) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _FeedMensaje(
                    icon: Icons.error_outline,
                    mensaje:
                        'No pudimos cargar las convocatorias.\n'
                        '${snapshot.error}',
                    onRetry: _refresh,
                  );
                }

                final List<Convocatoria> data = List<Convocatoria>.from(
                  snapshot.data ?? <Convocatoria>[],
                );
                if (data.isEmpty) {
                  return _FeedMensaje(
                    icon: Icons.campaign_outlined,
                    mensaje: 'No hay convocatorias activas por ahora.',
                    onRetry: _refresh,
                  );
                }

                // Publicaciones más recientes primero.
                data.sort(
                  (Convocatoria a, Convocatoria b) =>
                      b.fechaPublicacion.compareTo(a.fechaPublicacion),
                );

                return Stack(
                  children: <Widget>[
                    PageView.builder(
                      scrollDirection: Axis.vertical,
                      itemCount: data.length,
                      onPageChanged: (int page) => setState(() {
                        _paginaFeed = page;
                        _soloImagen = false;
                      }),
                      itemBuilder: (BuildContext context, int index) {
                        final Convocatoria convocatoria = data[index];
                        return _FeedPage(
                          convocatoria: convocatoria,
                          activa: index == _paginaFeed,
                          soloImagen: _soloImagen,
                          mostrarHintDeslizar:
                              index == 0 && _paginaFeed == 0 && data.length > 1,
                          onVerGrupos: () => _openGrupos(convocatoria),
                          onToggleSoloImagen: () =>
                              setState(() => _soloImagen = !_soloImagen),
                        );
                      },
                    ),
                    if (!_soloImagen)
                      _FeedTopBar(
                        usuarioFuture: _usuarioFuture,
                        invitacionesCountFuture: _invitacionesCountFuture,
                        puedePublicar: _puedePublicar,
                        onRefresh: _refresh,
                        onNotificaciones: _abrirNotificaciones,
                        onPublicar: _publicarEvento,
                      ),
                  ],
                );
              },
        ),
      ),
    );
  }
}

class _FeedTopBar extends StatelessWidget {
  const _FeedTopBar({
    required this.usuarioFuture,
    required this.invitacionesCountFuture,
    required this.puedePublicar,
    required this.onRefresh,
    required this.onNotificaciones,
    required this.onPublicar,
  });

  final Future<Usuario?> usuarioFuture;
  final Future<int> invitacionesCountFuture;
  final bool puedePublicar;
  final VoidCallback onRefresh;
  final VoidCallback onNotificaciones;
  final VoidCallback onPublicar;

  String _firstName(String nombre) {
    final String trimmed = nombre.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, topInset + 10, 6, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Colors.black.withValues(alpha: 0.35),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: <Widget>[
            const HubGlyph(size: 30, lineColor: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: FutureBuilder<Usuario?>(
                future: usuarioFuture,
                builder:
                    (BuildContext context, AsyncSnapshot<Usuario?> snapshot) {
                      final Usuario? usuario = snapshot.data;
                      final String title = usuario == null
                          ? 'Yuyanna Hub'
                          : 'Hola, ${_firstName(usuario.nombre)}';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.ui(
                              size: 15,
                              weight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Convocatorias recientes',
                            style: AppTypography.ui(
                              size: 11,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      );
                    },
              ),
            ),
            if (puedePublicar)
              IconButton(
                onPressed: onPublicar,
                tooltip: 'Publicar evento',
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            IconButton(
              onPressed: onRefresh,
              tooltip: 'Actualizar',
              icon: const Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            FutureBuilder<int>(
              future: invitacionesCountFuture,
              builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
                final int count = snapshot.data ?? 0;
                return IconButton(
                  onPressed: onNotificaciones,
                  tooltip: 'Notificaciones',
                  icon: Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count'),
                    backgroundColor: AppColors.goldFill,
                    textColor: AppColors.ink,
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedPage extends StatelessWidget {
  const _FeedPage({
    required this.convocatoria,
    required this.activa,
    required this.soloImagen,
    required this.mostrarHintDeslizar,
    required this.onVerGrupos,
    required this.onToggleSoloImagen,
  });

  final Convocatoria convocatoria;
  final bool activa;
  final bool soloImagen;
  final bool mostrarHintDeslizar;
  final VoidCallback onVerGrupos;
  final VoidCallback onToggleSoloImagen;

  String _publicadoHace() {
    final DateTime? publicada = DateTime.tryParse(
      convocatoria.fechaPublicacion,
    );
    if (publicada == null) {
      return 'Publicado el ${convocatoria.fechaPublicacion}';
    }
    final DateTime hoy = DateTime.now();
    final int dias = DateTime(hoy.year, hoy.month, hoy.day)
        .difference(DateTime(publicada.year, publicada.month, publicada.day))
        .inDays;
    if (dias <= 0) {
      return 'Publicado hoy';
    }
    if (dias == 1) {
      return 'Publicado ayer';
    }
    return 'Hace $dias días';
  }

  String _estadoCierre() {
    final DateTime? cierre = DateTime.tryParse(convocatoria.fechaCierre);
    if (cierre == null) {
      return 'Cierra el ${convocatoria.fechaCierre}';
    }
    final DateTime hoy = DateTime.now();
    final int dias = DateTime(
      cierre.year,
      cierre.month,
      cierre.day,
    ).difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
    if (dias < 0) {
      return 'Convocatoria cerrada';
    }
    if (dias == 0) {
      return 'Cierra hoy';
    }
    if (dias == 1) {
      return 'Cierra mañana';
    }
    return 'Cierra el ${convocatoria.fechaCierre} · $dias días';
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    return GestureDetector(
      onDoubleTap: onToggleSoloImagen,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          gradient: TipoConvocatoria.gradient(convocatoria.tipo),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Fondo: video (si hay) > imagen > gradiente del tipo (fallback).
            if (convocatoria.tieneVideo)
              Positioned.fill(
                child: _VideoFondo(url: convocatoria.videoUrl!, activa: activa),
              )
            else if (convocatoria.tieneImagen)
              Positioned.fill(
                child: _FondoImagen(
                  url: convocatoria.imagenUrl!,
                  fallback: TipoConvocatoria.gradient(convocatoria.tipo),
                ),
              ),
            // Overlays (se ocultan en modo "solo imagen" con doble-tap).
            if (!soloImagen) ...<Widget>[
              Positioned(
                top: -70,
                right: -50,
                child: _Blob(
                  size: 240,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              Positioned(
                bottom: 180,
                left: -80,
                child: _Blob(
                  size: 220,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              // Scrim: mantiene la mitad superior limpia (se ve la imagen) y
              // oscurece con fuerza la parte inferior para que el texto se lea.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.25),
                        Colors.black.withValues(alpha: 0.75),
                        Colors.black.withValues(alpha: 0.95),
                      ],
                      stops: const <double>[0.0, 0.45, 0.72, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 88,
                bottom: bottomInset + 22,
                child: _InfoConvocatoria(
                  convocatoria: convocatoria,
                  publicadoHace: _publicadoHace(),
                  estadoCierre: _estadoCierre(),
                ),
              ),
              Positioned(
                right: 10,
                bottom: bottomInset + 22,
                child: _RailAcciones(onVerGrupos: onVerGrupos),
              ),
              if (mostrarHintDeslizar)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: bottomInset + 4,
                  child: IgnorePointer(
                    child:
                        Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  size: 22,
                                ),
                                Text(
                                  'Desliza para ver más',
                                  style: AppTypography.ui(
                                    size: 11,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            )
                            .animate(
                              onPlay: (AnimationController c) => c.repeat(),
                            )
                            .moveY(
                              begin: 4,
                              end: -4,
                              duration: 900.ms,
                              curve: Curves.easeInOut,
                            )
                            .then()
                            .moveY(
                              begin: -4,
                              end: 4,
                              duration: 900.ms,
                              curve: Curves.easeInOut,
                            ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoConvocatoria extends StatelessWidget {
  const _InfoConvocatoria({
    required this.convocatoria,
    required this.publicadoHace,
    required this.estadoCierre,
  });

  final Convocatoria convocatoria;
  final String publicadoHace;
  final String estadoCierre;

  static const List<Shadow> _sombraTexto = <Shadow>[
    Shadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 1)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        convocatoria.tipo.toUpperCase(),
                        style: AppTypography.ui(
                          size: 10,
                          weight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        publicadoHace,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.ui(
                          size: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  convocatoria.titulo,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.display(
                    size: 28,
                    color: Colors.white,
                    height: 1.08,
                  ).copyWith(shadows: _sombraTexto),
                ),
                const SizedBox(height: 10),
                _DescripcionConLeerMas(
                  texto: convocatoria.descripcion,
                  style: AppTypography.ui(
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.45,
                  ).copyWith(shadows: _sombraTexto),
                  onLeerMas: () => _mostrarDetalle(
                    context,
                    convocatoria,
                    publicadoHace,
                    estadoCierre,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.emoji_events_outlined,
                      color: AppColors.goldFill,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        convocatoria.premio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.ui(
                          size: 13,
                          weight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.schedule_rounded,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        estadoCierre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.ui(
                          size: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ]
              .animate(interval: 60.ms)
              .fadeIn(duration: 320.ms)
              .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
    );
  }
}

/// Descripción del evento que se corta a [_maxLineas] líneas y, solo si el
/// texto no cabe completo, muestra un enlace "Leer más".
class _DescripcionConLeerMas extends StatelessWidget {
  const _DescripcionConLeerMas({
    required this.texto,
    required this.style,
    required this.onLeerMas,
  });

  final String texto;
  final TextStyle style;
  final VoidCallback onLeerMas;

  static const int _maxLineas = 4;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final TextPainter painter = TextPainter(
          text: TextSpan(text: texto, style: style),
          maxLines: _maxLineas,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);
        final bool truncado = painter.didExceedMaxLines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              texto,
              maxLines: _maxLineas,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
            if (truncado) ...<Widget>[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onLeerMas,
                child: Text(
                  'Leer más',
                  style:
                      AppTypography.ui(
                        size: 13,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ).copyWith(
                        shadows: _InfoConvocatoria._sombraTexto,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white,
                      ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

void _mostrarDetalle(
  BuildContext context,
  Convocatoria convocatoria,
  String publicadoHace,
  String estadoCierre,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext context) => _DetalleConvocatoria(
      convocatoria: convocatoria,
      publicadoHace: publicadoHace,
      estadoCierre: estadoCierre,
    ),
  );
}

class _DetalleConvocatoria extends StatelessWidget {
  const _DetalleConvocatoria({
    required this.convocatoria,
    required this.publicadoHace,
    required this.estadoCierre,
  });

  final Convocatoria convocatoria;
  final String publicadoHace;
  final String estadoCierre;

  @override
  Widget build(BuildContext context) {
    final Color tipoColor = TipoConvocatoria.textColor(convocatoria.tipo);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: TipoConvocatoria.color(convocatoria.tipo),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          convocatoria.tipo.toUpperCase(),
                          style: AppTypography.ui(
                            size: 10,
                            weight: FontWeight.w700,
                            color: tipoColor,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        publicadoHace,
                        style: AppTypography.ui(
                          size: 12,
                          color: AppColors.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    convocatoria.titulo,
                    style: AppTypography.display(size: 24, height: 1.1),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    convocatoria.descripcion,
                    style: AppTypography.ui(
                      size: 15,
                      color: AppColors.ink,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _DetalleFila(
                    icon: Icons.emoji_events_outlined,
                    color: AppColors.gold,
                    titulo: 'Premio / beneficio',
                    valor: convocatoria.premio,
                  ),
                  const SizedBox(height: 14),
                  _DetalleFila(
                    icon: Icons.checklist_rtl_outlined,
                    color: AppColors.blue,
                    titulo: 'Requisitos',
                    valor: convocatoria.requisitos,
                  ),
                  const SizedBox(height: 14),
                  _DetalleFila(
                    icon: Icons.schedule_rounded,
                    color: AppColors.red,
                    titulo: 'Cierre',
                    valor: estadoCierre,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetalleFila extends StatelessWidget {
  const _DetalleFila({
    required this.icon,
    required this.color,
    required this.titulo,
    required this.valor,
  });

  final IconData icon;
  final Color color;
  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                titulo,
                style: AppTypography.ui(
                  size: 11.5,
                  color: AppColors.inkSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: AppTypography.ui(
                  size: 14.5,
                  weight: FontWeight.w600,
                  color: AppColors.ink,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RailAcciones extends StatelessWidget {
  const _RailAcciones({required this.onVerGrupos});

  final VoidCallback onVerGrupos;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _AccionRail(
          icon: Icons.groups_rounded,
          color: Colors.white,
          label: 'Grupos',
          onTap: onVerGrupos,
        ),
      ],
    );
  }
}

class _AccionRail extends StatelessWidget {
  const _AccionRail({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.ui(
                size: 10,
                weight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedMensaje extends StatelessWidget {
  const _FeedMensaje({
    required this.icon,
    required this.mensaje,
    required this.onRetry,
  });

  final IconData icon;
  final String mensaje;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 42),
            const SizedBox(height: 12),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: AppTypography.ui(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Fondo de imagen del feed: la imagen se ajusta al **ancho** completo (sin
/// recortar los lados) y el espacio sobrante (arriba/abajo) se rellena con un
/// degradado derivado del **color más notorio** de la propia imagen. Mientras
/// se calcula el color, se ve el gradiente [fallback] del tipo de evento.
class _FondoImagen extends StatefulWidget {
  const _FondoImagen({required this.url, required this.fallback});

  final String url;
  final Gradient fallback;

  @override
  State<_FondoImagen> createState() => _FondoImagenState();
}

class _FondoImagenState extends State<_FondoImagen> {
  /// Caché del color por URL: se calcula una sola vez, así reciclar/rebuild de
  /// las páginas del PageView no vuelve a decodificar la imagen (era la causa
  /// del scroll trabado).
  static final Map<String, Color> _cacheColores = <String, Color>{};

  late ImageProvider _provider;
  Color? _color;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant _FondoImagen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // El PageView recicla la página para otro evento: recarga si cambió la URL.
    if (oldWidget.url != widget.url) {
      _cargar();
    }
  }

  void _cargar() {
    _provider = NetworkImage(widget.url);
    final Color? cacheado = _cacheColores[widget.url];
    if (cacheado != null) {
      _color = cacheado; // instantáneo, sin trabajo async ni "salto" de color.
      return;
    }
    _color = null;
    _extraerColor();
  }

  Future<void> _extraerColor() async {
    final String url = widget.url;
    try {
      final PaletteGenerator paleta = await PaletteGenerator.fromImageProvider(
        _provider,
        size: const Size(90, 90),
        maximumColorCount: 8,
      );
      // "Más notorio": primero el color vibrante; si no hay, el dominante.
      final Color? color =
          paleta.vibrantColor?.color ??
          paleta.dominantColor?.color ??
          paleta.mutedColor?.color;
      if (color == null) {
        return;
      }
      _cacheColores[url] = color;
      // Solo aplicamos si esta página sigue mostrando la misma imagen.
      if (mounted && widget.url == url) {
        setState(() => _color = color);
      }
    } catch (_) {
      // Se queda el gradiente fallback del tipo.
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color? c = _color;
    final Gradient gradiente = c == null
        ? widget.fallback
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color.lerp(c, Colors.black, 0.25)!,
              Color.lerp(c, Colors.black, 0.55)!,
              Color.lerp(c, Colors.black, 0.8)!,
            ],
          );
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // El color entra con una transición suave (no un salto brusco).
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          child: SizedBox.expand(
            key: ValueKey<Color?>(c),
            child: DecoratedBox(decoration: BoxDecoration(gradient: gradiente)),
          ),
        ),
        // Ajusta al ancho; lo que sobra arriba/abajo deja ver el degradado.
        Image(
          image: _provider,
          fit: BoxFit.fitWidth,
          alignment: Alignment.center,
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stackTrace) =>
                  const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Video de fondo de una página del feed. Se reproduce en bucle y silenciado
/// (política de autoplay del navegador) solo cuando la página está [activa];
/// en las demás se pausa. Si falla la carga, deja ver el fallback detrás.
class _VideoFondo extends StatefulWidget {
  const _VideoFondo({required this.url, required this.activa});

  final String url;
  final bool activa;

  @override
  State<_VideoFondo> createState() => _VideoFondoState();
}

class _VideoFondoState extends State<_VideoFondo> {
  VideoPlayerController? _controller;
  bool _listo = false;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    final VideoPlayerController controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
    );
    _controller = controller;
    try {
      await controller.initialize();
    } catch (_) {
      return; // Queda el fallback (imagen/gradiente) detrás.
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    await controller.setLooping(true);
    await controller.setVolume(0);
    setState(() => _listo = true);
    _sincronizarReproduccion();
  }

  void _sincronizarReproduccion() {
    final VideoPlayerController? c = _controller;
    if (c == null || !_listo) {
      return;
    }
    if (widget.activa) {
      c.play();
    } else {
      c.pause();
      c.seekTo(Duration.zero);
    }
  }

  @override
  void didUpdateWidget(_VideoFondo oldWidget) {
    super.didUpdateWidget(oldWidget);
    // El PageView recicla la página para otro evento: reinicia el controlador.
    if (oldWidget.url != widget.url) {
      _listo = false;
      _controller?.dispose();
      _controller = null;
      _inicializar();
      return;
    }
    if (oldWidget.activa != widget.activa) {
      _sincronizarReproduccion();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? c = _controller;
    if (!_listo || c == null) {
      return const SizedBox.shrink();
    }
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: c.value.size.width,
        height: c.value.size.height,
        child: VideoPlayer(c),
      ),
    );
  }
}
