import 'package:ainme_vault/services/anilist_service.dart';
import 'package:ainme_vault/services/anilist_sync_service.dart';
import 'package:ainme_vault/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnimeEntryBottomSheet extends StatefulWidget {
  final Map<String, dynamic> anime;

  const AnimeEntryBottomSheet({super.key, required this.anime});

  @override
  State<AnimeEntryBottomSheet> createState() => _AnimeEntryBottomSheetState();
}

class _AnimeEntryBottomSheetState extends State<AnimeEntryBottomSheet> {
  String _status = "Planning"; // Default
  int _progress = 0;
  DateTime? _startDate;
  DateTime? _finishDate;
  int _totalEpisodes = 0;
  bool _hasChanges = false;
  late bool _isNewEntry;
  bool get _episodesUnknown => widget.anime['episodes'] == null;

  bool _episodesLoading = true;
  bool _animeDetailsLoaded = false;

  final List<String> _statuses = ["Watching", "Completed", "Planning"];

  // ScrollController for episode progress list
  late ScrollController _episodeScrollController;

  @override
  void initState() {
    super.initState();
    _isNewEntry = true;
    _episodeScrollController = ScrollController();
    _loadEpisodes();
    _checkForExistingEntry();
  }

  @override
  void dispose() {
    _episodeScrollController.dispose();
    super.dispose();
  }

  /// Scrolls the episode list to center the selected episode
  void _scrollToSelectedEpisode() {
    if (!_episodeScrollController.hasClients) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final targetOffset = _progress * 58.0 - (screenWidth / 2) + 29;
    final maxOffset = _episodeScrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxOffset);

