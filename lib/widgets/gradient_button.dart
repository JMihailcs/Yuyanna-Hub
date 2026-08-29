import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.gradient = AppGradients.primaryButton,
    this.icon,
    this.loading = false,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final Gradient gradient;
  final IconData? icon;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !loading;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.redDeep.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: height,
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (icon != null) ...<Widget>[
                            Icon(icon, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            label,
                            style: AppTypography.ui(
                              size: 15,
                              weight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ),
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
