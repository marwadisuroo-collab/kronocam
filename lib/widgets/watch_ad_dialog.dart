import 'package:flutter/material.dart';

import '../provider/theme_provider.dart';
import '../services/ad_service.dart';

/// Shows a confirmation dialog, then plays a rewarded ad, then calls
/// [onUnlocked] once the user has earned the reward.
Future<void> showWatchAdToUnlockDialog(
  BuildContext context, {
  required VoidCallback onUnlocked,
}) async {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
  final bg = isDarkMode ? const Color(0xFF1A1A1C) : Colors.white;
  final textColor = isDarkMode ? Colors.white : Colors.black87;

  await showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.ondemand_video, color: ThemeProvider.accent),
            const SizedBox(width: 10),
            Text('Unlock Stamp Editor', style: TextStyle(color: textColor)),
          ],
        ),
        content: Text(
          'Watch a short ad to modify the date, time, day and project name on this photo.',
          style: TextStyle(color: textColor.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeProvider.accent,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _showLoadingAndPlayAd(context, onUnlocked);
            },
            icon: const Icon(Icons.play_circle_fill),
            label: const Text('Watch Ad'),
          ),
        ],
      );
    },
  );
}

void _showLoadingAndPlayAd(BuildContext context, VoidCallback onUnlocked) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const Center(child: CircularProgressIndicator()),
  );

  AdService.instance.showAd(
    onReward: () {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      onUnlocked();
    },
    onFailure: () {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad unavailable. Please try again.')),
      );
    },
  );
}
