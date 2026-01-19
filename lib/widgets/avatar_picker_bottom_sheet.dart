import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ainme_vault/theme/app_theme.dart';

class AnimeCategory {
  final String title;
  final List<AvatarItem> avatars;

  const AnimeCategory({required this.title, required this.avatars});
}

class AvatarItem {
  final String path;
  final bool isAvailable;

  const AvatarItem({required this.path, this.isAvailable = true});
}

class AvatarPickerBottomSheet extends StatefulWidget {
  const AvatarPickerBottomSheet({super.key});

  @override
  State<AvatarPickerBottomSheet> createState() =>
      _AvatarPickerBottomSheetState();
}

class _AvatarPickerBottomSheetState extends State<AvatarPickerBottomSheet> {
  // Categorized avatars by anime
  final List<AnimeCategory> animeCategories = [
    AnimeCategory(
      title: "Frieren: Beyond Journey's End",
      avatars: [
        AvatarItem(path: 'assets/avatars/avatar1.jpg'),
        AvatarItem(path: 'assets/avatars/avatar2.jpg'),
        AvatarItem(path: 'assets/avatars/avatar3.jpg', isAvailable: false),
        AvatarItem(path: 'assets/avatars/avatar4.jpg', isAvailable: false),
        AvatarItem(path: 'assets/avatars/avatar5.jpg', isAvailable: false),
      ],
    ),
    AnimeCategory(
      title: "Jujutsu Kaisen",
      avatars: [
        AvatarItem(path: 'assets/avatars/avatar6.jpg'),
        AvatarItem(path: 'assets/avatars/avatar7.jpg'),
        AvatarItem(path: 'assets/avatars/avatar1.jpg', isAvailable: false),
        AvatarItem(path: 'assets/avatars/avatar2.jpg', isAvailable: false),
        AvatarItem(path: 'assets/avatars/avatar3.jpg', isAvailable: false),
        AvatarItem(path: 'assets/avatars/avatar4.jpg', isAvailable: false),
      ],
    ),
    AnimeCategory(
      title: "Attack on Titan",
      avatars: [
        AvatarItem(path: 'assets/avatars/avatar4.jpg', isAvailable: false),
        AvatarItem(path: 'assets/avatars/avatar5.jpg', isAvailable: false),
        AvatarItem(path: 'assets/avatars/avatar6.jpg', isAvailable: false),
        AvatarItem(path: 'assets/avatars/avatar7.jpg', isAvailable: false),
        AvatarItem(path: 'assets/avatars/avatar1.jpg', isAvailable: false),
      ],
    ),
    AnimeCategory(
      title: "Demon Slayer",
      avatars: [
        AvatarItem(path: 'assets/avatars/avatar5.jpg', isAvailable: false),
        AvatarItem(path: 'assets/avatars/avatar6.jpg', isAvailable: false),
        AvatarItem(path: 'assets/avatars/avatar7.jpg', isAvailable: false),
        AvatarItem(path: 'assets/avatars/avatar1.jpg', isAvailable: false),
        AvatarItem(path: 'assets/avatars/avatar2.jpg', isAvailable: false),
        AvatarItem(path: 'assets/avatars/avatar3.jpg', isAvailable: false),
      ],
    ),
    AnimeCategory(
      title: "Spy x Family",
      avatars: [
        AvatarItem(path: 'assets/avatars/avatar3.jpg', isAvailable: false),
        AvatarItem(path: 'assets/avatars/avatar4.jpg', isAvailable: false),
        AvatarItem(path: 'assets/avatars/avatar5.jpg', isAvailable: false),
        AvatarItem(path: 'assets/avatars/avatar6.jpg', isAvailable: false),
        AvatarItem(path: 'assets/avatars/avatar7.jpg', isAvailable: false),
      ],
    ),
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
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

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
                Column(
                  children: [
                    Text(
                      "Choose Avatar",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Select from your favorite anime",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
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
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: animeCategories.length,
                    itemBuilder: (context, index) {
                      final category = animeCategories[index];
                      return _buildAnimeCategory(category);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimeCategory(AnimeCategory category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Anime Title
          Text(
            category.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 16),

          // Avatar Row (Horizontal scroll)
          SizedBox(
            height: 84,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: category.avatars.length,
              itemBuilder: (context, index) {
                final avatar = category.avatars[index];
                return Padding(
                  padding: EdgeInsets.only(
                    right: index < category.avatars.length - 1 ? 12 : 0,
                  ),
                  child: _buildAvatarItem(avatar),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarItem(AvatarItem avatar) {
    final isSelected = selectedAvatar == avatar.path && avatar.isAvailable;
    final isAvailable = avatar.isAvailable;

    return GestureDetector(
      onTap: isAvailable
          ? () {
              HapticFeedback.lightImpact();
              setState(() {
                selectedAvatar = avatar.path;
                _hasChanges = currentAvatar != selectedAvatar;
              });
            }
          : () {
              HapticFeedback.lightImpact();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppTheme.primary.withOpacity(0.3)
                  : Colors.black.withOpacity(0.08),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Avatar image
            ClipOval(
              child: ColorFiltered(
                colorFilter: isAvailable
                    ? const ColorFilter.mode(
                        Colors.transparent,
                        BlendMode.multiply,
                      )
                    : ColorFilter.mode(
                        Colors.grey.shade400,
                        BlendMode.saturation,
                      ),
                child: Image.asset(
                  avatar.path,
                  fit: BoxFit.cover,
                  width: 80,
                  height: 80,
                ),
              ),
            ),

            // Lock overlay for unavailable
            if (!isAvailable)
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.4),
                ),
                child: const Center(
                  child: Icon(
                    Icons.lock_outline,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),

            // Checkmark for selected
            if (isSelected)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
