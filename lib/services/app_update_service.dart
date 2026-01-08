import 'dart:io';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class AppUpdateService {
  static bool _dialogShown = false;

  static Future<void> checkForUpdate(BuildContext context) async {
    debugPrint("🚀 checkForUpdate() called");

    if (_dialogShown) return;

    final remoteConfig = FirebaseRemoteConfig.instance;

    // ✅ REQUIRED DEFAULTS (FIXES CRASH)
    await remoteConfig.setDefaults({
      'latest_version_android': '0.0.0',
      'latest_version_ios': '0.0.0',
      'force_update': false,
    });

    // ✅ Config settings
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero, // dev only

        // minimumFetchInterval: const Duration(hours: 6), //production use
      ),
    );

    await remoteConfig.fetchAndActivate();

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    final latestVersion = Platform.isAndroid
        ? remoteConfig.getString('latest_version_android')
        : remoteConfig.getString('latest_version_ios');

    final forceUpdate = remoteConfig.getBool('force_update');

    debugPrint("📦 Current version: $currentVersion");
    debugPrint("📦 Latest version (RC): $latestVersion");
    debugPrint("📦 Force update: $forceUpdate");

    // 🔐 Safety guards
    if (latestVersion.isEmpty || latestVersion == '0.0.0') return;

    if (_isUpdateAvailable(currentVersion, latestVersion)) {
      _dialogShown = true;
      _showUpdateDialog(
        context,
        forceUpdate,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
      );
    }
  }

  static bool _isUpdateAvailable(String current, String latest) {
    final c = current.split('.').map(int.parse).toList();
    final l = latest.split('.').map(int.parse).toList();

    for (int i = 0; i < l.length; i++) {
      if (i >= c.length) return true;
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return false;
  }

  static void _showUpdateDialog(
    BuildContext context,
    bool force, {
    required String currentVersion,
    required String latestVersion,
  }) {
    showCupertinoDialog(
      context: Navigator.of(context, rootNavigator: true).context,
      barrierDismissible: !force,
      builder: (_) => CupertinoAlertDialog(
        title: Column(
          children: [
            const SizedBox(height: 8),
            Image.asset('assets/Apple_logo_black.png', width: 56, height: 56),
            const SizedBox(height: 12),
            const Text(
              'Update Available',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              const Text(
                'A newer version of the app is available.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),

              // 🔥 Version display
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currentVersion,
                    style: const TextStyle(
                      color: CupertinoColors.systemGrey,
                      fontSize: 13,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      CupertinoIcons.arrow_right,
                      size: 14,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                  Text(
                    latestVersion,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          if (!force)
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
          CupertinoDialogAction(
            isDefaultAction: true,
            isDestructiveAction: force,
            onPressed: _launchStore,
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  static Future<void> _launchStore() async {
    final url = Platform.isAndroid
        ? Uri.parse(
            'https://play.google.com/store/apps/details?id=YOUR_PACKAGE_NAME',
          )
        : Uri.parse('https://apps.apple.com/app/idYOUR_APP_ID');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
