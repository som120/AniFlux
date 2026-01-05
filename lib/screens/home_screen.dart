import 'dart:async';
import 'package:ainme_vault/screens/anime_detail_screen.dart';
import 'package:ainme_vault/services/anilist_service.dart';
import 'package:ainme_vault/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  Timer? _timer;
  static const double _cardHorizontalMargin = 24.0;
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
    if (hex == null) return Colors.white;

    return _processCoverColor(_hexToColor(hex));
  }

  // ---------------- LIFECYCLE ----------------
  @override
  void initState() {
    super.initState();
    _bgColorNotifier = ValueNotifier(Colors.white);
    _pageIndexNotifier = ValueNotifier(0);
    _fetchAiringAnime();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bgColorNotifier.dispose();
    _pageIndexNotifier.dispose();
    _pageController.dispose();
    super.dispose();
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
        // Take 4 from airing, 3 from popular, 3 from upcoming
        final List<dynamic> combinedList = [
          ...airingData.take(4),
          ...popularData.take(3),
          ...upcomingData.take(3),
        ];

        // Remove duplicates based on anime ID
        final Set<int> seenIds = {};
        final List<dynamic> uniqueList = [];
        for (final anime in combinedList) {
          final id = anime['id'] as int?;
          if (id != null && !seenIds.contains(id)) {
            seenIds.add(id);
            uniqueList.add(anime);
          }
        }

        // Shuffle for random order
        uniqueList.shuffle();
        _airingAnimeList = uniqueList;
        _isLoading = false;

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
                  padding: const EdgeInsets.only(bottom: 120), // nav bar height
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight, //  KEY FIX
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
                          const Center(child: Text("No airing anime found"))
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
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                                  IconButton(
                                    icon: const Icon(Icons.filter_list_rounded),
                                    style: IconButton.styleFrom(
                                      foregroundColor: AppTheme.primary,
                                    ),
                                    onPressed: () {
                                      // TODO: open filter bottom sheet
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
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
}

class MyAnimeList extends StatelessWidget {
  final String status;
  final bool isGridView;

  const MyAnimeList({super.key, required this.status, this.isGridView = false});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('anime')
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.35, //  key fix
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
                    "No $status anime found 😢",
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

        // Grid View
        if (isGridView) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              16,
              0,
              16,
              120, //  space for bottom nav
            ),

            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, //  3 cards per row
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.70, // Better poster ratio
            ),

            itemCount: animeList.length,
            itemBuilder: (context, index) {
              final doc = animeList[index];
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
                          imageUrl: data['coverImage'],
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
            120, //  same bottom space
          ),

          itemCount: animeList.length,
          itemBuilder: (context, index) {
            final doc = animeList[index];
            final data = doc.data() as Map<String, dynamic>;

            final title = data['title'] ?? 'Unknown';

            final progress = data['progress'] ?? 0;
            final totalEpisodes = data['totalEpisodes'] ?? '?';

            final format = data['format']; // e.g. TV, MOVIE, ONA
            final year = data['seasonYear'] ?? data['startDate']?['year'];

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
                            imageUrl: data['coverImage'],
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

                                //  FORMAT + YEAR
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
                                    padding: EdgeInsets.zero, //  important
                                    constraints:
                                        const BoxConstraints(), //  important
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

  if (totalEpisodes != 0 && progress >= totalEpisodes) return;

  final Map<String, dynamic> updateData = {};

  // 🟡 PLANNING
  if (status == 'Planning') {
    if (totalEpisodes == 1) {
      // 🎬 Movie / single-episode anime
      updateData['status'] = 'Completed';
      updateData['progress'] = 1;
    } else {
      updateData['status'] = 'Watching';
      updateData['progress'] = 1;
    }
  }
  // 🔵 WATCHING → COMPLETED
  else if (status == 'Watching' &&
      totalEpisodes != 0 &&
      progress + 1 >= totalEpisodes) {
    updateData['status'] = 'Completed';
    updateData['progress'] = totalEpisodes;
  }
  // ▶️ NORMAL INCREMENT
  else {
    updateData['progress'] = progress + 1;
  }

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
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
