// =============================================================================
// ANIME PREVIEW MODEL
// =============================================================================
//
// PURPOSE:
// A lightweight, type-safe model for anime data used in search/list screens.
// This model extracts ONLY the fields needed for displaying anime cards,
// avoiding the overhead of a full anime model.
//
// WHY THIS EXISTS:
// Before this model, we used `List animeList = []` (dynamic typing).
// This caused several problems:
//
//   1. NO TYPE SAFETY - Runtime errors instead of compile-time errors
//      Example: anime['averageScroe'] (typo) would fail silently at runtime
//
//   2. NO IDE SUPPORT - No autocomplete, no refactoring support
//      Example: Renaming a field required find/replace across all files
//
//   3. HARD TO MAINTAIN - API changes caused cascading, hard-to-find bugs
//      Example: If AniList changed 'averageScore' to 'score', every usage breaks
//
//   4. POOR TESTABILITY - Can't easily create mock data for testing
//
// HOW IT WORKS:
// 1. API returns raw JSON → fromJson() parses it into AnimePreview
// 2. UI uses typed properties → anime.displayTitle, anime.coverImage
// 3. Detail screen needs raw JSON → toJson() converts back for compatibility
//
// DESIGN DECISIONS:
// - Only includes fields needed for list/grid display (not synopsis, genres, etc.)
// - Display getters (scoreDisplay, yearDisplay) handle null/formatting in one place
// - toJson() maintains backward compatibility with detail screen
// - Immutable (all fields are final) for predictable state
// - Equality based on ID for deduplication and comparison
//
// USAGE EXAMPLE:
// ```dart
// // Converting API response to typed list
// List<AnimePreview> animeList = data
//     .map((item) => AnimePreview.fromJson(item))
//     .toList();
//
// // Using in UI with type safety and autocomplete
// Text(anime.displayTitle)
// Text('${anime.scoreDisplay}%')
// Image.network(anime.coverImage)
//
// // Passing to detail screen (backward compatible)
// AnimeDetailScreen(anime: anime.toJson())
// ```
//
// =============================================================================

/// Lightweight model for anime preview data used in search/list screens.
///
/// This is NOT a full anime model. It contains only the fields necessary
/// for displaying anime cards in lists and grids. For detail screens that
/// need additional data (synopsis, characters, etc.), use [toJson] to
/// convert back to a Map and pass to screens expecting raw JSON.
///
/// ## Fields Included:
/// - `id` - Unique identifier from AniList
/// - `title` - Primary title (Romaji preferred, English fallback)
/// - `titleEnglish` - English title if available
/// - `coverImageMedium/Large` - Cover image URLs
/// - `averageScore` - User rating (0-100)
/// - `startYear` - Year the anime started airing
/// - `episodes` - Total episode count
/// - `format` - Type (TV, MOVIE, OVA, etc.)
///
/// ## Display Helpers:
/// Instead of doing null checks everywhere in UI code, use these getters:
/// - [coverImage] - Best available image URL
/// - [displayTitle] - Formatted title
/// - [scoreDisplay] - "85" or "N/A"
/// - [yearDisplay] - "2023" or "—"
/// - [episodesDisplay] - "24" or "N/A"
/// - [formatDisplay] - "TV" (with fallback)
class AnimePreview {
  /// Unique anime ID from AniList API
  final int id;

  /// Primary display title (Romaji preferred)
  /// This is the main title shown in cards and lists
  final String title;

  /// English title (if available)
  /// Used for search matching and accessibility
  final String? titleEnglish;

  /// Medium-sized cover image URL (~230px width)
  /// Preferred for list cards to save bandwidth
  final String? coverImageMedium;

  /// Large cover image URL (~500px width)
  /// Used as fallback or for larger displays
  final String? coverImageLarge;

  /// User rating score from 0-100
  /// Null if no ratings yet
  final int? averageScore;

  /// Year the anime started airing
  /// Null for upcoming anime without confirmed dates
  final int? startYear;

  /// Total episode count
  /// Null for ongoing anime or unknown
  final int? episodes;

  /// Anime format/type
  /// Values: TV, MOVIE, OVA, ONA, SPECIAL, MUSIC
  final String? format;

