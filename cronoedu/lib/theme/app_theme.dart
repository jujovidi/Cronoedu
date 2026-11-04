import 'package:flutter/material.dart';

/// Paleta de CronoEdu tomada de la propuesta de diseño.
class Palette {
  // Modo claro
  static const moradoEstudio = Color(0xFF6C5CE7);
  static const naranjaCreativo = Color(0xFFFF9F43);
  static const azulEnfoque = Color(0xFF4834D4);
  static const verdeLogro = Color(0xFF10AC84);
  static const grisGrafito = Color(0xFF2C3539);

  // Modo oscuro
  static const moradoProfundo = Color(0xFF4834D4);
  static const naranjaResaltado = Color(0xFFFFB16A);
  static const azulResaltado = Color(0xFF5D9AFE);
  static const azulEstudio = Color(0xFF2F80ED);
  static const verdeLuminoso = Color(0xFF22D39A);
  static const blancoCrema = Color(0xFFF3F4F6);

  static const rojoPendiente = Color(0xFFE5484D);
  static const rojoPendienteOscuro = Color(0xFFFF6B6B);
}

/// Colores semánticos que no existen en ColorScheme (logro, pendiente, tipos
/// de bloque). Se leen con `context.colors`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.success,
    required this.pending,
    required this.focus,
    required this.creative,
    required this.paused,
    required this.clase,
    required this.ocio,
    required this.trabajo,
    required this.extracurricular,
    required this.estudio,
  });

  final Color success;
  final Color pending;
  final Color focus;
  final Color creative;
  final Color paused;
  final Color clase;
  final Color ocio;
  final Color trabajo;
  final Color extracurricular;

  /// Sesiones de estudio autónomo: azul, distinto del morado de clases y tareas.
  final Color estudio;

  static const light = AppColors(
    success: Palette.verdeLogro,
    pending: Palette.rojoPendiente,
    focus: Palette.azulEnfoque,
    creative: Palette.naranjaCreativo,
    paused: Color(0xFFB8BCC2),
    clase: Palette.moradoEstudio,
    ocio: Palette.naranjaCreativo,
    trabajo: Palette.grisGrafito,
    extracurricular: Palette.verdeLogro,
    estudio: Palette.azulEstudio,
  );

  static const dark = AppColors(
    success: Palette.verdeLuminoso,
    pending: Palette.rojoPendienteOscuro,
    focus: Palette.azulResaltado,
    creative: Palette.naranjaResaltado,
    paused: Color(0xFF6B7075),
    clase: Color(0xFF7E70F0),
    ocio: Palette.naranjaResaltado,
    trabajo: Color(0xFF8A9499),
    extracurricular: Palette.verdeLuminoso,
    estudio: Palette.azulResaltado,
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t)!,
      pending: Color.lerp(pending, other.pending, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      creative: Color.lerp(creative, other.creative, t)!,
      paused: Color.lerp(paused, other.paused, t)!,
      clase: Color.lerp(clase, other.clase, t)!,
      ocio: Color.lerp(ocio, other.ocio, t)!,
      trabajo: Color.lerp(trabajo, other.trabajo, t)!,
      extracurricular: Color.lerp(extracurricular, other.extracurricular, t)!,
      estudio: Color.lerp(estudio, other.estudio, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: Palette.moradoEstudio, brightness: Brightness.light).copyWith(
      primary: Palette.moradoEstudio,
      onPrimary: Colors.white,
      secondary: Palette.naranjaCreativo,
      onSecondary: Colors.white,
      tertiary: Palette.azulEnfoque,
      onTertiary: Colors.white,
      surface: Colors.white,
      onSurface: Palette.grisGrafito,
      error: Palette.rojoPendiente,
    );
    return _base(scheme, AppColors.light, const Color(0xFFF3F4F8));
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(seedColor: Palette.moradoProfundo, brightness: Brightness.dark).copyWith(
      primary: const Color(0xFF7E70F0),
      onPrimary: Colors.white,
      secondary: Palette.naranjaResaltado,
      onSecondary: Palette.grisGrafito,
      tertiary: Palette.azulResaltado,
      onTertiary: Palette.grisGrafito,
      surface: const Color(0xFF262C30),
      onSurface: Palette.blancoCrema,
      error: Palette.rojoPendienteOscuro,
    );
    return _base(scheme, AppColors.dark, const Color(0xFF1B1F22));
  }

  static ThemeData _base(ColorScheme scheme, AppColors colors, Color bg) {
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(color: scheme.surface, elevation: 0, margin: EdgeInsets.zero, shape: rounded),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, letterSpacing: .5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: .5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
      chipTheme: ChipThemeData(shape: const StadiumBorder(), side: BorderSide.none),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: bg,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      dialogTheme: DialogThemeData(shape: rounded),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
