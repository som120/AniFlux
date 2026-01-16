import 'package:ainme_vault/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ainme_vault/screens/contributors_screen.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '1.0.0';
  String _buildNumber = '1';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = packageInfo.version;
        _buildNumber = packageInfo.buildNumber;
      });
    }
  }

  bool _isCheckingUpdate = false;

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
                    Icons.error_outline,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Could not launch $urlString',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            elevation: 8,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://api.github.com/repos/som120/AniFlux/releases/latest',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String latestVersionTag = data['tag_name'];
        final String latestVersion = latestVersionTag.replaceAll('v', '');
        final String releaseUrl = data['html_url'];
        final String releaseBody =
            data['body'] ?? 'No release notes available.';

        // Simple version comparison logic
        // Assumes semantic versioning (x.y.z)
        if (_isNewerVersion(latestVersion, _version)) {
          _showUpdateDialog(latestVersion, releaseUrl, releaseBody);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
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
                        Icons.check_circle_outline,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "You're using the latest version!",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
                margin: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                elevation: 8,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        throw Exception('Failed to load releases');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
                    Icons.error_outline,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to check for updates: $e',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            elevation: 8,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }

  Future<List<dynamic>> _fetchGitHubReleases() async {
    final response = await http.get(
      Uri.parse('https://api.github.com/repos/som120/AniFlux/releases'),
      headers: {'Accept': 'application/vnd.github+json'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load releases');
    }
  }

  bool _isNewerVersion(String latest, String current) {
    List<String> latestParts = latest.split('.');
    List<String> currentParts = current.split('.');

    for (int i = 0; i < latestParts.length && i < currentParts.length; i++) {
      int latestPart = int.tryParse(latestParts[i]) ?? 0;
      int currentPart = int.tryParse(currentParts[i]) ?? 0;

      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }

    // If main parts are equal, check length (e.g., 1.0.1 > 1.0)
    return latestParts.length > currentParts.length;
  }

  void _showUpdateDialog(String version, String url, String notes) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "New Version Available",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 4),
            Text(
              "v$version",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.green,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("A new version of AniFlux is available!"),
              const SizedBox(height: 12),
              const Text(
                "Release Notes:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              MarkdownBody(
                data: notes,
                styleSheet: MarkdownStyleSheet(
                  h2: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  h3: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  p: const TextStyle(fontSize: 13, height: 1.5),
                  listIndent: 20,
                  blockSpacing: 8,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Later"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _launchUrl(url);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8A5CF6),
              foregroundColor: Colors.white,
            ),
            child: const Text("Update Now"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      appBar: AppBar(
        title: const Text(
          "About",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // App Icon and Name
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Image.asset(
                        'assets/icon/aniflux_logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.movie_filter,
                              size: 50,
                              color: Color(0xFF8A5CF6),
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "AniFlux",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Version $_version (Build $_buildNumber)",
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Links Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildListTile(
                      icon: Icons.update,
                      title: _isCheckingUpdate
                          ? "Checking..."
                          : "Check for Updates",
                      onTap: _isCheckingUpdate
                          ? () {}
                          : () {
                              _checkForUpdates();
                            },
                    ),
                    _buildListTile(
                      icon: Icons.history,
                      title: "Changelog",
                      onTap: () {
                        _showChangelog(context);
                      },
                    ),
                    _buildListTile(
                      icon: Icons.bug_report_outlined,
                      title: "Report a Bug",
                      onTap: () => _launchUrl(
                        "https://github.com/som120/AniFlux/issues",
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Community & Support Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildListTile(
                      icon: Icons.code,
                      title: "GitHub Repository",
                      onTap: () =>
                          _launchUrl("https://github.com/som120/AniFlux"),
                    ),
                    _buildListTile(
                      icon: Icons.people_outline,
                      title: "Contributors",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ContributorsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildListTile(
                      icon: Icons.coffee,
                      title: "Buy Me a Coffee",
                      iconColor: Colors.orange,
                      onTap: () =>
                          _launchUrl("https://buymeacoffee.com/sompaul"),
                    ),
                    _buildListTile(
                      icon: Icons.article_outlined,
                      title: "License",
                      onTap: () {
                        _showLicenseDialog();
                      },
                    ),
                    _buildListTile(
                      icon: Icons.privacy_tip_outlined,
                      title: "Privacy Policy",
                      onTap: () {
                        _showPrivacyPolicyDialog();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              "Made with ❤️ by Somnath",
              style: TextStyle(color: Colors.black45, fontSize: 12),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? const Color(0xFF8A5CF6)).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: iconColor ?? const Color(0xFF8A5CF6),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      onTap: onTap,
    );
  }

  void _showLicenseDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF8A5CF6),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Image.asset(
                        'assets/icon/aniflux_logo.png',
                        width: 48,
                        height: 48,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.movie_filter,
                              size: 48,
                              color: Color(0xFF8A5CF6),
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "AniFlux",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Version $_version",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),

              // License content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8A5CF6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "MIT License",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8A5CF6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Copyright (c) 2026 Somnath Paul",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the \"Software\"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:",
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.",
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.",
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Close button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8A5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Close",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF8A5CF6),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.privacy_tip_outlined,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Privacy Policy",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Last updated: January 2026",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),

              // Privacy Policy content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPrivacySection(
                        "Data Collection",
                        "AniFlux collects only the minimum data required for the app to function. This includes your saved anime lists, watch progress, and app preferences. Account-related information is collected only for authentication purposes and is not used for advertising or marketing.",
                        Icons.data_usage_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildPrivacySection(
                        "Data Storage & Security",
                        "Your data is securely stored using Firebase services, including Firestore and Firebase Authentication. Backend operations are handled using Appwrite Cloud Functions. Reasonable security measures are in place to protect your data from unauthorized access.",
                        Icons.cloud_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildPrivacySection(
                        "Third-Party Services",
                        "AniFlux uses third-party services to provide core functionality. Anime information is retrieved using the AniList API. Firebase is used for authentication and data storage, and Appwrite is used for backend processing. These services operate under their own privacy policies.",
                        Icons.link_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildPrivacySection(
                        "Your Rights",
                        "You have the right to access and delete your data at any time. You may request account and data deletion by using the in-app options or by contacting the developer. Upon request, your data will be permanently removed within a reasonable timeframe.",
                        Icons.shield_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildContactSection(),
                    ],
                  ),
                ),
              ),

              // Buttons row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    // View Online button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _launchUrl(
                            "https://ani-flux.vercel.app/privacy-policy",
                          );
                        },
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text(
                          "View Online",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8A5CF6),
                          side: const BorderSide(color: Color(0xFF8A5CF6)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Close button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8A5CF6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Close",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }

  Widget _buildPrivacySection(String title, String content, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF8A5CF6).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8A5CF6).withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF8A5CF6)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF8A5CF6).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8A5CF6).withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.email_outlined,
                size: 20,
                color: Color(0xFF8A5CF6),
              ),
              const SizedBox(width: 8),
              const Text(
                "Contact",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.black54,
              ),
              children: [
                const TextSpan(
                  text:
                      "If you have any questions or concerns regarding privacy or data usage, you can contact us at ",
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () {
                      _launchUrl("mailto:aniflux.dev@gmail.com");
                    },
                    child: const Text(
                      "aniflux.dev@gmail.com",
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Color(0xFF8A5CF6),
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFF8A5CF6),
                      ),
                    ),
                  ),
                ),
                const TextSpan(
                  text:
                      ". You may also report issues or request support via the AniFlux GitHub repository.",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showChangelog(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final releases = await _fetchGitHubReleases();

      if (!mounted) return;
      Navigator.pop(context); // close loading dialog

      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 20, 24, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Changelog",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Content - Flexible allows it to shrink when content is small
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: releases.length,
                      itemBuilder: (context, index) {
                        final release = releases[index];
                        final String tag = release['tag_name'] ?? '';
                        final String body =
                            release['body'] ?? 'No release notes provided.';
                        final bool isCurrent =
                            tag.replaceAll('v', '') == _version;
                        final bool isLatest = index == 0;

                        return _buildReleaseItem(
                          tag,
                          body,
                          isCurrent,
                          isLatest,
                        );
                      },
                    ),
                  ),

                  // Actions
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Close"),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
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
                  Icons.error_outline,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Failed to load changelog",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 8,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildReleaseItem(
    String tag,
    String body,
    bool isCurrent,
    bool isLatest,
  ) {
    // Ensure tag has 'v' prefix
    final String displayTag = tag.startsWith('v') ? tag : 'v$tag';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                displayTag,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isLatest
                      ? AppTheme.green
                      : (isCurrent ? AppTheme.primary : Colors.black),
                ),
              ),
              if (isLatest)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "Latest",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.green,
                      ),
                    ),
                  ),
                ),
              if (isCurrent && !isLatest)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "Current",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          /// ✅ THIS is where Markdown goes
          MarkdownBody(
            data: body,
            styleSheet: MarkdownStyleSheet(
              h2: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              h3: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              p: const TextStyle(fontSize: 13, height: 1.5),
              listIndent: 24,
              blockSpacing: 10,
            ),
          ),

          const Divider(height: 24),
        ],
      ),
    );
  }
}
