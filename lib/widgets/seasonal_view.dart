import 'package:ainme_vault/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/anilist_service.dart';
import '../screens/anime_detail_screen.dart';
import '../widgets/retry_button.dart';

class SeasonalView extends StatefulWidget {
  const SeasonalView({super.key});

  @override
  State<SeasonalView> createState() => _SeasonalViewState();
}

class _SeasonalViewState extends State<SeasonalView> {
  int _selectedYear = DateTime.now().year;
  String _selectedSeason = 'WINTER';
  final Map<String, List<dynamic>> _seasonalCache = {};

  final List<String> _seasons = ['WINTER', 'SPRING', 'SUMMER', 'FALL'];
  final List<String> _seasonLabels = ['Winter', 'Spring', 'Summer', 'Fall'];
  final List<int> _years = List.generate(
    36,
    (index) => DateTime.now().year + 1 - index,
  );

  @override
  void initState() {
    super.initState();
    _determineCurrentSeason();
  }

  void _determineCurrentSeason() {
    final now = DateTime.now();
    final month = now.month;
    // Simple season approximation
    if (month >= 1 && month <= 3) {
      _selectedSeason = 'WINTER';
    } else if (month >= 4 && month <= 6) {
      _selectedSeason = 'SPRING';
    } else if (month >= 7 && month <= 9) {
      _selectedSeason = 'SUMMER';
    } else {
      _selectedSeason = 'FALL';
    }
  }

  Future<List<dynamic>> _fetchSeasonalAnime() async {
    final key = '$_selectedYear-$_selectedSeason';
    if (_seasonalCache.containsKey(key)) {
      return _seasonalCache[key]!;
    }

    try {
      final data = await AniListService.getAnimeBySeason(
        _selectedYear,
        _selectedSeason,
      );
      _seasonalCache[key] = data;
      return data;
    } catch (e) {
      debugPrint("Error fetching seasonal anime: $e");
      rethrow;
    }
  }

  void _showYearPicker() {
    int tempSelectedYear = _selectedYear;
    final FixedExtentScrollController scrollController =
        FixedExtentScrollController(initialItem: _years.indexOf(_selectedYear));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SizedBox(
              height: 300,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header Row with Title centered and Apply button on right
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Empty space to balance the Apply button
                        const SizedBox(width: 60),
                        // Centered Title
                        const Text(
                          "Select Year",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Apply Button on the right
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context, tempSelectedYear);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF714FDC),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text(
                              "Apply",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListWheelScrollView.useDelegate(
                      itemExtent: 50,
                      perspective: 0.005,
                      diameterRatio: 1.5,
                      physics: const FixedExtentScrollPhysics(),
                      controller: scrollController,
                      onSelectedItemChanged: (index) {
                        HapticFeedback.mediumImpact();
                        setModalState(() {
                          tempSelectedYear = _years[index];
                        });
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: _years.length,
                        builder: (context, index) {
                          final year = _years[index];
                          final isSelected = year == tempSelectedYear;
                          return Center(
                            child: Text(
                              year.toString(),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? const Color(0xFF714FDC)
                                    : Colors.grey,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((selectedYear) {
      scrollController.dispose();
      // Handle both button tap (returns year) and drag-to-dismiss (returns null)
      final yearToApply = selectedYear ?? tempSelectedYear;
      if (yearToApply != _selectedYear) {
        setState(() {
          _selectedYear = yearToApply;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter Row: Seasons + Year
        Container(
          height: 44, // Reduced height for smaller appearance
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              // Scrollable Seasons
              Expanded(
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.white, Colors.white, Colors.transparent],
                      stops: [0.0, 0.92, 1.0], // Fade out only the last 8%
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 4, right: 20),
                    itemCount: _seasons.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final season = _seasons[index];
                      final label = _seasonLabels[index];
                      final isSelected = season == _selectedSeason;

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _selectedSeason = season);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16, // Reduced padding
                            vertical: 0,
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF714FDC)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF714FDC)
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 13, // Slightly smaller text
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Year Filter Circle
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showYearPicker();
                },
                child: Container(
                  width: 44, // Reduced size
                  height: 44, // Reduced size
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _selectedYear.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),

        // Content
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            key: ValueKey('$_selectedYear-$_selectedSeason'),
            future: _fetchSeasonalAnime(),
            builder: (context, snapshot) {
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting;

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      const Text("Could not load seasonal anime"),
                      const SizedBox(height: 12),
                      RetryButton(
                        onPressed: () async {
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                );
              }

              final animeList = snapshot.data ?? [];
              final itemCount = isLoading ? 12 : animeList.length;

              if (!isLoading && animeList.isEmpty) {
                return const Center(
                  child: Text("No anime found for this season."),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.only(bottom: 100),
                // ====== CACHE EXTENT FOR SMOOTH SCROLLING ======
                // Pre-renders ~3-4 rows of grid items off-screen
                cacheExtent: 400,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  return TweenAnimationBuilder<double>(
                    duration: Duration(milliseconds: 400 + (index % 10 * 50)),
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: Opacity(opacity: value, child: child),
                      );
                    },
                    child: isLoading
                        ? _buildSkeletonCard()
                        : _buildSeasonalAnimeCard(context, animeList[index]),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildSeasonalAnimeCard(BuildContext context, dynamic anime) {
    final title =
        anime['title']?['romaji'] ?? anime['title']?['english'] ?? "Unknown";
    final image =
        anime['coverImage']?['large'] ?? anime['coverImage']?['medium'];

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
            // Poster image (full size)
            Positioned.fill(
              child: image != null
                  ? CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      // ====== MEMORY CACHE LIMITS ======
                      // Grid cards are ~120px wide, so 240px memory cache is sufficient
                      memCacheWidth: 240,
                      memCacheHeight: 360,
                      maxWidthDiskCache: 300,
                      maxHeightDiskCache: 450,
                      placeholder: (context, url) =>
                          Container(color: Colors.grey[200]),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image),
                      ),
                    )
                  : Container(color: Colors.grey[200]),
            ),

            // Gradient overlay at bottom
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.9),
                    ],
                  ),
                ),
              ),
            ),

            // Title ON the poster
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
  }
}
