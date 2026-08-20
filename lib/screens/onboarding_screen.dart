import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.onRequestNotifications,
    required this.onComplete,
    this.onRequestExactAlarm,
    this.showExactAlarmStep = false,
    super.key,
  });

  final Future<bool> Function() onRequestNotifications;
  final Future<bool> Function()? onRequestExactAlarm;
  final Future<void> Function() onComplete;
  final bool showExactAlarmStep;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  bool _busy = false;
  bool? _notificationsGranted;
  bool? _exactAlarmGranted;

  Future<void> _requestNotifications() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final granted = await widget.onRequestNotifications();
      if (!mounted) return;
      setState(() => _notificationsGranted = granted);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestExactAlarm() async {
    final request = widget.onRequestExactAlarm;
    if (_busy || request == null) return;
    setState(() => _busy = true);
    try {
      final granted = await request();
      if (!mounted) return;
      setState(() => _exactAlarmGranted = granted);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onComplete();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => context.setLocale(
                    context.locale.languageCode == 'th'
                        ? const Locale('en')
                        : const Locale('th'),
                  ),
                  icon: const Icon(Icons.language),
                  label: Text(context.locale.languageCode.toUpperCase()),
                ),
              ),
              Expanded(child: _buildStep(context)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(
                  3,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: index == _step ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: index == _step
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _primaryAction,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_primaryLabel.tr()),
                ),
              ),
              if (_step == 1 && _notificationsGranted != true)
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _step = 2),
                  child: Text('onboarding_not_now'.tr()),
                )
              else if (_step == 2 &&
                  widget.showExactAlarmStep &&
                  _exactAlarmGranted != true)
                TextButton(
                  onPressed: _busy ? null : _finish,
                  child: Text('onboarding_not_now'.tr()),
                )
              else
                const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  String get _primaryLabel {
    switch (_step) {
      case 0:
        return 'onboarding_continue';
      case 1:
        return _notificationsGranted == true
            ? 'onboarding_continue'
            : 'onboarding_enable_notifications';
      case 2:
        if (widget.showExactAlarmStep && _exactAlarmGranted != true) {
          return 'onboarding_enable_precise_reminders';
        }
        return 'onboarding_get_started';
      default:
        return 'onboarding_get_started';
    }
  }

  Future<void> _primaryAction() async {
    switch (_step) {
      case 0:
        setState(() => _step = 1);
      case 1:
        if (_notificationsGranted == true) {
          setState(() => _step = 2);
          return;
        }
        await _requestNotifications();
        if (mounted && _notificationsGranted == true) {
          setState(() => _step = 2);
        }
      case 2:
        if (widget.showExactAlarmStep && _exactAlarmGranted != true) {
          await _requestExactAlarm();
          if (!mounted) return;
          if (_exactAlarmGranted == true) await _finish();
          return;
        }
        await _finish();
    }
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return _OnboardingPanel(
          icon: Icons.medication_outlined,
          title: 'onboarding_welcome_title'.tr(),
          body: 'onboarding_welcome_body'.tr(),
          bullets: [
            'onboarding_feature_offline'.tr(),
            'onboarding_feature_reminders'.tr(),
            'onboarding_feature_stock'.tr(),
          ],
        );
      case 1:
        return _OnboardingPanel(
          icon: Icons.notifications_active_outlined,
          title: 'onboarding_notifications_title'.tr(),
          body: 'onboarding_notifications_body'.tr(),
          status: _notificationsGranted == null
              ? null
              : (_notificationsGranted!
                  ? 'onboarding_permission_enabled'.tr()
                  : 'onboarding_permission_not_enabled'.tr()),
        );
      case 2:
        if (widget.showExactAlarmStep) {
          return _OnboardingPanel(
            icon: Icons.alarm_outlined,
            title: 'onboarding_precise_title'.tr(),
            body: 'onboarding_precise_body'.tr(),
            status: _exactAlarmGranted == null
                ? 'onboarding_precise_optional'.tr()
                : (_exactAlarmGranted!
                    ? 'onboarding_permission_enabled'.tr()
                    : 'onboarding_permission_not_enabled'.tr()),
          );
        }
        return _OnboardingPanel(
          icon: Icons.check_circle_outline,
          title: 'onboarding_ready_title'.tr(),
          body: 'onboarding_ready_body'.tr(),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _OnboardingPanel extends StatelessWidget {
  const _OnboardingPanel({
    required this.icon,
    required this.title,
    required this.body,
    this.bullets = const <String>[],
    this.status,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<String> bullets;
  final String? status;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(icon, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 28),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (bullets.isNotEmpty) ...[
              const SizedBox(height: 28),
              ...bullets.map(
                (text) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.check_circle_outline, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(text)),
                    ],
                  ),
                ),
              ),
            ],
            if (status != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(status!, textAlign: TextAlign.center),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
