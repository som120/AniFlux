import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ainme_vault/theme/app_theme.dart';

class AvatarPickerBottomSheet extends StatefulWidget {
  const AvatarPickerBottomSheet({super.key});

  @override
  State<AvatarPickerBottomSheet> createState() =>
      _AvatarPickerBottomSheetState();
}

class _AvatarPickerBottomSheetState extends State<AvatarPickerBottomSheet> {
  final List<String> avatars = [
    'assets/avatars/avatar1.jpg',
    'assets/avatars/avatar2.jpg',
    'assets/avatars/avatar3.jpg',
    'assets/avatars/avatar4.jpg',
    'assets/avatars/avatar5.jpg',
    'assets/avatars/avatar6.jpg',
    'assets/avatars/avatar7.jpg',
  ];

  String? selectedAvatar;
  String? currentAvatar;
  bool isLoading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentAvatar();
  }

  Future<void> _loadCurrentAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (mounted && doc.exists) {
        final data = doc.data();
        setState(() {
          currentAvatar = data?['selectedAvatar'];
          selectedAvatar = currentAvatar;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading avatar: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _saveAvatar() async {
    if (selectedAvatar == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to save avatar')),
        );
      }
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'selectedAvatar': selectedAvatar,
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context, selectedAvatar);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving avatar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  color: Colors.grey,
                ),
                Text(
                  "Choose Avatar",
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 18),
                ),
                TextButton(
                  onPressed: _hasChanges
                      ? () async {
                          HapticFeedback.lightImpact();
                          await _saveAvatar();
                        }
                      : null,
                  child: Text(
                    "Save",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _hasChanges ? AppTheme.primary : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),

                        // Title
                        Text(
                          "Select Your Avatar",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Avatar Grid
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                          itemCount: avatars.length,
                          itemBuilder: (context, index) {
                            final avatarPath = avatars[index];
                            final isSelected = selectedAvatar == avatarPath;

                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  selectedAvatar = avatarPath;
                                  _hasChanges = currentAvatar != selectedAvatar;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.primary
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isSelected
                                          ? AppTheme.primary.withOpacity(0.3)
                                          : Colors.black.withOpacity(0.1),
                                      blurRadius: isSelected ? 12 : 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    ClipOval(
                                      child: Image.asset(
                                        avatarPath,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        bottom: 2,
                                        right: 2,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
