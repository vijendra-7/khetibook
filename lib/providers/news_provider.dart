import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/news.dart';
import '../services/news_service.dart';
import '../services/news_scraper_service.dart';

class NewsProvider with ChangeNotifier {
  List<News> _gujaratiNews = [];
  List<News> _hindiNews = [];
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Cache for enriched metadata to avoid re-scraping
  final Map<String, Map<String, String?>> _enrichedCache = {};
  // Track in-progress scraping to avoid duplicate requests
  final Set<String> _pendingEnrichment = {};

  List<News> get gujaratiNews => _gujaratiNews;
  List<News> get hindiNews => _hindiNews;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  NewsProvider() {
    // Stale-while-revalidate: load whatever is in the cache instantly
    // (ignoring the 1-hour freshness check) so the News tab has data
    // immediately on first open. fetchNews() will refresh in background.
    _preloadFromCache();
  }

  /// Silently load cached news from disk — no network, no loading state.
  /// Called once on construction so the News tab never starts with a spinner
  /// for returning users.
  Future<void> _preloadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guJson = prefs.getString(NewsService.cacheKeyGujarati);
      final hiJson = prefs.getString(NewsService.cacheKeyHindi);
      bool changed = false;
      if (guJson != null && _gujaratiNews.isEmpty) {
        _gujaratiNews = (jsonDecode(guJson) as List)
            .map((e) => News.fromJson(e as Map<String, dynamic>))
            .toList();
        changed = true;
      }
      if (hiJson != null && _hindiNews.isEmpty) {
        _hindiNews = (jsonDecode(hiJson) as List)
            .map((e) => News.fromJson(e as Map<String, dynamic>))
            .toList();
        changed = true;
      }
      if (changed) notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchNews({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final results = await Future.wait([
        NewsService.fetchGujaratiNews(forceRefresh: forceRefresh),
        NewsService.fetchHindiNews(forceRefresh: forceRefresh),
      ]);

      _gujaratiNews = results[0];
      _hindiNews = results[1];
      
      // Apply existing cache to fresh fetch
      _applyCacheToNewsList(_gujaratiNews);
      _applyCacheToNewsList(_hindiNews);
      
    } catch (e) {
      _errorMessage = 'Failed to load news';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _applyCacheToNewsList(List<News> newsList) {
    for (int i = 0; i < newsList.length; i++) {
      final cached = _enrichedCache[newsList[i].link];
      if (cached != null) {
        newsList[i] = _enrichItemWithData(newsList[i], cached);
      }
    }
  }

  News _enrichItemWithData(News item, Map<String, String?> data) {
    final newImageUrl = data['imageUrl'];
    final isJunk = NewsScraperService.isJunkImage(newImageUrl);
    
    return News(
      title: item.title,
      link: item.link,
      imageUrl: isJunk ? item.imageUrl : newImageUrl,
      date: item.date,
      description: data['description'] ?? item.description,
      source: item.source,
      pubDate: item.pubDate,
    );
  }

  /// Triggers background scraping for a specific news item if it lacks an image.
  Future<void> enrichNewsItem(News news) async {
    if (news.imageUrl != null && news.imageUrl!.startsWith('http')) return;
    if (_pendingEnrichment.contains(news.link)) return;

    _pendingEnrichment.add(news.link);

    try {
      final metadata = await NewsScraperService.scrapeMetadata(news.link);
      
      if (metadata.isNotEmpty) {
        _enrichedCache[news.link] = metadata;
        
        // Update the item in the local lists
        _updateItemInLists(news.link, metadata);
        notifyListeners();
      }
    } finally {
      _pendingEnrichment.remove(news.link);
    }
  }

  void _updateItemInLists(String link, Map<String, String?> metadata) {
    final guIdx = _gujaratiNews.indexWhere((e) => e.link == link);
    if (guIdx != -1) {
      _gujaratiNews[guIdx] = _enrichItemWithData(_gujaratiNews[guIdx], metadata);
    }

    final hiIdx = _hindiNews.indexWhere((e) => e.link == link);
    if (hiIdx != -1) {
      _hindiNews[hiIdx] = _enrichItemWithData(_hindiNews[hiIdx], metadata);
    }
  }
}
