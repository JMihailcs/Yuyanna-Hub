import 'package:flutter/material.dart';

import '../models/usuario.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Hoja modal para elegir un estudiante del directorio.
/// Devuelve el usuario elegido o null si se cierra sin elegir.
Future<Usuario?> mostrarSelectorUsuario(
  BuildContext context, {
  required List<Usuario> usuarios,
  required Set<String> excluirIds,
  String titulo = 'Agregar integrante',
}) {
  final List<Usuario> disponibles = usuarios
      .where((Usuario u) => !excluirIds.contains(u.id))
      .toList(growable: false);

  return showModalBottomSheet<Usuario>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(titulo, style: AppTypography.display(size: 19)),
            ),
            if (disponibles.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Text(
                  'No hay más estudiantes disponibles.',
                  style: AppTypography.ui(color: AppColors.inkSecondary),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: disponibles.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final Usuario usuario = disponibles[index];
                    return ListTile(
                      onTap: () => Navigator.of(context).pop(usuario),
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.blue.withValues(alpha: 0.12),
                        child: Text(
                          usuario.nombre.isEmpty
                              ? '?'
                              : usuario.nombre[0].toUpperCase(),
                          style: AppTypography.ui(
                            weight: FontWeight.w700,
                            color: AppColors.blue,
                          ),
                        ),
                      ),
                      title: Text(
                        usuario.nombre,
                        style: AppTypography.ui(
                          size: 14,
                          weight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${usuario.escuelaProfesional} · Sem. '
                        '${usuario.semestre}\n'
                        '${usuario.habilidades.join(', ')}',
                        style: AppTypography.ui(
                          size: 12,
                          color: AppColors.inkSecondary,
                        ),
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
              ),
          ],
        ),
      );
    },
  );
}
