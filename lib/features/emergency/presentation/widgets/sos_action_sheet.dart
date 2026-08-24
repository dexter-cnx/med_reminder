import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/emergency_contact_launcher.dart';
import '../../data/platform/url_launcher_emergency_contact_launcher.dart';
import '../providers/emergency_profile_providers.dart';
import '../screens/emergency_medical_card_screen.dart';

final emergencyContactLauncherProvider = Provider<EmergencyContactLauncher>(
  (ref) => const UrlLauncherEmergencyContactLauncher(),
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
              'sos_title'.tr(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              hasPhone
                  ? 'sos_contact'.tr(
                      namedArgs: {
                        'name': contactName.isEmpty
                            ? 'sos_contact_default'.tr()
                            : contactName,
                        'phone': phone,
                      },
                    )
                  : 'sos_no_contact'.tr(),
            ),
            const SizedBox(height: 8),
            Text(
              'sos_external_action_note'.tr(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: hasPhone
                  ? () => _launch(
                        context,
                        ref,
                        (launcher) => launcher.call(phone),
                      )
                  : null,
              icon: const Icon(Icons.call_outlined),
              label: Text('sos_call'.tr()),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: hasPhone
                  ? () => _launch(
                        context,
                        ref,
                        (launcher) => launcher.sms(phone),
                      )
                  : null,
              icon: const Icon(Icons.sms_outlined),
              label: Text('sos_sms'.tr()),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const EmergencyMedicalCardScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.medical_information_outlined),
              label: Text('emergency_card_title'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launch(
    BuildContext context,
    WidgetRef ref,
    Future<bool> Function(EmergencyContactLauncher launcher) action,
  ) async {
    final launched = await action(ref.read(emergencyContactLauncherProvider));
    if (!context.mounted || launched) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('sos_launch_failed'.tr())),
    );
  }
}
