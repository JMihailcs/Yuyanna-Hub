import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color paper = Color(0xFFFAF7F2);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceTint = Color(0xFFF2EDE3);
  static const Color ink = Color(0xFF1F1A2E);
  static const Color inkSecondary = Color(0xFF6B6478);
  static const Color line = Color(0xFFE5DFD3);

  static const Color red = Color(0xFFA6213B);
  static const Color redFill = Color(0xFFC8334B);
  static const Color redDeep = Color(0xFF7A1329);

  static const Color blue = Color(0xFF1F4E8C);
  static const Color blueFill = Color(0xFF3B7CCD);
  static const Color blueDeep = Color(0xFF143765);

  static const Color gold = Color(0xFFA87410);
  static const Color goldFill = Color(0xFFF2B229);
  static const Color goldDeep = Color(0xFFC8870F);
}

class AppGradients {
  AppGradients._();

  static const LinearGradient heroSplash = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFFAF7F2),
      Color(0xFFFBE9E4),
      Color(0xFFFBF1D8),
    ],
    stops: <double>[0.0, 0.55, 1.0],
  );

  static const LinearGradient headerSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFBE9E4), Color(0xFFFAF7F2)],
  );

  static const LinearGradient primaryButton = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[AppColors.redFill, AppColors.redDeep],
  );

  static const LinearGradient redHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[AppColors.redFill, AppColors.redDeep],
  );

  static const LinearGradient blueHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[AppColors.blueFill, AppColors.blueDeep],
  );

  static const LinearGradient goldHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[AppColors.goldFill, AppColors.goldDeep],
  );

  static const LinearGradient avatar = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[AppColors.redFill, AppColors.redDeep],
  );
}

class TipoConvocatoria {
  TipoConvocatoria._();

  static Color color(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'incubación':
      case 'incubacion':
      case 'pre incubación':
      case 'pre incubacion':
        return AppColors.goldFill;
      case 'intercambio':
      case 'hackatón':
      case 'hackaton':
      case 'hackathon':
        return AppColors.blueFill;
      case 'investigación':
      case 'investigacion':
        return AppColors.redFill;
      default:
        return AppColors.redFill;
    }
  }

  static Color textColor(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'incubación':
      case 'incubacion':
      case 'pre incubación':
      case 'pre incubacion':
        return AppColors.gold;
      case 'intercambio':
      case 'hackatón':
      case 'hackaton':
      case 'hackathon':
        return AppColors.blue;
      case 'investigación':
      case 'investigacion':
        return AppColors.red;
      default:
        return AppColors.red;
    }
  }

  static LinearGradient gradient(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'incubación':
      case 'incubacion':
      case 'pre incubación':
      case 'pre incubacion':
        return AppGradients.goldHero;
      case 'intercambio':
      case 'hackatón':
      case 'hackaton':
      case 'hackathon':
        return AppGradients.blueHero;
      case 'investigación':
      case 'investigacion':
        return AppGradients.redHero;
      default:
        return AppGradients.redHero;
    }
  }
}
