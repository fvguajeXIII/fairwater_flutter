import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/profile_service.dart';
import '../theme/app_theme.dart';

class CustomerQrPage extends StatelessWidget {
  const CustomerQrPage({super.key, required this.profile});

  final FairWaterUserProfile profile;

  String get _payload => 'fairwater://customer/${profile.uid}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WaterBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Container(
                  padding: const EdgeInsets.all(26),
                  decoration: AppDecorations.glassCard(radius: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      ),
                      const Icon(
                        Icons.water_drop_rounded,
                        size: 48,
                        color: AppColors.ocean,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Il tuo QR FairWater',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Mostralo al Refiller quando riempi la borraccia.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.slate, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.ocean.withValues(alpha: .14),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            QrImageView(
                              data: _payload,
                              version: QrVersions.auto,
                              size: 255,
                              errorCorrectionLevel: QrErrorCorrectLevel.H,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.circle,
                                color: AppColors.deepOcean,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.circle,
                                color: AppColors.deepOcean,
                              ),
                            ),
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.mist,
                                  width: 3,
                                ),
                              ),
                              child: const _QrBottleMark(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        profile.fullName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text('${profile.refillCount} refill completati'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Borraccia al centro del QR, disegnata come la MO9356 vera: tappo in acciaio,
// anello scuro, spalla arrotondata, corpo alto trasparente ed etichetta avvolgente.
class _QrBottleMark extends StatelessWidget {
  const _QrBottleMark();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 12,
    height: 38,
    child: CustomPaint(painter: _RealBottlePainter()),
  );
}

class _RealBottlePainter extends CustomPainter {
  const _RealBottlePainter();

  // Coordinate del disegno originale (le stesse delle borracce del sito):
  // larghezza 52-200, altezza 6-502.
  static const double _left = 52;
  static const double _top = 6;
  static const double _width = 148;
  static const double _height = 496;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / _width;
    final sy = size.height / _height;
    Offset p(double x, double y) => Offset((x - _left) * sx, (y - _top) * sy);
    Rect r(double l, double t, double rgt, double b) =>
        Rect.fromPoints(p(l, t), p(rgt, b));

    final body = Path()
      ..moveTo(p(99, 62).dx, p(99, 62).dy)
      ..lineTo(p(99, 71).dx, p(99, 71).dy)
      ..cubicTo(p(72, 75).dx, p(72, 75).dy, p(52, 96).dx, p(52, 96).dy,
          p(52, 136).dx, p(52, 136).dy)
      ..lineTo(p(52, 480).dx, p(52, 480).dy)
      ..quadraticBezierTo(p(52, 502).dx, p(52, 502).dy, p(74, 502).dx,
          p(74, 502).dy)
      ..lineTo(p(178, 502).dx, p(178, 502).dy)
      ..quadraticBezierTo(p(200, 502).dx, p(200, 502).dy, p(200, 480).dx,
          p(200, 480).dy)
      ..lineTo(p(200, 136).dx, p(200, 136).dy)
      ..cubicTo(p(200, 96).dx, p(200, 96).dy, p(180, 75).dx, p(180, 75).dy,
          p(153, 71).dx, p(153, 71).dy)
      ..lineTo(p(153, 62).dx, p(153, 62).dy)
      ..close();

    // Vetro azzurrino e acqua
    canvas.drawPath(body, Paint()..color = const Color(0xFFDCEBFF));
    canvas.save();
    canvas.clipPath(body);
    canvas.drawRect(r(40, 176, 212, 510), Paint()..color = AppColors.ocean);
    // Etichetta bianca con l'ombra dei bordi del cilindro
    final label = r(40, 200, 212, 472);
    canvas.drawRect(label, Paint()..color = Colors.white);
    canvas.drawRect(
      label,
      Paint()
        ..shader = LinearGradient(
          colors: [
            AppColors.deepOcean.withValues(alpha: 0.28),
            Colors.transparent,
            Colors.transparent,
            AppColors.deepOcean.withValues(alpha: 0.24),
          ],
          stops: const [0, 0.3, 0.7, 1],
        ).createShader(label),
    );
    // Logo e QR stampati sull'etichetta, solo accennati
    final ink = Paint()..color = AppColors.deepOcean;
    canvas.drawRect(r(84, 226, 168, 238), ink);
    canvas.drawRect(r(108, 400, 144, 436), ink);
    canvas.restore();

    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.deepOcean,
    );

    // Anello scuro e tappo in acciaio
    canvas.drawRRect(
      RRect.fromRectAndRadius(r(98, 56, 154, 68), const Radius.circular(1)),
      Paint()..color = const Color(0xFF3B4653),
    );
    final cap = r(95, 6, 157, 60);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cap, Radius.circular(9 * sx)),
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF7E8894),
            Color(0xFFF4F6F8),
            Color(0xFFCDD3DA),
            Color(0xFF6F7984),
          ],
          stops: [0, 0.42, 0.62, 1],
        ).createShader(cap),
    );
  }

  @override
  bool shouldRepaint(covariant _RealBottlePainter oldDelegate) => false;
}
