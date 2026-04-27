# Graph Report - AniFlux  (2026-04-25)

## Corpus Check
- 60 files · ~436,411 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 584 nodes · 679 edges · 20 communities detected
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 12 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]

## God Nodes (most connected - your core abstractions)
1. `package:flutter/material.dart` - 25 edges
2. `package:ainme_vault/theme/app_theme.dart` - 14 edges
3. `package:firebase_auth/firebase_auth.dart` - 14 edges
4. `package:flutter/services.dart` - 13 edges
5. `package:cloud_firestore/cloud_firestore.dart` - 10 edges
6. `package:cached_network_image/cached_network_image.dart` - 8 edges
7. `Create()` - 7 edges
8. `AppDelegate` - 6 edges
9. `package:shared_preferences/shared_preferences.dart` - 6 edges
10. `package:url_launcher/url_launcher.dart` - 6 edges

## Surprising Connections (you probably didn't know these)
- `my_application_dispose()` --calls--> `dispose`  [INFERRED]
  linux/runner/my_application.cc → lib/widgets/anime_entry_bottom_sheet.dart
- `OnCreate()` --calls--> `RegisterPlugins()`  [INFERRED]
  windows/runner/flutter_window.cpp → windows/flutter/generated_plugin_registrant.cc
- `OnCreate()` --calls--> `Show()`  [INFERRED]
  windows/runner/flutter_window.cpp → windows/runner/win32_window.cpp
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  windows/runner/main.cpp → windows/runner/utils.cpp
- `wWinMain()` --calls--> `SetQuitOnClose()`  [INFERRED]
  windows/runner/main.cpp → windows/runner/win32_window.cpp

## Communities

### Community 0 - "Community 0"
Cohesion: 0.04
Nodes (56): package:ainme_vault/screens/character_detail_screen.dart, package:ainme_vault/screens/search_screen.dart, package:ainme_vault/utils/light_skeleton.dart, package:ainme_vault/widgets/anime_entry_bottom_sheet.dart, AnimeDetailScreen, _AnimeDetailScreenState, build, _buildCharactersTab (+48 more)

### Community 1 - "Community 1"
Cohesion: 0.04
Nodes (51): dart:convert, package:firebase_remote_config/firebase_remote_config.dart, package:flutter/cupertino.dart, package:http/http.dart, package:package_info_plus/package_info_plus.dart, package:url_launcher/url_launcher.dart, AboutScreen, _AboutScreenState (+43 more)

### Community 2 - "Community 2"
Cohesion: 0.05
Nodes (39): package:ainme_vault/main.dart, package:ainme_vault/screens/login_screen.dart, package:flutter/gestures.dart, package:flutter/material.dart, package:graphql_flutter/graphql_flutter.dart, package:shared_preferences/shared_preferences.dart, AuthWrapper, build (+31 more)

### Community 3 - "Community 3"
Cohesion: 0.05
Nodes (40): dart:io, package:cloud_firestore/cloud_firestore.dart, package:firebase_auth/firebase_auth.dart, package:firebase_messaging/firebase_messaging.dart, package:flutter/services.dart, AvatarPickerScreen, _AvatarPickerScreenState, build (+32 more)

### Community 4 - "Community 4"
Cohesion: 0.05
Nodes (42): dart:math, package:ainme_vault/services/app_update_service.dart, AnimatedContainer, AnimatedSwitcher, _AnimeCard, BoxConstraints, build, _buildCarouselError (+34 more)

### Community 5 - "Community 5"
Cohesion: 0.05
Nodes (41): ../screens/anime_detail_screen.dart, ../services/anilist_service.dart, build, _buildAnimeCard, _buildSkeletonCard, CalendarView, _CalendarViewState, Center (+33 more)

### Community 6 - "Community 6"
Cohesion: 0.05
Nodes (40): anime_detail_screen.dart, package:shimmer/shimmer.dart, _addToHistory, AnimatedContainer, AnimeListCard, AnimeListShimmer, build, buildAnimatedSearchBar (+32 more)

### Community 7 - "Community 7"
Cohesion: 0.05
Nodes (27): fl_register_plugins(), main(), my_application_activate(), my_application_dispose(), my_application_new(), package:ainme_vault/services/anilist_service.dart, package:intl/intl.dart, AnimeEntryBottomSheet (+19 more)

### Community 8 - "Community 8"
Cohesion: 0.09
Nodes (25): FlutterWindow(), OnCreate(), RegisterPlugins(), wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16(), Create() (+17 more)

