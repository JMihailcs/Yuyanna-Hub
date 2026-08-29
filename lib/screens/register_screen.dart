import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/gradient_button.dart';
import '../widgets/selector_habilidades.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static final RegExp _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _ocupacionController = TextEditingController();
  final TextEditingController _escuelaController = TextEditingController();
  final TextEditingController _semestreController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final List<String> _habilidades = <String>[];
  final AuthService _authService = AuthService();

  bool _esEstudiante = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _ocupacionController.dispose();
    _escuelaController.dispose();
    _semestreController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  String? _validateEmail(String? value) {
    final String email = (value ?? '').trim().toLowerCase();
    if (email.isEmpty) {
      return 'Ingresa tu correo.';
    }
    if (!_emailRegExp.hasMatch(email)) {
      return 'Ingresa un correo válido.';
    }
    return null;
  }

  String? _validateEscuela(String? value) {
    final String escuela = (value ?? '').trim();
    if (escuela.isEmpty) {
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

  String? _validatePassword(String? value) {
    final String password = value ?? '';
    if (password.isEmpty) {
      return 'Ingresa una contraseña.';
    }
    if (password.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if ((value ?? '').isEmpty) {
      return 'Confirma tu contraseña.';
    }
    if (value != _passwordController.text) {
      return 'Las contraseñas no coinciden.';
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);

    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final String semestreRaw = _semestreController.text.trim();
    try {
      await _authService.registrar(
        nombre: _nombreController.text,
        correo: _emailController.text,
        habilidades: _habilidades,
        password: _passwordController.text,
        escuelaProfesional: _esEstudiante ? _escuelaController.text : null,
        semestre: _esEstudiante
            ? (semestreRaw.isEmpty ? null : int.tryParse(semestreRaw))
            : null,
        ocupacion: _esEstudiante ? null : _ocupacionController.text,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.red,
          content: Text(AuthService.mensajeDeError(error)),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const HomeScreen(),
      ),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AutovalidateMode fieldAutovalidateMode = _submitted
        ? AutovalidateMode.onUserInteraction
        : AutovalidateMode.disabled;

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Únete a Yuyanna Hub',
                      style: AppTypography.display(size: 26),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Crea tu perfil para postular a convocatorias.',
                      style: AppTypography.ui(
                        size: 13,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _Card(
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
                              hintText: 'Ej. Mariana Quispe Huamán',
                              prefixIcon: Icon(Icons.person_outline,
                                  color: AppColors.inkSecondary),
                            ),
                            validator: _validateNombre,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _emailController,
                            autovalidateMode: fieldAutovalidateMode,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: const InputDecoration(
                              labelText: 'Correo',
                              hintText: 'tucorreo@ejemplo.com',
                              prefixIcon: Icon(Icons.alternate_email,
                                  color: AppColors.inkSecondary),
                            ),
                            validator: _validateEmail,
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
                              textInputAction: TextInputAction.next,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(2),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Semestre actual',
                                hintText: 'Ej. 7',
                                prefixIcon: Icon(
                                    Icons.calendar_view_month_outlined,
                                    color: AppColors.inkSecondary),
                              ),
                              validator: _validateSemestre,
                            ),
                          ] else ...<Widget>[
                            TextFormField(
                              controller: _ocupacionController,
                              autovalidateMode: fieldAutovalidateMode,
                              textInputAction: TextInputAction.next,
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
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            autovalidateMode: fieldAutovalidateMode,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock_outline,
                                  color: AppColors.inkSecondary),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppColors.inkSecondary,
                                ),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: _validatePassword,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _confirmPasswordController,
                            autovalidateMode: fieldAutovalidateMode,
                            obscureText: _obscureConfirmPassword,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: 'Confirmar contraseña',
                              prefixIcon: const Icon(Icons.lock_reset_outlined,
                                  color: AppColors.inkSecondary),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppColors.inkSecondary,
                                ),
                                onPressed: () => setState(() =>
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword),
                              ),
                            ),
                            validator: _validateConfirmPassword,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
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
                      label: 'CREAR CUENTA',
                      icon: Icons.check_circle_outline,
                      loading: _isSubmitting,
                      onPressed: _isSubmitting ? null : _submit,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          '¿Ya tienes cuenta?',
                          style: AppTypography.ui(
                            size: 14,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Inicia sesión'),
                        ),
                      ],
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
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
