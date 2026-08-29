import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuyanna_hub/services/habilidades_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuyanna_hub/widgets/selector_habilidades.dart';

void main() {
  // HabilidadesStore persiste el catálogo con shared_preferences: sin el mock
  // el guardado lanza MissingPluginException fuera del test.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('HabilidadesStore Tests', () {
    test('Catálogo inicial no está vacío', () {
      final List<String> disponibles =
          HabilidadesStore.instance.habilidadesDisponibles;
      expect(disponibles, isNotEmpty);
      expect(disponibles.contains('Flutter'), isTrue);
      expect(disponibles.contains('Python'), isTrue);
    });

    test('agregarHabilidad inserta nuevas habilidades y evita duplicados case-insensitive', () {
      final String agregada =
          HabilidadesStore.instance.agregarHabilidad('docker');
      expect(agregada.toLowerCase(), equals('docker'));

      final List<String> disponibles =
          HabilidadesStore.instance.habilidadesDisponibles;
      expect(
        disponibles.any((String h) => h.toLowerCase() == 'docker'),
        isTrue,
      );

      // Re-agregar duplicado
      final String duplicada =
          HabilidadesStore.instance.agregarHabilidad('Docker');
      expect(duplicada.toLowerCase(), equals('docker'));
    });

    test('parsearEInsertar procesa texto separado por comas uno por uno', () {
      final List<String> resultado = HabilidadesStore.instance
          .parsearEInsertar('Go, Rust, Kotlin');
      expect(resultado.length, equals(3));
      expect(resultado.any((String h) => h.toLowerCase() == 'go'), isTrue);
      expect(resultado.any((String h) => h.toLowerCase() == 'rust'), isTrue);
      expect(resultado.any((String h) => h.toLowerCase() == 'kotlin'), isTrue);

      final List<String> catalog =
          HabilidadesStore.instance.habilidadesDisponibles;
      expect(catalog.any((String h) => h.toLowerCase() == 'rust'), isTrue);
    });

    test('buscar filtra correctamente', () {
      final List<String> resultados =
          HabilidadesStore.instance.buscar('flut');
      expect(resultados, contains('Flutter'));
    });
  });

  group('SelectorHabilidades Widget Tests', () {
    testWidgets('Renders SelectorHabilidades y muestra chips seleccionados',
        (WidgetTester tester) async {
      final List<String> seleccionadas = <String>['Flutter', 'Python'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectorHabilidades(
              habilidadesSeleccionadas: seleccionadas,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Flutter'), findsOneWidget);
      expect(find.text('Python'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Tapping chip remove icon removes skill one by one',
        (WidgetTester tester) async {
      final List<String> seleccionadas = <String>['Flutter', 'Python'];
      List<String>? updatedList;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectorHabilidades(
              habilidadesSeleccionadas: seleccionadas,
              onChanged: (List<String> list) {
                updatedList = list;
              },
            ),
          ),
        ),
      );

      final Finder closeButtons = find.byIcon(Icons.close);
      expect(closeButtons, findsNWidgets(2));

      await tester.tap(closeButtons.first);
      await tester.pumpAndSettle();

      final List<String> res = updatedList!;
      expect(res.contains('Flutter'), isFalse);
      expect(res.contains('Python'), isTrue);
    });
  });
}
