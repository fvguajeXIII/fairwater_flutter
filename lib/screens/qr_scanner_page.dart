import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

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

    if (Platform.isAndroid) {
      controller.pauseCamera();
    }
    controller.resumeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Errore scanner QR: $error'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          QRView(
            key: _qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: Colors.white,
              borderRadius: 28,
              borderLength: 34,
              borderWidth: 6,
              cutOutSize: 250,
              overlayColor: Colors.black.withValues(alpha: 0.45),
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
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'Inquadra un QR code all interno del riquadro.',
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

class _ScannerTopButton extends StatelessWidget {
  const _ScannerTopButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