### Community 9 - "Community 9"
Cohesion: 0.06
Nodes (31): dart:ui, firebase_options.dart, package:ainme_vault/providers/theme_provider.dart, package:firebase_core/firebase_core.dart, package:flutter_displaymode/flutter_displaymode.dart, package:flutter/foundation.dart, screens/home_screen.dart, screens/profile_screen.dart (+23 more)

### Community 10 - "Community 10"
Cohesion: 0.06
Nodes (30): ../main.dart, package:ainme_vault/screens/about_screen.dart, package:ainme_vault/utils/transitions.dart, package:ainme_vault/widgets/account_settings_bottom_sheet.dart, package:ainme_vault/widgets/avatar_picker_bottom_sheet.dart, package:ainme_vault/widgets/edit_profile_bottom_sheet.dart, package:cached_network_image/cached_network_image.dart, package:google_sign_in/google_sign_in.dart (+22 more)

### Community 11 - "Community 11"
Cohesion: 0.07
Nodes (27): package:ainme_vault/screens/forgot_password_screen.dart, package:ainme_vault/screens/signup_screen.dart, package:ainme_vault/services/notification_service.dart, package:ainme_vault/theme/app_theme.dart, build, _buildLabel, _buildSocialButton, _buildTextField (+19 more)

### Community 12 - "Community 12"
Cohesion: 0.08
Nodes (24): dart:async, package:ainme_vault/screens/anime_detail_screen.dart, package:connectivity_plus/connectivity_plus.dart, package:flutter_markdown/flutter_markdown.dart, build, _buildInfoItem, CharacterDetailScreen, _CharacterDetailScreenState (+16 more)

### Community 13 - "Community 13"
Cohesion: 0.09
Nodes (22): AccountSettingsBottomSheet, _AccountSettingsBottomSheetState, _actionTile, build, Color, Container, _dangerTile, _deleteAccountWithUser (+14 more)

### Community 14 - "Community 14"
Cohesion: 0.29
Nodes (2): AppDelegate, FlutterAppDelegate

### Community 15 - "Community 15"
Cohesion: 0.33
Nodes (3): RegisterGeneratedPlugins(), MainFlutterWindow, NSWindow

### Community 16 - "Community 16"
Cohesion: 0.4
Nodes (2): RunnerTests, XCTestCase

### Community 17 - "Community 17"
Cohesion: 0.4
Nodes (2): GeneratedPluginRegistrant, -registerWithRegistry

### Community 18 - "Community 18"
Cohesion: 0.5
Nodes (2): handle_new_rx_page(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.

### Community 19 - "Community 19"
Cohesion: 1.0
Nodes (1): MainActivity

## Knowledge Gaps
- **438 isolated node(s):** `-registerWithRegistry`, `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `MainActivity`, `DefaultFirebaseOptions`, `UnsupportedError` (+433 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 14`** (7 nodes): `AppDelegate`, `.application()`, `.applicationShouldTerminateAfterLastWindowClosed()`, `.applicationSupportsSecureRestorableState()`, `FlutterAppDelegate`, `AppDelegate.swift`, `AppDelegate.swift`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 16`** (5 nodes): `RunnerTests.swift`, `RunnerTests.swift`, `RunnerTests`, `.testExample()`, `XCTestCase`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 17`** (5 nodes): `GeneratedPluginRegistrant.java`, `GeneratedPluginRegistrant`, `.registerWith()`, `-registerWithRegistry`, `GeneratedPluginRegistrant.m`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 18`** (4 nodes): `handle_new_rx_page()`, `__lldb_init_module()`, `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `flutter_lldb_helper.py`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 19`** (2 nodes): `MainActivity.kt`, `MainActivity`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter/material.dart` connect `Community 2` to `Community 0`, `Community 1`, `Community 3`, `Community 4`, `Community 5`, `Community 6`, `Community 7`, `Community 9`, `Community 10`, `Community 11`, `Community 12`, `Community 13`?**
  _High betweenness centrality (0.282) - this node is a cross-community bridge._
- **Why does `package:flutter/services.dart` connect `Community 3` to `Community 0`, `Community 1`, `Community 2`, `Community 4`, `Community 5`, `Community 6`, `Community 7`, `Community 9`, `Community 11`, `Community 12`?**
  _High betweenness centrality (0.098) - this node is a cross-community bridge._
- **Why does `package:ainme_vault/theme/app_theme.dart` connect `Community 11` to `Community 0`, `Community 1`, `Community 2`, `Community 3`, `Community 4`, `Community 5`, `Community 7`, `Community 9`, `Community 10`, `Community 12`, `Community 13`?**
  _High betweenness centrality (0.097) - this node is a cross-community bridge._
- **What connects `-registerWithRegistry`, `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `MainActivity` to the rest of the system?**
  _438 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.04 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.04 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._