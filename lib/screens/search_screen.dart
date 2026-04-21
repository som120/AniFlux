//import 'package:ainme_vault/main.dart';
//import 'package:ainme_vault/utils/transitions.dart';
import 'package:ainme_vault/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/anilist_service.dart';
import '../widgets/calendar_view.dart';
import '../widgets/retry_button.dart';
import '../widgets/seasonal_view.dart';
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
  SearchScreenState createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen> {
  /// Called from the nav bar when the search tab is tapped while already active.
  /// Focuses the search text field so the user can start typing immediately.
  void focusSearchField() {
    _searchFocus.requestFocus();
    setState(() {
      isFocused = true;
    });
  }

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

  // ====== STALE REQUEST CANCELLATION ======
  // Session IDs to cancel pending API requests when user types quickly
  // or switches filters rapidly. Each new request increments the session ID,
  // and when a response returns, it checks if it's still the active session.
  // If not, the response is discarded to prevent stale data from overwriting
  // newer results.
  int _searchSessionId = 0;
  int _categorySessionId = 0;

  // ====== CENTRALIZED RETRY LOGIC ======
  // Stores the last API call function so retry logic is in ONE place.
  // Before: Retry logic was duplicated in _retryLastAction AND _buildErrorWidget
  // After: Both just call _retryLastAction(), which uses this stored function.
  // Benefits: No code duplication, no logic drift, easy to maintain.
  Future<List> Function()? _lastApiCall;

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

  /// ====== CENTRALIZED RETRY LOGIC ======
  /// Single source of truth for retrying the last action.
  /// Called by:
  ///   - Error widget retry button
  ///   - Auto-retry on network restoration
  ///   - Pull-to-refresh (if implemented)
  ///
  /// Uses [_lastApiCall] stored by [_fetchAnimeByCategory] to avoid
  /// duplicating filter-to-API-call mapping everywhere.
  Future<void> _retryLastAction() async {
    if (selectedFilter == "Search") {
      // Search uses the text field content, not stored API call
      await _performSearch(_controller.text);
    } else if (selectedFilter == "Calendar" || selectedFilter == "Seasonal") {
      // These views have their own FutureBuilder error handling
      // Just reset error state to trigger rebuild
      setState(() {
        hasError = false;
      });
    } else if (_lastApiCall != null) {
      // Use stored API call - cleaner and guaranteed to match
      await _fetchAnimeByCategory(selectedFilter, _lastApiCall!);
    } else {
      // Fallback: should rarely happen, default to Top 100
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

    // ====== STORE API CALL FOR RETRY ======
    // Save the API call function so _retryLastAction can use it
    // without needing to duplicate the filter-to-API mapping
    _lastApiCall = apiCall;

    // ====== STALE REQUEST CANCELLATION ======
    // Increment session ID to invalidate any pending requests.
    // When the API response returns, we'll check if currentSessionId
    // still matches _categorySessionId. If not, this request is stale.
    final currentSessionId = ++_categorySessionId;

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

      // ====== CHECK FOR STALE RESPONSE ======
      // If user switched filters while we were loading, discard this response
      if (currentSessionId != _categorySessionId) {
        debugPrint(
          "⏭️ Stale category request ignored: $filterName (session $currentSessionId, current $_categorySessionId)",
        );
        return;
      }

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
      // Only show error if this is still the active request
      if (currentSessionId != _categorySessionId) return;
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

    // ====== STALE REQUEST CANCELLATION ======
    // Increment search session to cancel any pending searches.
    // If user types "Na" then "Nar" then "Naruto", only "Naruto" results show.
    final currentSearchSession = ++_searchSessionId;

    await _addToHistory(text);

    // Check if search was superseded before making API call
    if (currentSearchSession != _searchSessionId) {
      debugPrint(
        "⏭️ Search cancelled before API call: '$text' (session $currentSearchSession, current $_searchSessionId)",
      );
      return;
    }

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
          HapticFeedback.lightImpact();
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
              color: Colors.black.withValues(alpha: 0.12),
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
              color: Colors.black.withValues(alpha: 0.08),
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
                color: Colors.red.withValues(alpha: 0.1),
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
            // ====== USES CENTRALIZED RETRY ======
            // Before: 35 lines of duplicated filter-specific logic
            // After: Single method call - no duplication, no drift
            RetryButton(onPressed: _retryLastAction),
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
                                            HapticFeedback.lightImpact();
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
                                    HapticFeedback.lightImpact();
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
                                    HapticFeedback.lightImpact();
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
                    ? const CalendarView()
                    : selectedFilter == "Seasonal"
                    ? const SeasonalView()
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
                        // ====== INCREASED CACHE EXTENT ======
                        // Pre-renders ~5 extra items off-screen for smoother scrolling.
                        // Before: 100px (~1 item) - caused visible pop-in on fast scroll
                        // After: 500px (~5 items) - images pre-load before becoming visible
                        cacheExtent: 500,
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
                  color: Colors.black.withValues(alpha: 0.05),
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
                      Padding(
                        padding: EdgeInsets.only(right: isInList ? 30 : 0),
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Format + Year (Color Removed)
                      Row(
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
                              color: const Color(
                                0xFF714FDC,
                              ).withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "$episodes eps",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(
                                  0xFF714FDC,
                                ).withValues(alpha: 0.8),
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
              top: 15,
              right: 12,
              child: Icon(
                Icons.bookmark_rounded,
                color: const Color(0xFF714FDC).withValues(alpha: 0.25),
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
          // ====== MEMORY CACHE LIMITS ======
          // Limit image size in memory to reduce RAM usage.
          // Without limits: Full-res images (e.g., 1000x1500px = ~4.5MB each)
          // With limits: Downscaled to ~2x display size (~0.3MB each)
          // For 100 images: 450MB → 30MB RAM savings
          memCacheWidth: (width * 2).toInt(),
          memCacheHeight: (height * 2).toInt(),
          maxWidthDiskCache: 300,
          maxHeightDiskCache: 400,
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



