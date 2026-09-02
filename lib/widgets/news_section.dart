import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import '../models/news.dart';
import '../providers/settings_provider.dart';
import '../providers/news_provider.dart';
import '../providers/system_config_provider.dart';
import '../screens/news_detail_screen.dart';
import 'news_video_player.dart';

class NewsSection extends StatefulWidget {
  final bool isVertical;
  final bool showLabel;
  final String? forcedLanguage; // 'gu' or 'hi'
  final bool isActive;
  final bool hideVideoHero;

  const NewsSection({
    super.key,
    this.isVertical = false,
    this.showLabel = true,
    this.forcedLanguage,
    this.isActive = true,
    this.hideVideoHero = false,
  });

  @override
  State<NewsSection> createState() => _NewsSectionState();
}

class _NewsSectionState extends State<NewsSection> {
  bool _isGujaratiNews = true;
  
  // Cache for performance optimization
  List<dynamic>? _cachedFlattenedItems;
  Object? _lastGroupCacheKey;

  static const _monthsGu = [
    '', 'જાન્યુઆરી', 'ફેબ્રુઆરી', 'માર્ચ', 'એપ્રિલ', 'મે', 'જૂન',
    'જુલાઈ', 'ઓગસ્ટ', 'સપ્ટેમ્બર', 'ઓક્ટોબર', 'નવેમ્બર', 'ડિસેમ્બર'
  ];
  
  static const _engDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  static const _guDigits = ['૦', '૧', '૨', '૩', '૪', '૫', '૬', '૭', '૮', '૯'];

