import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/anilist_service.dart';
import '../screens/anime_detail_screen.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  int _selectedDayIndex = 0;
  late final List<DateTime> _days;
  final Map<int, List<dynamic>> _scheduleCache = {}; // Cache for each day
  late final ScrollController _dayScrollController;
  final DateTime _today = DateTime.now();

  static const _kCardWidth = 50.0;
  static const _kCardSpacing = 7.0;
  static const Color _primaryColor = Color(0xFF714FDC);

  @override
  void initState() {
    super.initState();
    _days = List.generate(7, (index) => _today.add(Duration(days: index)));
    _dayScrollController = ScrollController();
  }

  @override
  void dispose() {
    _dayScrollController.dispose();
    super.dispose();
  }

  String _getShortDayName(int weekday) {
    const days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];
    return days[weekday - 1];
  }

  String _getFullDayName(int weekday) {
    const days = [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday",
    ];
    return days[weekday - 1];
  }

  String _getMonthName(int month) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return months[month - 1];
  }

  bool _isToday(DateTime date) {
    return date.year == _today.year &&
        date.month == _today.month &&
        date.day == _today.day;
  }

  String _getDateLabel(DateTime date) {
    if (_isToday(date)) return "Today";
    return "${_getFullDayName(date.weekday)}, ${_getMonthName(date.month)} ${date.day}";
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  Future<List<dynamic>> _fetchSchedule() async {
    // Check if data is already cached
    if (_scheduleCache.containsKey(_selectedDayIndex)) {
      return _scheduleCache[_selectedDayIndex]!;
    }

    // Fetch new data
    final date = _days[_selectedDayIndex];
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay
        .add(const Duration(days: 1))
        .subtract(const Duration(seconds: 1));

    final start = startOfDay.millisecondsSinceEpoch ~/ 1000;
    final end = endOfDay.millisecondsSinceEpoch ~/ 1000;

    final schedules = await AniListService.getAiringSchedule(
      start: start,
      end: end,
      perPage: 50,
    );

    // Cache the result
    _scheduleCache[_selectedDayIndex] = schedules;

    return schedules;
  }

  void _onDaySelected(int index) {
    HapticFeedback.lightImpact();
    setState(() => _selectedDayIndex = index);

    // Scroll to center the selected card
    final targetOffset =
        index * (_kCardWidth + _kCardSpacing) -
        (MediaQuery.sizeOf(context).width / 2 - _kCardWidth / 2 - 12);
    _dayScrollController.animateTo(
      targetOffset.clamp(0.0, _dayScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = _days[_selectedDayIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ────── Premium Day Timeline ──────
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          child: SizedBox(
            height: 78,
            child: ListView.separated(
              controller: _dayScrollController,
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              itemCount: _days.length,
              separatorBuilder: (_, _) => const SizedBox(width: _kCardSpacing),
              itemBuilder: (context, index) {
                final date = _days[index];
                final isSelected = index == _selectedDayIndex;
                final isDateToday = _isToday(date);

                return GestureDetector(
                  onTap: () => _onDaySelected(index),
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    scale: isSelected ? 1.08 : 1.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      width: _kCardWidth,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _primaryColor
                            : const Color(0xFFE8E5F0),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: _primaryColor.withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : [],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Short day name (MON, TUE, etc.)
                          Text(
                            _getShortDayName(date.weekday),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : Colors.grey.shade500,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Date number — inner badge for selected
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                            width: 26,
                            height: 27,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "${date.day}",
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey.shade700,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),

                          const SizedBox(height: 3),

                          // Dot indicator — today dot (purple) or selected dot (white)
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: (isSelected || isDateToday) ? 1.0 : 0.0,
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : _primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // ────── Selected Date Label ──────
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12, top: 4),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
              return Stack(
                alignment: Alignment.centerLeft,
                children: <Widget>[
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              );
            },
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.1), // Slide from bottom instead of right
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: child,
                ),
              );
            },
            child: Text(
              _getDateLabel(selectedDate),
              key: ValueKey(_selectedDayIndex),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D2D3A),
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),

        // ────── Grid Content ──────
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            key: ValueKey(_selectedDayIndex),
            future: _fetchSchedule(),
            builder: (context, snapshot) {
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting;

              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }

              final schedules = snapshot.data ?? [];
              final itemCount = isLoading ? 12 : schedules.length;

              if (!isLoading && schedules.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_busy_rounded,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "No anime airing on this day",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
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
                  // Staggered animation delay based on index
                  return TweenAnimationBuilder<double>(
                    duration: Duration(milliseconds: 400 + (index * 50)),
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
                        : _buildAnimeCard(schedules[index]),
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

  Widget _buildAnimeCard(dynamic item) {
    final media = item['media'];
    final airingAt = item['airingAt'];
    final episode = item['episode'];

    if (media == null) return const SizedBox.shrink();

    final title =
        media['title']?['romaji'] ?? media['title']?['english'] ?? "Unknown";
    final image =
        media['coverImage']?['large'] ?? media['coverImage']?['medium'];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnimeDetailScreen(anime: media),
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

            // Title and episode info ON the poster
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
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
                  const SizedBox(height: 4),
                  Text(
                    "Ep $episode at ${_formatTime(airingAt)}",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
