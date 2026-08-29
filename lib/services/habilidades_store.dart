import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Almacén central de habilidades disponibles en la aplicación.
/// Permite listar, buscar y registrar nuevas habilidades para que
/// puedan ser reutilizadas como opciones de selección (select/autocomplete).
class HabilidadesStore extends ChangeNotifier {
  HabilidadesStore._();

  static final HabilidadesStore instance = HabilidadesStore._();
  
  static const String _kHabilidadesKey = 'habilidades_custom_catalog';

  final Set<String> _catalog = <String>{
    'Gestión de proyectos',
    'Pitch',
    'Liderazgo',
    'Flutter',
    'Firebase',
    'IA generativa',
    'Biotecnología',
    'Laboratorio',
    'Investigación',
    'Inglés B2',
    'Guiado turístico',
    'Marketing',
    'Inglés intermedio',
    'Estadística',
    'Disciplina',
    'Procesamiento de señales',
    'MATLAB',
    'Python',
    'Quechua',
    'Lingüística',
    'Docencia',
    'Diseño UX',
    'Figma',
    'Branding',
    'PyTorch',
    'NLP',
    'Modelo de negocio',
    'C++',
    'Traducción',
    'Fotografía',
    'Ilustración',
    'Rust',
    'Docker',
    'React',
    'Node.js',
    'Git',
    'Base de datos',
  };

  /// Carga las habilidades personalizadas guardadas localmente.
  Future<void> init() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String>? guardadas = prefs.getStringList(_kHabilidadesKey);
    if (guardadas != null) {
      _catalog.addAll(guardadas);
      notifyListeners();
    }
  }

  void _guardarLocal() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kHabilidadesKey, _catalog.toList());
  }

  /// Lista ordenada de todas las habilidades disponibles en el catálogo.
  List<String> get habilidadesDisponibles {
    final List<String> sorted = _catalog.toList()
      ..sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return List<String>.unmodifiable(sorted);
  }

  /// Registra una nueva habilidad en el catálogo si aún no existe.
  /// Retorna la habilidad formateada tal como quedó en el catálogo.
  String agregarHabilidad(String habilidad) {
    final String trimmed = habilidad.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final String existente = _catalog.firstWhere(
      (String h) => h.toLowerCase() == trimmed.toLowerCase(),
      orElse: () => '',
    );

    if (existente.isNotEmpty) {
      return existente;
    }

    String formateada = trimmed;
    if (formateada.isNotEmpty && formateada[0] == formateada[0].toLowerCase()) {
      formateada = formateada[0].toUpperCase() + formateada.substring(1);
    }

    _catalog.add(formateada);
    _guardarLocal();
    notifyListeners();
    return formateada;
  }

  /// Procesa una cadena de texto (que puede incluir comas para separar varias habilidades),
  /// agrega cada una al catálogo global si no existía y retorna la lista de habilidades.
  List<String> parsearEInsertar(String rawText) {
    if (rawText.trim().isEmpty) {
      return <String>[];
    }

    final List<String> partes = rawText.split(',');
    final List<String> result = <String>[];

    for (final String parte in partes) {
      final String limpia = parte.trim();
      if (limpia.isNotEmpty) {
        final String agregada = agregarHabilidad(limpia);
        if (agregada.isNotEmpty && !result.contains(agregada)) {
          result.add(agregada);
        }
      }
    }
    return result;
  }

  /// Busca habilidades en el catálogo que coincidan con la consulta [query].
  List<String> buscar(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return habilidadesDisponibles;
    }
    return habilidadesDisponibles
        .where((String h) => h.toLowerCase().contains(q))
        .toList();
  }
}
