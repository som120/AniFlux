import 'package:ainme_vault/utils/transitions.dart';
import 'package:flutter/material.dart';
import 'package:ainme_vault/screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ainme_vault/widgets/avatar_picker_bottom_sheet.dart';
import 'package:ainme_vault/widgets/edit_profile_bottom_sheet.dart';
import 'package:ainme_vault/widgets/account_settings_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // import to access MainScreen

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pushReplacement(
            context,
            SlideRightRoute(page: const MainScreen()),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F3FF),
        body: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            // Loading state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Check if user is logged in
            final isLoggedIn = snapshot.hasData && snapshot.data != null;
            final user = snapshot.data;

            if (!isLoggedIn) {
              // Show login card for guests
              return _buildGuestView(context);
            }

            // Show full profile for logged-in users
            return _buildAuthenticatedView(context, user!);
          },
        ),
      ),
    );
  }

  // Guest view - Show login card
  Widget _buildGuestView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8A5CF6), Color(0xFFC78BFA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Welcome to AniVault!",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Login to track your anime, save your progress, and sync across devices.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8A5CF6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    "Login / Sign Up",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, String> formatWatchTime(double totalHours) {
    if (totalHours < 48) {
      return {"value": totalHours.toStringAsFixed(1), "label": "Hours"};
    } else {
      final days = totalHours / 24;
      return {"value": days.toStringAsFixed(2), "label": "Days"};
    }
  }

  // Authenticated view - Show full profile
  Widget _buildAuthenticatedView(BuildContext context, User user) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // ---------------------------
          // TOP CURVED GRADIENT CARD
          // ---------------------------
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                height: 150,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF8A5CF6), Color(0xFFC78BFA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
              ),

              // Avatar
              Positioned(
                bottom: -60,
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    String? selectedAvatar;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      selectedAvatar = data?['selectedAvatar'];
                    }

                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundImage: selectedAvatar != null
                            ? AssetImage(selectedAvatar) as ImageProvider
                            : (user.photoURL != null
                                  ? NetworkImage(user.photoURL!)
                                  : const AssetImage("assets/avatar.png")
                                        as ImageProvider),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 65), // Space for protruding avatar

          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              String displayName = user.displayName ?? "User Name";

              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                displayName = data?['username'] ?? displayName;
              }

              return Text(
                displayName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          // ---------------------------
          // STATS OVERVIEW
          // ---------------------------
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('anime')
                .snapshots(),
            builder: (context, snapshot) {
              int completedCount = 0;
              int totalAnimes = 0;
              double totalHours = 0;

              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                totalAnimes = snapshot.data!.docs.length;

                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] ?? '';

                  // Count completed anime
                  if (status == 'Completed') {
                    completedCount++;
                  }

                  // 🔥 Use watchMinutes directly (accurate for movies + TV)
                  final minutes = data['watchMinutes'] ?? 0;
                  totalHours += minutes / 60;
                }
              }
              final watchTime = formatWatchTime(totalHours);

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ), // Smaller card width
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(watchTime["value"]!, watchTime["label"]!),
                      _buildStatItem(completedCount.toString(), "Completed"),
                      _buildStatItem(totalAnimes.toString(), "Anime"),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 23),

          // ---------------------------
          // SETTINGS LIST
          // ---------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16), // Wider card
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
                children: [
                  _buildSettingsTile(
                    Icons.edit,
                    "Edit Profile",
                    context,
                    false,
                  ),
                  const SizedBox(height: 20),
                  _buildSettingsTile(
                    Icons.palette,
                    "Customize Avatar",
                    context,
                    false,
                  ),
                  const SizedBox(height: 20),
                  _buildSettingsTile(
                    Icons.dark_mode,
                    "Change Theme",
                    context,
                    false,
                  ),
                  const SizedBox(height: 20),
                  _buildSettingsTile(
                    Icons.settings,
                    "Account Settings",
                    context,
                    false,
                  ),
                  const SizedBox(height: 20),
                  _buildSettingsTile(
                    Icons.info_outline,
                    "About",
                    context,
                    false,
                  ),
                  const SizedBox(height: 20),
                  _buildSettingsTile(Icons.logout, "Logout", context, true),
                ],
              ),
            ),
          ),

          const SizedBox(height: 100), // Extra space for bottom navigation
        ],
      ),
    );
  }

  // ---------------------------
  // STAT ITEM WIDGET
  // ---------------------------
  Widget _buildStatItem(String value, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF8A5CF6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
      ],
    );
  }

  // ---------------------------
  // SETTINGS TILE WIDGET
  // ---------------------------
  // ---------------------------
  // SETTINGS TILE WIDGET
  // ---------------------------
  Widget _buildSettingsTile(
    IconData icon,
    String title,
    BuildContext context,
    bool isDestructive,
  ) {
    return _ScaleButton(
      onTap: () async {
        if (title == "Logout") {
          // Show confirmation dialog
          final shouldLogout = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Logout'),
              content: const Text('Are you sure you want to logout?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Logout'),
                ),
              ],
            ),
          );

          if (shouldLogout == true && context.mounted) {
            try {
              final auth = FirebaseAuth.instance;
              final googleSignIn = GoogleSignIn();

              // Clear image cache
              await CachedNetworkImage.evictFromCache('');

              // Clear search history
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('search_history');

              // Sign out from Google if signed in
              if (await googleSignIn.isSignedIn()) {
                await googleSignIn.signOut();
              }

              // Sign out from Firebase
              await auth.signOut();

              // Show success message
              // The StreamBuilder will automatically update to show guest view
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Logged out successfully'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error logging out: $e')),
                );
              }
            }
          }
        } else if (title == "Edit Profile") {
          // Show edit profile bottom sheet
          final result = await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const EditProfileBottomSheet(),
          );

          // Show success message if profile was updated
          if (result != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile updated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else if (title == "Customize Avatar") {
          // Show avatar picker bottom sheet
          final result = await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const AvatarPickerBottomSheet(),
          );

          // Show success message if avatar was updated
          if (result != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Avatar updated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else if (title == "Account Settings") {
          // Show account settings bottom sheet
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const AccountSettingsBottomSheet(),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("$title tapped")));
        }
      },
      child: Container(
        color: Colors.transparent, // Ensures hit test works
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDestructive
                    ? Colors.red.withOpacity(0.1)
                    : const Color(0xFF8A5CF6).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isDestructive ? Colors.red : const Color(0xFF8A5CF6),
                size: 25,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
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
}

class _ScaleButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _ScaleButton({required this.onTap, required this.child});

  @override
  State<_ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<_ScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}
