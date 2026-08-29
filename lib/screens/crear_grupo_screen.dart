import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../database/sqlite_helper.dart';
import '../models/convocatoria.dart';
import '../models/grupo.dart';
import '../models/invitacion_grupo.dart';
import '../models/usuario.dart';
import '../services/grupo_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/gradient_button.dart';
import '../widgets/selector_habilidades.dart';
import '../widgets/selector_usuario.dart';

/// Formulario para crear un grupo. Se abre desde la vista de grupos de una
/// convocatoria ([GruposScreen]), por lo que recibe la [convocatoria] ya
/// seleccionada y la fija (no se elige otra).
class CrearGrupoScreen extends StatefulWidget {
  const CrearGrupoScreen({super.key, required this.convocatoria});

  final Convocatoria convocatoria;

  @override
  State<CrearGrupoScreen> createState() => _CrearGrupoScreenState();
}

class _CrearGrupoScreenState extends State<CrearGrupoScreen> {
  final GrupoService _grupoService = GrupoService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _capacidadController =
      TextEditingController(text: '3');

  final List<String> _habilidades = <String>[];
  final List<Usuario> _miembrosIniciales = <Usuario>[];

  late Future<_FormBootstrap> _bootstrapFuture;
  Convocatoria? _selectedConvocatoria;
  bool _isSubmitting = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _selectedConvocatoria = widget.convocatoria;
    _bootstrapFuture = _loadBootstrap();
  }

  Future<_FormBootstrap> _loadBootstrap() async {
    final Usuario? usuario = await LocalSessionManager.getUser();
    final List<Usuario> usuarios = await _grupoService.getUsuarios();
    return _FormBootstrap(usuario: usuario, usuarios: usuarios);
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _capacidadController.dispose();
    super.dispose();
  }

  String? _validateNombre(String? value) {
    final String nombre = (value ?? '').trim();
    if (nombre.isEmpty) {
      return 'Ingresa un nombre para el grupo.';
    }
    if (nombre.length < 3) {
      return 'El nombre debe tener al menos 3 caracteres.';
    }
    return null;
  }

  String? _validateDescripcion(String? value) {
    final String desc = (value ?? '').trim();
    if (desc.isEmpty) {
      return 'Describe brevemente el grupo.';
    }
    if (desc.length < 15) {
      return 'La descripción debe tener al menos 15 caracteres.';
    }
    return null;
  }

  String? _validateCapacidad(String? value) {
    final String raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return 'Ingresa la capacidad máxima.';
    }
    final int? capacidad = int.tryParse(raw);
    if (capacidad == null) {
      return 'Debe ser un número entero.';
    }
    if (capacidad < 2 || capacidad > 8) {
      return 'La capacidad debe estar entre 2 y 8.';
    }
    return null;
  }



  Future<void> _agregarMiembroInicial(_FormBootstrap data) async {
    final Set<String> excluidos = <String>{
      if (data.usuario != null) data.usuario!.id,
      ..._miembrosIniciales.map<String>((Usuario u) => u.id),
    };
    final Usuario? elegido = await mostrarSelectorUsuario(
      context,
      usuarios: data.usuarios,
      excluirIds: excluidos,
    );
    if (elegido != null && mounted) {
      setState(() => _miembrosIniciales.add(elegido));
    }
  }

  Usuario _liderDe(Usuario? usuario) {
    if (usuario != null && usuario.nombre.trim().isNotEmpty) {
      return usuario;
    }
    return const Usuario(
      id: 'anon',
      nombre: 'Estudiante UNSAAC',
      correo: '',
      escuelaProfesional: '',
      semestre: 1,
      habilidades: <String>[],
    );
  }

  Future<void> _submit(Usuario? usuario) async {
    setState(() => _submitted = true);

    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    if (_selectedConvocatoria == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una convocatoria.')),
      );
      return;
    }
    if (_habilidades.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Indica al menos una habilidad buscada: sin ellas nadie '
            'recibirá la invitación.',
          ),
        ),
      );
      return;
    }
    final int capacidad = int.parse(_capacidadController.text.trim());
    if (_miembrosIniciales.length + 1 > capacidad) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Los integrantes iniciales superan la capacidad máxima.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final Convocatoria convocatoria = _selectedConvocatoria!;
    final Usuario lider = _liderDe(usuario);

    final Grupo nuevo = await _grupoService.crearGrupo(
      convocatoriaId: convocatoria.id,
      nombre: _nombreController.text.trim(),
      descripcion: _descripcionController.text.trim(),
      lider: lider,
      capacidadMax: capacidad,
      habilidadesBuscadas: List<String>.unmodifiable(_habilidades),
      miembrosIniciales: List<Usuario>.unmodifiable(_miembrosIniciales),
    );

    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);

    await _preguntarPublicacion(nuevo, lider);

    // Volvemos a la vista de grupos (que refresca y muestra el nuevo grupo).
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _preguntarPublicacion(
    Grupo grupo,
    Usuario lider,
  ) async {
    final bool? publicar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            '¿Publicar "${grupo.nombre}"?',
            style: AppTypography.display(size: 19),
          ),
          content: Text(
            'Al publicarlo, la app buscará a los estudiantes que mejor '
            'cubren las habilidades que faltan y notificará a los '
            '${GrupoService.maxInvitaciones} mejores perfiles para que '
            'puedan unirse. Mientras sea borrador, solo tú lo ves.',
            style: AppTypography.ui(
              size: 13.5,
              color: AppColors.inkSecondary,
              height: 1.45,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Dejar como borrador'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Publicar'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (publicar != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Grupo "${grupo.nombre}" guardado como borrador. Publícalo '
            'cuando quieras desde la lista de grupos o en "Mis grupos".',
          ),
        ),
      );
      return;
    }

    final ResultadoPublicacion resultado = await _grupoService.publicarGrupo(
      grupoId: grupo.id,
      usuarioSesion: lider.id == 'anon' ? null : lider,
    );

    if (!mounted) {
      return;
    }
    await _mostrarResultadoPublicacion(resultado);
  }

  Future<void> _mostrarResultadoPublicacion(
    ResultadoPublicacion resultado,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        final List<InvitacionGrupo> invitaciones = resultado.invitaciones;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '¡"${resultado.grupo.nombre}" publicado!',
                  style: AppTypography.display(size: 19),
                ),
                const SizedBox(height: 6),
                Text(
                  invitaciones.isEmpty
                      ? 'No encontramos perfiles que coincidan con las '
                          'habilidades buscadas. Los estudiantes igual '
                          'podrán solicitar unirse.'
                      : 'Notificamos a los ${invitaciones.length} mejores '
                          'perfiles para las habilidades que buscas:',
                  style: AppTypography.ui(
                    size: 13,
                    color: AppColors.inkSecondary,
                    height: 1.4,
                  ),
                ),
                if (invitaciones.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: invitaciones.length,
                      itemBuilder: (BuildContext context, int index) {
                        final InvitacionGrupo inv = invitaciones[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                AppColors.gold.withValues(alpha: 0.15),
                            child: Text(
                              '${index + 1}',
                              style: AppTypography.ui(
                                size: 13,
                                weight: FontWeight.w700,
                                color: AppColors.gold,
                              ),
                            ),
                          ),
                          title: Text(
                            inv.usuario.nombre,
                            style: AppTypography.ui(
                              size: 14,
                              weight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'Coincide en: '
                            '${inv.habilidadesCoincidentes.join(', ')}',
                            style: AppTypography.ui(
                              size: 12,
                              color: AppColors.inkSecondary,
                            ),
                          ),
                          trailing: Text(
                            '${inv.puntuacion} pts',
                            style: AppTypography.ui(
                              size: 12.5,
                              weight: FontWeight.w700,
                              color: AppColors.blue,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Listo'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear grupo')),
      body: SafeArea(
        child: FutureBuilder<_FormBootstrap>(
          future: _bootstrapFuture,
          builder:
              (BuildContext context, AsyncSnapshot<_FormBootstrap> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Ocurrió un error al cargar el formulario: ${snapshot.error}',
                  style: AppTypography.ui(color: AppColors.red),
                ),
              );
            }
            final _FormBootstrap data = snapshot.requireData;
            return _buildForm(data);
          },
        ),
      ),
    );
  }

  Widget _buildForm(_FormBootstrap data) {
    final AutovalidateMode fieldAutovalidateMode = _submitted
        ? AutovalidateMode.onUserInteraction
        : AutovalidateMode.disabled;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const _ScreenHeader(),
            const SizedBox(height: 20),
            const _SectionTitle(label: 'Convocatoria'),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.campaign_outlined,
                    color: AppColors.inkSecondary),
              ),
              child: Text(
                widget.convocatoria.titulo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.ui(
                    size: 14, weight: FontWeight.w600, color: AppColors.ink),
              ),
            ),
            const SizedBox(height: 18),
            const _SectionTitle(label: 'Datos del grupo'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nombreController,
              autovalidateMode: fieldAutovalidateMode,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre del grupo',
                hintText: 'Ej. EcoSaq Startup',
                prefixIcon:
                    Icon(Icons.badge_outlined, color: AppColors.inkSecondary),
              ),
              validator: _validateNombre,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descripcionController,
              autovalidateMode: fieldAutovalidateMode,
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,
              maxLines: 4,
              minLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText:
                    'Cuenta de qué trata tu proyecto y qué perfiles buscas.',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 56),
                  child:
                      Icon(Icons.notes_outlined, color: AppColors.inkSecondary),
                ),
              ),
              validator: _validateDescripcion,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _capacidadController,
              autovalidateMode: fieldAutovalidateMode,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(1),
              ],
              decoration: const InputDecoration(
                labelText: 'Capacidad máxima (2-8)',
                hintText: 'Ej. 4',
                prefixIcon:
                    Icon(Icons.groups_outlined, color: AppColors.inkSecondary),
              ),
              validator: _validateCapacidad,
            ),
            const SizedBox(height: 20),
            const _SectionTitle(label: 'Habilidades buscadas (opcional)'),
            const SizedBox(height: 8),
            SelectorHabilidades(
              habilidadesSeleccionadas: _habilidades,
              onChanged: (List<String> nuevas) {
                setState(() {
                  _habilidades
                    ..clear()
                    ..addAll(nuevas);
                });
              },
            ),
            const SizedBox(height: 20),
            const _SectionTitle(label: 'Integrantes iniciales (opcional)'),
            const SizedBox(height: 6),
            Text(
              'Antes de publicar puedes agregar a quien quieras. Una vez '
              'publicado, los demás solo entran por invitación de la app, '
              'solicitud aprobada o si tú los agregas.',
              style: AppTypography.ui(
                size: 12,
                color: AppColors.inkSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed:
                  _isSubmitting ? null : () => _agregarMiembroInicial(data),
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
              label: const Text('Agregar integrante'),
            ),
            if (_miembrosIniciales.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _miembrosIniciales
                    .map<Widget>(
                      (Usuario u) => Chip(
                        avatar: CircleAvatar(
                          backgroundColor:
                              AppColors.blue.withValues(alpha: 0.15),
                          child: Text(
                            u.nombre.isEmpty ? '?' : u.nombre[0].toUpperCase(),
                            style: AppTypography.ui(
                              size: 11,
                              weight: FontWeight.w700,
                              color: AppColors.blue,
                            ),
                          ),
                        ),
                        label: Text(u.nombre),
                        labelStyle:
                            AppTypography.ui(size: 13, color: AppColors.ink),
                        backgroundColor: AppColors.surfaceTint,
                        side: const BorderSide(color: AppColors.line),
                        deleteIconColor: AppColors.inkSecondary,
                        onDeleted: _isSubmitting
                            ? null
                            : () => setState(
                                  () => _miembrosIniciales.remove(u),
                                ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 28),
            GradientButton(
              label: _isSubmitting ? 'Creando…' : 'CREAR GRUPO',
              icon: Icons.add_box_outlined,
              loading: _isSubmitting,
              onPressed: _isSubmitting ? null : () => _submit(data.usuario),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                data.usuario == null
                    ? 'Inicia sesión para figurar como líder del grupo.'
                    : 'Tú serás el líder. El grupo se crea como borrador '
                        'y eliges cuándo publicarlo.',
                textAlign: TextAlign.center,
                style: AppTypography.ui(size: 12, color: AppColors.inkSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: AppGradients.primaryButton,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.add_box_outlined, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Crear Grupo', style: AppTypography.display(size: 22)),
              Text(
                'Postula en equipo a una convocatoria',
                style:
                    AppTypography.ui(size: 12, color: AppColors.inkSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label.toUpperCase(),
        style: AppTypography.ui(
          size: 12,
          weight: FontWeight.w700,
          color: AppColors.inkSecondary,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _FormBootstrap {
  const _FormBootstrap({
    required this.usuario,
    required this.usuarios,
  });

  final Usuario? usuario;
  final List<Usuario> usuarios;
}
