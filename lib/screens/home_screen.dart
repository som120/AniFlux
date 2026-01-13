import 'dart:async';
import 'dart:math';
import 'package:ainme_vault/screens/anime_detail_screen.dart';
import 'package:ainme_vault/services/anilist_service.dart';
import 'package:ainme_vault/services/notification_service.dart';
import 'package:ainme_vault/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ainme_vault/services/app_update_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ---------------- STATE VARIABLES ----------------
  final PageController _pageController = PageController();
  List<dynamic> _airingAnimeList = [];
  bool _isLoading = true;
  bool _isDark(Color c) => c.computeLuminance() < 0.5;
  String _selectedStatus = 'Completed';
  bool _isGridView = false; // Track view mode

  // Sort options
  String _sortBy = 'lastUpdated'; // title, progress, lastUpdated, score
  bool _sortAscending = false; // false = descending (default)

  Timer? _timer;

  // Carousel error retry
  Timer? _carouselRetryTimer;
  late final ValueNotifier<int> _carouselRetryCountdown;

  // Auth state listener for immediate UI updates on login/logout
  StreamSubscription<User?>? _authSubscription;
  User? _currentUser;
  static const double _cardHorizontalMargin = 16.0;
  static const int _visibleDotCount = 5; // Number of dots to display

  late final ValueNotifier<Color> _bgColorNotifier;
  late final ValueNotifier<int> _pageIndexNotifier;

  Color _processCoverColor(Color color) {
    final hsl = HSLColor.fromColor(color);

    // Clamp saturation (avoid neon colors)
    final double saturation = hsl.saturation.clamp(0.25, 0.55);

    // Clamp lightness (avoid too dark / too bright)
    final double lightness = hsl.lightness.clamp(0.55, 0.75);

    final softened = hsl
        .withSaturation(saturation)
        .withLightness(lightness)
        .toColor();

    // Blend slightly with white for UI softness
    return Color.lerp(softened, Colors.white, 0.15)!;
  }

  Color _getProcessedColor(int index) {
    if (index < 0 || index >= _airingAnimeList.length) {
      return Colors.white;
    }

    final hex = _airingAnimeList[index]['coverImage']?['color'];
    if (hex == null) return AppTheme.accent;

    return _processCoverColor(_hexToColor(hex));
  }

  // ---------------- LIFECYCLE ----------------
  @override
  void initState() {
    super.initState();
    _bgColorNotifier = ValueNotifier(Colors.white);
    _pageIndexNotifier = ValueNotifier(0);
    _carouselRetryCountdown = ValueNotifier(0);

    // Initialize current user and listen for auth state changes
    _currentUser = FirebaseAuth.instance.currentUser;
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    });

    _fetchAiringAnime();
    NotificationService.init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService.checkForUpdate(context);
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _timer?.cancel();
    _carouselRetryTimer?.cancel();
    _bgColorNotifier.dispose();
    _pageIndexNotifier.dispose();
    _carouselRetryCountdown.dispose();
    _pageController.dispose();
    super.dispose();
  }

  List<T> pickWeightedRandom<T>(
    List<T> list,
    int count, {
    int weightTop = 3, // higher = more bias toward top
  }) {
    final weighted = <T>[];

    for (int i = 0; i < list.length; i++) {
      final weight =
          (i < 10) // top 10 get higher weight
          ? weightTop
          : 1;

      for (int w = 0; w < weight; w++) {
        weighted.add(list[i]);
      }
    }

    weighted.shuffle(Random(DateTime.now().millisecondsSinceEpoch));
    return weighted.take(count).toList();
  }

  // ---------------- DATA FETCHING ----------------
  Future<void> _fetchAiringAnime({bool retry = true}) async {
    try {
      // Fetch from all three sources in parallel
      final results = await Future.wait([
        AniListService.getAiringAnime(),
        AniListService.getPopularAnime(),
        AniListService.getUpcomingAnime(),
      ]);

      if (!mounted) return;

      final airingData = results[0];
      final popularData = results[1];
      final upcomingData = results[2];

      setState(() {
        // ✅ USE WEIGHTED RANDOM HERE
        final combinedList = [
          ...pickWeightedRandom(airingData, 4),
          ...pickWeightedRandom(popularData, 3),
          ...pickWeightedRandom(upcomingData, 3),
        ];

        // Remove duplicates based on anime ID
        final Set<int> seenIds = {};
        final List<dynamic> uniqueList = [];

        for (final anime in combinedList) {
          final id = anime['id'] as int?;
          if (id != null && seenIds.add(id)) {
            uniqueList.add(anime);
          }
        }

        // Optional: shuffle final list for display randomness
        uniqueList.shuffle();

        _airingAnimeList = uniqueList;
        _isLoading = false;

        // Cancel retry timer on success
        _carouselRetryTimer?.cancel();
        _carouselRetryTimer = null;
        _carouselRetryCountdown.value = 0;

        if (_airingAnimeList.isNotEmpty) {
          _bgColorNotifier.value = _getProcessedColor(0);
          _pageIndexNotifier.value = 0;
          _startAutoScroll();
        }
      });
    } catch (e) {
      if (!mounted) return;

      // 🔁 retry once after short delay
      if (retry) {
        await Future.delayed(const Duration(seconds: 1));
        return _fetchAiringAnime(retry: false);
      }

      setState(() {
        _isLoading = false;
        _airingAnimeList = [];
      });

      debugPrint("Error fetching anime for carousel: $e");
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) {
      hex = "FF$hex";
    }
    return Color(int.parse(hex, radix: 16));
  }

  void _startAutoScroll() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_pageController.hasClients || _airingAnimeList.isEmpty) return;

      final current = _pageIndexNotifier.value;
      final next = (current + 1) % _airingAnimeList.length;

      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    });
  }

  // ---------------- UI BUILD ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // We extend body behind app bar if we want the color to go all the way up,
      // but standard approach is fine too.
      body: Stack(
        children: [
          // 1. Dynamic Background Layer
          // This fills the top part or whole screen based on design.
          // User said "behind the banner make the purple color white and make it dynamic"
          // We'll make a large curved background or simpler block.
          Positioned.fill(
            child: Column(
              children: [
                ValueListenableBuilder<Color>(
                  valueListenable: _bgColorNotifier,
                  builder: (_, color, __) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      height: 360,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            color,
                            Color.lerp(color, Colors.white, 0.35)!,
                            Colors.white,
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                      ),
                    );
                  },
                ),
                Expanded(child: Container(color: Colors.white)),
              ],
            ),
          ),

          // 2. Content Layer
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 100), // nav bar height
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight, // 🔥 KEY FIX
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        // Greeting
                        ValueListenableBuilder<Color>(
                          valueListenable: _bgColorNotifier,
                          builder: (_, bgColor, __) {
                            final textColor = _isDark(bgColor)
                                ? Colors.white
                                : Colors.black87;

                            return RepaintBoundary(
                              child: GreetingSection(textColor: textColor),
                            );
                          },
                        ),

                        const SizedBox(height: 30),

                        // Carousel
                        if (_isLoading)
                          _buildLoadingShimmer()
                        else if (_airingAnimeList.isEmpty)
                          _buildCarouselError()
                        else
                          Column(
                            children: [
                              SizedBox(
                                height: 220,
                                child: NotificationListener<ScrollNotification>(
                                  onNotification: (notification) {
                                    if (notification
                                        is ScrollStartNotification) {
                                      _timer?.cancel();
                                    } else if (notification
                                        is ScrollEndNotification) {
                                      _startAutoScroll();
                                    }
                                    return false; // allow notification to bubble
                                  },
                                  child: PageView.builder(
                                    controller: _pageController,
                                    itemCount: _airingAnimeList.length,
                                    onPageChanged: (index) {
                                      _pageIndexNotifier.value = index;
                                      _bgColorNotifier.value =
                                          _getProcessedColor(index);
                                    },
                                    itemBuilder: (context, index) {
                                      final anime = _airingAnimeList[index];
                                      return _buildAnimeCard(anime);
                                    },
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),
                              // Indicators - Fixed at 5 dots regardless of anime count
                              ValueListenableBuilder<int>(
                                valueListenable: _pageIndexNotifier,
                                builder: (_, current, __) {
                                  // Map current page to dot index (modular)
                                  final activeDotIndex =
                                      current % _visibleDotCount;
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(_visibleDotCount, (
                                      index,
                                    ) {
                                      return AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        height: 8,
                                        width: activeDotIndex == index ? 24 : 8,
                                        decoration: BoxDecoration(
                                          color: activeDotIndex == index
                                              ? AppTheme.primary
                                              : AppTheme.accent.withOpacity(
                                                  0.5,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      );
                                    }),
                                  );
                                },
                              ),
                            ],
                          ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "My List",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              // Only show controls when logged in
                              if (_currentUser != null)
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        _isGridView
                                            ? Icons.view_list_rounded
                                            : Icons.grid_view_rounded,
                                      ),
                                      style: IconButton.styleFrom(
                                        foregroundColor: AppTheme.primary,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isGridView = !_isGridView;
                                        });
                                      },
                                    ),
                                    PopupMenuButton<String>(
                                      icon: Icon(
                                        Icons.tune_rounded,
                                        color: AppTheme.primary,
                                      ),
                                      offset: const Offset(0, 52),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      color: Colors.white,
                                      elevation: 12,
                                      onSelected: (value) {
                                        setState(() {
                                          if (_sortBy == value) {
                                            _sortAscending = !_sortAscending;
                                          } else {
                                            _sortBy = value;
                                            _sortAscending = value == 'title';
                                          }
                                        });
                                      },
                                      itemBuilder: (context) => [
                                        _filterItem(
                                          value: 'title',
                                          label: 'Title',
                                          icon: Icons.sort_by_alpha_rounded,
                                        ),
                                        _filterItem(
                                          value: 'score',
                                          label: 'Score',
                                          icon: Icons.star_rounded,
                                        ),
                                        _filterItem(
                                          value: 'progress',
                                          label: 'Progress',
                                          icon: Icons.trending_up_rounded,
                                        ),
                                        _filterItem(
                                          value: 'lastUpdated',
                                          label: 'Updated',
                                          icon: Icons.update_rounded,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        // Only show status chips when logged in
                        if (_currentUser != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: Row(
                                children: [
                                  _statusChip("Completed"),
                                  const SizedBox(width: 12),
                                  _statusChip("Planning"),
                                  const SizedBox(width: 12),
                                  _statusChip("Watching"),
                                ],
                              ),
                            ),
                          ),

                        MyAnimeList(
                          status: _selectedStatus,
                          isGridView: _isGridView,
                          sortBy: _sortBy,
                          sortAscending: _sortAscending,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label) {
    final bool isSelected = _selectedStatus == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatus = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _filterItem({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _sortBy == value;

    return PopupMenuItem<String>(
      value: value,
      height: 52,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Icon
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppTheme.primary : Colors.grey.shade600,
            ),
            const SizedBox(width: 12),

            // Label
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppTheme.primary : Colors.black87,
                ),
              ),
            ),

            // Sort direction arrow
            if (isSelected)
              Icon(
                _sortAscending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 16,
                color: AppTheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimeCard(dynamic anime) {
    final coverImage = anime['coverImage']?['large'] ?? "";
    final title = anime['title']?['english'] ?? anime['title']?['romaji'] ?? "";
    final score = ((anime['averageScore'] ?? 0) as num) / 10;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnimeDetailScreen(anime: anime),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: _cardHorizontalMargin),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: coverImage,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
              // Gradient Overlay for Title readability
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: score > 0
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              score.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.upcoming_rounded,
                              color: Colors.lightBlueAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              "Upcoming",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return SizedBox(
      height: 220,
      child: PageView.builder(
        controller: _pageController,
        itemCount: 1,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(
              horizontal: _cardHorizontalMargin,
            ),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
            child: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _startCarouselRetryCountdown() {
    _carouselRetryTimer?.cancel();
    _carouselRetryCountdown.value = 10;

    _carouselRetryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _carouselRetryCountdown.value--;

      if (_carouselRetryCountdown.value <= 0) {
        timer.cancel();
        _retryCarouselFetch();
      }
    });
  }

  void _retryCarouselFetch() {
    _carouselRetryTimer?.cancel();
    _carouselRetryCountdown.value = 0;
    setState(() {
      _isLoading = true;
    });
    _fetchAiringAnime();
  }

  Widget _buildCarouselError() {
    // Start countdown if not already running
    if (_carouselRetryCountdown.value == 0 && _carouselRetryTimer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _airingAnimeList.isEmpty && !_isLoading) {
          _startCarouselRetryCountdown();
        }
      });
    }

    return Container(
      height: 220,
      margin: const EdgeInsets.symmetric(horizontal: _cardHorizontalMargin),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _retryCarouselFetch,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  "Couldn't load anime",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                ValueListenableBuilder<int>(
                  valueListenable: _carouselRetryCountdown,
                  builder: (context, countdown, _) {
                    return Text(
                      countdown > 0
                          ? "Retrying in $countdown seconds..."
                          : "Tap to retry",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Retry Now",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyAnimeList extends StatefulWidget {
  final String status;
  final bool isGridView;
  final String sortBy;
  final bool sortAscending;

  const MyAnimeList({
    super.key,
    required this.status,
    this.isGridView = false,
    this.sortBy = 'lastUpdated',
    this.sortAscending = false,
  });

  @override
  State<MyAnimeList> createState() => _MyAnimeListState();
}

class _MyAnimeListState extends State<MyAnimeList> {
  List<QueryDocumentSnapshot>? _cachedSortedList;
  String? _lastSortKey;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.35,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                "Login to track your anime",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('anime')
          .where('status', isEqualTo: widget.status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.35, // 🔥 key fix
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inbox_rounded,
                    size: 56,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "No ${widget.status} anime found 😢",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final animeList = snapshot.data!.docs;

        // Smart Caching:
        // 1. Include status in key so tab switching invalidates cache
        // 2. Only re-sort if:
        //    a) Sort criteria/status changed
        //    b) First load (cache null)
        //    c) List structure changed (items added/removed)
        //    This prevents items from "jumping" when you just update progress (lastUpdated changes).

        final sortKey =
            '${widget.sortBy}_${widget.sortAscending}_${widget.status}';
        bool shouldResort =
            _cachedSortedList == null || _lastSortKey != sortKey;

        if (!shouldResort && _cachedSortedList != null) {
          final currentIds = animeList.map((d) => d.id).toSet();
          final cachedIds = _cachedSortedList!.map((d) => d.id).toSet();

          // If sets differ, items were added or removed -> must re-sort
          if (currentIds.length != cachedIds.length ||
              !currentIds.containsAll(cachedIds)) {
            shouldResort = true;
          }
        }

        if (shouldResort) {
          _cachedSortedList = _sortAnimeList(
            animeList,
            widget.sortBy,
            widget.sortAscending,
          );
          _lastSortKey = sortKey;
        }

        // 🔥 Keep order but refresh document data
        final Map<String, QueryDocumentSnapshot> latestDocsMap = {
          for (final doc in animeList) doc.id: doc,
        };

        final sortedList = _cachedSortedList!
            .where((doc) => latestDocsMap.containsKey(doc.id))
            .map((doc) => latestDocsMap[doc.id]!)
            .toList();

        // Grid View
        if (widget.isGridView) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              16,
              0,
              16,
              100, // 🔥 space for bottom nav
            ),

            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // 🔥 3 cards per row
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.70, // Better poster ratio
            ),

            itemCount: sortedList.length,
            itemBuilder: (context, index) {
              final doc = sortedList[index];
              final data = doc.data() as Map<String, dynamic>;

              final title = data['title'] ?? 'Unknown';

              // Reconstruct anime object from Firestore data
              final anime = {
                'id': data['id'],
                'title': {'english': data['title'], 'romaji': data['title']},
                'coverImage': {'large': data['coverImage']},
                'averageScore': data['averageScore'],
                'episodes': data['totalEpisodes'],
              };

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AnimeDetailScreen(anime: anime),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      // Poster image
                      Positioned.fill(
                        child: CachedNetworkImage(
                          imageUrl: data['coverImage'] ?? '',
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              Container(color: Colors.grey[300]),
                        ),
                      ),

                      // Bottom gradient shadow
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.center,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.85),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Title text inside card
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }

        // List View
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            120, // 🔥 same bottom space
          ),

          itemCount: sortedList.length,
          itemBuilder: (context, index) {
            final doc = sortedList[index];
            final data = doc.data() as Map<String, dynamic>;

            final title = data['title'] ?? 'Unknown';

            final progress = data['progress'] ?? 0;
            final totalEpisodes = data['totalEpisodes'] ?? '?';

            final format = data['format']; // e.g. TV, MOVIE, ONA
            final int? year =
                data['seasonYear'] ??
                (data['startDate'] is Timestamp
                    ? (data['startDate'] as Timestamp).toDate().year
                    : null);

            // Reconstruct anime object from Firestore data
            final anime = {
              'id': data['id'],
              'title': {'english': data['title'], 'romaji': data['title']},
              'coverImage': {'large': data['coverImage']},
              'averageScore': data['averageScore'],
              'episodes': data['totalEpisodes'],
            };

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.97,
                      end: 1.0,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Container(
                key: ValueKey('${doc.id}_${data['status']}_${progress}'),
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AnimeDetailScreen(anime: anime),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 🔥 BIGGER POSTER
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: data['coverImage'] ?? '',
                            width: 80, // ⬅️ increased
                            height: 115, // ⬅️ increased
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                Container(color: Colors.grey[300]),
                          ),
                        ),

                        const SizedBox(width: 14),

                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // TITLE
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                // 🔥 FORMAT + YEAR
                                if (format != null || year != null)
                                  Text(
                                    [
                                      if (format != null) format,
                                      if (year != null) year.toString(),
                                    ].join(' • '),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),

                                const SizedBox(height: 8),

                                // EPISODE TEXT
                                Text(
                                  "Ep: $progress / $totalEpisodes",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),

                                // PROGRESS BAR
                                if (data['status'] != 'Completed') ...[
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: totalEpisodes == 0
                                          ? 0
                                          : progress / totalEpisodes,
                                      minHeight: 3,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation(
                                        AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // ACTION / STATUS
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: data['status'] == 'Completed'
                                ? const Center(
                                    key: ValueKey('completed'),
                                    child: Icon(
                                      Icons.check_circle_rounded,
                                      color: Colors.green,
                                      size: 28,
                                    ),
                                  )
                                : IconButton(
                                    key: const ValueKey('add'),
                                    icon: const Icon(
                                      Icons.add_circle_outline_rounded,
                                      size: 28,
                                    ),
                                    padding: EdgeInsets.zero, // 🔥 important
                                    constraints:
                                        const BoxConstraints(), // 🔥 important
                                    color: AppTheme.primary,
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      _onAddEpisode(
                                        context: context,
                                        docId: doc.id,
                                        data: data,
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void didUpdateWidget(covariant MyAnimeList oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.status != widget.status) {
      _cachedSortedList = null;
      _lastSortKey = null;
    }
  }

  List<QueryDocumentSnapshot> _sortAnimeList(
    List<QueryDocumentSnapshot> docs,
    String sortBy,
    bool ascending,
  ) {
    final list = List<QueryDocumentSnapshot>.from(docs);

    list.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;

      int result;

      switch (sortBy) {
        case 'title':
          final titleA = (dataA['title'] ?? '').toString().toLowerCase();
          final titleB = (dataB['title'] ?? '').toString().toLowerCase();
          result = titleA.compareTo(titleB);
          break;
        case 'progress':
          final progressA = dataA['progress'] ?? 0;
          final progressB = dataB['progress'] ?? 0;
          result = (progressA as int).compareTo(progressB as int);
          break;
        case 'lastUpdated':
          // Support both field names for backward compatibility
          final updatedA =
              (dataA['lastUpdated'] ?? dataA['updatedAt']) as Timestamp?;
          final updatedB =
              (dataB['lastUpdated'] ?? dataB['updatedAt']) as Timestamp?;

          // Always push null values to the end (don't invert by ascending flag)
          if (updatedA == null && updatedB == null) {
            result = 0;
          } else if (updatedA == null) {
            return 1; // A goes to end (regardless of sort direction)
          } else if (updatedB == null) {
            return -1; // B goes to end (regardless of sort direction)
          } else {
            result = updatedA.compareTo(updatedB);
          }
          break;
        case 'score':
          final scoreA = dataA['averageScore'] ?? 0;
          final scoreB = dataB['averageScore'] ?? 0;
          result = (scoreA as num).compareTo(scoreB as num);
          break;
        default:
          result = 0;
      }

      return ascending ? result : -result;
    });

    return list;
  }
}

Future<void> _onAddEpisode({
  required BuildContext context,
  required String docId,
  required Map<String, dynamic> data,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final int progress = data['progress'] ?? 0;
  final int totalEpisodes = data['totalEpisodes'] ?? 0;
  final String status = data['status'];
  // 🔥 Read episode duration (movies have full runtime, TV has ~24 min)
  final int episodeMinutes = data['episodeDuration'] ?? 24;
  final int currentWatchMinutes = data['watchMinutes'] ?? 0;

  if (totalEpisodes != 0 && progress >= totalEpisodes) return;

  final Map<String, dynamic> updateData = {};

  // 🟡 PLANNING
  if (status == 'Planning') {
    if (totalEpisodes == 1) {
      // 🎬 Movie / single-episode anime
      updateData['status'] = 'Completed';
      updateData['progress'] = 1;
      updateData['watchMinutes'] = episodeMinutes;
      updateData['startDate'] = Timestamp.now();
      updateData['finishDate'] = Timestamp.now();
    } else {
      updateData['status'] = 'Watching';
      updateData['progress'] = 1;
      updateData['watchMinutes'] = episodeMinutes;
      updateData['startDate'] = Timestamp.now();
    }
  }
  // 🔵 WATCHING → COMPLETED
  else if (status == 'Watching' &&
      totalEpisodes != 0 &&
      progress + 1 >= totalEpisodes) {
    updateData['status'] = 'Completed';
    updateData['progress'] = totalEpisodes;
    updateData['watchMinutes'] = currentWatchMinutes + episodeMinutes;
    updateData['finishDate'] = Timestamp.now();
  }
  // ▶️ NORMAL INCREMENT
  else {
    updateData['progress'] = progress + 1;
    updateData['watchMinutes'] = currentWatchMinutes + episodeMinutes;
  }

  updateData['lastUpdated'] = FieldValue.serverTimestamp();

  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('anime')
      .doc(docId)
      .update(updateData);
}

class GreetingSection extends StatelessWidget {
  final Color textColor;

  const GreetingSection({super.key, required this.textColor});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getGreeting(),
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Anime Fan",
              style: TextStyle(
                color: textColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        String displayName = user.displayName ?? "Anime Fan";

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          displayName = data?['username'] ?? displayName;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(),
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayName,
                style: TextStyle(
                  color: textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
