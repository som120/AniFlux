import 'package:ainme_vault/services/anilist_auth_service.dart';
import 'package:ainme_vault/services/anilist_sync_service.dart';
import 'package:ainme_vault/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bottom sheet for AniList integration - login, sync, and manage connection
class AniListIntegrationBottomSheet extends StatefulWidget {
  const AniListIntegrationBottomSheet({super.key});

  @override
  State<AniListIntegrationBottomSheet> createState() =>
      _AniListIntegrationBottomSheetState();
}

class _AniListIntegrationBottomSheetState
    extends State<AniListIntegrationBottomSheet> {
  bool _isLoading = true;
  bool _isAniListConnected = false;
  Map<String, String?> _anilistUser = {};

  // Sync state
  bool _isSyncing = false;
  String _syncStatus = '';
  int _syncProgress = 0;
  int _syncTotal = 0;
  String _syncCurrentTitle = '';
  String _selectedSyncMode = 'merge';

  @override
  void initState() {
    super.initState();
    _loadAniListStatus();
  }

  Future<void> _loadAniListStatus() async {
    setState(() => _isLoading = true);

    try {
      final isConnected = await AniListAuthService.isLoggedIn();

      if (isConnected) {
        final userInfo = await AniListAuthService.getStoredUserInfo();

        if (mounted) {
          setState(() {
            _isAniListConnected = true;
            _anilistUser = userInfo;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isAniListConnected = false;
            _anilistUser = {};
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading AniList status: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithAniList() async {
    // Check if Firebase user is logged in
    if (FirebaseAuth.instance.currentUser == null) {
      _showSnackbar(
        'Please login with Google first to sync your anime list',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _syncStatus = 'Connecting to AniList...';
    });

    try {
      final success = await AniListAuthService.login();

      if (success) {
        await _loadAniListStatus();
        _showSnackbar('Successfully connected to AniList! 🎉');
      } else {
        _showSnackbar('Failed to connect. Please try again.', isError: true);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackbar('Error: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _disconnectAniList() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Disconnect AniList?'),
        content: const Text(
          'This will unlink your AniList account. Your synced anime will remain in your library.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AniListAuthService.logout();
      await _loadAniListStatus();
      _showSnackbar('AniList disconnected');
    }
  }

  Future<void> _syncAnimeList() async {
    if (FirebaseAuth.instance.currentUser == null) {
      _showSnackbar('Please login with Google first', isError: true);
      return;
    }

    setState(() {
      _isSyncing = true;
      _syncProgress = 0;
      _syncTotal = 0;
      _syncCurrentTitle = '';
      _syncStatus = 'Starting import...';
    });

    try {
      final result = await AniListSyncService.importToFirebase(
        mode: _selectedSyncMode,
        onProgress: (current, total, title) {
          if (mounted) {
            setState(() {
              _syncProgress = current;
              _syncTotal = total;
              _syncCurrentTitle = title;
              _syncStatus = 'Importing $current of $total';
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncStatus = '';
        });

        _showSuccessDialog(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncStatus = '';
        });
        _showSnackbar('Import failed: $e', isError: true);
      }
    }
  }

  void _showSuccessDialog(ImportResult result) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green.shade600,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Import Complete! 🎉',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _statRow(
                Icons.add_circle_outline,
                'Added',
                result.added,
                Colors.green,
              ),
              if (result.updated > 0)
                _statRow(Icons.update, 'Updated', result.updated, Colors.blue),
              if (result.skipped > 0)
                _statRow(
                  Icons.skip_next,
                  'Skipped',
                  result.skipped,
                  Colors.orange,
                ),
              if (result.failed > 0)
                _statRow(
                  Icons.error_outline,
                  'Failed',
                  result.failed,
                  Colors.red,
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Awesome!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(IconData icon, String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF5F3FF),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
                        'AniList Integration',
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

              // Main Content
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
                  child: _isLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : _isSyncing
                      ? _buildSyncProgress()
                      : _isAniListConnected
                      ? _buildConnectedView()
                      : _buildLoginView(),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginView() {
    return Column(
      children: [
        // AniList Logo/Icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF02A9FF).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.sync_rounded,
            size: 40,
            color: Color(0xFF02A9FF),
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          'Connect Your AniList',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        Text(
          'Import your anime watchlist from AniList and keep everything in sync.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 24),

        // Features list
        _featureItem(Icons.cloud_download_rounded, 'Import your anime list'),
        _featureItem(Icons.history_rounded, 'Keep watch progress'),
        _featureItem(Icons.star_rounded, 'Preserve your ratings'),

        const SizedBox(height: 24),

        // Login Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loginWithAniList,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF02A9FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.login_rounded, size: 20),
                const SizedBox(width: 10),
                const Text(
                  'Login with AniList',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _featureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF02A9FF)),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedView() {
    final username = _anilistUser['username'] ?? 'Unknown';
    final avatar = _anilistUser['avatar'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User Info
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFF02A9FF).withOpacity(0.1),
              backgroundImage: avatar != null ? NetworkImage(avatar) : null,
              child: avatar == null
                  ? const Icon(Icons.person, color: Color(0xFF02A9FF))
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Connected',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AniList Account',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Sync Mode Selection
        _sectionLabel('Import Mode'),
        const SizedBox(height: 10),
        _syncModeOption(
          'merge',
          'Merge',
          'Add new entries, update existing',
          Icons.merge_type_rounded,
        ),
        const SizedBox(height: 8),
        _syncModeOption(
          'addNew',
          'Add New Only',
          'Skip entries already in your list',
          Icons.add_circle_outline_rounded,
        ),
        const SizedBox(height: 8),
        _syncModeOption(
          'replace',
          'Replace All',
          'Delete current list, import fresh',
          Icons.swap_horiz_rounded,
        ),

        const SizedBox(height: 20),

        // Sync Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _syncAnimeList,
            icon: const Icon(Icons.sync_rounded),
            label: const Text(
              'Import from AniList',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF02A9FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Disconnect Button
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _disconnectAniList,
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
            child: const Text('Disconnect AniList'),
          ),
        ),
      ],
    );
  }

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

  Widget _syncModeOption(
    String value,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = _selectedSyncMode == value;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedSyncMode = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF02A9FF).withOpacity(0.08)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF02A9FF) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? const Color(0xFF02A9FF)
                  : Colors.grey.shade500,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFF02A9FF)
                          : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF02A9FF),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncProgress() {
    final progress = _syncTotal > 0 ? _syncProgress / _syncTotal : 0.0;

    return Column(
      children: [
        const SizedBox(height: 20),

        // Animated sync icon
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(seconds: 2),
          builder: (context, value, child) {
            return Transform.rotate(
              angle: value * 6.28 * 2, // 2 full rotations
              child: child,
            );
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF02A9FF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sync_rounded,
              size: 40,
              color: Color(0xFF02A9FF),
            ),
          ),
        ),

        const SizedBox(height: 24),

        Text(
          _syncStatus,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 8),

        if (_syncCurrentTitle.isNotEmpty)
          Text(
            _syncCurrentTitle,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

        const SizedBox(height: 20),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF02A9FF)),
            minHeight: 8,
          ),
        ),

        const SizedBox(height: 12),

        if (_syncTotal > 0)
          Text(
            '$_syncProgress / $_syncTotal',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),

        const SizedBox(height: 20),
      ],
    );
  }
}
