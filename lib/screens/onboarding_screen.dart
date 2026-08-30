import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.onRequestNotifications,
    required this.onComplete,
    required this.onLanguageSelected,
    this.onRequestExactAlarm,
    this.showMedicationPermissionSteps = true,
    this.showExactAlarmStep = false,
    super.key,
  });

  final Future<bool> Function() onRequestNotifications;
  final Future<bool> Function()? onRequestExactAlarm;
  final Future<void> Function() onComplete;
  final Future<void> Function(String languageCode) onLanguageSelected;
  final bool showMedicationPermissionSteps;
  final bool showExactAlarmStep;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _OnboardingStep { welcome, notifications, preciseReminders, ready }

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _stepIndex = 0;
  bool _busy = false;
  bool? _notificationsGranted;
  bool? _exactAlarmGranted;

  List<_OnboardingStep> get _steps => <_OnboardingStep>[
    _OnboardingStep.welcome,
    if (widget.showMedicationPermissionSteps) _OnboardingStep.notifications,
    if (widget.showMedicationPermissionSteps && widget.showExactAlarmStep)
      _OnboardingStep.preciseReminders
    else
      _OnboardingStep.ready,
  ];

  int get _effectiveStepIndex {
    final lastIndex = _steps.length - 1;
    return _stepIndex <= lastIndex ? _stepIndex : lastIndex;
  }

  _OnboardingStep get _currentStep => _steps[_effectiveStepIndex];

  Future<void> _toggleLanguage() async {
    if (_busy) return;
    final next = context.locale.languageCode == 'th' ? 'en' : 'th';
    setState(() => _busy = true);
    try {
      await widget.onLanguageSelected(next);
      if (!mounted) return;
      await context.setLocale(Locale(next));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestNotifications() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final granted = await widget.onRequestNotifications();
      if (!mounted) return;
      setState(() => _notificationsGranted = granted);
    } catch (_) {
      if (!mounted) return;
      setState(() => _notificationsGranted = false);
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _exactAlarmGranted = false);
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

  void _advance() {
    final currentIndex = _effectiveStepIndex;
    if (currentIndex >= _steps.length - 1) return;
    setState(() => _stepIndex = currentIndex + 1);
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    final effectiveStepIndex = _effectiveStepIndex;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _busy ? null : _toggleLanguage,
                  icon: const Icon(Icons.language),
                  label: Text(context.locale.languageCode.toUpperCase()),
                ),
              ),
              Expanded(child: _buildStep(context)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(
                  steps.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: index == effectiveStepIndex ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: index == effectiveStepIndex
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
              if (_currentStep == _OnboardingStep.notifications &&
                  _notificationsGranted != true)
                TextButton(
                  onPressed: _busy ? null : _advance,
                  child: Text('onboarding_not_now'.tr()),
                )
              else if (_currentStep == _OnboardingStep.preciseReminders &&
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

  String get _primaryLabel => switch (_currentStep) {
    _OnboardingStep.welcome => 'onboarding_continue',
    _OnboardingStep.notifications => _notificationsGranted == true
        ? 'onboarding_continue'
        : 'onboarding_enable_notifications',
    _OnboardingStep.preciseReminders => _exactAlarmGranted == true
        ? 'onboarding_get_started'
        : 'onboarding_enable_precise_reminders',
    _OnboardingStep.ready => 'onboarding_get_started',
  };

  Future<void> _primaryAction() async {
    switch (_currentStep) {
      case _OnboardingStep.welcome:
        _advance();
        return;
      case _OnboardingStep.notifications:
        if (_notificationsGranted == true) {
          _advance();
          return;
        }
        await _requestNotifications();
        if (mounted && _notificationsGranted == true) _advance();
        return;
      case _OnboardingStep.preciseReminders:
        if (_exactAlarmGranted == true) {
          await _finish();
          return;
        }
        await _requestExactAlarm();
        if (mounted && _exactAlarmGranted == true) await _finish();
        return;
      case _OnboardingStep.ready:
        await _finish();
        return;
    }
  }

  Widget _buildStep(BuildContext context) {
    switch (_currentStep) {
      case _OnboardingStep.welcome:
        return _OnboardingPanel(
          icon: Icons.favorite_outline,
          title: 'onboarding_welcome_title'.tr(),
          body: 'onboarding_welcome_body'.tr(),
          bullets: [
            'onboarding_feature_offline'.tr(),
            if (widget.showMedicationPermissionSteps)
              'onboarding_feature_reminders'.tr(),
            if (widget.showMedicationPermissionSteps)
              'onboarding_feature_stock'.tr(),
          ],
        );
      case _OnboardingStep.notifications:
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
      case _OnboardingStep.preciseReminders:
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
      case _OnboardingStep.ready:
        return _OnboardingPanel(
          icon: Icons.check_circle_outline,
          title: 'onboarding_ready_title'.tr(),
          body: 'onboarding_ready_body'.tr(),
        );
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
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
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
