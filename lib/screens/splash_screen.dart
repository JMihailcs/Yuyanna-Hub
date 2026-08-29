import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/hub_glyph.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.authService});

  /// Inyectable para tests; en producción usa el [AuthService] real.
  final AuthService? authService;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Duration _splashDuration = Duration(milliseconds: 2500);

  late final AuthService _authService = widget.authService ?? AuthService();

  @override
  void initState() {
    super.initState();
    _executeTimingRoute();
  }

  Future<void> _executeTimingRoute() async {
    await Future<void>.delayed(_splashDuration);
    // La sesión de Firebase Auth es la fuente de verdad; refrescamos la
    // caché local del perfil si hay un usuario autenticado.
    bool isLoggedIn = _authService.haySesion;
    if (isLoggedIn) {
      try {
        isLoggedIn = await _authService.usuarioActual() != null;
      } catch (_) {
        isLoggedIn = false;
      }
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => isLoggedIn
            ? const HomeScreen()
            : LoginScreen(authService: _authService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppGradients.heroSplash),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -60,
              right: -40,
              child: _Blob(
                size: 220,
                color: AppColors.goldFill.withValues(alpha: 0.10),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: _Blob(
                size: 200,
                color: AppColors.blueFill.withValues(alpha: 0.08),
              ),
            ),
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const HubGlyph(size: 104)
                        .animate()
                        .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                        .scale(
                          begin: const Offset(0.85, 0.85),
                          end: const Offset(1, 1),
                          duration: 600.ms,
                          curve: Curves.easeOutBack,
                        ),
                    const SizedBox(height: 28),
                    Text(
                      'Yuyanna Hub',
                      textAlign: TextAlign.center,
                      style: AppTypography.display(
                        size: 38,
                        weight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 300.ms, duration: 600.ms)
                        .slideY(begin: 0.25, end: 0, curve: Curves.easeOutCubic),
                    const SizedBox(height: 10),
                    Text(
                      'Conectando Talento Antoniano',
                      textAlign: TextAlign.center,
                      style: AppTypography.ui(
                        size: 14,
                        weight: FontWeight.w500,
                        color: AppColors.inkSecondary,
                        letterSpacing: 0.4,
                      ),
                    ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
                    const SizedBox(height: 52),
                    const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.red),
                      ),
                    ).animate().fadeIn(delay: 1200.ms, duration: 500.ms),
                  ],
                ),
              ),
            ),
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
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
