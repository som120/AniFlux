//import 'package:ainme_vault/main.dart';
//import 'package:ainme_vault/utils/transitions.dart';
import 'package:ainme_vault/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../services/anilist_service.dart';
import 'anime_detail_screen.dart';
import 'dart:async';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SearchScreen extends StatefulWidget {
  final String? initialGenre;
  const SearchScreen({super.key, this.initialGenre});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List animeList = [];
  bool isLoading = false;
  bool hasError = false;
  bool isFocused = false;
  bool _isScrolled = false;
  bool _showFilters = true;
  double _lastScrollOffset = 0;
  double _cumulativeScroll = 0; // Track cumulative scroll for slow scrolling
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  String selectedFilter = "Top 100";

  List<String> searchHistory = [];
  Set<String> _userAnimeIds = {};
  StreamSubscription? _userListSubscription;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_onFocusChange);
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.unfocus();
      isFocused = false;
      setState(() {});
    });

    _init();
    _subscribeToUserList();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  void _subscribeToUserList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _userAnimeIds = {};
      return;
    }
    _userListSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('anime')
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(() {
              _userAnimeIds = snapshot.docs.map((doc) => doc.id).toSet();
            });
          }
        });
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    final bool isOnline = !result.contains(ConnectivityResult.none);

    debugPrint(
      "🌐 Connectivity changed: ${isOnline ? 'ONLINE' : 'OFFLINE'} | hasError: $hasError | selectedFilter: $selectedFilter",
    );

    // Only retry if we're transitioning from offline to online AND we have an error
    if (isOnline && hasError) {
      debugPrint("🔄 Auto-retry triggered for filter: $selectedFilter");
      // Retry the last action
      _retryLastAction();
    } else if (!isOnline && !hasError && animeList.isEmpty && !isLoading) {
      // If we lose connection and have no content, show error
      debugPrint("❌ Network lost with no content, showing error");
      setState(() {
        hasError = true;
      });
    }
  }

  Future<void> _retryLastAction() async {
    if (selectedFilter == "Search") {
      await _performSearch(_controller.text);
    } else if (selectedFilter == "Calendar") {
      // Calendar view has its own error handling, just refresh the state
      setState(() {
        hasError = false;
      });
    } else if (selectedFilter == "Seasonal") {
      setState(() {
        hasError = false;
      });
    } else if (selectedFilter == "Top 100") {
      await _fetchAnimeByCategory("Top 100", AniListService.getTopAnime);
    } else if (selectedFilter == "Popular") {
      await _fetchAnimeByCategory("Popular", AniListService.getPopularAnime);
    } else if (selectedFilter == "Upcoming") {
      await _fetchAnimeByCategory("Upcoming", AniListService.getUpcomingAnime);
    } else if (selectedFilter == "Airing") {
      await _fetchAnimeByCategory("Airing", AniListService.getAiringAnime);
    } else if (selectedFilter == "Movies") {
      await _fetchAnimeByCategory("Movies", AniListService.getTopMovies);
    } else {
      // Fallback: default to Top 100
      await _fetchAnimeByCategory("Top 100", AniListService.getTopAnime);
    }
  }

  void _onFocusChange() {
    if (_searchFocus.hasFocus) {
      setState(() {
        isFocused = true;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final currentOffset = _scrollController.offset;
      final scrolled = currentOffset > 20;
      final scrollDelta = currentOffset - _lastScrollOffset;

      // Always show filters when near the top
      if (currentOffset < 50 && !_showFilters) {
        setState(() {
          _showFilters = true;
        });
        _cumulativeScroll = 0;
        _lastScrollOffset = currentOffset;
        return;
      }

      // Track cumulative scroll in the same direction
      if ((scrollDelta > 0 && _cumulativeScroll > 0) ||
          (scrollDelta < 0 && _cumulativeScroll < 0)) {
        // Same direction - accumulate
        _cumulativeScroll += scrollDelta;
      } else {
        // Direction changed - reset
        _cumulativeScroll = scrollDelta;
      }

      // Hide filters when scrolled down enough (cumulative 80px down)
      if (_cumulativeScroll > 80 && _showFilters && currentOffset > 120) {
        setState(() {
          _showFilters = false;
        });
        _cumulativeScroll = 0;
      }
      // Show filters when scrolled up enough (cumulative 60px up)
      else if (_cumulativeScroll < -60 && !_showFilters) {
        setState(() {
          _showFilters = true;
        });
        _cumulativeScroll = 0;
      }

      _lastScrollOffset = currentOffset;

      // Update scrolled state for search bar animation
      if (scrolled != _isScrolled) {
        setState(() {
          _isScrolled = scrolled;
        });
      }
    }
  }

  Future<void> _init() async {
    await _loadSearchHistory(); // wait until history loads fully
    if (widget.initialGenre != null) {
      await _fetchAnimeByCategory(
        widget.initialGenre!,
        () => AniListService.getAnimeByGenre(widget.initialGenre!),
      );
    } else {
      await _fetchAnimeByCategory("Top 100", AniListService.getTopAnime);
    }
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      searchHistory = prefs.getStringList('search_history') ?? [];
      if (searchHistory.length > 10) {
        searchHistory = searchHistory.sublist(0, 10);
      }
    });
  }

  Future<void> _saveSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('search_history', searchHistory);
  }

  Future<void> _addToHistory(String query) async {
    if (query.isEmpty) return;
    setState(() {
      searchHistory.remove(query);
      searchHistory.insert(0, query);
      if (searchHistory.length > 10) {
        searchHistory.removeLast();
      }
    });
    await _saveSearchHistory();
  }

  Future<void> _removeFromHistory(String query) async {
    setState(() {
      searchHistory.remove(query);
    });
    await _saveSearchHistory();
  }

  Future<void> _clearHistory() async {
    setState(() {
      searchHistory.clear();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('search_history');
  }

  Future<void> _fetchAnimeByCategory(
    String filterName,
    Future<List> Function() apiCall,
  ) async {
    // Prevent unnecessary reloads ONLY if we're not in an error state
    // This allows auto-retry to work when network is restored
    if (selectedFilter == filterName &&
        !isLoading &&
        animeList.isNotEmpty &&
        filterName != "Search" &&
        !hasError) {
      return;
    }

    setState(() {
      isLoading = true;
      hasError = false; // Reset error state on new fetch

      // Only clear search bar on filter change
      if (filterName != "Search") {
        _controller.clear();
        FocusManager.instance.primaryFocus?.unfocus(); // Robust unfocus
        _searchFocus.unfocus();
        isFocused = false;
      }

      selectedFilter = filterName;
    });

    try {
      final data = await apiCall();
      if (!mounted) return;

      // For search, an empty list is a valid result (no results).
      // For categories (Top 100, Popular, etc), an empty list likely indicates a fetch error.
      if (data.isEmpty && filterName != "Search") {
        setState(() {
          isLoading = false;
          hasError = true;
        });
        return;
      }

      setState(() {
        animeList = data;
        isLoading = false;
        hasError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        hasError = true;
      });
      debugPrint("Search error: $e");
    }
  }

  // ------------------ SEARCH FUNCTION ------------------
  // Called while typing (debounce) → DOES NOT close keyboard
  Future<void> _performSearch(String text) async {
    if (text.isEmpty) return;

    await _addToHistory(text);
    await _fetchAnimeByCategory(
      "Search",
      () => AniListService.searchAnime(text),
    );
  }

  // Called when pressing the "search" button → closes keyboard
  void searchAnimeSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _addToHistory(text);
    _fetchAnimeByCategory("Search", () => AniListService.searchAnime(text));

    FocusManager.instance.primaryFocus?.unfocus(); // ONLY HERE
  }

  // ------------------ UI HELPER ------------------
  Widget buildFilterButton(String label, Future<List> Function() apiCall) {
    final bool active = selectedFilter == label;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          _searchFocus.unfocus();
          isFocused = false;
          setState(() {});
          _fetchAnimeByCategory(label, apiCall);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF714FDC) : Colors.grey[300],
            borderRadius: BorderRadius.circular(25),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildAnimatedSearchBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      clipBehavior: Clip.hardEdge,
      transform: _isScrolled && !isFocused
          ? Matrix4.diagonal3Values(0.95, 0.9, 1.0)
          : Matrix4.identity(),
      transformAlignment: Alignment.topCenter,
      padding: EdgeInsets.symmetric(
        horizontal: _isScrolled && !isFocused ? 12 : 18,
        vertical: _isScrolled && !isFocused ? 0 : 4,
      ),
      decoration: BoxDecoration(
        color: isFocused ? Colors.white : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(isFocused ? 30 : 24),
        boxShadow: [
          if (isFocused)
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (isFocused) {
                FocusManager.instance.primaryFocus?.unfocus();
                setState(() {
                  isFocused = false;
                  _controller.clear();
                });
                if (selectedFilter == "Search") {
                  _fetchAnimeByCategory("Top 100", AniListService.getTopAnime);
                }
              }
            },
            child: Icon(
              isFocused ? Icons.arrow_back : Icons.search,
              size: 24,
              color: isFocused ? const Color(0xFF714FDC) : Colors.grey[500],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              focusNode: _searchFocus,
              controller: _controller,
              onChanged: (value) {
                setState(() {}); // update clear icon

                if (_debounce?.isActive ?? false) _debounce!.cancel();

                _debounce = Timer(const Duration(milliseconds: 600), () {
                  if (!mounted) return;
                  if (value.trim().isNotEmpty) {
                    _performSearch(
                      value.trim(),
                    ); // ✔ alive search with keyboard open
                  }
                });
              },

              onSubmitted: (_) =>
                  searchAnimeSubmit(), // ✔ closes keyboard only on submit

              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: "Search anime...",
                hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                border: InputBorder.none,
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _controller.clear();
                setState(() {});
                // Optional: If you want clearing search to go back to Top 100:
                // _fetchAnimeByCategory("Top 100", AniListService.getTopAnime);
              },
              child: const Icon(Icons.close, size: 20, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget buildSearchHistory() {
    if (searchHistory.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Recent Searches",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              GestureDetector(
                onTap: _clearHistory,
                child: const Text(
                  "Clear All",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: searchHistory.length,
            itemBuilder: (context, index) {
              final query = searchHistory[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(Icons.history, color: Colors.grey),
                title: Text(query),
                trailing: GestureDetector(
                  onTap: () => _removeFromHistory(query),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.close, size: 20, color: Colors.grey),
                  ),
                ),
                onTap: () {
                  _controller.text = query;
                  FocusManager.instance.primaryFocus?.unfocus();
                  isFocused = false;
                  searchAnimeSubmit();
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNoResultsWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 50,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "No Anime Found",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "We couldn't find any anime\nmatching your search.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          // Push it up a bit visually to stay centered in the "content" area
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Something went wrong",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "We couldn't load the anime list.\nPlease check your connection.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            _RetryButton(
              onPressed: () async {
                if (selectedFilter == "Search") {
                  await _performSearch(_controller.text);
                } else {
                  // Re-fetch current category
                  // Note: We need a way to call the original apiCall.
                  // Since we don't store the apiCall, we can just call the category fetch logic again.
                  if (selectedFilter == "Top 100") {
                    await _fetchAnimeByCategory(
                      "Top 100",
                      AniListService.getTopAnime,
                    );
                  } else if (selectedFilter == "Popular") {
                    await _fetchAnimeByCategory(
                      "Popular",
                      AniListService.getPopularAnime,
                    );
                  } else if (selectedFilter == "Upcoming") {
                    await _fetchAnimeByCategory(
                      "Upcoming",
                      AniListService.getUpcomingAnime,
                    );
                  } else if (selectedFilter == "Airing") {
                    await _fetchAnimeByCategory(
                      "Airing",
                      AniListService.getAiringAnime,
                    );
                  } else if (selectedFilter == "Movies") {
                    await _fetchAnimeByCategory(
                      "Movies",
                      AniListService.getTopMovies,
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ------------------ BUILD ------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const SizedBox(height: 10),

              // ------------------ Search Bar ------------------
              buildAnimatedSearchBar(),
              const SizedBox(height: 10),

              // ------------------ Filter Buttons ------------------
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOutCubic,
                height: _showFilters ? 50 : 0,
                child: ClipRect(
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOutCubic,
                    offset: _showFilters ? Offset.zero : const Offset(0, -0.5),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _showFilters ? 1.0 : 0.0,
                      child: SizedBox(
                        height: 40,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              // Show genre filter if active and not a standard filter
                              if (selectedFilter != "Top 100" &&
                                  selectedFilter != "Popular" &&
                                  selectedFilter != "Upcoming" &&
                                  selectedFilter != "Airing" &&
                                  selectedFilter != "Movies" &&
                                  selectedFilter != "Calendar" &&
                                  selectedFilter != "Seasonal" &&
                                  selectedFilter != "Search")
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 6,
                                    right: 6,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF714FDC),
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          selectedFilter,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: () {
                                            _fetchAnimeByCategory(
                                              "Top 100",
                                              AniListService.getTopAnime,
                                            );
                                          },
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              buildFilterButton(
                                "Top 100",
                                AniListService.getTopAnime,
                              ),
                              // Calendar Button
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    _searchFocus.unfocus();
                                    isFocused = false;
                                    setState(() {
                                      selectedFilter = "Calendar";
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selectedFilter == "Calendar"
                                          ? const Color(0xFF714FDC)
                                          : Colors.grey[300],
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    child: Text(
                                      "Calendar",
                                      style: TextStyle(
                                        color: selectedFilter == "Calendar"
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Seasonal Button
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    _searchFocus.unfocus();
                                    isFocused = false;
                                    setState(() {
                                      selectedFilter = "Seasonal";
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selectedFilter == "Seasonal"
                                          ? const Color(0xFF714FDC)
                                          : Colors.grey[300],
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    child: Text(
                                      "Seasonal",
                                      style: TextStyle(
                                        color: selectedFilter == "Seasonal"
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              buildFilterButton(
                                "Popular",
                                AniListService.getPopularAnime,
                              ),
                              buildFilterButton(
                                "Upcoming",
                                AniListService.getUpcomingAnime,
                              ),
                              buildFilterButton(
                                "Airing",
                                AniListService.getAiringAnime,
                              ),
                              buildFilterButton(
                                "Movies",
                                AniListService.getTopMovies,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ------------------ List View / History ------------------
              Expanded(
                child: isFocused && _controller.text.isEmpty
                    ? buildSearchHistory()
                    : selectedFilter == "Calendar"
                    ? const _CalendarView()
                    : selectedFilter == "Seasonal"
                    ? const _SeasonalView()
                    : isLoading
                    ? const AnimeListShimmer()
                    : hasError
                    ? _buildErrorWidget()
                    : animeList.isEmpty && selectedFilter == "Search"
                    ? _buildNoResultsWidget()
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 100),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        cacheExtent: 100,
                        itemCount: animeList.length,
                        itemBuilder: (context, index) {
                          final anime = animeList[index];
                          return TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutBack,
                            tween: Tween<double>(begin: 0.0, end: 1.0),
                            builder: (context, value, child) {
                              return Transform.translate(
                                offset: Offset(0, 50 * (1 - value)),
                                child: Transform.scale(
                                  scale: 0.85 + (0.15 * value),
                                  child: Opacity(
                                    opacity: value.clamp(0.0, 1.0),
                                    child: child,
                                  ),
                                ),
                              );
                            },
                            child: AnimeListCard(
                              anime: anime,
                              rank: selectedFilter == "Top 100"
                                  ? index + 1
                                  : null,
                              isInList: _userAnimeIds.contains(
                                anime['id'].toString(),
                              ),
                              onTap: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                _searchFocus.unfocus();
                                isFocused = false;
                                setState(() {});
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AnimeDetailScreen(anime: anime),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _userListSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _searchFocus.removeListener(_onFocusChange);
    _searchFocus.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }
}

// ------------------ EXTRACTED WIDGET ------------------
class AnimeListCard extends StatelessWidget {
  final dynamic anime;
  final int? rank;
  final bool isInList;
  final VoidCallback onTap;

  const AnimeListCard({
    super.key,
    required this.anime,
    this.rank,
    this.isInList = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        anime['coverImage']?['medium'] ?? anime['coverImage']?['large'];
    final title =
        anime['title']?['romaji'] ?? anime['title']?['english'] ?? 'Unknown';
    final score = anime['averageScore']?.toString() ?? 'N/A';
    final year = anime['startDate']?['year']?.toString() ?? '—';
    final episodes = anime['episodes']?.toString() ?? "N/A";

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeInImageWidget(imageUrl: imageUrl, width: 70, height: 95),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Format + Year (Color Removed)
                      Container(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              anime['format'] ?? "TV",
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.circle,
                              size: 4,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              year,
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "$score%",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text("•", style: TextStyle(color: Colors.grey)),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF714FDC).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "$episodes eps",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF714FDC).withOpacity(0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (isInList)
            Positioned(
              top: 10,
              right: 12,
              child: Icon(
                Icons.bookmark_rounded,
                color: const Color(0xFF714FDC).withOpacity(0.6),
                size: 24,
              ),
            ),

          if (rank != null)
            Positioned(
              top: 6,
              left: 0,
              child: rank! <= 3
                  ? Stack(
                      children: [
                        Positioned.fill(
                          child: Shimmer.fromColors(
                            baseColor: rank == 1
                                ? Colors.amber[600]!
                                : rank == 2
                                ? Colors.grey[500]!
                                : rank == 3
                                ? Colors.brown[400]!
                                : Colors.indigo,
                            highlightColor: rank == 1
                                ? Colors.amber[100]!
                                : rank == 2
                                ? Colors.grey[200]!
                                : rank == 3
                                ? Colors.brown[200]!
                                : Colors.indigo.shade100,
                            period: const Duration(milliseconds: 1200),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          child: Text(
                            "#$rank",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: rank == 1
                            ? Colors.amber[600]
                            : rank == 2
                            ? Colors.grey[500]
                            : rank == 3
                            ? Colors.brown[400]
                            : Colors.indigo,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "#$rank",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

class AnimeListShimmer extends StatelessWidget {
  const AnimeListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          period: const Duration(milliseconds: 1200),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 70,
                  height: 95,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 16,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 14,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: List.generate(
                          3,
                          (_) => Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Container(
                              height: 14,
                              width: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class FadeInImageWidget extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;

  const FadeInImageWidget({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: width,
          height: height,
          fit: BoxFit.cover,
          memCacheWidth: (width * 3).toInt(), // Optimize memory usage
          placeholder: (context, url) => Container(color: Colors.grey[200]),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image, color: Colors.grey),
          ),
          fadeInDuration: const Duration(milliseconds: 250),
        ),
      ),
    );
  }
}

class _CalendarView extends StatefulWidget {
  const _CalendarView();

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  int _selectedDayIndex = 0;
  late final List<DateTime> _days;
  final Map<int, List<dynamic>> _scheduleCache = {}; // Cache for each day

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _days = List.generate(7, (index) => now.add(Duration(days: index)));
  }

  String _getDayName(int weekday) {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Day Tabs
        Container(
          height: 40,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _days.length,
            separatorBuilder: (context, index) => const SizedBox(width: 20),
            itemBuilder: (context, index) {
              final date = _days[index];
              final isSelected = index == _selectedDayIndex;

              return GestureDetector(
                onTap: () => setState(() => _selectedDayIndex = index),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _getDayName(date.weekday),
                      style: TextStyle(
                        color: isSelected ? Colors.black87 : Colors.grey,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      height: 3,
                      width: isSelected ? 24 : 0,
                      decoration: BoxDecoration(
                        color: const Color(0xFF714FDC),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Grid Content
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
                return const Center(
                  child: Text("No anime airing on this day."),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.only(bottom: 100),
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
                    colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
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
                      color: Colors.white.withOpacity(0.8),
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

class _RetryButton extends StatefulWidget {
  final Future<void> Function() onPressed;
  const _RetryButton({required this.onPressed});

  @override
  State<_RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<_RetryButton>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() {}),
      onTapUp: (_) => setState(() {}),
      onTapCancel: () => setState(() {}),
      onTap: _isLoading
          ? null
          : () async {
              setState(() {
                _isLoading = true;
              });
              _controller.repeat();

              // Run minimum delay and task in parallel
              // This ensures we see the animation for at least 1s
              // but also wait for the actual network request if it takes longer.
              final minDelay = Future.delayed(
                const Duration(milliseconds: 1000),
              );
              final task = widget.onPressed();

              await Future.wait([minDelay, task]);

              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
                _controller.stop();
              }
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF714FDC),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF714FDC).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _isLoading
            ? RotationTransition(
                turns: _controller,
                child: const Icon(Icons.refresh, color: Colors.white, size: 20),
              )
            : const Text(
                "Retry",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }
}

class _SeasonalView extends StatefulWidget {
  const _SeasonalView();

  @override
  State<_SeasonalView> createState() => _SeasonalViewState();
}

class _SeasonalViewState extends State<_SeasonalView> {
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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    child: Text(
                      "Select Year",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
    ).whenComplete(() {
      scrollController.dispose();
      if (tempSelectedYear != _selectedYear) {
        setState(() {
          _selectedYear = tempSelectedYear;
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
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final season = _seasons[index];
                      final label = _seasonLabels[index];
                      final isSelected = season == _selectedSeason;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedSeason = season),
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
                onTap: _showYearPicker,
                child: Container(
                  width: 44, // Reduced size
                  height: 44, // Reduced size
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
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
                      _RetryButton(
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
                    colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
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
