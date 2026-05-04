import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class ReviewService {
  static final InAppReview _inAppReview = InAppReview.instance;

  // Keys for SharedPreferences
  static const String _keyAnimeAddedCount = 'review_anime_added_count';
  static const String _keyEpisodesWatchedCount = 'review_episodes_watched_count';
  static const String _keyFirstOpenDate = 'review_first_open_date';
  static const String _keyLastRequestDate = 'review_last_request_date';
  static const String _keyHasReviewed = 'review_has_reviewed';

  /// Initialize the service (sets first open date if not set)
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_keyFirstOpenDate) == null) {
      await prefs.setString(
        _keyFirstOpenDate,
        DateTime.now().toIso8601String(),
      );
    }
  }

  /// Increment the count of anime added to list
  static Future<void> incrementAnimeAddedCount() async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt(_keyAnimeAddedCount) ?? 0;
    await prefs.setInt(_keyAnimeAddedCount, current + 1);
    await _checkAndRequestReview();
  }

  /// Increment the count of episodes watched
  static Future<void> incrementEpisodesWatchedCount(int count) async {
    if (count <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt(_keyEpisodesWatchedCount) ?? 0;
    await prefs.setInt(_keyEpisodesWatchedCount, current + count);
    await _checkAndRequestReview();
  }

  /// Check if criteria are met and request a review if so
  static Future<void> _checkAndRequestReview() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Check if already reviewed
    if (prefs.getBool(_keyHasReviewed) ?? false) return;

    // 2. Check usage duration (at least 2 days)
    final firstOpenStr = prefs.getString(_keyFirstOpenDate);
    if (firstOpenStr == null) return;
    final firstOpenDate = DateTime.parse(firstOpenStr);
    final daysSinceFirstOpen = DateTime.now().difference(firstOpenDate).inDays;
    if (daysSinceFirstOpen < 2) return;

    // 3. Check activity thresholds
    final animeAdded = prefs.getInt(_keyAnimeAddedCount) ?? 0;
    final episodesWatched = prefs.getInt(_keyEpisodesWatchedCount) ?? 0;

    // Logic: 3+ anime added OR 5+ episodes watched
    bool criteriaMet = animeAdded >= 3 || episodesWatched >= 5;
    if (!criteriaMet) return;

    // 4. Check last request date (avoid spamming, e.g., once every 90 days)
    final lastRequestStr = prefs.getString(_keyLastRequestDate);
    if (lastRequestStr != null) {
      final lastRequestDate = DateTime.parse(lastRequestStr);
      final daysSinceLastRequest =
          DateTime.now().difference(lastRequestDate).inDays;
      if (daysSinceLastRequest < 90) return;
    }

    // 5. Trigger review request
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        await prefs.setString(
          _keyLastRequestDate,
          DateTime.now().toIso8601String(),
        );
      }
    } catch (e) {
      debugPrint('Error requesting review: $e');
    }
  }

  /// Manually open the store for rating (Android Play Store)
  static Future<void> openStoreListing() async {
    try {
      if (Platform.isAndroid) {
        if (await _inAppReview.isAvailable()) {
          await _inAppReview.openStoreListing();
        } else {
          // Fallback to url_launcher if in_app_review fails
          final String packageName = 'com.aniflux.app';
          final Uri url = Uri.parse('market://details?id=$packageName');

          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          } else {
            // Web fallback if market:// fails
            final Uri webUrl = Uri.parse(
              'https://play.google.com/store/apps/details?id=$packageName',
            );
            await launchUrl(webUrl, mode: LaunchMode.externalApplication);
          }
        }
      }
    } catch (e) {
      debugPrint('Error opening store listing: $e');
    }
  }
}
