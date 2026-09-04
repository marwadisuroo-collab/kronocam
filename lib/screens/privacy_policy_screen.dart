import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/theme_provider.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDarkMode ? const Color(0xFF0E0E10) : const Color(0xFFF3F4F6);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subColor = isDarkMode ? Colors.white60 : Colors.black54;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text('Privacy Policy', style: TextStyle(color: textColor)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'KronoCam — Privacy Policy',
            style: TextStyle(
              color: textColor,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Last updated: ${DateTime.now().year}',
            style: TextStyle(color: subColor, fontSize: 12),
          ),
          const SizedBox(height: 20),
          _section(
            textColor,
            subColor,
            'What KronoCam does',
            'KronoCam lets you capture photos with your device camera or '
                'select existing photos from your gallery, and add a '
                'customizable date, time, day and project-name stamp to '
                'them. Captured photos and stamped copies are processed and '
                'saved on your device when you choose to capture or save them.',
          ),
          _section(
            textColor,
            subColor,
            'Permissions we ask for',
            '• Camera — to let you take photos inside the app.\n'
                '• Photos / Storage — to let you pick existing photos and '
                'to save the photos you capture or stamp back to your '
                'gallery.\n\n'
                'KronoCam does not access your camera or photo library in '
                'the background, and does not read photos you have not '
                'chosen to open in the app.',
          ),
          _section(
            textColor,
            subColor,
            'Location information',
            'If you grant location permission, KronoCam reads your current '
                'GPS coordinates while the camera screen is open and may '
                'reverse-geocode them into an address for the stamp. Location '
                'data is used only for the photo metadata and is not uploaded '
                'to a KronoCam server. You can disable access at any time in '
                'your device settings.',
          ),
          _section(
            textColor,
            subColor,
            'Data we store on your device',
            'Your theme preference and app settings are stored locally on '
                'your device using standard app storage. KronoCam does '
                'not require an account and does not collect your name, '
                'email or contacts.',
          ),
          _section(
            textColor,
            subColor,
            'Advertising',
            'KronoCam shows a rewarded video ad, served through our '
              'advertising service providers, when you choose to unlock '
              'the stamp editor. Our advertising service providers may '
              'collect device and advertising identifiers to serve and '
              'measure ads, in line with their own privacy policies. You '
              'can reset or limit ad personalization from '
                'your device\'s system settings.',
          ),
          _section(
            textColor,
            subColor,
            'Photos you edit',
            'All photo editing (adding the date/time/day/project-name '
                'stamp) happens entirely on your device. KronoCam does '
                'not upload your photos to any server.',
          ),
                  _section(
                textColor,
                subColor,
                'Security and children',
                'KronoCam does not create user accounts or maintain a personal '
                    'online profile. The app is not intended to collect personal '
                    'information from children. Keep your device and operating '
                    'system updated to help protect locally stored photos.',
                  ),
                  _section(
                textColor,
                subColor,
                'Changes to this policy',
                'This policy may be updated when the app features, permissions or '
                    'advertising providers change. The latest version is shown '
                    'inside the app with its update year.',
                  ),
          _section(
            textColor,
            subColor,
            'Contact',
            'If you have questions about this privacy policy, please '
                'contact the developer through the app store listing '
                'page.',
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'App made by Shubham',
              style: TextStyle(
                color: subColor,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _section(Color textColor, Color subColor, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(color: subColor, fontSize: 13.5, height: 1.5),
          ),
        ],
      ),
    );
  }
}
