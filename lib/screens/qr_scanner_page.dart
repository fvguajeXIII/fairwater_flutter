import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

import '../theme/app_theme.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'fairwater-qr');

  QRViewController? _controller;
  bool _handledScan = false;
  bool _torchEnabled = false;

  @override
  void reassemble() {
    super.reassemble();
    final controller = _controller;
    if (controller == null || kIsWeb) {
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      controller.pauseCamera();
    }
    controller.resumeCamera();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    await controller.toggleFlash();
    final status = await controller.getFlashStatus() ?? false;
    if (!mounted) return;
    setState(() {
      _torchEnabled = status;
    });
  }

  void _onQRViewCreated(QRViewController controller) {
    _controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (_handledScan) {
        return;
      }

      final rawValue = scanData.code;
      if (rawValue == null || rawValue.isEmpty) {
        return;
      }

      _handledScan = true;
      await controller.pauseCamera();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(rawValue);
    });
  }

  void _onScannerError(BuildContext context, Object? error) {
    debugPrint('[QrScanner] error: $error');
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Errore scanner QR: $error')));
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const _QrScannerWebFallback();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          QRView(
            key: _qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: AppColors.ocean,
              borderRadius: 34,
              borderLength: 38,
              borderWidth: 7,
              cutOutSize: 250,
              overlayColor: Colors.black.withValues(alpha: 0.58),
            ),
            onPermissionSet: (controller, granted) {
              if (!granted) {
                _onScannerError(
                  context,
                  'Permesso fotocamera negato sul dispositivo.',
                );
              }
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      _ScannerTopButton(
                        icon: Icons.arrow_back_rounded,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      _ScannerTopButton(
                        icon: _torchEnabled
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        onPressed: _toggleTorch,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.deepOcean.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: const Text(
                      'Inquadra il QR del refill all interno del riquadro.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrScannerWebFallback extends StatefulWidget {
  const _QrScannerWebFallback();

  @override
  State<_QrScannerWebFallback> createState() => _QrScannerWebFallbackState();
}

class _QrScannerWebFallbackState extends State<_QrScannerWebFallback> {
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _submitCode() {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      return;
    }
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WaterBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: AppDecorations.glassCard(radius: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.deepOcean,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const WaterBottleBadge(size: 74),
                      const SizedBox(height: 18),
                      const Text(
                        'Inserisci codice refill',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'La scansione con fotocamera e disponibile sull app mobile. Sul web puoi usare il codice stampato sotto al QR.',
                        style: TextStyle(
                          height: 1.45,
                          color: AppColors.slate.withValues(alpha: 0.92),
                        ),
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: _codeController,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          hintText: 'Codice refill',
                          prefixIcon: Icon(Icons.qr_code_2_rounded),
                        ),
                        onSubmitted: (_) => _submitCode(),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _submitCode,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Registra refill'),
                        ),
                      ),
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

class _ScannerTopButton extends StatelessWidget {
  const _ScannerTopButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.deepOcean.withValues(alpha: 0.36),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}
