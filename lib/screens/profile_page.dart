import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/refill_notification_service.dart';
import '../theme/app_theme.dart';

const Color _kProfilePrimary = AppColors.ocean;
const Color _kProfilePrimaryDark = AppColors.deepOcean;
const Color _kProfileInk = AppColors.ink;

class ProfilePage extends StatelessWidget {
  ProfilePage({super.key});

  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    if (user == null) {
      return const _ProfileUnavailableState();
    }

    return StreamBuilder<FairWaterUserProfile>(
      stream: _profileService.watchUserProfile(user.uid),
      builder: (context, profileSnapshot) {
        if (profileSnapshot.hasError) {
          return _ProfileErrorState(message: profileSnapshot.error.toString());
        }

        if (!profileSnapshot.hasData) {
          return const _ProfileLoadingState();
        }

        final profile = profileSnapshot.data!;

        return StreamBuilder<FairWaterCommunityStats>(
          stream: _profileService.watchCommunityStats(),
          builder: (context, communitySnapshot) {
            final community =
                communitySnapshot.data ??
                const FairWaterCommunityStats(
                  totalMembers: 0,
                  totalRefills: 0,
                  totalPlasticSavedKg: 0,
                );
            return StreamBuilder<FairWaterSolidarityImpact>(
              stream: _profileService.watchSolidarityImpact(),
              builder: (context, solidaritySnapshot) {
                final solidarity =
                    solidaritySnapshot.data ??
                    const FairWaterSolidarityImpact(
                      totalSponsorRevenueEuro: 0,
                      fundsForWellsEuro: 0,
                      wellsFunded: 0,
                      peopleSupported: 0,
                      nextWellTargetEuro: 0,
                    );

                return WaterBackdrop(
                  child: SafeArea(
                    bottom: false,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ProfileHero(
                                  profile: profile,
                                  onSignOut: () => _signOut(context),
                                  onEditPhoto: () => _pickProfileImage(context),
                                ),
                                const SizedBox(height: 18),
                                _ProfileDetailsCard(profile: profile),
                                const SizedBox(height: 18),
                                _ImpactCard(
                                  title: 'Il tuo impatto',
                                  subtitle:
                                      'Dal giorno in cui hai iniziato a usare la borraccia FairWater.',
                                  primaryMetric: _MetricView(
                                    label: 'Refill completati',
                                    value: '${profile.refillCount}',
                                    helper:
                                        'Bottiglie evitate: ${profile.refillCount}',
                                    icon: Icons.local_drink_rounded,
                                  ),
                                  secondaryMetric: _MetricView(
                                    label: 'Plastica risparmiata',
                                    value:
                                        '${profile.plasticSavedKg.toStringAsFixed(profile.plasticSavedKg >= 10 ? 0 : 1)} kg',
                                    helper:
                                        'Stima: 25 g per ogni refill completato',
                                    icon: Icons.eco_rounded,
                                  ),
                                  actions: [
                                    _ShareAction(
                                      label: 'Facebook',
                                      icon: Icons.thumb_up_alt_rounded,
                                      onTap: () => _shareOnFacebook(
                                        context,
                                        profile: profile,
                                      ),
                                    ),
                                    _ShareAction(
                                      label: 'Instagram',
                                      icon: Icons.camera_alt_rounded,
                                      onTap: () => _shareOnInstagram(
                                        context,
                                        profile: profile,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                _MilestonesCard(
                                  title: 'Le tue milestone',
                                  subtitle:
                                      'Ogni refill rende il tuo impatto piu concreto e visibile.',
                                  milestones: _buildUserMilestones(profile),
                                ),
                                const SizedBox(height: 18),
                                _ImpactCard(
                                  title: 'Impatto della community FairWater',
                                  subtitle:
                                      'Non sei solo: qui vedi la forza collettiva della comunita.',
                                  primaryMetric: _MetricView(
                                    label: 'Refill della community',
                                    value: '${community.totalRefills}',
                                    helper:
                                        'Membri attivi: ${community.totalMembers}',
                                    icon: Icons.groups_rounded,
                                  ),
                                  secondaryMetric: _MetricView(
                                    label: 'Plastica risparmiata insieme',
                                    value:
                                        '${community.totalPlasticSavedKg.toStringAsFixed(community.totalPlasticSavedKg >= 10 ? 0 : 1)} kg',
                                    helper:
                                        'Stima aggregata su tutti i refill registrati',
                                    icon: Icons.water_drop_rounded,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _SolidarityCard(solidarity: solidarity),
                                const SizedBox(height: 18),
                                _MilestonesCard(
                                  title: 'Milestone pozzi in Africa',
                                  subtitle:
                                      'Una parte dei compensi degli sponsor alimenta questo traguardo solidale.',
                                  milestones: _buildSolidarityMilestones(
                                    solidarity,
                                  ),
                                  footer: solidarity.nextWellTargetEuro > 0
                                      ? _NextWellProgress(
                                          solidarity: solidarity,
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 18),
                                _MilestonesCard(
                                  title: 'Milestone della community',
                                  subtitle:
                                      'Obiettivi condivisi che raccontano quanto FairWater sta crescendo.',
                                  milestones: _buildCommunityMilestones(
                                    community,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await RefillNotificationService.instance.stopBackgroundMonitoring();
      await _authService.signOut();
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Non riesco a completare il logout in questo momento.'),
        ),
      );
    }
  }

  Future<void> _pickProfileImage(BuildContext context) async {
    final user = _authService.currentUser;
    if (user == null) {
      return;
    }

    try {
      final selectedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 72,
        maxWidth: 900,
      );

      if (selectedImage == null) {
        return;
      }

      final imageBytes = await selectedImage.readAsBytes();
      final encodedImage = base64Encode(imageBytes);

      await _profileService.updateProfileImage(
        uid: user.uid,
        photoBase64: encodedImage,
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Immagine profilo aggiornata con successo.'),
        ),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Non riesco ad aggiornare la foto profilo ora.'),
        ),
      );
    }
  }

  Future<void> _shareOnFacebook(
    BuildContext context, {
    required FairWaterUserProfile profile,
  }) async {
    final message = _buildShareMessage(profile);
    final uri = Uri.https('www.facebook.com', '/sharer/sharer.php', {
      'u': 'https://fairwater.app',
      'quote': message,
      'hashtag': '#FairWater',
    });

    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Non riesco ad aprire Facebook su questo dispositivo.'),
      ),
    );
  }

  Future<void> _shareOnInstagram(
    BuildContext context, {
    required FairWaterUserProfile profile,
  }) async {
    final message = _buildShareMessage(profile);
    await Clipboard.setData(ClipboardData(text: message));

    final candidateUris = <Uri>[
      if (!kIsWeb) Uri.parse('instagram://app'),
      Uri.parse('https://www.instagram.com/'),
    ];

    var opened = false;
    for (final uri in candidateUris) {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        opened = true;
        break;
      }
    }

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          opened
              ? 'Testo copiato. Incollalo nella tua storia o nel post Instagram.'
              : 'Testo copiato. Apri Instagram e incollalo nel contenuto che vuoi pubblicare.',
        ),
      ),
    );
  }

  String _buildShareMessage(FairWaterUserProfile profile) {
    final plastic = profile.plasticSavedKg.toStringAsFixed(
      profile.plasticSavedKg >= 10 ? 0 : 1,
    );
    return 'Con FairWater ho completato ${profile.refillCount} refill e ho gia risparmiato circa $plastic kg di plastica. Ogni ricarica conta. #FairWater #RefillRevolution';
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.profile,
    required this.onSignOut,
    required this.onEditPhoto,
  });

  final FairWaterUserProfile profile;
  final VoidCallback onSignOut;
  final VoidCallback onEditPhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppDecorations.heroGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _kProfilePrimary.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileAvatar(
                photoBase64: profile.photoBase64,
                photoUrl: profile.photoUrl,
                initials: profile.initials,
                onEdit: onEditPhoto,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      profile.email,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.86),
                      ),
                    ),
                    if (profile.residence.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 15,
                            color: Colors.white.withValues(alpha: 0.90),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              profile.residence,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.86),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                tooltip: 'Esci',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroBadge(
                icon: Icons.local_drink_rounded,
                label: '${profile.refillCount} refill',
              ),
              _HeroBadge(
                icon: Icons.eco_rounded,
                label:
                    '${profile.plasticSavedKg.toStringAsFixed(profile.plasticSavedKg >= 10 ? 0 : 1)} kg risparmiati',
              ),
              _HeroBadge(
                icon: Icons.verified_user_rounded,
                label: profile.provider.isEmpty
                    ? 'Membro FairWater'
                    : profile.provider,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.photoBase64,
    required this.photoUrl,
    required this.initials,
    required this.onEdit,
  });

