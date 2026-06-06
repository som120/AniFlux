import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppUpdateService {
  static bool _dialogShown = false;
  static bool _maintenanceDialogShown = false;
  static BuildContext? _maintenanceDialogContext;
  static bool _updateDialogShown = false;
  static BuildContext? _updateDialogContext;
  static String? _lastShownLatestVersion;
  static String? _lastShownLatestBuild;
  static bool? _lastShownForceUpdate;
  static StreamSubscription<DocumentSnapshot>? _configSubscription;

  static Future<void> checkForUpdate(BuildContext context) async {
    debugPrint("🚀 checkForUpdate() called");

    // Cancel old subscription if any
    await _configSubscription?.cancel();
    _configSubscription = null;

    _configSubscription = FirebaseFirestore.instance
        .collection('AppSettings')
        .doc('config')
        .snapshots()
        .listen((docSnapshot) async {
      debugPrint("📦 AppSettings config snapshot received");

      if (!docSnapshot.exists) {
        debugPrint("⚠️ AppSettings/config document not found");
        return;
      }

      final data = docSnapshot.data();
      if (data == null) return;
      debugPrint("📦 AppSettings config data: $data");

      // 1. Check Maintenance Mode
      final bool maintenanceMode = data['maintenanceMode'] ?? false;
      if (maintenanceMode) {
        // First dismiss the update dialog if it is showing
        if (_updateDialogShown && _updateDialogContext != null) {
          if (_updateDialogContext!.mounted) {
            Navigator.of(_updateDialogContext!).pop();
          }
          _updateDialogShown = false;
          _dialogShown = false;
          _updateDialogContext = null;
        }

        if (_maintenanceDialogShown) return;

        final String title = data['maintenanceTitle'] ?? "Maintenance in Progress";
        String message = data['maintenanceMessage'] ?? "We're performing maintenance to improve the app. Please check back later.";
        
        final Timestamp? estTime = data['maintenanceEstTime'] as Timestamp?;
        String formattedEstTime = "";
        if (estTime != null) {
          final dateTime = estTime.toDate().toLocal();
          formattedEstTime = DateFormat('dd MMMM yyyy, hh:mm a').format(dateTime); // e.g. "06 June 2026, 05:30 PM"
        }
        
        message = message.replaceAll('{maintenanceEstTime}', formattedEstTime);

        if (!context.mounted) return;
        _dialogShown = true;
        _maintenanceDialogShown = true;
        _showMaintenanceDialog(context, title: title, message: message);
        return; // Stop further checks if in maintenance mode
      } else {
        // If maintenance mode was active but is now disabled, auto-dismiss the dialog
        if (_maintenanceDialogShown && _maintenanceDialogContext != null) {
          if (_maintenanceDialogContext!.mounted) {
            Navigator.of(_maintenanceDialogContext!).pop();
          }
          _maintenanceDialogShown = false;
          _dialogShown = false;
          _maintenanceDialogContext = null;
        }

        // 2. Check for App Updates
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;
        final currentBuild = packageInfo.buildNumber;

        final latestVersion = data['latestVersion'] ?? '0.0.0';
        final latestBuild = (data['latestBuild'] ?? 0).toString();
        final forceUpdate = data['forceUpdate'] ?? false;
        final updateTitle = data['updateTitle'] ?? 'Update Available';
        final updateMessage = data['updateMessage'] ?? 'A newer version of the app is available.';

        debugPrint("📦 Current version: $currentVersion (Build $currentBuild)");
        debugPrint("📦 Latest version (Firestore): $latestVersion (Build $latestBuild)");
        debugPrint("📦 Force update: $forceUpdate");

        if (latestVersion == '0.0.0') return;

        if (_isUpdateAvailable(currentVersion, latestVersion, currentBuild: currentBuild, latestBuild: latestBuild)) {
          // If the update dialog is already showing but update parameters changed, refresh it
          if (_updateDialogShown) {
            if (latestVersion != _lastShownLatestVersion || 
                latestBuild != _lastShownLatestBuild || 
                forceUpdate != _lastShownForceUpdate) {
              
              if (_updateDialogContext != null && _updateDialogContext!.mounted) {
                Navigator.of(_updateDialogContext!).pop();
              }
              _updateDialogShown = false;
              _dialogShown = false;
              _updateDialogContext = null;
            } else {
              // Dialog is showing and update parameters are identical, no need to refresh
              return;
            }
          }

          if (_dialogShown) return; // Don't show update if another dialog is already showing
          if (!context.mounted) return;
          _dialogShown = true;
          _updateDialogShown = true;
          _lastShownLatestVersion = latestVersion;
          _lastShownLatestBuild = latestBuild;
          _lastShownForceUpdate = forceUpdate;

          _showUpdateDialog(
            context,
            forceUpdate,
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            currentBuild: currentBuild,
            latestBuild: latestBuild,
            title: updateTitle,
            message: updateMessage,
          );
        }
      }
    }, onError: (e) {
      debugPrint("❌ Error in AppUpdateService config listener: $e");
    });
  }

  static bool _isUpdateAvailable(
    String current,
    String latest, {
    required String currentBuild,
    required String latestBuild,
  }) {
    final c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final l = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < l.length; i++) {
      if (i >= c.length) return true;
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }

    if (l.length < c.length) return false;

    final curBuildNum = int.tryParse(currentBuild) ?? 0;
    final latBuildNum = int.tryParse(latestBuild) ?? 0;
    return latBuildNum > curBuildNum;
  }

  static void _showMaintenanceDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showCupertinoDialog(
      context: Navigator.of(context, rootNavigator: true).context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _maintenanceDialogContext = dialogContext;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: PopScope(
            canPop: false, // 🚫 block back button
            child: CupertinoAlertDialog(
              title: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemOrange.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        CupertinoIcons.wrench_fill,
                        color: CupertinoColors.systemOrange,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              content: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _maintenanceDialogShown = false;
      _dialogShown = false;
      _maintenanceDialogContext = null;
    });
  }

  static void _showUpdateDialog(
    BuildContext context,
    bool force, {
    required String currentVersion,
    required String latestVersion,
    required String currentBuild,
    required String latestBuild,
    required String title,
    required String message,
  }) {
    showCupertinoDialog(
      context: Navigator.of(context, rootNavigator: true).context,
      barrierDismissible: !force,
      builder: (dialogContext) {
        _updateDialogContext = dialogContext;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: PopScope(
            canPop: !force, // 🚫 block back button if forced
            child: CupertinoAlertDialog(
              title: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/icon/aniflux_logo.png',
                        width: 56,
                        height: 56,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              content: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "$currentVersion ($currentBuild)",
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
                          "$latestVersion ($latestBuild)",
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
                    onPressed: () => Navigator.pop(dialogContext),
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
          ),
        );
      },
    ).then((_) {
      _updateDialogShown = false;
      _dialogShown = false;
      _updateDialogContext = null;
      _lastShownLatestVersion = null;
      _lastShownLatestBuild = null;
      _lastShownForceUpdate = null;
    });
  }

  static Future<void> _launchStore() async {
    final url = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.aniflux.app',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
