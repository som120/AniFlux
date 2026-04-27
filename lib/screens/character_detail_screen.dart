import 'package:ainme_vault/services/anilist_service.dart';
import 'package:ainme_vault/theme/app_theme.dart';
import 'package:ainme_vault/screens/anime_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

class CharacterDetailScreen extends StatefulWidget {
  final int characterId;
  final String? placeholderName;
  final String? placeholderImage;

  const CharacterDetailScreen({
    super.key,
    required this.characterId,
    this.placeholderName,
    this.placeholderImage,
    this.scrollController,
  });

  final ScrollController? scrollController;

  @override
  State<CharacterDetailScreen> createState() => _CharacterDetailScreenState();
}

class _CharacterDetailScreenState extends State<CharacterDetailScreen> {
  bool isLoading = true;
  bool hasError = false;
  Map<String, dynamic>? character;
  bool isDescriptionExpanded = false;
  bool showSpoilers = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    if (!result.contains(ConnectivityResult.none) && hasError) {
      setState(() {
        isLoading = true;
        hasError = false;
      });
      _fetchDetails();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    try {
      final data = await AniListService.getCharacterDetails(widget.characterId);
      if (mounted) {
        if (data != null) {
          setState(() {
            character = data;
            isLoading = false;
            hasError = false;
          });
        } else {
          setState(() {
            isLoading = false;
            hasError = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
        });
      }
    }
  }

  Future<void> _handleLink(String href) async {
    final uri = Uri.tryParse(href);
    if (uri == null) return;

    // Handle AniList internal links for Characters
    final pathSegments = uri.pathSegments;
    if (uri.host.contains('anilist.co') && pathSegments.length >= 2) {
      final type = pathSegments[0]; // 'character'
      final id = int.tryParse(pathSegments[1]);

      if (id != null && type == 'character') {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CharacterDetailScreen(characterId: id),
            ),
          );
        }
        return;
      }
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name =
        character?['name']?['full'] ?? widget.placeholderName ?? "Unknown";
    final nativeName = character?['name']?['native'];
    final image = character?['image']?['large'] ?? widget.placeholderImage;
    String rawDescription =
        character?['description'] ?? "No description available.";
    String height = "Unknown";

    // Extract Height from description (looks for formats like __Height:__ 158 cm or Height: 158 cm)
    final heightRegex = RegExp(
      r'(?:__|\*\*)?Height:?(?:__|\*\*)?\s*([^\n\r]+)',
      caseSensitive: false,
    );
    final heightMatch = heightRegex.firstMatch(rawDescription);
    if (heightMatch != null) {
      height = heightMatch.group(1)?.trim() ?? "Unknown";
      // Remove the height line from description to avoid redundancy
      rawDescription = rawDescription.replaceFirst(heightRegex, '').trim();
    }

    // Handle Spoilers: AniList uses ~! ... !~
    // We wrap them in ~~ (strikethrough) which we will style as purple without a line
    final spoilerRegex = RegExp(r'~!(.*?)!~', dotAll: true);
    if (showSpoilers) {
      // Show text in special color
      rawDescription = rawDescription.replaceAllMapped(
        spoilerRegex,
        (match) => "~~${match.group(1) ?? ""}~~",
      );
    } else {
      // Hide with placeholder in special color
      rawDescription = rawDescription.replaceAll(
        spoilerRegex,
        "~~[Spoiler content hidden]~~",
      );
    }

