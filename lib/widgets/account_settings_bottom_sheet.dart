import 'package:ainme_vault/main.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ainme_vault/theme/app_theme.dart';
import 'package:ainme_vault/services/anilist_service.dart';
import 'package:ainme_vault/services/anilist_auth_service.dart';
import 'package:ainme_vault/widgets/anilist_integration_bottom_sheet.dart';

class AccountSettingsBottomSheet extends StatefulWidget {
  const AccountSettingsBottomSheet({super.key});

  @override
  State<AccountSettingsBottomSheet> createState() =>
      _AccountSettingsBottomSheetState();
}

class _AccountSettingsBottomSheetState
    extends State<AccountSettingsBottomSheet> {
  bool _showAdultContent = false;
  bool _isAniListConnected = false;
  String? _aniListUsername;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final isConnected = await AniListAuthService.isLoggedIn();
    final userInfo = await AniListAuthService.getStoredUserInfo();

    if (mounted) {
      setState(() {
        _showAdultContent = prefs.getBool('show_adult_content') ?? false;
        _isAniListConnected = isConnected;
        _aniListUsername = userInfo['username'];
      });
    }
  }

  Future<void> _toggleAdultContent(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_adult_content', value);

    // Invalidate the cache in AniListService so it picks up the new value
    AniListService.invalidateAdultContentCache();

    if (mounted) {
      setState(() {
        _showAdultContent = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            const SizedBox(height: 12),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: Colors.black54,
                  ),
                  const Expanded(
                    child: Text(
                      "Account Settings",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Main Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel("Current Email"),
                    const SizedBox(height: 10),
                    _infoTile(
                      icon: Icons.email_outlined,
                      value: user?.email ?? "No email",
                    ),

                    const SizedBox(height: 24),

                    _sectionLabel("Integrations"),
                    const SizedBox(height: 10),
                    _actionTile(
                      icon: Icons.link,
                      title: _isAniListConnected
                          ? "Connected as $_aniListUsername"
                          : "Login with AniList",
                      subtitle: _isAniListConnected
                          ? "Tap to manage or sync"
                          : "Sync your anime list",
                      iconColor: _isAniListConnected
                          ? Colors.green
                          : const Color(0xFF02A9FF),
                      onTap: () {
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const AniListIntegrationBottomSheet(),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    _sectionLabel("Content Settings"),
                    const SizedBox(height: 10),
                    _switchTile(
                      icon: Icons.explicit,
                      title: "Adult Content",
                      subtitle: "Enable 18+ content in search results",
                      value: _showAdultContent,
                      onChanged: _toggleAdultContent,
                    ),

                    const SizedBox(height: 28),

                    _sectionLabel("Danger Zone"),
                    const SizedBox(height: 10),
                    _dangerTile(context),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ------------------ Helpers ------------------

  Widget _sectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.black54,
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _infoTile({required IconData icon, required String value}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _iconCircle(icon, AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _iconCircle(icon, iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.black26,
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _iconCircle(icon, const Color(0xFFEF4444)), // Using Red for explicit
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const Color(0xFFEF4444);
              }
              return AppTheme.primary;
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const Color(0xFFEF4444).withOpacity(0.4);
              }
              return AppTheme.primary.withOpacity(0.35);
            }),
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _dangerTile(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showDeleteConfirmation(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            _iconCircle(Icons.delete_forever, Colors.red),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                "Delete Account",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red.shade300),
          ],
        ),
      ),
    );
  }

  Widget _iconCircle(IconData icon, Color color) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  // Delete dialog
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever,
                  color: Colors.red,
                  size: 32,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                "Delete Account",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),

              const SizedBox(height: 10),

              const Text(
                "This action cannot be undone.\nAll your data will be permanently lost.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.black38, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final user = FirebaseAuth.instance.currentUser;

                        // ✅ Capture a SAFE context BEFORE popping
                        final rootContext = Navigator.of(
                          context,
                          rootNavigator: true,
                        ).context;

                        Navigator.pop(context); // close dialog

                        if (user != null) {
                          await _deleteAccountWithUser(rootContext, user);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "Delete",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAccountWithUser(BuildContext context, User user) async {
    final uid = user.uid;

    try {
      debugPrint("🔥 Attempting account deletion");

      // ✅ 1. Delete Firestore data FIRST
      await _deleteUserFirestoreDataByUid(uid);

      // ✅ 2. Delete auth user
      await user.delete();

      debugPrint("🔥 USER DELETED SUCCESSFULLY");

      // ✅ 3. Clear local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // ✅ 4. Google sign out
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }

      // ✅ 5. Firebase sign out
      await FirebaseAuth.instance.signOut();

      if (!context.mounted) return;

      // ✅ Close bottom sheet
      Navigator.of(context, rootNavigator: true).pop();

      // ✅ Go to Home/Profile (auth-aware)
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        debugPrint("🔐 Re-auth required");

        if (!context.mounted) return;

        await _reauthenticateUser(context);

        debugPrint("🔁 Retrying deletion");

        // ✅ Firestore FIRST again
        await _deleteUserFirestoreDataByUid(uid);

        // ✅ Then auth delete
        await user.delete();

        await FirebaseAuth.instance.signOut();

        if (!context.mounted) return;

        Navigator.of(context, rootNavigator: true).pop();
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (_) => false,
        );
      } else {
        _showDeleteError(context, e.message);
      }
    } catch (e) {
      debugPrint("❌ Delete failed: $e");
      _showDeleteError(context, e.toString());
    }
  }

  Future<void> _deleteUserFirestoreDataByUid(String uid) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(uid);

    final batch = firestore.batch();

    // Delete anime subcollection
    final animeSnapshot = await userRef.collection('anime').get();
    for (final doc in animeSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete episode notifications
    final notifSnapshot = await userRef
        .collection('episode_notifications')
        .get();
    for (final doc in notifSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete user document itself
    batch.delete(userRef);

    await batch.commit();
  }

  void _showDeleteError(BuildContext context, String? message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? "Account deletion failed"),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _reauthenticateUser(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final providerId = user.providerData.first.providerId;

    try {
      // 🔐 Google Sign-In re-auth
      if (providerId == 'google.com') {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) throw Exception("Google sign-in cancelled");

        final googleAuth = await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        await user.reauthenticateWithCredential(credential);
      }
      // 🔐 Email & Password re-auth
      else if (providerId == 'password') {
        final password = await _askForPassword(context);
        if (password == null) throw Exception("Password required");

        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );

        await user.reauthenticateWithCredential(credential);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Re-authentication failed"),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  Future<String?> _askForPassword(BuildContext context) async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: Navigator.of(context, rootNavigator: true).context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Confirm Password"),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(hintText: "Enter your password"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }
}
