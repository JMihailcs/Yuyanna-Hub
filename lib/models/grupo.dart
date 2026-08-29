import 'miembro_resumen.dart';

enum EstadoGrupo { borrador, publicado }

class Grupo {
  const Grupo({
    required this.id,
    required this.convocatoriaId,
    required this.nombre,
    required this.descripcion,
    required this.liderId,
    required this.liderNombre,
    required this.miembros,
    required this.capacidadMax,
    required this.habilidadesBuscadas,
    required this.abierto,
    required this.estado,
  });

  final String id;
  final String convocatoriaId;
  final String nombre;
  final String descripcion;
  final String liderId;
  final String liderNombre;
  final List<MiembroResumen> miembros;
  final int capacidadMax;
  final List<String> habilidadesBuscadas;
  final bool abierto;
  final EstadoGrupo estado;

  int get integrantes => miembros.length;
  bool get tienePlazas => integrantes < capacidadMax;
  int get plazasDisponibles => capacidadMax - integrantes;
  bool get esBorrador => estado == EstadoGrupo.borrador;

  bool esLider(String usuarioId) => liderId == usuarioId;
  bool esMiembro(String usuarioId) =>
      miembros.any((MiembroResumen m) => m.id == usuarioId);

  factory Grupo.fromJson(Map<String, dynamic> json) {
    return Grupo(
      id: json['id'] as String,
      convocatoriaId: json['convocatoria_id'] as String,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String,
      liderId: json['lider_id'] as String,
      liderNombre: json['lider_nombre'] as String,
      miembros: (json['miembros'] as List<dynamic>? ?? <dynamic>[])
          .map<MiembroResumen>(
            (dynamic m) => MiembroResumen.fromJson(m as Map<String, dynamic>),
          )
          .toList(),
      capacidadMax: json['capacidad_max'] as int,
      habilidadesBuscadas: List<String>.from(
        (json['habilidades_buscadas'] as List<dynamic>? ?? <dynamic>[])
            .map<String>((dynamic h) => h.toString()),
      ),
      abierto: json['abierto'] as bool,
      estado: EstadoGrupo.values.byName(json['estado'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'convocatoria_id': convocatoriaId,
      'nombre': nombre,
      'descripcion': descripcion,
      'lider_id': liderId,
      'lider_nombre': liderNombre,
      'miembros': miembros.map((MiembroResumen m) => m.toJson()).toList(),
      'capacidad_max': capacidadMax,
      'habilidades_buscadas': habilidadesBuscadas,
      'abierto': abierto,
      'estado': estado.name,
    };
  }

  Grupo copyWith({
    String? id,
    String? convocatoriaId,
    String? nombre,
    String? descripcion,
    String? liderId,
    String? liderNombre,
    List<MiembroResumen>? miembros,
    int? capacidadMax,
    List<String>? habilidadesBuscadas,
    bool? abierto,
    EstadoGrupo? estado,
  }) {
    return Grupo(
      id: id ?? this.id,
      convocatoriaId: convocatoriaId ?? this.convocatoriaId,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      liderId: liderId ?? this.liderId,
      liderNombre: liderNombre ?? this.liderNombre,
      miembros: miembros ?? this.miembros,
      capacidadMax: capacidadMax ?? this.capacidadMax,
      habilidadesBuscadas: habilidadesBuscadas ?? this.habilidadesBuscadas,
      abierto: abierto ?? this.abierto,
      estado: estado ?? this.estado,
    );
  }
}
