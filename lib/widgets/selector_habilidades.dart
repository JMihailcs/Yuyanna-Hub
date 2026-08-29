import 'package:flutter/material.dart';

import '../services/habilidades_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Widget interactivo para la selección y registro de habilidades uno por uno.
///
/// Permite:
/// 1. Seleccionar habilidades existentes desde un menú despegable/select (autocomplete).
/// 2. Agregar sugerencias rápidas con un solo toque.
/// 3. Escribir nuevas habilidades (individuales o separadas por comas), agregándolas
///    a la selección del usuario y guardándolas en el catálogo global reutilizable.
class SelectorHabilidades extends StatefulWidget {
  const SelectorHabilidades({
    super.key,
    required this.habilidadesSeleccionadas,
    required this.onChanged,
    this.hintText = 'Ej. Flutter, Rust, Liderazgo',
  });

  final List<String> habilidadesSeleccionadas;
  final ValueChanged<List<String>> onChanged;
  final String hintText;

  @override
  State<SelectorHabilidades> createState() => _SelectorHabilidadesState();
}

class _SelectorHabilidadesState extends State<SelectorHabilidades> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    HabilidadesStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    HabilidadesStore.instance.removeListener(_onStoreChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _addSkill(String skill) {
    final String clean = skill.trim();
    if (clean.isEmpty) {
      return;
    }

    final String registered =
        HabilidadesStore.instance.agregarHabilidad(clean);
    final String target = registered.isNotEmpty ? registered : clean;

    final bool alreadySelected = widget.habilidadesSeleccionadas.any(
      (String h) => h.toLowerCase() == target.toLowerCase(),
    );

    if (!alreadySelected) {
      final List<String> updated = <String>[
        ...widget.habilidadesSeleccionadas,
        target,
      ];
      widget.onChanged(updated);
    }
    _textController.clear();
  }

  void _addFromInput() {
    final String text = _textController.text;
    if (text.trim().isEmpty) {
      return;
    }

    final List<String> parsed =
        HabilidadesStore.instance.parsearEInsertar(text);
    final List<String> updated = <String>[...widget.habilidadesSeleccionadas];

    for (final String item in parsed) {
      final bool already = updated.any(
        (String h) => h.toLowerCase() == item.toLowerCase(),
      );
      if (!already) {
        updated.add(item);
      }
    }

    widget.onChanged(updated);
    _textController.clear();
  }

  void _removeSkill(String skill) {
    final List<String> updated = widget.habilidadesSeleccionadas
        .where((String h) => h != skill)
        .toList();
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final List<String> disponibles = HabilidadesStore
        .instance.habilidadesDisponibles
        .where(
          (String item) => !widget.habilidadesSeleccionadas.any(
            (String sel) => sel.toLowerCase() == item.toLowerCase(),
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        RawAutocomplete<String>(
          focusNode: _focusNode,
          textEditingController: _textController,
          optionsBuilder: (TextEditingValue textEditingValue) {
            final String query = textEditingValue.text.trim();
            final List<String> matches =
                HabilidadesStore.instance.buscar(query);
            return matches.where(
              (String item) => !widget.habilidadesSeleccionadas.any(
                (String sel) => sel.toLowerCase() == item.toLowerCase(),
              ),
            );
          },
          onSelected: (String option) {
            _addSkill(option);
          },
          fieldViewBuilder: (
            BuildContext context,
            TextEditingController fieldTextEditingController,
            FocusNode fieldFocusNode,
            VoidCallback onFieldSubmitted,
          ) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: fieldTextEditingController,
                    focusNode: fieldFocusNode,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      prefixIcon: const Icon(
                        Icons.bolt_outlined,
                        color: AppColors.inkSecondary,
                      ),
                      suffixIcon: fieldTextEditingController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () =>
                                  fieldTextEditingController.clear(),
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _addFromInput(),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 54,
                  width: 54,
                  child: ElevatedButton(
                    onPressed: _addFromInput,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(54, 54),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(Icons.add, size: 22),
                  ),
                ),
              ],
            );
          },
          optionsViewBuilder: (
            BuildContext context,
            AutocompleteOnSelected<String> onSelected,
            Iterable<String> options,
          ) {
            if (options.isEmpty) {
              return const SizedBox.shrink();
            }
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8,
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 320,
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.bolt,
                          color: AppColors.red,
                          size: 18,
                        ),
                        title: Text(
                          option,
                          style: AppTypography.ui(
                            size: 14,
                            weight: FontWeight.w500,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.add_circle_outline,
                          size: 18,
                          color: AppColors.inkSecondary,
                        ),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),

        // Habilidades seleccionadas (Chips agregados uno por uno)
        if (widget.habilidadesSeleccionadas.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.habilidadesSeleccionadas
                .map<Widget>(
                  (String h) => Chip(
                    avatar: const Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: AppColors.red,
                    ),
                    label: Text(h),
                    labelStyle: AppTypography.ui(
                      size: 13,
                      weight: FontWeight.w500,
                      color: AppColors.ink,
                    ),
                    backgroundColor: AppColors.surfaceTint,
                    side: const BorderSide(color: AppColors.line),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    deleteIconColor: AppColors.inkSecondary,
                    onDeleted: () => _removeSkill(h),
                  ),
                )
                .toList(),
          ),
        ],

        // Sugerencias reutilizables para selección rápida en select
        if (disponibles.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              const Icon(
                Icons.touch_app_outlined,
                size: 14,
                color: AppColors.inkSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                'Seleccionar de catálogo reutilizable:',
                style: AppTypography.ui(
                  size: 12,
                  weight: FontWeight.w600,
                  color: AppColors.inkSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: disponibles.take(10).map<Widget>((String opcion) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    avatar: const Icon(
                      Icons.add,
                      size: 14,
                      color: AppColors.red,
                    ),
                    label: Text(opcion),
                    labelStyle: AppTypography.ui(
                      size: 12,
                      color: AppColors.ink,
                    ),
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.line),
                    onPressed: () => _addSkill(opcion),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}
