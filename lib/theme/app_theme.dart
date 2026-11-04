import 'package:flutter/material.dart';

class AppColors {
  static const Color deepOcean = Color(0xFF195BAA);
  static const Color ocean = Color(0xFF2D7FE0);
  static const Color aqua = Color(0xFF6FB4FF);
  static const Color mist = Color(0xFFEAF3FF);
  static const Color foam = Color(0xFFF7FAFF);
  static const Color ink = Color(0xFF15324F);
  static const Color slate = Color(0xFF5D7188);
  static const Color success = Color(0xFF1D9A67);
  static const Color border = Color(0xFFD8E6F7);
  static const Color borderStrong = Color(0xFFBCD3EF);
  static const Color iconMuted = Color(0xFF7D91A9);
  static const Color line = Color(0xFFE5EDF7);
  static const Color surfaceAlt = Color(0xFFEAF3FF);
  static const Color surfaceMuted = Color(0xFFF1F6FC);
}

class AppTheme {
  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.ocean,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.ocean,
          secondary: AppColors.aqua,
          tertiary: AppColors.deepOcean,
          surface: Colors.white,
          onSurface: AppColors.ink,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.foam,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
          height: 1.05,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
        titleLarge: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        bodyLarge: TextStyle(fontSize: 15, color: AppColors.ink, height: 1.45),
        bodyMedium: TextStyle(
          fontSize: 13,
          color: AppColors.slate,
          height: 1.45,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.ink,
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.ocean,
        headerForegroundColor: Colors.white,
        dividerColor: AppColors.border,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        shadowColor: AppColors.deepOcean.withValues(alpha: 0.10),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ocean,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.ocean.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.deepOcean,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(fontSize: 14, color: AppColors.iconMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.ocean, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

class AppDecorations {
  static const LinearGradient shellGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF7FAFF), Color(0xFFEAF3FF), Color(0xFFFAFCFF)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.deepOcean, AppColors.ocean, AppColors.aqua],
  );

  static BoxDecoration glassCard({double radius = 28}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.90),
          Colors.white.withValues(alpha: 0.68),
        ],
      ),
      border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
      boxShadow: [
        BoxShadow(
          color: AppColors.deepOcean.withValues(alpha: 0.12),
          blurRadius: 28,
          offset: const Offset(0, 16),
        ),
      ],
    );
  }
}

class WaterPatternBackground extends StatelessWidget {
  const WaterPatternBackground({super.key});

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE9FAFF), Color(0xFFBDECF5), Color(0xFF91D8E8)],
      ),
    ),
    child: CustomPaint(painter: _WaterPatternPainter()),
  );
}

class _WaterPatternPainter extends CustomPainter {
  const _WaterPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    for (var row = 0; row < 16; row++) {
      final y = row * 48.0 + 12;
      final path = Path()
        ..moveTo(0, y)
        ..cubicTo(
          size.width * 0.24,
          y - 18,
          size.width * 0.30,
          y + 18,
          size.width * 0.52,
          y,
        )
        ..cubicTo(
          size.width * 0.72,
          y - 16,
          size.width * 0.82,
          y + 16,
          size.width,
          y - 2,
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.ocean.withValues(alpha: row.isEven ? 0.11 : 0.07)
          ..style = PaintingStyle.stroke
          ..strokeWidth = row.isEven ? 2 : 1,
      );
    }

    final bubblePaint = Paint()..style = PaintingStyle.stroke;
    for (final bubble in const [
      (0.12, 0.18, 8.0),
      (0.82, 0.12, 12.0),
      (0.90, 0.42, 6.0),
      (0.08, 0.68, 11.0),
      (0.76, 0.82, 7.0),
    ]) {
      bubblePaint
        ..color = Colors.white.withValues(alpha: 0.48)
        ..strokeWidth = 2;
      canvas.drawCircle(
        Offset(size.width * bubble.$1, size.height * bubble.$2),
        bubble.$3,
        bubblePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaterPatternPainter oldDelegate) => false;
}

class WaterBottleBadge extends StatelessWidget {
  const WaterBottleBadge({super.key, this.size = 84, this.showGlow = true});

  final double size;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppDecorations.heroGradient,
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: AppColors.ocean.withValues(alpha: 0.24),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.62,
            height: size * 0.62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          Icon(
            Icons.water_drop_rounded,
            color: Colors.white,
            size: size * 0.40,
          ),
          Positioned(
            top: size * 0.18,
            child: Container(
              width: size * 0.18,
              height: size * 0.18,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(size * 0.08),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WaterBackdrop extends StatelessWidget {
  const WaterBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppDecorations.shellGradient),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -30,
            child: _Bubble(
              size: 220,
              color: AppColors.aqua.withValues(alpha: 0.12),
            ),
          ),
          const Positioned(
            top: 110,
            left: -40,
            child: _Bubble(size: 150, color: Color(0x1A69D5E7)),
          ),
          Positioned(
            bottom: -70,
            right: 20,
            child: _Bubble(
              size: 180,
              color: AppColors.ocean.withValues(alpha: 0.08),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class WaterPatternBackground extends StatelessWidget {
  const WaterPatternBackground({super.key});

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE9FAFF), Color(0xFFBDECF5), Color(0xFF91D8E8)],
      ),
    ),
    child: CustomPaint(painter: _WaterPatternPainter()),
  );
}

class _WaterPatternPainter extends CustomPainter {
  const _WaterPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    for (var row = 0; row < 16; row++) {
      final y = row * 48.0 + 12;
      final path = Path()
        ..moveTo(0, y)
        ..cubicTo(
          size.width * 0.24,
          y - 18,
          size.width * 0.30,
          y + 18,
          size.width * 0.52,
          y,
        )
        ..cubicTo(
          size.width * 0.72,
          y - 16,
          size.width * 0.82,
          y + 16,
          size.width,
          y - 2,
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.ocean.withValues(alpha: row.isEven ? 0.11 : 0.07)
          ..style = PaintingStyle.stroke
          ..strokeWidth = row.isEven ? 2 : 1,
      );
    }

    final bubblePaint = Paint()..style = PaintingStyle.stroke;
    for (final bubble in const [
      (0.12, 0.18, 8.0),
      (0.82, 0.12, 12.0),
      (0.90, 0.42, 6.0),
      (0.08, 0.68, 11.0),
      (0.76, 0.82, 7.0),
    ]) {
      bubblePaint
        ..color = Colors.white.withValues(alpha: 0.48)
        ..strokeWidth = 2;
      canvas.drawCircle(
        Offset(size.width * bubble.$1, size.height * bubble.$2),
        bubble.$3,
        bubblePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaterPatternPainter oldDelegate) => false;
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
