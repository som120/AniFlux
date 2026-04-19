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
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    await FlutterDisplayMode.setHighRefreshRate();
  } catch (e) {
    // Ignore errors
  }

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
      debugShowCheckedModeBanner: false,
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
  DateTime? _lastBackPressTime;
  late SharedPreferences _prefs;

  final List<Widget> _screens = const [
    HomeScreen(key: PageStorageKey('home_key')),
    SearchScreen(key: PageStorageKey('search_key')),
    ProfileScreen(key: PageStorageKey('profile_key')),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentIndex = 0;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _prefs.setInt('last_tab', _currentIndex);
    }
    if (state == AppLifecycleState.resumed) {
      setState(() {});
    }
  }

  Future<bool> _handleBackPress() async {
    if (_currentIndex != 0) {
      if (mounted) {
        setState(() => _currentIndex = 0);
      }
      await _prefs.setInt('last_tab', 0);
      return false;
    }

    final now = DateTime.now();

    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;

      if (mounted) {
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
                      color: Colors.white.withValues(alpha: 0.2),
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
      }
      return false;
    }

    await SystemNavigator.pop();
    return false;
  }

  void _updateSystemNavBar(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        systemNavigationBarColor: isDark ? Colors.black : Colors.white,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double rawInset = MediaQuery.paddingOf(context).bottom;
    final double bottomInset = rawInset == 0 ? 12.0 : rawInset;

    _updateSystemNavBar(context);

    // REVERTED TO WILLPOPSCOPE AS REQUESTED
    return WillPopScope(
      onWillPop: _handleBackPress,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        body: Stack(
          children: [
            Positioned.fill(
              child: IndexedStack(
                key: const PageStorageKey('main_stack_key'),
                index: _currentIndex,
                children: _screens,
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 80,
              child: IgnorePointer(
                ignoring: true,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white12,
                        Colors.white60,
                        Colors.white,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.3, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              left: 20,
              right: 20,
              bottom: bottomInset,
              child: RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF714FDC,
                            ).withValues(alpha: 0.2),
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
                          _NavItem(
                            icon: Icons.home_rounded,
                            label: "Home",
                            index: 0,
                            currentIndex: _currentIndex,
                            onTap: (idx) => setState(() => _currentIndex = idx),
                          ),
                          _NavItem(
                            icon: Icons.search_rounded,
                            label: "Search",
                            index: 1,
                            currentIndex: _currentIndex,
                            onTap: (idx) => setState(() => _currentIndex = idx),
                          ),
                          _NavItem(
                            icon: Icons.person_rounded,
                            label: "Profile",
                            index: 2,
                            currentIndex: _currentIndex,
                            onTap: (idx) => setState(() => _currentIndex = idx),
                          ),
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
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool active = currentIndex == index;

    return AnimatedScale(
      duration: const Duration(milliseconds: 200),
      scale: active ? 1.15 : 1.0,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap(index);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: active
                  ? const Color(0xFF714FDC).withValues(alpha: 0.2)
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
                    decoration: const BoxDecoration(
                      color: Color(0xFF714FDC),
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
}
