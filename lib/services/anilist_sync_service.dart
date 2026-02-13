import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'anilist_auth_service.dart';

/// Service to sync anime list between AniList and Firebase.
///
/// This service fetches the user's anime list from AniList and
/// imports it into their Firebase account.
class AniListSyncService {
  static const String _graphqlUrl = 'https://graphql.anilist.co';

  /// Status mapping from AniList to our app
  static const Map<String, String> _statusMap = {
    'CURRENT': 'Watching',
    'COMPLETED': 'Completed',
    'PLANNING': 'Planning',
    'DROPPED': 'Planning', // Map dropped to planning
    'PAUSED': 'Watching', // Map paused to watching
    'REPEATING': 'Watching', // Map rewatching to watching
  };

  /// Reverse status mapping from our app to AniList
  static const Map<String, String> _reverseStatusMap = {
    'Watching': 'CURRENT',
    'Completed': 'COMPLETED',
    'Planning': 'PLANNING',
  };

  /// Sync a single anime entry TO AniList
  /// Call this after saving an anime to Firebase
  static Future<bool> syncToAniList({
    required int mediaId,
    required String status,
    required int progress,
    DateTime? startDate,
    DateTime? finishDate,
  }) async {
    final token = await AniListAuthService.getAccessToken();
    if (token == null) {
      debugPrint('⚠️ Not logged in to AniList, skipping sync');
      return false;
    }

    final anilistStatus = _reverseStatusMap[status] ?? 'PLANNING';

    // Build the mutation
    const mutation = '''
      mutation SaveMediaListEntry(
        \$mediaId: Int!,
        \$status: MediaListStatus,
        \$progress: Int,
        \$startedAt: FuzzyDateInput,
        \$completedAt: FuzzyDateInput
      ) {
        SaveMediaListEntry(
          mediaId: \$mediaId,
          status: \$status,
          progress: \$progress,
          startedAt: \$startedAt,
          completedAt: \$completedAt
        ) {
          id
          mediaId
          status
          progress
        }
      }
    ''';

    // Build variables
    final variables = <String, dynamic>{
      'mediaId': mediaId,
      'status': anilistStatus,
      'progress': progress,
    };

    if (startDate != null) {
      variables['startedAt'] = {
        'year': startDate.year,
        'month': startDate.month,
        'day': startDate.day,
      };
    }

    if (finishDate != null) {
      variables['completedAt'] = {
        'year': finishDate.year,
        'month': finishDate.month,
        'day': finishDate.day,
      };
    }

    try {
      debugPrint(
        '🔄 Syncing to AniList: mediaId=$mediaId, status=$anilistStatus, progress=$progress',
      );

      final response = await http.post(
        Uri.parse(_graphqlUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'query': mutation, 'variables': variables}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['errors'] != null) {
          debugPrint('❌ AniList sync error: ${data['errors']}');
          return false;
        }
        debugPrint('✅ Synced to AniList successfully!');
        return true;
      } else {
        debugPrint(
          '❌ AniList sync failed: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('❌ AniList sync exception: $e');
      return false;
    }
  }

  /// Delete an anime entry from AniList
  static Future<bool> deleteFromAniList({required int mediaId}) async {
    debugPrint('🗑️ deleteFromAniList called with mediaId: $mediaId');

    final token = await AniListAuthService.getAccessToken();
    if (token == null) {
      debugPrint('⚠️ Not logged in to AniList, skipping delete');
      return false;
    }

    debugPrint('🔑 Got AniList token, proceeding with delete...');

    // Get the user's ID first
    final userInfo = await AniListAuthService.getStoredUserInfo();
    final userId = userInfo['userId'];
    if (userId == null) {
      debugPrint('❌ No AniList user ID found');
      return false;
    }

    // First, we need to get the list entry ID for this media (for THIS user)
    const getEntryQuery = '''
      query GetMediaListEntry(\$mediaId: Int!, \$userId: Int!) {
        MediaList(mediaId: \$mediaId, userId: \$userId) {
          id
        }
      }
    ''';

    try {
      debugPrint('📤 Fetching entry ID for mediaId: $mediaId, userId: $userId');

      // Get the entry ID
      final getResponse = await http.post(
        Uri.parse(_graphqlUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'query': getEntryQuery,
          'variables': {'mediaId': mediaId, 'userId': int.parse(userId)},
        }),
      );

      debugPrint('📥 Get entry response: ${getResponse.statusCode}');
      debugPrint('📥 Get entry body: ${getResponse.body}');

      if (getResponse.statusCode != 200) {
        debugPrint('❌ Failed to get AniList entry: ${getResponse.body}');
        return false;
      }

      final getData = jsonDecode(getResponse.body);
      final entryId = getData['data']?['MediaList']?['id'];

      if (entryId == null) {
        debugPrint(
          '⚠️ Anime not found in AniList (mediaId: $mediaId), nothing to delete',
        );
        return true; // Not an error, just doesn't exist
      }

      debugPrint('🎯 Found entry ID: $entryId, proceeding to delete...');

      // Now delete the entry
      const deleteMutation = '''
        mutation DeleteMediaListEntry(\$id: Int!) {
          DeleteMediaListEntry(id: \$id) {
            deleted
          }
        }
      ''';

      final deleteResponse = await http.post(
        Uri.parse(_graphqlUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'query': deleteMutation,
          'variables': {'id': entryId},
        }),
      );

      debugPrint('📥 Delete response: ${deleteResponse.statusCode}');
      debugPrint('📥 Delete body: ${deleteResponse.body}');

      if (deleteResponse.statusCode == 200) {
        final deleteData = jsonDecode(deleteResponse.body);
        if (deleteData['data']?['DeleteMediaListEntry']?['deleted'] == true) {
          debugPrint('✅ Deleted from AniList successfully!');
          return true;
        }
      }

      debugPrint('❌ AniList delete failed: ${deleteResponse.body}');
      return false;
    } catch (e) {
      debugPrint('❌ AniList delete exception: $e');
      return false;
    }
  }

  /// Fetch all anime from user's AniList account
  /// Returns a list of anime entries with their details
  static Future<List<Map<String, dynamic>>> fetchUserAnimeList({
    void Function(int current, int total)? onProgress,
  }) async {
    final token = await AniListAuthService.getAccessToken();
    if (token == null) {
      throw Exception('Not logged in to AniList');
    }

    final userInfo = await AniListAuthService.getStoredUserInfo();
    final userId = userInfo['userId'];
    if (userId == null) {
      throw Exception('AniList user ID not found');
    }

    final List<Map<String, dynamic>> allAnime = [];
    bool hasNextPage = true;
    int page = 1;
    int totalFetched = 0;

    debugPrint('📥 Starting AniList anime list fetch...');

    while (hasNextPage) {
      final query = '''
        query (\$userId: Int!, \$page: Int!) {
          Page(page: \$page, perPage: 50) {
            pageInfo {
              hasNextPage
              total
            }
            mediaList(userId: \$userId, type: ANIME) {
              id
              status
              progress
              score(format: POINT_10)
              startedAt { year month day }
              completedAt { year month day }
              updatedAt
              media {
                id
                title { english romaji }
                episodes
                averageScore
                format
                seasonYear
                duration
                status
                coverImage { large medium }
              }
            }
          }
        }
      ''';

      try {
        final response = await http.post(
          Uri.parse(_graphqlUrl),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'query': query,
            'variables': {'userId': int.parse(userId), 'page': page},
          }),
        );

        if (response.statusCode != 200) {
          debugPrint('❌ AniList API error: ${response.body}');
          throw Exception(
            'Failed to fetch anime list (${response.statusCode})',
          );
        }

        final data = jsonDecode(response.body);
        final pageData = data['data']?['Page'];

        if (pageData == null) {
          debugPrint('❌ Invalid response structure');
          break;
        }

        final mediaList = pageData['mediaList'] as List<dynamic>? ?? [];
        final pageInfo = pageData['pageInfo'];
        final total = pageInfo?['total'] ?? 0;

        for (final entry in mediaList) {
          allAnime.add(Map<String, dynamic>.from(entry));
        }

        totalFetched = allAnime.length;
        onProgress?.call(totalFetched, total);

        hasNextPage = pageInfo?['hasNextPage'] ?? false;
        page++;

        debugPrint(
          '📄 Page $page: Fetched ${mediaList.length} entries (Total: $totalFetched)',
        );

        // Small delay to avoid rate limiting
        if (hasNextPage) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      } catch (e) {
        debugPrint('❌ Error fetching page $page: $e');
        rethrow;
      }
    }

    debugPrint('✅ Fetched ${allAnime.length} anime from AniList');
    return allAnime;
  }

  /// Import anime list from AniList to Firebase
  ///
  /// [mode] can be:
  /// - 'merge': Add new entries, update existing ones
  /// - 'replace': Delete all Firebase entries first, then import
  /// - 'addNew': Only add entries that don't exist in Firebase
  static Future<ImportResult> importToFirebase({
    required String mode,
    void Function(int current, int total, String currentTitle)? onProgress,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not logged in to Firebase');
    }

    // Fetch anime list from AniList
    final anilistEntries = await fetchUserAnimeList(
      onProgress: (current, total) {
        onProgress?.call(current, total, 'Fetching from AniList...');
      },
    );

    if (anilistEntries.isEmpty) {
      return ImportResult(added: 0, updated: 0, skipped: 0, failed: 0);
    }

    final firestore = FirebaseFirestore.instance;
    final animeCollection = firestore
        .collection('users')
        .doc(user.uid)
        .collection('anime');

    // Get existing Firebase entries if needed
    Set<String> existingIds = {};
    if (mode == 'addNew') {
      final snapshot = await animeCollection.get();
      existingIds = snapshot.docs.map((doc) => doc.id).toSet();
    }

    // Replace mode: delete all existing entries first
    if (mode == 'replace') {
      final snapshot = await animeCollection.get();
      final batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      debugPrint('🗑️ Cleared ${snapshot.docs.length} existing entries');
    }

    int added = 0;
    int updated = 0;
    int skipped = 0;
    int failed = 0;

    // Process in batches of 500 (Firestore limit)
    final batches = <WriteBatch>[];
    WriteBatch currentBatch = firestore.batch();
    int batchCount = 0;

    for (int i = 0; i < anilistEntries.length; i++) {
      final entry = anilistEntries[i];

      try {
        final media = entry['media'];
        if (media == null) continue;

        final animeId = media['id'].toString();
        final title =
            media['title']?['english'] ??
            media['title']?['romaji'] ??
            'Unknown';

        onProgress?.call(i + 1, anilistEntries.length, title);

        // Skip if addNew mode and entry exists
        if (mode == 'addNew' && existingIds.contains(animeId)) {
          skipped++;
          continue;
        }

        // Map AniList status to our status
        final anilistStatus = entry['status'] as String? ?? 'PLANNING';
        final ourStatus = _statusMap[anilistStatus] ?? 'Planning';

        // Parse dates
        DateTime? startDate;
        DateTime? finishDate;

        final startedAt = entry['startedAt'];
        if (startedAt != null && startedAt['year'] != null) {
          startDate = DateTime(
            startedAt['year'],
            startedAt['month'] ?? 1,
            startedAt['day'] ?? 1,
          );
        }

        final completedAt = entry['completedAt'];
        if (completedAt != null && completedAt['year'] != null) {
          finishDate = DateTime(
            completedAt['year'],
            completedAt['month'] ?? 1,
            completedAt['day'] ?? 1,
          );
        }

        // Calculate watch time
        final format = media['format'] as String?;
        final int episodeDuration;
        if (format == 'MOVIE') {
          episodeDuration = media['duration'] ?? 90;
        } else {
          episodeDuration = media['duration'] ?? 24;
        }

        final progress = entry['progress'] ?? 0;
        final watchMinutes = progress * episodeDuration;

        // Build Firebase document
        final data = <String, dynamic>{
          'id': media['id'],
          'title': title,
          'coverImage':
              media['coverImage']?['large'] ??
              media['coverImage']?['medium'] ??
              '',
          'status': ourStatus,
          'progress': progress,
          'totalEpisodes': media['episodes'] ?? 0,
          'averageScore': media['averageScore'],
          'lastUpdated': FieldValue.serverTimestamp(),
          'format': format,
          'seasonYear': media['seasonYear'],
          'episodeDuration': episodeDuration,
          'watchMinutes': watchMinutes,
          'importedFromAniList': true,
          'anilistUpdatedAt': entry['updatedAt'],
        };

        if (startDate != null) {
          data['startDate'] = Timestamp.fromDate(startDate);
        }
        if (finishDate != null) {
          data['finishDate'] = Timestamp.fromDate(finishDate);
        }

        // Add to batch
        final docRef = animeCollection.doc(animeId);
        currentBatch.set(docRef, data, SetOptions(merge: mode == 'merge'));
        batchCount++;

        // Check if entry existed for counting
        if (mode == 'merge' && existingIds.contains(animeId)) {
          updated++;
        } else {
          added++;
        }

        // Commit batch if we reach 500 operations
        if (batchCount >= 500) {
          batches.add(currentBatch);
          currentBatch = firestore.batch();
          batchCount = 0;
        }
      } catch (e) {
        debugPrint('❌ Failed to process entry: $e');
        failed++;
      }
    }

    // Add remaining batch
    if (batchCount > 0) {
      batches.add(currentBatch);
    }

    // Commit all batches
    for (final batch in batches) {
      await batch.commit();
    }

    debugPrint(
      '✅ Import complete: Added $added, Updated $updated, Skipped $skipped, Failed $failed',
    );

    return ImportResult(
      added: added,
      updated: updated,
      skipped: skipped,
      failed: failed,
    );
  }
}

/// Result of an import operation
class ImportResult {
  final int added;
  final int updated;
  final int skipped;
  final int failed;

  ImportResult({
    required this.added,
    required this.updated,
    required this.skipped,
    required this.failed,
  });

  int get total => added + updated + skipped + failed;

  @override
  String toString() {
    return 'ImportResult(added: $added, updated: $updated, skipped: $skipped, failed: $failed)';
  }
}
