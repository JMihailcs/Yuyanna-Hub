import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/gradient_button.dart';
import '../widgets/hub_glyph.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authService});

  /// Inyectable para tests; en producción usa el [AuthService] real.
  final AuthService? authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static final RegExp _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late final AuthService _authService = widget.authService ?? AuthService();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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

  String? _validatePassword(String? value) {
    final String password = value ?? '';
    if (password.isEmpty) {
      return 'Ingresa tu contraseña.';
    }
    if (password.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
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

    try {
      await _authService.iniciarSesion(
        correo: _emailController.text,
        password: _passwordController.text,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSubmitting = false);
      _mostrarError(AuthService.mensajeDeError(error));
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

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.red,
        content: Text(mensaje),
      ),
    );
  }

  Future<void> _recuperarPassword() async {
    final String email = _emailController.text.trim();
    if (email.isEmpty || !_emailRegExp.hasMatch(email)) {
      _mostrarError(
        'Ingresa tu correo institucional arriba para restablecer tu contraseña.',
      );
      return;
    }

    try {
      await _authService.enviarRestablecimiento(email);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Enviamos un correo para restablecer tu contraseña.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _mostrarError(AuthService.mensajeDeError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AutovalidateMode fieldAutovalidateMode = _submitted
        ? AutovalidateMode.onUserInteraction
        : AutovalidateMode.disabled;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.headerSoft),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const HubGlyph(size: 64)
                        .animate()
                        .scale(duration: 400.ms, curve: Curves.easeOutBack),
                    const SizedBox(height: 16),
                    Text(
                      'Bienvenido',
                      textAlign: TextAlign.center,
                      style: AppTypography.display(size: 32),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Conecta equipos, postula y logra tus proyectos',
                      textAlign: TextAlign.center,
                      style: AppTypography.ui(
                        size: 14,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _FormCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            TextFormField(
                              controller: _emailController,
                              autovalidateMode: fieldAutovalidateMode,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              enableSuggestions: false,
                              decoration: const InputDecoration(
                                labelText: 'Correo institucional',
                                hintText: 'usuario@unsaac.edu.pe',
                                prefixIcon: Icon(Icons.alternate_email,
                                    color: AppColors.inkSecondary),
                              ),
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              autovalidateMode: fieldAutovalidateMode,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
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
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: _validatePassword,
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed:
                                    _isSubmitting ? null : _recuperarPassword,
                                child: const Text('¿Olvidaste tu contraseña?'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            GradientButton(
                              label: 'INGRESAR',
                              loading: _isSubmitting,
                              onPressed: _isSubmitting ? null : _submit,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          '¿No tienes cuenta?',
                          style: AppTypography.ui(
                            size: 14,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (BuildContext context) =>
                                          const RegisterScreen(),
                                    ),
                                  ),
                          child: const Text('Regístrate'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Solo personal y estudiantes UNSAAC.',
                      textAlign: TextAlign.center,
                      style: AppTypography.ui(
                        size: 12,
                        color: AppColors.inkSecondary,
                      ).copyWith(
                        color: AppColors.inkSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.06),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}
