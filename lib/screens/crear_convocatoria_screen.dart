import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/convocatoria.dart';
import '../services/convocatoria_service.dart';
import '../services/media_upload_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/gradient_button.dart';

/// Formulario para que un admin de Paqarina publique o **edite** un evento.
/// Al guardar, escribe en la colección `convocatorias` de Firestore. Si se pasa
/// [convocatoria], el formulario entra en modo edición (campos precargados).
class CrearConvocatoriaScreen extends StatefulWidget {
  const CrearConvocatoriaScreen({
    super.key,
    this.convocatoriaService,
    this.convocatoria,
  });

  /// Inyectable para tests; en producción usa el servicio real.
  final ConvocatoriaService? convocatoriaService;

  /// Evento a editar. Si es `null`, el formulario crea uno nuevo.
  final Convocatoria? convocatoria;

  @override
  State<CrearConvocatoriaScreen> createState() =>
      _CrearConvocatoriaScreenState();
}

class _CrearConvocatoriaScreenState extends State<CrearConvocatoriaScreen> {
  // Tipos que publica Paqarina (rol admin_paqarina).
  // PENDIENTE: próximamente habrá roles de admin para Investigación e
  // Intercambio; cuando existan, agregar 'Investigación' e 'Intercambio' aquí
  // (idealmente filtrando los tipos según el rol del admin). Por ahora NO.
  static const List<String> _tipos = <String>[
    'Hackatón',
    'Incubación',
    'Pre incubación',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final ConvocatoriaService _service =
      widget.convocatoriaService ?? ConvocatoriaService();
  final ImagePicker _picker = ImagePicker();
  final MediaUploadService _uploader = MediaUploadService();

  bool _subiendoImagen = false;
  bool _subiendoVideo = false;

  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _premioController = TextEditingController();
  final TextEditingController _requisitosController = TextEditingController();
  final TextEditingController _imagenController = TextEditingController();
  final TextEditingController _videoController = TextEditingController();

  String _tipo = _tipos.first;
  DateTime? _fechaCierre;
  bool _isSubmitting = false;
  bool _submitted = false;

  bool get _esEdicion => widget.convocatoria != null;

  @override
  void initState() {
    super.initState();
    final Convocatoria? c = widget.convocatoria;
    if (c == null) {
      return;
    }
    // Precarga en modo edición.
    _tituloController.text = c.titulo;
    _descripcionController.text = c.descripcion;
    _premioController.text = c.premio;
    _requisitosController.text = c.requisitos;
    _imagenController.text = c.imagenUrl ?? '';
    _videoController.text = c.videoUrl ?? '';
    _tipo = _tipos.contains(c.tipo) ? c.tipo : _tipos.first;
    _fechaCierre = DateTime.tryParse(c.fechaCierre);
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _premioController.dispose();
    _requisitosController.dispose();
    _imagenController.dispose();
    _videoController.dispose();
    super.dispose();
  }

  String? _requerido(String? v, String campo) {
    if ((v ?? '').trim().isEmpty) {
      return 'Ingresa $campo.';
    }
    return null;
  }

  String? _validarUrl(String? value) {
    final String url = (value ?? '').trim();
    if (url.isEmpty) {
      return null; // opcional
    }
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || !uri.isAbsolute || !uri.hasScheme) {
      return 'Ingresa una URL válida (https://...).';
    }
    return null;
  }

