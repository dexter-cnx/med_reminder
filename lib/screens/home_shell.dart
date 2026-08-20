import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const HomeScreen(),
        Positioned(
          top: 0,
          right: 56,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                tooltip: 'settings_title'.tr(),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
                icon: const Icon(Icons.settings_outlined),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
