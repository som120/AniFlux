import 'dart:ui';

import 'package:ainme_vault/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';

import 'package:flutter_displaymode/flutter_displaymode.dart';

// Screens
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/profile_screen.dart';
//import 'firestore_test_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    await FlutterDisplayMode.setHighRefreshRate();
  } catch (e) {
    // Ignore errors if platform doesn't support it
  }

  // Register AniFlux MIT license to show properly in license page
  LicenseRegistry.addLicense(() async* {
    final licenseText = await rootBundle.loadString(
      'assets/licenses/MIT_LICENSE.txt',
    );
    yield LicenseEntryWithLineBreaks(['AniFlux'], licenseText);
  });

  runApp(const AnimeVaultApp());
}

class AnimeVaultApp extends StatelessWidget {
  const AnimeVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AniFlux',
      theme: AppTheme.lightTheme,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  double scrollOpacity = 0.18;

  DateTime? _lastBackPressTime;
  late SharedPreferences _prefs;

  // Screens used in bottom navigation
  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    ProfileScreen(),
  ];
  Widget navItem(IconData icon, String label, int index) {
    bool active = _currentIndex == index;

    return AnimatedScale(
      duration: const Duration(milliseconds: 200),
      scale: active ? 1.15 : 1.0, // BOUNCE ANIMATION
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _currentIndex = index);
          },

          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: active
                  ? const Color(0xFF714FDC).withOpacity(0.2)
                  : Colors.transparent,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: active ? 22 : 24,
                  color: active ? const Color(0xFF714FDC) : Colors.white,
                ),
                if (active) ...[
                  const SizedBox(height: 2),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFF714FDC),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();

    // ❗ Always start from Home on cold start
    setState(() {
      _currentIndex = 0;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App sent to background → save last tab
      _prefs.setInt('last_tab', _currentIndex);
    }

    if (state == AppLifecycleState.resumed) {
      // Force rebuild so BackdropFilter reapplies blur
      setState(() {});
    }
  }

  Future<bool> _handleBackPress() async {
    // If not on Home → go to Home
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      await _prefs.setInt('last_tab', 0);
      return false;
    }

    final now = DateTime.now();

    // First back press
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.exit_to_app_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Press back again to exit",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            elevation: 8,
            duration: const Duration(seconds: 2),
          ),
        );

      return false; // ⛔ don’t exit yet
    }

    // Second back press within 2 seconds → EXIT
    await SystemNavigator.pop();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBackPress,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: Colors.grey[100],
          body: Stack(
            children: [
              Positioned.fill(
                child: IndexedStack(index: _currentIndex, children: _screens),
              ),

              // Bottom progressive fade blur
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 80,
                child: IgnorePointer(
                  ignoring: true, // allows touches to pass through
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white12,
                          Colors.white60, // subtle fade
                          Colors.white, // full fade under nav bar
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.3, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              // Floating Rounded Nav Bar
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: RepaintBoundary(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(
                            0.18,
                          ), // transparent glass
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                            color: Colors.white.withOpacity(
                              0.5,
                            ), // glass border
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF714FDC,
                              ).withOpacity(0.2), // purple glow
                              blurRadius: 25,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),

                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            navItem(Icons.home_rounded, "Home", 0),
                            navItem(Icons.search_rounded, "Search", 1),
                            navItem(Icons.person_rounded, "Profile", 2),
                          ],
                        ),
                      ),
                    ),
                  ),
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