  final String photoBase64;
  final String photoUrl;
  final String initials;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final memoryPhoto = _decodeProfileImage(photoBase64);
    final hasMemoryPhoto = memoryPhoto != null;
    final hasNetworkPhoto = photoUrl.isNotEmpty;
    final hasPhoto = hasMemoryPhoto || hasNetworkPhoto;

    return Stack(
      children: [
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.65),
              width: 3,
            ),
            gradient: hasPhoto ? null : AppDecorations.heroGradient,
          ),
          child: ClipOval(
            child: hasMemoryPhoto
                ? Image.memory(
                    memoryPhoto,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        _AvatarFallback(initials: initials),
                  )
                : hasNetworkPhoto
                ? Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        _AvatarFallback(initials: initials),
                  )
                : _AvatarFallback(initials: initials),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 6,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onEdit,
              child: const SizedBox(
                width: 30,
                height: 30,
                child: Icon(
                  Icons.photo_camera_rounded,
                  size: 16,
                  color: _kProfilePrimaryDark,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileDetailsCard extends StatelessWidget {
  const _ProfileDetailsCard({required this.profile});

  final FairWaterUserProfile profile;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            title: 'Dati profilo',
            subtitle: 'Le informazioni principali del tuo account FairWater.',
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ProfileInfoPill(
                icon: Icons.badge_rounded,
                label: 'Nome',
                value: profile.fullName,
              ),
              _ProfileInfoPill(
                icon: Icons.phone_rounded,
                label: 'Telefono',
                value: profile.phone.isEmpty ? 'Non inserito' : profile.phone,
              ),
              _ProfileInfoPill(
                icon: Icons.home_rounded,
                label: 'Residenza',
                value: profile.residence.isEmpty
                    ? 'Non inserita'
                    : profile.residence,
              ),
              _ProfileInfoPill(
                icon: Icons.card_giftcard_rounded,
                label: 'Referral',
                value: profile.referralCode.isEmpty
                    ? 'Nessun codice'
                    : profile.referralCode,
              ),
              _ProfileInfoPill(
                icon: Icons.calendar_month_rounded,
                label: 'Membro dal',
                value: _formatDate(profile.createdAt),
              ),
              _ProfileInfoPill(
                icon: Icons.water_drop_rounded,
                label: 'Borraccia attiva dal',
                value: _formatDate(profile.bottleOwnerSince),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImpactCard extends StatelessWidget {
  const _ImpactCard({
    required this.title,
    required this.subtitle,
    required this.primaryMetric,
    required this.secondaryMetric,
    this.actions = const <_ShareAction>[],
  });

  final String title;
  final String subtitle;
  final _MetricView primaryMetric;
  final _MetricView secondaryMetric;
  final List<_ShareAction> actions;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(title: title, subtitle: subtitle),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _MetricTile(metric: primaryMetric)),
              const SizedBox(width: 12),
              Expanded(child: _MetricTile(metric: secondaryMetric)),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: actions
                  .map(
                    (action) => OutlinedButton.icon(
                      onPressed: action.onTap,
                      icon: Icon(action.icon, size: 16),
                      label: Text(action.label),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kProfilePrimaryDark,
                        side: const BorderSide(color: Color(0xFFDCE8F3)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _MilestonesCard extends StatelessWidget {
  const _MilestonesCard({
    required this.title,
    required this.subtitle,
    required this.milestones,
    this.footer,
  });

  final String title;
  final String subtitle;
  final List<_MilestoneView> milestones;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(title: title, subtitle: subtitle),
          const SizedBox(height: 18),
          for (var index = 0; index < milestones.length; index++) ...[
            _MilestoneTile(milestone: milestones[index]),
            if (index != milestones.length - 1) const SizedBox(height: 12),
          ],
          if (footer != null) ...[const SizedBox(height: 16), footer!],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _kProfileInk,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: Colors.blueGrey.shade600,
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final _MetricView metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDEAF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(metric.icon, color: _kProfilePrimaryDark),
          ),
          const SizedBox(height: 14),
          Text(
            metric.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.blueGrey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            metric.value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _kProfileInk,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            metric.helper,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.blueGrey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({required this.milestone});

  final _MilestoneView milestone;

  @override
  Widget build(BuildContext context) {
    final progress = milestone.target == 0
        ? 0.0
        : (milestone.current / milestone.target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: milestone.completed
            ? const Color(0xFFF2FBF6)
            : const Color(0xFFF7FCFE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: milestone.completed
              ? const Color(0xFFCBEED9)
              : const Color(0xFFE3ECF4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: milestone.completed
                      ? const Color(0xFF17A05D)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  milestone.icon,
                  color: milestone.completed
                      ? Colors.white
                      : _kProfilePrimaryDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      milestone.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _kProfileInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      milestone.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: milestone.completed
                      ? const Color(0xFF17A05D)
                      : const Color(0xFFEAF4FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  milestone.completed
                      ? 'Sbloccata'
                      : '${milestone.current}/${milestone.target}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: milestone.completed
                        ? Colors.white
                        : _kProfilePrimaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: progress,
              backgroundColor: const Color(0xFFDDE8F2),
              valueColor: AlwaysStoppedAnimation<Color>(
                milestone.completed
                    ? const Color(0xFF17A05D)
                    : _kProfilePrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoPill extends StatelessWidget {
  const _ProfileInfoPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4ECF4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _kProfilePrimaryDark),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.blueGrey.shade500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kProfileInk,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SolidarityCard extends StatelessWidget {
  const _SolidarityCard({required this.solidarity});

  final FairWaterSolidarityImpact solidarity;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            title: 'Pozzi finanziati in Africa',
            subtitle:
                'Una parte dei compensi degli sponsor viene destinata alla costruzione di pozzi e all accesso all acqua.',
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  metric: _MetricView(
                    label: 'Pozzi finanziati',
                    value: '${solidarity.wellsFunded}',
                    helper: solidarity.peopleSupported > 0
                        ? 'Persone supportate: ${solidarity.peopleSupported}'
                        : 'Contatore aggiornabile dal team FairWater',
                    icon: Icons.water_rounded,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  metric: _MetricView(
                    label: 'Fondi destinati',
                    value:
                        'EUR ${solidarity.fundsForWellsEuro.toStringAsFixed(0)}',
                    helper:
                        'Ricavi sponsor complessivi: EUR ${solidarity.totalSponsorRevenueEuro.toStringAsFixed(0)}',
                    icon: Icons.volunteer_activism_rounded,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NextWellProgress extends StatelessWidget {
  const _NextWellProgress({required this.solidarity});

  final FairWaterSolidarityImpact solidarity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3ECF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progresso verso il prossimo pozzo',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.blueGrey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: solidarity.nextWellProgress,
              backgroundColor: const Color(0xFFDDE8F2),
              valueColor: const AlwaysStoppedAnimation<Color>(_kProfilePrimary),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            solidarity.euroMissingForNextWell <= 0
                ? 'Obiettivo raggiunto. Il prossimo pozzo puo essere avviato.'
                : 'Mancano EUR ${solidarity.euroMissingForNextWell.toStringAsFixed(0)} per completare il prossimo traguardo.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.blueGrey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileLoadingState extends StatelessWidget {
  const _ProfileLoadingState();

  @override
  Widget build(BuildContext context) {
    return const WaterBackdrop(
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ProfileUnavailableState extends StatelessWidget {
  const _ProfileUnavailableState();

  @override
  Widget build(BuildContext context) {
    return const WaterBackdrop(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Profilo non disponibile. Effettua di nuovo l accesso per continuare.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _ProfileErrorState extends StatelessWidget {
  const _ProfileErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return WaterBackdrop(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Non riesco a caricare il profilo.\n$message',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _MetricView {
  const _MetricView({
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
  });

  final String label;
  final String value;
  final String helper;
  final IconData icon;
}

class _ShareAction {
  const _ShareAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _MilestoneView {
  const _MilestoneView({
    required this.title,
    required this.description,
    required this.current,
    required this.target,
    required this.completed,
    required this.icon,
  });

  final String title;
  final String description;
  final int current;
  final int target;
  final bool completed;
  final IconData icon;
}

List<_MilestoneView> _buildUserMilestones(FairWaterUserProfile profile) {
  final milestones =
      <({String title, String description, int target, IconData icon})>[
        (
          title: 'Primo refill',
          description: 'Hai iniziato il tuo percorso FairWater.',
          target: 1,
          icon: Icons.play_circle_fill_rounded,
        ),
        (
          title: 'Abitudine sostenibile',
          description: 'Cinque refill significano una nuova routine.',
          target: 5,
          icon: Icons.loop_rounded,
        ),
        (
          title: 'Impatto concreto',
          description: 'Dieci refill: la differenza inizia a vedersi davvero.',
          target: 10,
          icon: Icons.trending_up_rounded,
        ),
        (
          title: 'Ambassador FairWater',
          description: 'Venticinque refill raccontano una scelta coerente.',
          target: 25,
          icon: Icons.workspace_premium_rounded,
        ),
      ];

  return milestones
      .map(
        (milestone) => _MilestoneView(
          title: milestone.title,
          description: milestone.description,
          current: profile.refillCount,
          target: milestone.target,
          completed: profile.refillCount >= milestone.target,
          icon: milestone.icon,
        ),
      )
      .toList();
}

List<_MilestoneView> _buildCommunityMilestones(
  FairWaterCommunityStats community,
) {
  final milestones =
      <({String title, String description, int target, IconData icon})>[
        (
          title: 'Community in movimento',
          description: 'I primi 25 refill condivisi dalla comunita.',
          target: 25,
          icon: Icons.directions_walk_rounded,
        ),
        (
          title: 'Quartiere attivo',
          description: 'A 100 refill il progetto inizia a farsi notare.',
          target: 100,
          icon: Icons.location_city_rounded,
        ),
        (
          title: 'Onda FairWater',
          description: 'A 250 refill la rete cresce con costanza.',
          target: 250,
          icon: Icons.waves_rounded,
        ),
        (
          title: 'Impatto collettivo',
          description: 'A 500 refill la community cambia davvero le abitudini.',
          target: 500,
          icon: Icons.public_rounded,
        ),
      ];

  return milestones
      .map(
        (milestone) => _MilestoneView(
          title: milestone.title,
          description: milestone.description,
          current: community.totalRefills,
          target: milestone.target,
          completed: community.totalRefills >= milestone.target,
          icon: milestone.icon,
        ),
      )
      .toList();
}

List<_MilestoneView> _buildSolidarityMilestones(
  FairWaterSolidarityImpact solidarity,
) {
  final milestones = <({String title, String description, int target, IconData icon})>[
    (
      title: 'Primo pozzo',
      description:
          'Il primo traguardo concreto finanziato grazie agli sponsor.',
      target: 1,
      icon: Icons.flag_circle_rounded,
    ),
    (
      title: 'Tre pozzi attivi',
      description: 'La rete solidale comincia ad avere un impatto stabile.',
      target: 3,
      icon: Icons.hub_rounded,
    ),
    (
      title: 'Cinque pozzi finanziati',
      description:
          'FairWater trasforma i contributi sponsor in un progetto scalabile.',
      target: 5,
      icon: Icons.public_rounded,
    ),
    (
      title: 'Dieci pozzi costruiti',
      description:
          'Una milestone simbolica che racconta una comunita davvero generativa.',
      target: 10,
      icon: Icons.emoji_events_rounded,
    ),
  ];

  return milestones
      .map(
        (milestone) => _MilestoneView(
          title: milestone.title,
          description: milestone.description,
          current: solidarity.wellsFunded,
          target: milestone.target,
          completed: solidarity.wellsFunded >= milestone.target,
          icon: milestone.icon,
        ),
      )
      .toList();
}

String _formatDate(DateTime? date) {
  if (date == null) {
    return 'In aggiornamento';
  }

  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  return '$day/$month/$year';
}

Uint8List? _decodeProfileImage(String photoBase64) {
  if (photoBase64.isEmpty) {
    return null;
  }

  try {
    return base64Decode(photoBase64);
  } catch (_) {
    return null;
  }
}
