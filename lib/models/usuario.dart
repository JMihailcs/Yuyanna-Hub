class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.habilidades,
    this.escuelaProfesional,
    this.semestre,
    this.ocupacion,
  });

  final String id;
  final String nombre;
  final String correo;
  final List<String> habilidades;

  /// Datos de estudiante (opcionales: la gente externa puede dejarlos vacíos).
  final String? escuelaProfesional;
  final int? semestre;

  /// Ocupación libre para quien no es estudiante (p. ej. "Emprendedor",
  /// "Diseñador"). Opcional.
  final String? ocupacion;

  /// Correo del dominio institucional UNSAAC → recibe la etiqueta
  /// "Estudiante UNSAAC". No restringe el acceso, solo lo distingue.
  static const String dominioUnsaac = '@unsaac.edu.pe';
  bool get esUnsaac => correo.toLowerCase().trim().endsWith(dominioUnsaac);

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      correo: json['correo'] as String,
      escuelaProfesional: json['escuela_profesional'] as String?,
      semestre: json['semestre'] as int?,
      ocupacion: json['ocupacion'] as String?,
      habilidades: List<String>.from(
        (json['habilidades'] as List<dynamic>? ?? <dynamic>[])
            .map<String>((dynamic h) => h.toString()),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'nombre': nombre,
      'correo': correo,
      'habilidades': habilidades,
      if (escuelaProfesional != null) 'escuela_profesional': escuelaProfesional,
      if (semestre != null) 'semestre': semestre,
      if (ocupacion != null) 'ocupacion': ocupacion,
    };
  }

  Usuario copyWith({
    String? id,
    String? nombre,
    String? correo,
    String? escuelaProfesional,
    int? semestre,
    String? ocupacion,
    List<String>? habilidades,
  }) {
    return Usuario(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      correo: correo ?? this.correo,
      escuelaProfesional: escuelaProfesional ?? this.escuelaProfesional,
      semestre: semestre ?? this.semestre,
      ocupacion: ocupacion ?? this.ocupacion,
      habilidades: habilidades ?? this.habilidades,
    );
  }
}