  Future<void> _elegirFecha() async {
    final DateTime ahora = DateTime.now();
    final DateTime? elegida = await showDatePicker(
      context: context,
      initialDate: _fechaCierre ?? ahora.add(const Duration(days: 14)),
      firstDate: ahora,
      lastDate: DateTime(ahora.year + 2),
    );
    if (elegida != null) {
      setState(() => _fechaCierre = elegida);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);

    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    if (_fechaCierre == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una fecha de cierre.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final Convocatoria convocada = _esEdicion
          ? await _service.actualizarConvocatoria(
              id: widget.convocatoria!.id,
              fechaPublicacion: widget.convocatoria!.fechaPublicacion,
              titulo: _tituloController.text,
              tipo: _tipo,
              descripcion: _descripcionController.text,
              fechaCierre: _formatearFecha(_fechaCierre!),
              premio: _premioController.text,
              requisitos: _requisitosController.text,
              imagenUrl: _imagenController.text,
              videoUrl: _videoController.text,
            )
          : await _service.crearConvocatoria(
              titulo: _tituloController.text,
              tipo: _tipo,
              descripcion: _descripcionController.text,
              fechaCierre: _formatearFecha(_fechaCierre!),
              premio: _premioController.text,
              requisitos: _requisitosController.text,
              imagenUrl: _imagenController.text,
              videoUrl: _videoController.text,
            );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _esEdicion
                ? 'Evento "${convocada.titulo}" actualizado.'
                : '¡Convocatoria "${convocada.titulo}" publicada!',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _esEdicion
                ? 'No se pudo actualizar: $error'
                : 'No se pudo publicar: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _formatearFecha(DateTime fecha) {
    final String mm = fecha.month.toString().padLeft(2, '0');
    final String dd = fecha.day.toString().padLeft(2, '0');
    return '${fecha.year}-$mm-$dd';
  }

  Future<ImageSource?> _elegirFuente() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galería'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Cámara'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _subirImagen() async {
    final ImageSource? fuente = await _elegirFuente();
    if (fuente == null) {
      return;
    }
    final XFile? archivo = await _picker.pickImage(
      source: fuente,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (archivo != null) {
      await _subir(archivo, esVideo: false);
    }
  }

  Future<void> _subirVideo() async {
    final ImageSource? fuente = await _elegirFuente();
    if (fuente == null) {
      return;
    }
    final XFile? archivo = await _picker.pickVideo(
      source: fuente,
      maxDuration: const Duration(minutes: 2),
    );
    if (archivo != null) {
      await _subir(archivo, esVideo: true);
    }
  }

  Future<void> _subir(XFile archivo, {required bool esVideo}) async {
    setState(() {
      if (esVideo) {
        _subiendoVideo = true;
      } else {
        _subiendoImagen = true;
      }
    });
    try {
      final Uint8List bytes = await archivo.readAsBytes();
      final String url = await _uploader.subir(
        bytes: bytes,
        nombreArchivo: archivo.name,
        contentType: archivo.mimeType ??
            MediaUploadService.contentTypePara(archivo.name),
      );
      if (!mounted) {
        return;
      }
      if (esVideo) {
        _videoController.text = url;
      } else {
        _imagenController.text = url;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(esVideo ? 'Video subido.' : 'Imagen subida.'),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.red,
            content: Text('No se pudo subir: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (esVideo) {
            _subiendoVideo = false;
          } else {
            _subiendoImagen = false;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AutovalidateMode fieldAutovalidateMode = _submitted
        ? AutovalidateMode.onUserInteraction
        : AutovalidateMode.disabled;

    return Scaffold(
      appBar: AppBar(
          title: Text(_esEdicion ? 'Editar evento' : 'Publicar evento')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      _esEdicion
                          ? 'Editar evento de Paqarina'
                          : 'Nuevo evento de Paqarina',
                      style: AppTypography.display(size: 24),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Se mostrará en el feed de todos los usuarios.',
                      style: AppTypography.ui(
                        size: 13,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _tituloController,
                      autovalidateMode: fieldAutovalidateMode,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Título',
                        hintText: 'Ej. Feria de Incubación Paqarina Wasi 2026',
                      ),
                      validator: (String? v) => _requerido(v, 'un título'),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      autovalidateMode: fieldAutovalidateMode,
                      initialValue: _tipo,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: _tipos
                          .map<DropdownMenuItem<String>>(
                            (String t) => DropdownMenuItem<String>(
                              value: t,
                              child: Text(t),
                            ),
                          )
                          .toList(),
                      onChanged: (String? v) =>
                          setState(() => _tipo = v ?? _tipo),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _descripcionController,
                      autovalidateMode: fieldAutovalidateMode,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        alignLabelWithHint: true,
                      ),
                      validator: (String? v) => _requerido(v, 'una descripción'),
                    ),
                    const SizedBox(height: 14),
                    _CampoFecha(
                      fecha: _fechaCierre == null
                          ? null
                          : _formatearFecha(_fechaCierre!),
                      onTap: _elegirFecha,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _premioController,
                      autovalidateMode: fieldAutovalidateMode,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Premio / beneficio',
                        hintText: 'Ej. Capital semilla de S/ 10,000',
                      ),
                      validator: (String? v) => _requerido(v, 'el premio'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _requisitosController,
                      autovalidateMode: fieldAutovalidateMode,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Requisitos',
                        alignLabelWithHint: true,
                      ),
                      validator: (String? v) => _requerido(v, 'los requisitos'),
                    ),
                    const SizedBox(height: 22),
                    const _EtiquetaSeccion(label: 'Multimedia (opcional)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _imagenController,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: 'Imagen (subir o URL)',
                        hintText: 'Sube desde el celular o pega una URL',
                        prefixIcon: const Icon(Icons.image_outlined,
                            color: AppColors.inkSecondary),
                        suffixIcon: _subiendoImagen
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                tooltip: 'Subir imagen',
                                icon: const Icon(Icons.upload_outlined),
                                onPressed: _subirImagen,
                              ),
                      ),
                      validator: _validarUrl,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _videoController,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: 'Video (subir o URL)',
                        hintText: 'Sube un mp4 o pega una URL',
                        prefixIcon: const Icon(Icons.movie_outlined,
                            color: AppColors.inkSecondary),
                        suffixIcon: _subiendoVideo
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                tooltip: 'Subir video',
                                icon: const Icon(Icons.upload_outlined),
                                onPressed: _subirVideo,
                              ),
                      ),
                      validator: _validarUrl,
                    ),
                    const SizedBox(height: 28),
                    GradientButton(
                      label: _esEdicion ? 'GUARDAR CAMBIOS' : 'PUBLICAR EVENTO',
                      icon: _esEdicion
                          ? Icons.check_circle_outline
                          : Icons.campaign_outlined,
                      loading: _isSubmitting,
                      onPressed: _isSubmitting ? null : _submit,
                    ),
                    const SizedBox(height: 16),
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

class _CampoFecha extends StatelessWidget {
  const _CampoFecha({required this.fecha, required this.onTap});

  final String? fecha;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Fecha de cierre',
          prefixIcon: Icon(Icons.event_outlined, color: AppColors.inkSecondary),
        ),
        child: Text(
          fecha ?? 'Elige una fecha',
          style: AppTypography.ui(
            size: 15,
            color: fecha == null ? AppColors.inkSecondary : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _EtiquetaSeccion extends StatelessWidget {
  const _EtiquetaSeccion({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label.toUpperCase(),
        style: AppTypography.ui(
          size: 12,
          weight: FontWeight.w700,
          color: AppColors.inkSecondary,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}