  @override
  void initState() {
    super.initState();
    // Default to Gujarati news if not forced
    _isGujaratiNews = widget.forcedLanguage == null ? true : (widget.forcedLanguage == 'gu');
    
    // Initial fetch if needed (caching handles freshness)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NewsProvider>().fetchNews();
    });
  }

  void _loadNews({bool forceRefresh = false}) {
    context.read<NewsProvider>().fetchNews(forceRefresh: forceRefresh);
  }

  List<dynamic> _getFlattenedNews(List<News> news) {
    // Generate a unique key for this grouping configuration
    final cacheKey = '${_isGujaratiNews}_${news.length}_${news.firstOrNull?.link}';
    if (_cachedFlattenedItems != null && _lastGroupCacheKey == cacheKey) {
      return _cachedFlattenedItems!;
    }

    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // Exclude the top 5 featured news
    final listForGrouping = widget.isVertical && news.length > 5 
        ? news.sublist(5) 
        : news;

    final sortedNews = listForGrouping
        .where((item) => item.pubDate == null || item.pubDate!.isAfter(thirtyDaysAgo))
        .toList()
      ..sort((a, b) {
        if (a.pubDate == null && b.pubDate == null) return 0;
        if (a.pubDate == null) return 1;
        if (b.pubDate == null) return -1;
        return b.pubDate!.compareTo(a.pubDate!);
      });

    final Map<String, List<News>> groups = {};
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var item in sortedNews) {
      String groupKey;
      if (item.pubDate == null) {
        groupKey = _isGujaratiNews ? 'અન્ય' : 'Other';
      } else {
        final date = DateTime(item.pubDate!.year, item.pubDate!.month, item.pubDate!.day);
        if (date == today) {
          groupKey = _isGujaratiNews ? 'આજે' : 'Today';
        } else if (date == yesterday) {
          groupKey = _isGujaratiNews ? 'ગઈકાલે' : 'Yesterday';
        } else {
          if (_isGujaratiNews) {
            String day = date.day.toString();
            String year = date.year.toString();
            
            for (int i = 0; i < 10; i++) {
              day = day.replaceAll(_engDigits[i], _guDigits[i]);
              year = year.replaceAll(_engDigits[i], _guDigits[i]);
            }
            groupKey = '$day ${_monthsGu[date.month]} $year';
          } else {
            groupKey = DateFormat('dd MMM yyyy').format(date);
          }
        }
      }
      groups.putIfAbsent(groupKey, () => []).add(item);
    }

    final result = <dynamic>[];
    for (var entry in groups.entries) {
      result.add(entry.key);
      result.addAll(entry.value);
    }

    _cachedFlattenedItems = result;
    _lastGroupCacheKey = cacheKey;
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gu = context.watch<SettingsProvider>().isGujarati;
    final newsProvider = context.watch<NewsProvider>();
    
    final effectiveIsGujarati = widget.forcedLanguage != null 
        ? widget.forcedLanguage == 'gu' 
        : _isGujaratiNews;
        
    final newsList = effectiveIsGujarati ? newsProvider.gujaratiNews : newsProvider.hindiNews;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.forcedLanguage == null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
              if (widget.showLabel)
                _SectionLabel(
                  label: 'Agricultural News',
                  guLabel: 'ખેતી સમાચાર',
                  isGujarati: gu,
                )
              else
                const SizedBox.shrink(),
              Row(
                children: [
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        _LangToggleItem(
                          label: 'ગુજરાતી',
                          isSelected: _isGujaratiNews,
                          onTap: () {
                            if (!_isGujaratiNews) {
                              setState(() => _isGujaratiNews = true);
                            }
                          },
                        ),
                        _LangToggleItem(
                          label: 'હિન્દી',
                          isSelected: !_isGujaratiNews,
                          onTap: () {
                            if (_isGujaratiNews) {
                              setState(() => _isGujaratiNews = false);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, size: 20, color: cs.primary),
                    onPressed: () => _loadNews(forceRefresh: true),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    style: IconButton.styleFrom(
                      backgroundColor: cs.surfaceContainerHigh,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      _buildContent(context, newsProvider, newsList, cs),
      ],
    );
  }

  String _getTimeAgo(DateTime? date, bool gu) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) {
      return gu ? '${diff.inMinutes} મિનિટ પહેલા' : '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return gu ? '${diff.inHours} કલાક પહેલા' : '${diff.inHours}h ago';
    } else {
      return DateFormat('dd MMM').format(date);
    }
  }

  Widget _buildContent(BuildContext context, NewsProvider newsProvider, List<News> newsList, ColorScheme cs) {
    if (newsProvider.isLoading && newsList.isEmpty) {
      return _buildShimmer(context);
    }
    if (newsProvider.errorMessage.isNotEmpty && newsList.isEmpty) {
      return _buildError(context);
    }
    if (newsList.isEmpty) {
       return _buildError(context);
    }

    final gu = context.read<SettingsProvider>().isGujarati;

    if (widget.isVertical) {
      final featured = newsList.take(5).toList();
      final flattened = _getFlattenedNews(newsList);
      final config = context.watch<SystemConfigProvider>();
      
      Widget heroWidget;
      final heroMode = config.newsHeroMode;
      final heroVideoUrl = config.newsHeroYoutubeUrl;

      if (heroMode == 'video' && heroVideoUrl.isNotEmpty && !widget.hideVideoHero) {
        heroWidget = Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: NewsVideoPlayer(
            youtubeUrl: heroVideoUrl,
            isActive: widget.isActive,
          ),
        );
      } else if (config.newsHeroMode == 'news') {
        heroWidget = Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _FeaturedCarousel(news: featured),
        );
      } else {
        heroWidget = const SizedBox.shrink(); // hidden
      }
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heroWidget,
          // Using spread with map instead of shrinkWrap ListView for better performance
          ...flattened.map((item) {
            if (item is String) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _GroupHeader(title: item),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0, left: 16.0, right: 16.0),
              child: _NewsCard(
                news: item as News, 
                isWide: true,
              ),
            );
          }),
        ],
      );
    }

    return SizedBox(
      height: 140, // Reduced height as no images
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: newsList.length,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return _NewsCard(
            news: newsList[index],
            timeAgo: _getTimeAgo(newsList[index].pubDate, gu),
          );
        },
      ),
    );
  }

  Widget _buildShimmer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    if (widget.isVertical) {
      return Column(
        children: [
          Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const SizedBox(height: 32),
          ...List.generate(4, (index) => Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              height: 80,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          )),
        ],
      );
    }
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(
            width: 260,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final gu = context.read<SettingsProvider>().isGujarati;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            Icon(Icons.rss_feed_rounded, size: 48, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              gu ? 'સમાચાર લોડ કરવામાં ભૂલ આવી' : 'Error loading news',
              style: TextStyle(color: Theme.of(context).colorScheme.outline, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedCarousel extends StatelessWidget {
  final List<News> news;
  const _FeaturedCarousel({required this.news});

  @override
  Widget build(BuildContext context) {
    if (news.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 220, // Restored height
      child: PageView.builder(
        itemCount: news.length,
        controller: PageController(viewportFraction: 0.92),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: _NewsCard(news: news[index], isFeatured: true),
          );
        },
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String title;
  const _GroupHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: cs.primary,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _LangToggleItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LangToggleItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _NewsCard extends StatefulWidget {
  final News news;
  final bool isWide;
  final bool isFeatured;
  final String? timeAgo;

  const _NewsCard({
    required this.news,
    this.isWide = false,
    this.isFeatured = false,
    this.timeAgo,
  });

  @override
  State<_NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<_NewsCard> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final news = widget.news;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NewsDetailScreen(news: news),
          ),
        );
      },
      child: Container(
        width: widget.isFeatured || widget.isWide ? double.infinity : 280,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24), // Original radius
          border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: widget.isFeatured 
            ? Container(
                padding: const EdgeInsets.all(24), // Restored padding
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primaryContainer.withOpacity(0.9),
                      cs.secondaryContainer.withOpacity(0.4),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSourceBadge(cs),
                    const SizedBox(height: 12),
                    Text(
                      news.title,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontSize: 22, // Restored font size
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              )
            : widget.isWide
                ? Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Text(
                              news.source?.toUpperCase() ?? 'NEWS',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: cs.onSecondaryContainer,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                news.title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 80,
                        width: double.infinity,
                        alignment: Alignment.center,
                        color: cs.secondaryContainer.withOpacity(0.3),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            news.source?.toUpperCase() ?? 'NEWS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: cs.onSecondaryContainer,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Text(
                          news.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSourceBadge(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        widget.news.source?.toUpperCase() ?? 'NEWS',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: cs.onSecondaryContainer,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final String guLabel;
  final bool isGujarati;

  const _SectionLabel({
    required this.label,
    required this.guLabel,
    required this.isGujarati,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.feed_rounded, size: 20, color: cs.primary),
        const SizedBox(width: 8),
        Text(
          isGujarati ? guLabel : label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

