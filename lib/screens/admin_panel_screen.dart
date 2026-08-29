import 'package:flutter/material.dart';

import '../models/convocatoria.dart';
import '../models/grupo.dart';
import '../models/usuario.dart';
import '../services/admin_service.dart';
import '../services/convocatoria_service.dart';
import '../services/grupo_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'crear_convocatoria_screen.dart';

/// Panel de administración (solo admins). 4 pestañas: Eventos, Usuarios,
/// Grupos y Admins. Cada una lista desde Firestore y ofrece acciones.
class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel de administración'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: 'Eventos', icon: Icon(Icons.campaign_outlined)),
              Tab(text: 'Usuarios', icon: Icon(Icons.people_outline)),
              Tab(text: 'Grupos', icon: Icon(Icons.groups_outlined)),
              Tab(text: 'Admins', icon: Icon(Icons.shield_outlined)),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[
            _EventosTab(),
            _UsuariosTab(),
            _GruposTab(),
            _AdminsTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pestaña: Eventos
// ---------------------------------------------------------------------------

class _EventosTab extends StatefulWidget {
  const _EventosTab();

  @override
  State<_EventosTab> createState() => _EventosTabState();
}

class _EventosTabState extends State<_EventosTab> {
  final ConvocatoriaService _service = ConvocatoriaService();
  late Future<List<Convocatoria>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getConvocatoriasActivas();
  }

  void _recargar() =>
      setState(() => _future = _service.getConvocatoriasActivas());

  Future<void> _crear() async {
    final bool? creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => const CrearConvocatoriaScreen(),
      ),
    );
    if (creado == true) {
      _recargar();
    }
  }

  Future<void> _editar(Convocatoria c) async {
    final bool? guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) =>
            CrearConvocatoriaScreen(convocatoria: c),
      ),
    );
    if (guardado == true) {
      _recargar();
    }
  }

  Future<void> _eliminar(Convocatoria c) async {
    final bool ok = await _confirmar(context, '¿Eliminar el evento "${c.titulo}"?');
    if (!ok) {
      return;
    }
    await _service.eliminarConvocatoria(c.id);
    if (mounted) {
      _recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _crear,
              icon: const Icon(Icons.add),
              label: const Text('Publicar evento nuevo'),
            ),
          ),
        ),
        Expanded(
          child: _ListaFuture<Convocatoria>(
            future: _future,
            onRefresh: _recargar,
            vacio: 'Aún no hay eventos publicados.',
            item: (Convocatoria c) => Card(
              child: ListTile(
                leading: Icon(
                  c.tieneVideo
                      ? Icons.movie_outlined
                      : (c.tieneImagen
                          ? Icons.image_outlined
                          : Icons.campaign_outlined),
                  color: AppColors.blue,
                ),
                title: Text(c.titulo),
                subtitle: Text('${c.tipo} · cierra ${c.fechaCierre}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Editar',
                      icon: const Icon(Icons.edit_outlined,
                          color: AppColors.blue),
                      onPressed: () => _editar(c),
                    ),
                    IconButton(
                      tooltip: 'Eliminar',
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.red),
                      onPressed: () => _eliminar(c),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pestaña: Usuarios
// ---------------------------------------------------------------------------

class _UsuariosTab extends StatefulWidget {
  const _UsuariosTab();

  @override
  State<_UsuariosTab> createState() => _UsuariosTabState();
}

class _UsuariosTabState extends State<_UsuariosTab> {
  final GrupoService _grupoService = GrupoService();
  final AdminService _adminService = AdminService();
  late Future<({List<Usuario> usuarios, Map<String, RolAdmin> roles})> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargar();
  }

  Future<({List<Usuario> usuarios, Map<String, RolAdmin> roles})>
      _cargar() async {
    final List<Usuario> usuarios = await _grupoService.getUsuarios();
    final Map<String, RolAdmin> roles = await _adminService.rolesDeAdmins();
    usuarios.sort((Usuario a, Usuario b) =>
        a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    return (usuarios: usuarios, roles: roles);
  }

  void _recargar() => setState(() => _future = _cargar());

  Future<void> _hacerAdmin(Usuario u) async {
    final RolAdmin? rol = await _elegirRol(context, u.nombre);
    if (rol == null) {
      return;
    }
    await _adminService.promover(u, rol: rol);
    if (mounted) {
      _recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({List<Usuario> usuarios, Map<String, RolAdmin> roles})>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<({List<Usuario> usuarios, Map<String, RolAdmin> roles})> snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _MensajeCentro(
              texto: 'Error: ${snap.error}', onReintentar: _recargar);
        }
        final List<Usuario> usuarios = snap.data?.usuarios ?? <Usuario>[];
        final Map<String, RolAdmin> roles =
            snap.data?.roles ?? <String, RolAdmin>{};
        if (usuarios.isEmpty) {
          return _MensajeCentro(
              texto: 'No hay usuarios registrados.', onReintentar: _recargar);
        }
        return RefreshIndicator(
          onRefresh: () async => _recargar(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: usuarios.length,
            itemBuilder: (BuildContext context, int i) {
              final Usuario u = usuarios[i];
              final RolAdmin? rol = roles[u.id];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.blue.withValues(alpha: 0.15),
                    child: Text(
                      _iniciales(u.nombre),
                      style: AppTypography.ui(
                          size: 13, weight: FontWeight.w700),
                    ),
                  ),
                  title: Text(u.nombre),
                  subtitle: Text(u.correo),
                  trailing: rol != null
                      ? _Etiqueta(
                          texto: rol.etiqueta,
                          color: rol == RolAdmin.admin
                              ? AppColors.gold
                              : AppColors.blue,
                        )
                      : TextButton(
                          onPressed: () => _hacerAdmin(u),
                          child: const Text('Hacer admin'),
                        ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Pestaña: Grupos
// ---------------------------------------------------------------------------

class _GruposTab extends StatefulWidget {
  const _GruposTab();

  @override
  State<_GruposTab> createState() => _GruposTabState();
}

class _GruposTabState extends State<_GruposTab> {
  final GrupoService _service = GrupoService();
  late Future<List<Grupo>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getTodosLosGrupos();
  }

  void _recargar() => setState(() => _future = _service.getTodosLosGrupos());

  Future<void> _eliminar(Grupo g) async {
    final bool ok = await _confirmar(context, '¿Eliminar el grupo "${g.nombre}"?');
    if (!ok) {
      return;
    }
    await _service.eliminarGrupo(g.id);
    if (mounted) {
      _recargar();
    }
  }

  String _estado(Grupo g) {
    if (g.estado == EstadoGrupo.borrador) {
      return 'Borrador';
    }
    return g.abierto ? 'Publicado · abierto' : 'Publicado · cerrado';
  }

  @override
  Widget build(BuildContext context) {
    return _ListaFuture<Grupo>(
      future: _future,
      onRefresh: _recargar,
      vacio: 'Aún no hay grupos.',
      item: (Grupo g) => Card(
        child: ListTile(
          leading: const Icon(Icons.groups_outlined, color: AppColors.blue),
          title: Text(g.nombre),
          subtitle: Text(
            '${_estado(g)} · ${g.integrantes}/${g.capacidadMax} · líder: ${g.liderNombre}',
          ),
          trailing: IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline, color: AppColors.red),
            onPressed: () => _eliminar(g),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pestaña: Admins
// ---------------------------------------------------------------------------

class _AdminsTab extends StatefulWidget {
  const _AdminsTab();

  @override
  State<_AdminsTab> createState() => _AdminsTabState();
}

class _AdminsTabState extends State<_AdminsTab> {
  final AdminService _service = AdminService();
  final TextEditingController _correoController = TextEditingController();
  late Future<List<AdminInfo>> _future;
  bool _promoviendo = false;

  @override
  void initState() {
    super.initState();
    _future = _service.listarAdmins();
  }

  @override
  void dispose() {
    _correoController.dispose();
    super.dispose();
  }

  void _recargar() => setState(() => _future = _service.listarAdmins());

  Future<void> _promover() async {
    final String correo = _correoController.text.trim();
    if (correo.isEmpty) {
      return;
    }
    final RolAdmin? rol = await _elegirRol(context, correo);
    if (rol == null) {
      return;
    }
    setState(() => _promoviendo = true);
    try {
      await _service.promoverPorCorreo(correo, rol: rol);
      _correoController.clear();
      if (mounted) {
        _mostrar('Admin agregado.');
        _recargar();
      }
    } catch (error) {
      if (mounted) {
        _mostrar('$error', esError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _promoviendo = false);
      }
    }
  }

  Future<void> _cambiarRol(AdminInfo a) async {
    final RolAdmin? rol =
        await _elegirRol(context, a.nombre.isEmpty ? a.correo : a.nombre);
    if (rol == null || rol == a.rol) {
      return;
    }
    await _service.cambiarRol(a.uid, rol);
    if (mounted) {
      _recargar();
    }
  }

  Future<void> _quitar(AdminInfo a) async {
    final bool ok = await _confirmar(context, '¿Quitar admin a ${a.nombre}?');
    if (!ok) {
      return;
    }
    await _service.quitarAdmin(a.uid);
    if (mounted) {
      _recargar();
    }
  }

  void _mostrar(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: esError ? AppColors.red : null,
        content: Text(mensaje),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _correoController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Promover por correo',
                    hintText: 'correo@ejemplo.com',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  onSubmitted: (_) => _promover(),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _promoviendo ? null : _promover,
                  child: _promoviendo
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add_alt),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _ListaFuture<AdminInfo>(
            future: _future,
            onRefresh: _recargar,
            vacio: 'No hay administradores.',
            item: (AdminInfo a) => Card(
              child: ListTile(
                leading: Icon(
                  a.rol == RolAdmin.paqarina
                      ? Icons.event_outlined
                      : (a.fundador
                          ? Icons.verified_user
                          : Icons.shield_outlined),
                  color:
                      a.rol == RolAdmin.admin ? AppColors.gold : AppColors.blue,
                ),
                title: Text(a.nombre.isEmpty ? a.correo : a.nombre),
                subtitle: Text(
                  '${a.correo} · ${a.rol.etiqueta}'
                  '${a.fundador ? ' · fundador' : ''}',
                ),
                trailing: a.fundador
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            tooltip: 'Cambiar rol',
                            icon: const Icon(Icons.swap_horiz,
                                color: AppColors.blue),
                            onPressed: () => _cambiarRol(a),
                          ),
                          IconButton(
                            tooltip: 'Quitar admin',
                            icon: const Icon(Icons.remove_circle_outline,
                                color: AppColors.red),
                            onPressed: () => _quitar(a),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reutilizables
// ---------------------------------------------------------------------------

class _ListaFuture<T> extends StatelessWidget {
  const _ListaFuture({
    required this.future,
    required this.onRefresh,
    required this.vacio,
    required this.item,
    super.key,
  });

  final Future<List<T>> future;
  final VoidCallback onRefresh;
  final String vacio;
  final Widget Function(T) item;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<T>>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<List<T>> snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _MensajeCentro(
              texto: 'Error: ${snap.error}', onReintentar: onRefresh);
        }
        final List<T> items = snap.data ?? <T>[];
        if (items.isEmpty) {
          return _MensajeCentro(texto: vacio, onReintentar: onRefresh);
        }
        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (BuildContext context, int i) => item(items[i]),
          ),
        );
      },
    );
  }
}

class _MensajeCentro extends StatelessWidget {
  const _MensajeCentro({required this.texto, required this.onReintentar});

  final String texto;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              texto,
              textAlign: TextAlign.center,
              style: AppTypography.ui(color: AppColors.inkSecondary),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Recargar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        texto,
        style: AppTypography.ui(
            size: 11, weight: FontWeight.w700, color: AppColors.ink),
      ),
    );
  }
}

String _iniciales(String nombre) {
  final List<String> partes = nombre
      .trim()
      .split(RegExp(r'\s+'))
      .where((String p) => p.isNotEmpty)
      .toList();
  if (partes.isEmpty) {
    return '?';
  }
  if (partes.length == 1) {
    return partes.first.substring(0, 1).toUpperCase();
  }
  return (partes[0].substring(0, 1) + partes[1].substring(0, 1)).toUpperCase();
}

Future<RolAdmin?> _elegirRol(BuildContext context, String quien) {
  return showDialog<RolAdmin>(
    context: context,
    builder: (BuildContext context) => SimpleDialog(
      backgroundColor: AppColors.surface,
      title: Text('Rol para $quien', style: AppTypography.display(size: 18)),
      children: <Widget>[
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(RolAdmin.admin),
          child: const ListTile(
            leading: Icon(Icons.admin_panel_settings_outlined,
                color: AppColors.red),
            title: Text('Administrador'),
            subtitle: Text('Acceso completo al panel'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(RolAdmin.paqarina),
          child: const ListTile(
            leading: Icon(Icons.event_outlined, color: AppColors.blue),
            title: Text('Admin Paqarina'),
            subtitle: Text('Solo ve eventos y sus grupos'),
          ),
        ),
      ],
    ),
  );
}

Future<bool> _confirmar(BuildContext context, String mensaje) async {
  final bool? r = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      backgroundColor: AppColors.surface,
      content: Text(mensaje, style: AppTypography.ui(size: 15)),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Confirmar'),
        ),
      ],
    ),
  );
  return r ?? false;
}
