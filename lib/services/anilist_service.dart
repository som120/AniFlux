import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AniListService {
  static final HttpLink httpLink = HttpLink('https://graphql.anilist.co');

  // 🔥 Cached adult content preference to avoid repeated disk hits
  static bool? _cachedShowAdult;

  /// Get the cached show adult content preferen
  static Future<bool> _showAdult() async {
    if (_cachedShowAdult != null) return _cachedShowAdult!;
    final prefs = await SharedPreferences.getInstance();
    _cachedShowAdult = prefs.getBool('show_adult_content') ?? false;
    return _cachedShowAdult!;
  }

  /// Call this when the user changes the adult content setting
  static void invalidateAdultContentCache() {
    _cachedShowAdult = null;
  }

  static GraphQLClient client() {
    return GraphQLClient(
      link: httpLink,
      cache: GraphQLCache(store: InMemoryStore()),
    );
  }

  // ---------------- QUERY CONSTANTS ----------------
  // Note: isAdult is optional - when not provided, returns all content
  // When isAdult: false, only returns non-adult content (server-side filter)

  static const String searchQuery = r'''
     query ($search: String, $page: Int, $perPage: Int, $isAdult: Boolean) {
      Page(page: $page, perPage: $perPage) {
        media(search: $search, type: ANIME, isAdult: $isAdult) {
          id
          title { romaji english }
          format
          genres
          description(asHtml: false)
          episodes
          averageScore
          popularity
          favourites
          rankings { rank type allTime }
          status
          bannerImage
          startDate { year }
          coverImage { large medium }
          isAdult
        }
      }
    }
  ''';

  static const String topAnimeQuery = r'''
    query ($page: Int, $perPage: Int, $isAdult: Boolean) {
      Page(page: $page, perPage: $perPage) {
        media(sort: SCORE_DESC, type: ANIME, isAdult: $isAdult) {
          id
          title { romaji english }
          format
          genres
          description(asHtml: false)
          episodes
          averageScore
          popularity
          favourites
          rankings { rank type allTime }
          status
          bannerImage
          startDate { year }
          coverImage { medium large }
          isAdult
        }
      }
    }
  ''';

  static const String popularAnimeQuery = r'''
    query ($page: Int, $perPage: Int, $isAdult: Boolean) {
      Page(page: $page, perPage: $perPage) {
        media(sort: POPULARITY_DESC, type: ANIME, isAdult: $isAdult) {
          id
          title { romaji english }
          format
          genres
          description(asHtml: false)
          episodes
          averageScore
          popularity
          favourites
          rankings { rank type allTime }
          status
          bannerImage
          startDate { year }
          coverImage { medium large }
          isAdult
        }
      }
    }
  ''';

  static const String upcomingAnimeQuery = r'''
    query ($page: Int, $perPage: Int, $isAdult: Boolean) {
      Page(page: $page, perPage: $perPage) {
        media(sort: POPULARITY_DESC, type: ANIME, status: NOT_YET_RELEASED, isAdult: $isAdult) {
          id
          title { romaji english }
          format
          genres
          description(asHtml: false)
          episodes
          averageScore
          popularity
          favourites
          rankings { rank type allTime }
          status
          bannerImage
          startDate { year }
          coverImage { medium large }
          isAdult
        }
      }
    }
  ''';

  static const String airingAnimeQuery = r'''
    query ($page: Int, $perPage: Int, $isAdult: Boolean) {
      Page(page: $page, perPage: $perPage) {
        media(sort: TRENDING_DESC, type: ANIME, status: RELEASING, isAdult: $isAdult) {
          id
          title { romaji english }
          format
          genres
          description(asHtml: false)
          episodes
          averageScore
          popularity
          favourites
          rankings { rank type allTime }
          status
          bannerImage
          startDate { year }
          coverImage { medium large color }
          isAdult
        }
      }
    }
  ''';

  static const String topMoviesQuery = r'''
    query ($page: Int, $perPage: Int, $isAdult: Boolean) {
      Page(page: $page, perPage: $perPage) {
        media(sort: SCORE_DESC, type: ANIME, format: MOVIE, isAdult: $isAdult) {
          id
          title { romaji english }
          format
          genres
          description(asHtml: false)
          episodes
          averageScore
          popularity
          favourites
          rankings { rank type allTime }
          status
          bannerImage
          startDate { year }
          coverImage { medium large }
          isAdult
        }
      }
    }
  ''';

  static const String genreQuery = r'''
    query ($genre: String, $page: Int, $perPage: Int, $isAdult: Boolean) {
      Page(page: $page, perPage: $perPage) {
        media(genre: $genre, sort: POPULARITY_DESC, type: ANIME, isAdult: $isAdult) {
          id
          title { romaji english }
          format
          genres
          description(asHtml: false)
          episodes
          averageScore
          popularity
          favourites
          rankings { rank type allTime }
          status
          bannerImage
          startDate { year }
          coverImage { medium large }
          isAdult
        }
      }
    }
  ''';

  static const String seasonQuery = r'''
    query ($season: MediaSeason, $seasonYear: Int, $page: Int, $perPage: Int, $isAdult: Boolean) {
      Page(page: $page, perPage: $perPage) {
        media(season: $season, seasonYear: $seasonYear, sort: POPULARITY_DESC, type: ANIME, isAdult: $isAdult) {
          id
          title { romaji english }
          format
          genres
          description(asHtml: false)
          episodes
          averageScore
          popularity
          favourites
          rankings { rank type allTime }
          status
          bannerImage
          startDate { year }
          coverImage { medium large }
          isAdult
        }
      }
    }
  ''';

  static const String mediaDetailQuery = r'''
    query ($id: Int) {
      Media(id: $id) {
        id
        title { romaji english }
        format
        genres
        description(asHtml: false)
        episodes
        averageScore
        popularity
        favourites
        rankings { rank type allTime }
        status
        nextAiringEpisode {
          airingAt
          timeUntilAiring
          episode
        }
        bannerImage
        startDate { year month day }
        endDate { year month day }
        season
        seasonYear
        source
        duration
        coverImage { medium large }
        studios(isMain: true) { nodes { name } }
        trailer { id site thumbnail }
        isAdult
        characters(sort: [ROLE, RELEVANCE], perPage: 25) {
          edges {
            role
            node {
              id
              name { full }
              image { medium }
            }
          }
        }
        recommendations(sort: RATING_DESC, perPage: 25) {
          nodes {
            mediaRecommendation {
              id
              title { romaji english }
              format
              status
              coverImage { medium large }
              isAdult
            }
          }
        }
        relations {
          edges {
            relationType
            node {
              id
              title { romaji english }
              format
              status
              coverImage { medium large }
              isAdult
            }
          }
        }
        externalLinks {
          id
          url
          site
          type
          icon
          color
        }
      }
    }
  ''';

  static const String characterQuery = r'''
    query ($id: Int) {
      Character(id: $id) {
        id
        name { full native alternative }
        image { large }
        description(asHtml: false)
        gender
        dateOfBirth { year month day }
        age
        bloodType
        siteUrl
        favourites
        media(sort: POPULARITY_DESC, type: ANIME, perPage: 10) {
          nodes {
            id
            title { romaji }
            coverImage { medium }
            isAdult
          }
        }
      }
    }
  ''';

  // ------------ GENERIC FETCH FUNCTION ------------
  static Future<List<dynamic>> _fetch(
    String query, {
    Map<String, dynamic>? variables,
    FetchPolicy fetchPolicy = FetchPolicy.networkOnly,
  }) async {
    // Get adult content preference
    final showAdult = await _showAdult();

    // Build final variables
    final finalVariables = Map<String, dynamic>.from(variables ?? {});

    // 🔥 Server-side optimization: when toggle is OFF, tell API to skip adult content
    // This cuts payload size significantly for popular lists
    if (!showAdult) {
      finalVariables['isAdult'] = false;
    }
    // When toggle is ON, don't pass isAdult - API returns everything

    final opts = QueryOptions(
      document: gql(query),
      variables: finalVariables,
      fetchPolicy: fetchPolicy,
    );

    try {
      final result = await client().query(opts);

      if (result.hasException) {
        debugPrint('AniList API Error: ${result.exception}');
        return [];
      }

      final page = result.data?['Page'];
      if (page == null) return [];
      final media = page['media'];
      if (media == null) return [];

      var list = List<dynamic>.from(media);

      // 🔥 Client-side filtering as fallback (only needed when toggle is ON)
      // When toggle is OFF, server already filtered, but double-check just in case
      if (!showAdult) {
        list = list
            .where((item) => (item['isAdult'] as bool?) != true)
            .toList();
      }

      return list;
    } catch (e, st) {
      debugPrint('AniList fetch failed: $e\n$st');
      return [];
    }
  }

  // ------------ MULTI-PAGE FETCH (merge pages) ------------

  static Future<List<dynamic>> _fetchMultiplePages(
    String query, {
    int perPage = 50,
    int pages = 2,
    Map<String, dynamic>? otherVariables,
  }) async {
    final List<Future<List<dynamic>>> futures = [];

    for (var p = 1; p <= pages; p++) {
      final vars = <String, dynamic>{'page': p, 'perPage': perPage};
      if (otherVariables != null) vars.addAll(otherVariables);
      futures.add(
        _fetch(query, variables: vars, fetchPolicy: FetchPolicy.networkOnly),
      );
    }

    final results = await Future.wait(futures);

    final combined = <dynamic>[];
    for (final pageData in results) {
      // Fail-soft: add whatever we got from successful pages
      if (pageData.isNotEmpty) {
        combined.addAll(pageData);
      }
    }

    return combined;
  }

  // ------------ PUBLIC FUNCTIONS ------------
  static Future<List<dynamic>> searchAnime(
    String name, {
    int page = 1,
    int perPage = 50,
  }) async => _fetch(
    searchQuery,
    variables: {'search': name, 'page': page, 'perPage': perPage},
  );

  static Future<List<dynamic>> getTopAnime() async =>
      _fetchMultiplePages(topAnimeQuery, perPage: 50, pages: 2);

  static Future<List<dynamic>> getPopularAnime() async =>
      _fetchMultiplePages(popularAnimeQuery, perPage: 50, pages: 2);

  static Future<List<dynamic>> getUpcomingAnime() async =>
      _fetchMultiplePages(upcomingAnimeQuery, perPage: 50, pages: 2);

  static Future<List<dynamic>> getAiringAnime() async =>
      _fetchMultiplePages(airingAnimeQuery, perPage: 50, pages: 2);

  static Future<List<dynamic>> getTopMovies() async =>
      _fetchMultiplePages(topMoviesQuery, perPage: 50, pages: 2);

  static Future<List<dynamic>> getAnimeByGenre(String genre) async =>
      _fetchMultiplePages(
        genreQuery,
        perPage: 50,
        pages: 2,
        otherVariables: {'genre': genre.trim()},
      );

  static Future<List<dynamic>> getAnimeBySeason(
    int year,
    String season,
  ) async => _fetchMultiplePages(
    seasonQuery,
    perPage: 50,
    pages: 2,
    otherVariables: {'season': season, 'seasonYear': year},
  );

  static Future<Map<String, dynamic>?> getCharacterDetails(int id) async {
    final opts = QueryOptions(
      document: gql(characterQuery),
      variables: {'id': id},
      fetchPolicy: FetchPolicy.networkOnly,
    );

    try {
      final result = await client().query(opts);

      if (result.hasException) {
        debugPrint('AniList API Error: ${result.exception}');
        return null;
      }

      final character = result.data?['Character'];
      if (character == null) return null;

      // 🔥 Client-side filtering for adult content in character's media
      final showAdult = await _showAdult();

      if (!showAdult) {
        final media = character['media'];
        if (media != null) {
          final nodes = media['nodes'] as List<dynamic>?;
          if (nodes != null) {
            final filteredNodes = nodes
                .where((n) => (n['isAdult'] as bool?) != true)
                .toList();
            media['nodes'] = filteredNodes;
          }
        }
      }

      return character;
    } catch (e, st) {
      debugPrint('AniList fetch failed: $e\n$st');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getAnimeDetails(int id) async {
    final opts = QueryOptions(
      document: gql(mediaDetailQuery),
      variables: {'id': id},
      fetchPolicy: FetchPolicy.networkOnly,
    );

    try {
      final result = await client().query(opts);

      if (result.hasException) {
        debugPrint('AniList API Error: ${result.exception}');
        return null;
      }

      return result.data?['Media'];
    } catch (e, st) {
      debugPrint('AniList fetch failed: $e\n$st');
      return null;
    }
  }

  static const String airingScheduleQuery = r'''
    query ($start: Int, $end: Int, $page: Int, $perPage: Int) {
      Page(page: $page, perPage: $perPage) {
        airingSchedules(airingAt_greater: $start, airingAt_lesser: $end, sort: TIME) {
          id
          episode
          airingAt
          media {
            id
            title { romaji english }
            coverImage { large medium }
            format
            genres
            status
            averageScore
            episodes
            isAdult
            nextAiringEpisode {
              airingAt
              episode
            }
          }
        }
      }
    }
  ''';

  static Future<List<dynamic>> getAiringSchedule({
    required int start,
    required int end,
    int page = 1,
    int perPage = 50,
  }) async {
    final opts = QueryOptions(
      document: gql(airingScheduleQuery),
      variables: {'start': start, 'end': end, 'page': page, 'perPage': perPage},
      fetchPolicy: FetchPolicy.networkOnly,
    );

    try {
      final result = await client().query(opts);

      if (result.hasException) {
        debugPrint('AniList API Error: ${result.exception}');
        return [];
      }

      final pageData = result.data?['Page'];
      if (pageData == null) return [];
      final schedules = pageData['airingSchedules'];
      if (schedules == null) return [];

      var list = List<dynamic>.from(schedules);

      // 🔥 Client-side Adult Content Filter
      final showAdult = await _showAdult();

      if (!showAdult) {
        list = list.where((item) {
          final media = item['media'];
          return media != null && (media['isAdult'] as bool?) != true;
        }).toList();
      }

      return list;
    } catch (e, st) {
      debugPrint('AniList fetch failed: $e\n$st');
      return [];
    }
  }
}
