import 'package:flutter/material.dart';

import '../models/convocatoria.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class HeroConvocatoriaCard extends StatelessWidget {
  const HeroConvocatoriaCard({
    super.key,
    required this.convocatoria,
    required this.onVerGrupos,
  });

  final Convocatoria convocatoria;
  final VoidCallback onVerGrupos;

  @override
  Widget build(BuildContext context) {
    final Color tipoText = TipoConvocatoria.textColor(convocatoria.tipo);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: TipoConvocatoria.gradient(convocatoria.tipo),
            ),
            child: Row(
              children: <Widget>[
                _WhitePill(
                  text: convocatoria.tipo.toUpperCase(),
                  textColor: tipoText,
                ),
                const Spacer(),
                _WhitePill(
                  text: 'Cierra ${convocatoria.fechaCierre}',
                  textColor: AppColors.ink,
                  icon: Icons.event_outlined,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  convocatoria.titulo,
                  style: AppTypography.display(size: 22, height: 1.15),
                ),
                const SizedBox(height: 8),
                Text(
                  convocatoria.descripcion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.ui(
                    size: 13,
                    color: AppColors.inkSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.emoji_events_outlined,
                        size: 18, color: AppColors.gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        convocatoria.premio,
                        style: AppTypography.ui(
                          size: 13,
                          weight: FontWeight.w500,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onVerGrupos,
                    icon: const Icon(Icons.groups_outlined, size: 18),
                    label: const Text('Ver Grupos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tipoText,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CardConvocatoria extends StatelessWidget {
  const CardConvocatoria({
    super.key,
    required this.convocatoria,
    required this.onTap,
  });

  final Convocatoria convocatoria;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color tipoText = TipoConvocatoria.textColor(convocatoria.tipo);
    final Color tipoFill = TipoConvocatoria.color(convocatoria.tipo);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 5,
                height: 44,
                decoration: BoxDecoration(
                  color: tipoFill,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      convocatoria.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.ui(
                        size: 15,
                        weight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${convocatoria.tipo} · Cierra ${convocatoria.fechaCierre}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.ui(size: 12, color: tipoText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right,
                  color: AppColors.inkSecondary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhitePill extends StatelessWidget {
  const _WhitePill({
    required this.text,
    required this.textColor,
    this.icon,
  });

  final String text;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: AppTypography.ui(
              size: 11,
              weight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
