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
                              child: const Icon(
                                Icons.water_drop_rounded,
                                color: AppColors.ocean,
                                size: 31,
                              ),
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
