class Convocatoria {
  const Convocatoria({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.tipo,
    required this.fechaPublicacion,
    required this.fechaCierre,
    required this.premio,
    required this.requisitos,
    this.imagenUrl,
    this.videoUrl,
  });

  final String id;
  final String titulo;
  final String descripcion;
  final String tipo;
  final String fechaPublicacion;
  final String fechaCierre;
  final String premio;
  final String requisitos;

  /// URL de la imagen/banner del evento (subida por el panel a un host
  /// externo, p. ej. Cloudflare R2). En Firestore solo se guarda la URL.
  final String? imagenUrl;

  /// URL del video promocional del evento, si lo hay. Igual que la imagen:
  /// solo la URL; el archivo vive en el host externo.
  final String? videoUrl;

  bool get tieneImagen => imagenUrl != null && imagenUrl!.isNotEmpty;
  bool get tieneVideo => videoUrl != null && videoUrl!.isNotEmpty;

  factory Convocatoria.fromJson(Map<String, dynamic> json) {
    return Convocatoria(
      id: json['id'] as String,
      titulo: json['titulo'] as String,
      descripcion: json['descripcion'] as String,
      tipo: json['tipo'] as String,
      fechaPublicacion: json['fecha_publicacion'] as String,
      fechaCierre: json['fecha_cierre'] as String,
      premio: json['premio'] as String,
      requisitos: json['requisitos'] as String,
      imagenUrl: json['imagen_url'] as String?,
      videoUrl: json['video_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'titulo': titulo,
      'descripcion': descripcion,
      'tipo': tipo,
      'fecha_publicacion': fechaPublicacion,
      'fecha_cierre': fechaCierre,
      'premio': premio,
      'requisitos': requisitos,
      if (imagenUrl != null) 'imagen_url': imagenUrl,
      if (videoUrl != null) 'video_url': videoUrl,
    };
  }

  Convocatoria copyWith({
    String? id,
    String? titulo,
    String? descripcion,
    String? tipo,
    String? fechaPublicacion,
    String? fechaCierre,
    String? premio,
    String? requisitos,
    String? imagenUrl,
    String? videoUrl,
  }) {
    return Convocatoria(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      tipo: tipo ?? this.tipo,
      fechaPublicacion: fechaPublicacion ?? this.fechaPublicacion,
      fechaCierre: fechaCierre ?? this.fechaCierre,
      premio: premio ?? this.premio,
      requisitos: requisitos ?? this.requisitos,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      videoUrl: videoUrl ?? this.videoUrl,
    );
  }
}
