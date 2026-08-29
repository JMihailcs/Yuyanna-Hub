// Smoke test del splash. Inyecta un AuthService con mocks de Firebase
// (MockFirebaseAuth / FakeFirebaseFirestore) para no tocar servicios reales.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yuyanna_hub/screens/splash_screen.dart';
import 'package:yuyanna_hub/services/auth_service.dart';

void main() {
  testWidgets('Splash screen shows app name smoke test', (
    WidgetTester tester,
  ) async {
    // Sesión cerrada por defecto → el splash debe llevar al login.
    final AuthService authService = AuthService(
      auth: MockFirebaseAuth(),
      firestore: FakeFirebaseFirestore(),
    );

    await tester.pumpWidget(
      MaterialApp(home: SplashScreen(authService: authService)),
    );

    // El splash muestra el nombre de la app en el primer frame.
    expect(find.text('Yuyanna Hub'), findsOneWidget);
    expect(find.text('Conectando Talento Antoniano'), findsOneWidget);

    // Avanzar más allá del timer del splash para disparar la navegación.
    await tester.pump(const Duration(milliseconds: 2600));
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // Sin sesión activa, aterriza en la pantalla de login.
    expect(find.text('Bienvenido'), findsOneWidget);
  });
}