    // Process description: strip HTML but keep markdown structure
    final description = rawDescription
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();
    final age = character?['age'] ?? "Unknown";
    final gender = character?['gender'] ?? "Unknown";
    final bloodType = character?['bloodType'] ?? "Unknown";
    final favourites = character?['favourites']?.toString() ?? "0";
    final dateOfBirth = character?['dateOfBirth'];
    String birthday = "Unknown";
    if (dateOfBirth != null &&
        dateOfBirth['month'] != null &&
        dateOfBirth['day'] != null) {
      birthday = "${dateOfBirth['month']}/${dateOfBirth['day']}";
      if (dateOfBirth['year'] != null) {
        birthday += "/${dateOfBirth['year']}";
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        controller: widget.scrollController,
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 350,
            pinned: true,
            backgroundColor: AppTheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 10)],
                ),
              ),
              centerTitle: true,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (image != null)
                    CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      memCacheWidth: 800,
                      memCacheHeight: 1200,
                      placeholder: (context, url) =>
                          Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                      errorWidget: (context, url, error) =>
                          Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                      fadeInDuration: const Duration(milliseconds: 300),
                    )
                  else
                    Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.2),
                          Colors.black.withValues(alpha: 0.8),
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (hasError)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 24,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: Colors.red[300],
                      size: 60,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Character info unavailable",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "We couldn't load the character details.\nPlease check your connection.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 15),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          isLoading = true;
                          hasError = false;
                        });
                        _fetchDetails();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text("Retry Connection"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (nativeName != null) ...[
                      Center(
                        child: Text(
                          nativeName,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                    ],

                    // Info Grid
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.black.withValues(alpha: 0.3)
                                : Colors.black.withValues(alpha: 0.08),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildInfoItem(
                                "Age",
                                age,
                                Icons.cake_rounded,
                                Colors.pinkAccent,
                              ),
                              _buildInfoItem(
                                "Gender",
                                gender,
                                Icons.person_rounded,
                                Colors.blueAccent,
                              ),
                              _buildInfoItem(
                                "Height",
                                height,
                                Icons.height_rounded,
                                Colors.greenAccent.shade700,
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            child: Divider(
                              indent: 20,
                              endIndent: 20,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildInfoItem(
                                "Birthday",
                                birthday,
                                Icons.calendar_today_rounded,
                                Colors.orangeAccent,
                              ),
                              _buildInfoItem(
                                "Blood",
                                bloodType,
                                Icons.bloodtype_rounded,
                                Colors.redAccent,
                              ),
                              _buildInfoItem(
                                "Favourites",
                                favourites,
                                Icons.favorite_rounded,
                                Colors.red,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    Row(
                      children: [
                        const Text(
                          "About",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              showSpoilers = !showSpoilers;
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: showSpoilers
                                  ? AppTheme.primary.withValues(alpha: 0.1)
                                  : Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: showSpoilers
                                    ? AppTheme.primary.withValues(alpha: 0.3)
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  showSpoilers
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                  size: 16,
                                  color: showSpoilers
                                      ? AppTheme.primary
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  showSpoilers
                                      ? "Hide Spoilers"
                                      : "Show Spoilers",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: showSpoilers
                                        ? AppTheme.primary
                                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRect(
                        child: !isDescriptionExpanded
                            ? SizedBox(
                                height: 140,
                                child: ShaderMask(
                                  shaderCallback: (rect) {
                                    return LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black,
                                        Colors.transparent,
                                      ],
                                      stops: const [0.7, 1.0],
                                    ).createShader(rect);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: SingleChildScrollView(
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    child: MarkdownBody(
                                      data: description,
                                      selectable: true,
                                      softLineBreak: true,
                                      styleSheet: MarkdownStyleSheet(
                                        p: TextStyle(
                                          fontSize: 16,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                          height: 1.6,
                                        ),
                                        del: TextStyle(
                                          color: AppTheme.primary,
                                          decoration: TextDecoration.none,
                                          fontWeight: FontWeight.normal,
                                          backgroundColor: AppTheme.primary
                                              .withValues(alpha: 0.05),
                                        ),
                                      ),
                                      onTapLink: (text, href, title) {
                                        if (href != null) {
                                          _handleLink(href);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              )
                            : MarkdownBody(
                                data: description,
                                selectable: true,
                                softLineBreak: true,
                                styleSheet: MarkdownStyleSheet(
                                  p: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                    height: 1.6,
                                  ),
                                  del: TextStyle(
                                    color: AppTheme.primary,
                                    decoration: TextDecoration.none,
                                    fontWeight: FontWeight.normal,
                                    backgroundColor: AppTheme.primary
                                        .withValues(alpha: 0.05),
                                  ),
                                ),
                                onTapLink: (text, href, title) {
                                  if (href != null) {
                                    _handleLink(href);
                                  }
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          isDescriptionExpanded = !isDescriptionExpanded;
                        });
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isDescriptionExpanded ? "Read Less" : "Read More",
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Icon(
                            isDescriptionExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: AppTheme.primary,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Appearances
                    if (character?['media']?['nodes'] != null &&
                        (character!['media']['nodes'] as List).isNotEmpty) ...[
                      const Text(
                        "Appearances",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        height: 200,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          cacheExtent: 300,
                          addRepaintBoundaries: true,
                          itemCount:
                              (character!['media']['nodes'] as List).length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 15),
                          itemBuilder: (context, index) {
                            final anime = character!['media']['nodes'][index];
                            final title =
                                anime['title']?['romaji'] ?? "Unknown";
                            final image = anime['coverImage']?['medium'];

                            return RepaintBoundary(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          AnimeDetailScreen(anime: anime),
                                    ),
                                  );
                                },
                                child: SizedBox(
                                  width: 120,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      image != null
                                          ? FadeInImageWidget(
                                              imageUrl: image,
                                              width: 120,
                                              height: 160,
                                            )
                                          : Container(
                                              width: 120,
                                              height: 160,
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                Icons.image,
                                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                              ),
                                            ),
                                      const SizedBox(height: 8),
                                      Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: SizedBox(
        height: 85, // Fixed height for consistent grid alignment
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Expanded(
              child: Center(
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: width,
        height: height,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: width,
          height: height,
          fit: BoxFit.cover,
          memCacheWidth: (width * 3).toInt(),
          placeholder: (context, url) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          errorWidget: (context, url, error) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.broken_image,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
          fadeInDuration: const Duration(milliseconds: 250),
        ),
      ),
    );
  }
}
