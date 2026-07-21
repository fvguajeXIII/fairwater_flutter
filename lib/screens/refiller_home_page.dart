import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import 'qr_scanner_page.dart';

class RefillerHomePage extends StatelessWidget {
  RefillerHomePage({super.key});

  final ProfileService _profiles = ProfileService();
  final AuthService _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<FairWaterUserProfile>(
      stream: _profiles.watchUserProfile(user.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: WaterBackdrop(
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final profile = snapshot.data!;
        return Scaffold(
          body: WaterBackdrop(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.mist,
                        child: Icon(
                          Icons.storefront_rounded,
                          color: AppColors.deepOcean,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Profilo Refiller',
                              style: TextStyle(
                                color: AppColors.ocean,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              profile.fullName,
                              style: const TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Esci',
                        onPressed: _auth.signOut,
                        icon: const Icon(Icons.logout_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: AppDecorations.glassCard(radius: 28),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.water_drop_rounded,
                          size: 44,
                          color: AppColors.ocean,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${profile.refillCount}',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: AppColors.deepOcean,
                          ),
                        ),
                        const Text(
                          'refill erogati',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _scan(context),
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            label: const Text('Scansiona QR Customer'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppDecorations.glassCard(radius: 24),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          color: AppColors.ocean,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Inquadra il QR personale del Customer. Le statistiche di entrambi saranno aggiornate automaticamente.',
                            style: TextStyle(height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.large(
            onPressed: () => _scan(context),
            child: const Icon(Icons.qr_code_scanner_rounded),
          ),
        );
      },
    );
  }

  Future<void> _scan(BuildContext context) async {
    final payload = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScannerPage()));
    if (!context.mounted || payload == null) return;
    try {
      final result = await _profiles.recordCustomerRefill(payload);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.ocean,
            size: 48,
          ),
          title: const Text('Refill registrato!'),
          content: Text(
            '${result.customerName.isEmpty ? 'Il Customer' : result.customerName} ha ora ${result.customerRefillCount} refill.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continua'),
            ),
          ],
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'QR non valido.')),
      );
    }
  }
}
