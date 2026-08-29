import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/gradient_button.dart';
import '../widgets/selector_habilidades.dart';

/// Edición del perfil propio: nombre, tipo (Estudiante/Externo) con sus
/// campos, y habilidades. El correo no se edita (es la identidad de la cuenta).
/// Devuelve el [Usuario] actualizado con `Navigator.pop` al guardar.
class EditarPerfilScreen extends StatefulWidget {
  const EditarPerfilScreen({
    super.key,
    required this.usuario,
    this.authService,
  });

  final Usuario usuario;

  /// Inyectable para tests; en producción usa el servicio real.
  final AuthService? authService;

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final AuthService _authService =
      widget.authService ?? AuthService();

  late final TextEditingController _nombreController =
      TextEditingController(text: widget.usuario.nombre);
  late final TextEditingController _ocupacionController =
      TextEditingController(text: widget.usuario.ocupacion ?? '');
  late final TextEditingController _escuelaController =
      TextEditingController(text: widget.usuario.escuelaProfesional ?? '');
  late final TextEditingController _semestreController = TextEditingController(
      text: widget.usuario.semestre?.toString() ?? '');

  late final List<String> _habilidades =
      List<String>.from(widget.usuario.habilidades);

  late bool _esEstudiante = _inferirEsEstudiante(widget.usuario);
  bool _isSubmitting = false;
  bool _submitted = false;

  /// Si tiene ocupación (y no escuela), lo tratamos como externo; en cualquier
  /// otro caso, estudiante.
  static bool _inferirEsEstudiante(Usuario u) {
    final bool tieneOcupacion = (u.ocupacion ?? '').trim().isNotEmpty;
    final bool tieneEscuela = (u.escuelaProfesional ?? '').trim().isNotEmpty;
    return tieneEscuela || !tieneOcupacion;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _ocupacionController.dispose();
    _escuelaController.dispose();
    _semestreController.dispose();
    super.dispose();
  }

  String? _validateNombre(String? value) {
    final String nombre = (value ?? '').trim();
    if (nombre.isEmpty) {
      return 'Ingresa tu nombre completo.';
    }
    if (nombre.length < 3) {
      return 'El nombre debe tener al menos 3 caracteres.';
    }
    return null;
  }

  String? _validateEscuela(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Ingresa tu escuela profesional.';
    }
    return null;
  }

  String? _validateOcupacion(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Ingresa tu ocupación.';
    }
    return null;
  }

  String? _validateSemestre(String? value) {
    final String raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return 'Ingresa tu semestre.';
    }
    final int? semestre = int.tryParse(raw);
    if (semestre == null) {
      return 'El semestre debe ser un número entero.';
    }
    if (semestre < 1 || semestre > 14) {
      return 'El semestre debe estar entre 1 y 14.';
    }
    return null;
  }

  Future<void> _guardar() async {
    setState(() => _submitted = true);

    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final String semestreRaw = _semestreController.text.trim();
    final Usuario actualizado = Usuario(
      id: widget.usuario.id,
      nombre: _nombreController.text.trim(),
      correo: widget.usuario.correo,
      habilidades: List<String>.from(_habilidades),
      escuelaProfesional:
          _esEstudiante ? _escuelaController.text.trim() : null,
      semestre: _esEstudiante ? int.tryParse(semestreRaw) : null,
      ocupacion: _esEstudiante ? null : _ocupacionController.text.trim(),
    );

    try {
      await _authService.actualizarPerfil(actualizado);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.red,
          content: Text('No se pudo guardar: $error'),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(actualizado);
  }

  @override
  Widget build(BuildContext context) {
    final AutovalidateMode fieldAutovalidateMode = _submitted
        ? AutovalidateMode.onUserInteraction
        : AutovalidateMode.disabled;

    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SegmentedButton<bool>(
                      segments: const <ButtonSegment<bool>>[
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('Estudiante'),
                          icon: Icon(Icons.school_outlined),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('Externo'),
                          icon: Icon(Icons.badge_outlined),
                        ),
                      ],
                      selected: <bool>{_esEstudiante},
                      showSelectedIcon: false,
                      onSelectionChanged: (Set<bool> seleccion) =>
                          setState(() => _esEstudiante = seleccion.first),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _nombreController,
                      autovalidateMode: fieldAutovalidateMode,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: Icon(Icons.person_outline,
                            color: AppColors.inkSecondary),
                      ),
                      validator: _validateNombre,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      initialValue: widget.usuario.correo,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Correo (no editable)',
                        prefixIcon: Icon(Icons.alternate_email,
                            color: AppColors.inkSecondary),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_esEstudiante) ...<Widget>[
                      TextFormField(
                        controller: _escuelaController,
                        autovalidateMode: fieldAutovalidateMode,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Escuela profesional',
                          hintText: 'Ej. Ingeniería Informática',
                          prefixIcon: Icon(Icons.school_outlined,
                              color: AppColors.inkSecondary),
                        ),
                        validator: _validateEscuela,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _semestreController,
                        autovalidateMode: fieldAutovalidateMode,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Semestre actual',
                          hintText: 'Ej. 7',
                          prefixIcon: Icon(Icons.calendar_view_month_outlined,
                              color: AppColors.inkSecondary),
                        ),
                        validator: _validateSemestre,
                      ),
                    ] else ...<Widget>[
                      TextFormField(
                        controller: _ocupacionController,
                        autovalidateMode: fieldAutovalidateMode,
                        textInputAction: TextInputAction.done,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Ocupación',
                          hintText: 'Ej. Emprendedor, Diseñador, Docente',
                          prefixIcon: Icon(Icons.badge_outlined,
                              color: AppColors.inkSecondary),
                        ),
                        validator: _validateOcupacion,
                      ),
                    ],
                    const SizedBox(height: 22),
                    const _SectionLabel(label: 'Habilidades'),
                    const SizedBox(height: 8),
                    SelectorHabilidades(
                      habilidadesSeleccionadas: _habilidades,
                      onChanged: (List<String> nuevasHabilidades) {
                        setState(() {
                          _habilidades
                            ..clear()
                            ..addAll(nuevasHabilidades);
                        });
                      },
                    ),
                    const SizedBox(height: 28),
                    GradientButton(
                      label: 'GUARDAR CAMBIOS',
                      icon: Icons.check_circle_outline,
                      loading: _isSubmitting,
                      onPressed: _isSubmitting ? null : _guardar,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

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
