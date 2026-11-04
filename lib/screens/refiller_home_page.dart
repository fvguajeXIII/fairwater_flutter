import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import 'qr_scanner_page.dart';

class RefillerHomePage extends StatefulWidget {
  const RefillerHomePage({super.key});

  @override
  State<RefillerHomePage> createState() => _RefillerHomePageState();
}

class _RefillerHomePageState extends State<RefillerHomePage> {
  final ProfileService _profiles = ProfileService();
  final AuthService _auth = AuthService();
  String? _refillNameBackfillError;

  @override
  void initState() {
    super.initState();
    _backfillRefillEventCustomerNames();
  }

  Future<void> _backfillRefillEventCustomerNames() async {
    if (_auth.currentUser == null) return;

    try {
      await _profiles.backfillRefillEventCustomerNames();
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _refillNameBackfillError =
            error.message ?? 'Impossibile recuperare i nomi dei clienti.';
      });
    }
  }

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Storico refill',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.deepOcean,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_refillNameBackfillError case final error?)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Impossibile recuperare alcuni nomi: $error',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        StreamBuilder<List<FairWaterRefillEvent>>(
                          stream: _profiles.watchRefillerRefills(user.uid),
                          builder: (context, eventsSnapshot) {
                            if (eventsSnapshot.hasError) {
                              return const Text(
                                'Impossibile caricare lo storico dei refill.',
                              );
                            }
                            if (!eventsSnapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final events = eventsSnapshot.data!;
                            if (events.isEmpty) {
                              return const Text(
                                'Nessun refill registrato per ora.',
                              );
                            }

                            return Column(
                              children: [
                                for (
                                  var index = 0;
                                  index < events.length;
                                  index++
                                ) ...[
                                  if (index > 0) const Divider(height: 16),
                                  _RefillHistoryTile(event: events[index]),
                                ],
                              ],
                            );
                          },
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
    final withPurchase = await showDialog<bool>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Tipo di refill', textAlign: TextAlign.center),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(true),
            child: const ListTile(
              leading: Icon(Icons.local_cafe_rounded),
              title: Text('Refill con consumazione'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(false),
            child: const ListTile(
              leading: Icon(Icons.water_drop_rounded),
              title: Text('Refill senza consumazione'),
            ),
          ),
        ],
      ),
    );
    if (!context.mounted || withPurchase == null) return;
    final payload = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScannerPage()));
    if (!context.mounted || payload == null) return;
    try {
      final result = await _profiles.recordCustomerRefill(
        payload,
        withPurchase: withPurchase,
      );
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

class _RefillHistoryTile extends StatelessWidget {
  const _RefillHistoryTile({required this.event});

  final FairWaterRefillEvent event;

  @override
  Widget build(BuildContext context) {
    final purchaseLabel = switch (event.withPurchase) {
      true => 'Con consumazione',
      false => 'Senza consumazione',
      null => 'Tipo non disponibile',
    };
    final refillDate = event.createdAt;
    final dateLabel = refillDate == null
        ? 'Data non disponibile'
        : '${refillDate.toLocal().day.toString().padLeft(2, '0')}/'
              '${refillDate.toLocal().month.toString().padLeft(2, '0')}/'
              '${refillDate.toLocal().year} '
              '${refillDate.toLocal().hour.toString().padLeft(2, '0')}:'
              '${refillDate.toLocal().minute.toString().padLeft(2, '0')}';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: AppColors.mist,
        child: Icon(Icons.person_outline_rounded, color: AppColors.deepOcean),
      ),
      title: Text(
        event.customerName.isEmpty
            ? 'Cliente non disponibile'
            : event.customerName,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('$purchaseLabel • $dateLabel'),
      trailing: Icon(
        event.withPurchase == true
            ? Icons.local_cafe_rounded
            : Icons.water_drop_rounded,
        color: AppColors.ocean,
      ),
    );
  }
}