    _episodeScrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _checkForExistingEntry() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final animeId = widget.anime['id'].toString();
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('anime')
          .doc(animeId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _isNewEntry = false;
          _status = data['status'] ?? "Planning";
          _progress = data['progress'] ?? 0;
          // Don't restore score - we only show anime's rating now

          if (data['startDate'] != null) {
            _startDate = (data['startDate'] as Timestamp).toDate();
          }
          if (data['finishDate'] != null) {
            _finishDate = (data['finishDate'] as Timestamp).toDate();
          }
        });

        // Scroll to current progress after loading
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToSelectedEpisode();
        });
      }
    } catch (e) {
      debugPrint("Error checking anime entry: $e");
    }
  }

  Future<void> _loadEpisodes() async {
    final episodes = widget.anime['episodes'];

    // Episodes already available AND metadata exists
    if (episodes != null &&
        episodes > 0 &&
        widget.anime['format'] != null &&
        widget.anime['seasonYear'] != null) {
      setState(() {
        _totalEpisodes = episodes;
        _episodesLoading = false;
        _animeDetailsLoaded = true;
      });

      // Scroll to selected episode after list is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedEpisode();
      });
      return;
    }

    try {
      final fullAnime = await AniListService.getAnimeDetails(
        widget.anime['id'],
      );
      if (!mounted || fullAnime == null) return;

      setState(() {
        _totalEpisodes = fullAnime['episodes'] ?? 0;

        // 🔥 Hydrate missing fields
        widget.anime['format'] = fullAnime['format'];
        widget.anime['seasonYear'] =
            fullAnime['seasonYear'] ?? fullAnime['startDate']?['year'];
        widget.anime['duration'] =
            fullAnime['duration']; // 🔥 Episode duration in minutes

        _episodesLoading = false;
        _animeDetailsLoaded = true;
      });

      // Scroll to selected episode after list is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedEpisode();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _totalEpisodes = 0;
        _episodesLoading = false;
        _animeDetailsLoaded = false;
      });

      debugPrint("Episode fetch failed: $e");
    }
  }

  Future<void> _saveEntry() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to save anime')),
      );
      return;
    }

    try {
      final animeId = widget.anime['id'].toString();
      final title =
          widget.anime['title']['english'] ??
          widget.anime['title']['romaji'] ??
          'Unknown';
      final coverImage = widget.anime['coverImage']['large'] ?? "";

      // 🔥 Fix: Ensure Completed entries have max progress
      // (Handles race condition where user clicked Completed before episodes loaded)
      if (_status == "Completed" && _totalEpisodes > 0) {
        _progress = _totalEpisodes;
      }

      // 🔥 Calculate episode duration (movies have full runtime, TV has per-episode)
      final format = widget.anime['format'];
      final int episodeDuration;
      if (format == 'MOVIE') {
        // Movies: use full runtime (e.g., 130 min for A Silent Voice)
        episodeDuration = widget.anime['duration'] ?? 90;
      } else {
        // TV/ONA/OVA: use per-episode duration (default 24 min)
        episodeDuration = widget.anime['duration'] ?? 24;
      }

      // 🔥 Calculate watchMinutes based on progress
      // This handles: direct progress changes, marking Completed, decreasing episodes
      final int watchMinutes = _progress * episodeDuration;

      final data = {
        'id': widget.anime['id'],
        'title': title,
        'coverImage': coverImage,
        'status': _status,
        'progress': _progress,
        'totalEpisodes': _totalEpisodes,
        'averageScore':
            widget.anime['averageScore'], // Store anime's actual rating
        'lastUpdated': FieldValue.serverTimestamp(),
        'format': format, // TV, MOVIE, ONA
        'seasonYear': widget.anime['seasonYear'], // 2019
        'episodeDuration':
            episodeDuration, // 🔥 For accurate watch time tracking
        'watchMinutes':
            watchMinutes, // 🔥 Track total watch time for this anime
      };

      if (_startDate != null) {
        data['startDate'] = Timestamp.fromDate(_startDate!);
      }
      if (_finishDate != null) {
        data['finishDate'] = Timestamp.fromDate(_finishDate!);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('anime')
          .doc(animeId)
          .set(data, SetOptions(merge: true));

      // 🔄 Two-way sync: Also update AniList if connected
      AniListSyncService.syncToAniList(
        mediaId: widget.anime['id'],
        status: _status,
        progress: _progress,
        startDate: _startDate,
        finishDate: _finishDate,
      );
    } catch (e) {
      if (mounted) {
        showErrorSnackbar(context, 'Error saving: $e');
      }
    }
  }

  void showErrorSnackbar(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int maxEps = _episodesUnknown
        ? 100
        : (_totalEpisodes > 0 ? _totalEpisodes : 100);
    final canSave =
        !_episodesLoading &&
        _animeDetailsLoaded &&
        (_isNewEntry || _hasChanges);

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
                  "Edit Entry",
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 18),
                ),
                TextButton(
                  onPressed: canSave
                      ? () async {
                          HapticFeedback.mediumImpact();
                          await _saveEntry();
                          if (context.mounted) Navigator.pop(context);
                        }
                      : null,
                  child: Text(
                    _episodesLoading || !_animeDetailsLoaded
                        ? "Loading…"
                        : "Save",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: canSave ? AppTheme.primary : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. Status
                  _buildSectionTitle("Status"),
                  const SizedBox(height: 12),
                  Row(
                    children: _statuses.map((status) {
                      final isSelected = _status == status;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              final previousStatus = _status;
                              setState(() {
                                _status = status;
                                _hasChanges = true;

                                // Planning: Reset everything
                                if (status == "Planning") {
                                  _progress = 0;
                                  _startDate = null;
                                  _finishDate = null;
                                }

                                // Watching: Set progress to 1 (if 0), set start date, clear finish date
                                if (status == "Watching") {
                                  // Coming from Completed: decrease by 1
                                  if (previousStatus == "Completed" &&
                                      _progress > 1) {
                                    _progress = _progress - 1;
                                  } else if (_progress == 0) {
                                    // Coming from Planning: set to 1
                                    _progress = 1;
                                  }
                                  if (_startDate == null) {
                                    _startDate = DateTime.now();
                                  }
                                  // Clear finish date when moving back from Completed
                                  if (previousStatus == "Completed") {
                                    _finishDate = null;
                                  }
                                }

                                // Completed: Set max progress and both dates
                                if (status == "Completed") {
                                  if (_totalEpisodes > 0) {
                                    _progress = _totalEpisodes;
                                  }
                                  if (_startDate == null) {
                                    _startDate = DateTime.now();
                                  }
                                  if (_finishDate == null) {
                                    _finishDate = DateTime.now();
                                  }
                                }
                              });

                              // Scroll to selected episode after status change
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _scrollToSelectedEpisode();
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primary
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.transparent),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppTheme.primary.withOpacity(
                                            0.3,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : [],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // 3. Progress (Sliding Horizontal)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle("Episode Progress"),
                      _episodesLoading
                          ? const Text(
                              "Loading...",
                              style: TextStyle(color: Colors.grey),
                            )
                          : Text(
                              "$_progress / $_totalEpisodes",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ],
                  ),
                  if (_episodesUnknown)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        "Episode count unknown",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 50,
                    child: _episodesLoading
                        ? const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: maxEps + 1,
                            controller: _episodeScrollController,
                            itemBuilder: (context, index) {
                              final isSelected = index == _progress;
                              return GestureDetector(
                                onTap: () {
                                  final previousProgress = _progress;
                                  setState(() {
                                    _progress = index;
                                    _hasChanges = true;

                                    // Auto-set start date when progress goes from 0 to 1+
                                    if (previousProgress == 0 &&
                                        index > 0 &&
                                        _startDate == null) {
                                      _startDate = DateTime.now();
                                    }

                                    if (_progress == _totalEpisodes &&
                                        _totalEpisodes > 0) {
                                      _status = "Completed";
                                      // Auto-set finish date when reaching last episode
                                      if (_finishDate == null) {
                                        _finishDate = DateTime.now();
                                      }
                                    } else if (_progress > 0) {
                                      _status = "Watching";
                                    }
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 50,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: isSelected
                                        ? Border.all(
                                            color: AppTheme.primary,
                                            width: 2,
                                          )
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    "$index",
                                    style: TextStyle(
                                      fontSize: isSelected ? 20 : 16,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? AppTheme.primary
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 20),

                  // 4. Anime Score (Read-only display from AniList)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle("Anime Rating"),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.amber.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "${((widget.anime['averageScore'] ?? 0) / 10).toStringAsFixed(1)}/10",
                              style: const TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "This is the official rating from AniList",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 5. Date Selectors
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateSelector(
                          "Start Date",
                          _startDate,
                          (date) => setState(() => _startDate = date),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDateSelector(
                          "Finish Date",
                          _finishDate,
                          (date) => setState(() => _finishDate = date),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // 6. Remove Button (only visible for existing entries)
                  if (!_isNewEntry)
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (_) => Dialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Warning Icon
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.redAccent,
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // Title
                                    const Text(
                                      "Remove anime?",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Message
                                    Text(
                                      "This will remove it from your list.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Buttons
                                    Row(
                                      children: [
                                        // Cancel Button
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 14,
                                                  ),
                                              side: BorderSide(
                                                color: Colors.grey.shade300,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(50),
                                              ),
                                            ),
                                            child: Text(
                                              "Cancel",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Remove Button
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.redAccent,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 14,
                                                  ),
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(50),
                                              ),
                                            ),
                                            child: const Text(
                                              "Remove",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
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

                          if (confirmed == true) {
                            // remove logic
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              try {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .collection('anime')
                                    .doc(widget.anime['id'].toString())
                                    .delete();

                                // 🔄 Two-way sync: Also delete from AniList if connected
                                final int animeId = widget.anime['id'] is int
                                    ? widget.anime['id']
                                    : int.tryParse(
                                            widget.anime['id'].toString(),
                                          ) ??
                                          0;
                                final anilistDeleted =
                                    await AniListSyncService.deleteFromAniList(
                                      mediaId: animeId,
                                    );

                                if (context.mounted) {
                                  Navigator.pop(context); // Close bottom sheet

                                  // Show feedback about AniList sync
                                  if (anilistDeleted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          'Removed from list and AniList',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        backgroundColor: Colors.green,
                                        behavior: SnackBarBehavior.floating,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  showErrorSnackbar(
                                    context,
                                    'Error removing anime',
                                  );
                                }
                              }
                            }
                          }
                        },

                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.red.withOpacity(0.05),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 22,
                        ),
                        label: const Text(
                          "Remove from list",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildDateSelector(
    String label,
    DateTime? date,
    Function(DateTime) onSelect,
  ) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: AppTheme.primary,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          if (label == "Finish Date") {
            setState(() {
              _finishDate = picked;
              _status = "Completed";
              _hasChanges = true;

              if (!_episodesUnknown && _totalEpisodes > 0) {
                _progress = _totalEpisodes;
              }
            });
          } else {
            setState(() {
              _startDate = picked;
              _hasChanges = true;
            });
          }
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: date != null ? AppTheme.primary : Colors.grey.shade600,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    date != null
                        ? DateFormat('MMM dd, yyyy').format(date)
                        : "Select Date",
                    style: TextStyle(
                      color: date != null
                          ? Colors.black87
                          : Colors.grey.shade500,
                      fontWeight: date != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
