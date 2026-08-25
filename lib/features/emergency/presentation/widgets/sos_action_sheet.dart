import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/emergency_contact_launcher.dart';
import '../../data/platform/platform_emergency_contact_launcher.dart';
import '../providers/emergency_profile_providers.dart';

final emergencyContactLauncherProvider = Provider<EmergencyContactLauncher>(
  (ref) => const PlatformEmergencyContactLauncher(),
);

Future<void> showSosActionSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const SosActionSheet(),
    );

class SosActionSheet extends ConsumerWidget {
  const SosActionSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(emergencyProfileProvider);
    final phone = profile?.emergencyContactPhone.trim() ?? '';
    final contactName = profile?.emergencyContactName.trim() ?? '';
    final hasPhone = phone.isNotEmpty;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'SOS',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'emergency_contact'.tr(),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              <String>[
                    if (contactName.isNotEmpty) contactName,
                    if (phone.isNotEmpty) phone,
                  ].join(' · ').isEmpty
                  ? '—'
                  : <String>[
                      if (contactName.isNotEmpty) contactName,
                      if (phone.isNotEmpty) phone,
                    ].join(' · '),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: hasPhone
                  ? () => ref.read(emergencyContactLauncherProvider).call(phone)
                  : null,
              icon: const Icon(Icons.call_outlined),
              label: Text(hasPhone ? phone : 'emergency_contact_phone'.tr()),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: hasPhone
                  ? () => ref.read(emergencyContactLauncherProvider).sms(phone)
                  : null,
              icon: const Icon(Icons.sms_outlined),
              label: const Text('SMS'),
            ),
          ],
        ),
      ),
    );
  }
}