  /// Creates an immutable AnimePreview instance.
  ///
  /// [id] and [title] are required as they're essential for display.
  /// All other fields are optional and will use fallbacks in display getters.
  const AnimePreview({
    required this.id,
    required this.title,
    this.titleEnglish,
    this.coverImageMedium,
    this.coverImageLarge,
    this.averageScore,
    this.startYear,
    this.episodes,
    this.format,
  });

  /// Creates an [AnimePreview] from AniList API JSON response.
  ///
  /// Handles the nested structure of AniList's GraphQL response:
  /// ```json
  /// {
  ///   "id": 1,
  ///   "title": { "romaji": "...", "english": "..." },
  ///   "coverImage": { "medium": "...", "large": "..." },
  ///   "startDate": { "year": 2023 },
  ///   ...
  /// }
  /// ```
  ///
  /// If the title is missing, defaults to 'Unknown'.
  factory AnimePreview.fromJson(Map<String, dynamic> json) {
    return AnimePreview(
      id: json['id'] as int,
      title:
          json['title']?['romaji'] as String? ??
          json['title']?['english'] as String? ??
          'Unknown',
      titleEnglish: json['title']?['english'] as String?,
      coverImageMedium: json['coverImage']?['medium'] as String?,
      coverImageLarge: json['coverImage']?['large'] as String?,
      averageScore: json['averageScore'] as int?,
      startYear: json['startDate']?['year'] as int?,
      episodes: json['episodes'] as int?,
      format: json['format'] as String?,
    );
  }

  // ===========================================================================
  // DISPLAY HELPERS
  // ===========================================================================
  // These getters centralize null-handling and formatting logic.
  // Use these in UI code instead of raw field access.

  /// Best available cover image URL.
  ///
  /// Prefers medium-sized image for bandwidth efficiency,
  /// falls back to large, or returns empty string if none available.
  String get coverImage => coverImageMedium ?? coverImageLarge ?? '';

  /// Primary display title.
  ///
  /// Currently returns [title] (Romaji), but this getter exists
  /// so we can easily change display preference later.
  String get displayTitle => title;

  /// Score formatted for display.
  ///
  /// Returns the score as a string (e.g., "85") or "N/A" if not rated.
  /// Note: This is a percentage, so display as "${scoreDisplay}%"
  String get scoreDisplay => averageScore?.toString() ?? 'N/A';

  /// Year formatted for display.
  ///
  /// Returns the year as a string (e.g., "2023") or em-dash "—" if unknown.
  String get yearDisplay => startYear?.toString() ?? '—';

  /// Episode count formatted for display.
  ///
  /// Returns count as string (e.g., "24") or "N/A" for ongoing/unknown.
  String get episodesDisplay => episodes?.toString() ?? 'N/A';

  /// Format type with fallback.
  ///
  /// Returns the format (e.g., "TV", "MOVIE") or "TV" as default.
  String get formatDisplay => format ?? 'TV';

  // ===========================================================================
  // SERIALIZATION
  // ===========================================================================

  /// Converts back to the JSON structure expected by detail screens.
  ///
  /// This maintains backward compatibility with existing code that
  /// expects raw Map<String, dynamic> (like AnimeDetailScreen).
  ///
  /// The output matches AniList's response structure so detail screens
  /// can access additional fields they might need.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': {'romaji': title, 'english': titleEnglish},
      'coverImage': {'medium': coverImageMedium, 'large': coverImageLarge},
      'averageScore': averageScore,
      'startDate': {'year': startYear},
      'episodes': episodes,
      'format': format,
    };
  }

  // ===========================================================================
  // OBJECT OVERRIDES
  // ===========================================================================

  /// Returns a readable string representation for debugging.
  @override
  String toString() => 'AnimePreview(id: $id, title: $title)';

  /// Two AnimePreview instances are equal if they have the same ID.
  ///
  /// This is useful for:
  /// - Deduplicating lists
  /// - Checking if anime is already in user's list
  /// - State comparison in Flutter
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnimePreview &&
          runtimeType == other.runtimeType &&
          id == other.id;

  /// Hash code based on ID for consistent hashing in Sets and Maps.
  @override
  int get hashCode => id.hashCode;
}
