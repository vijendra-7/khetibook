import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/news_provider.dart';
import '../providers/system_config_provider.dart';
import '../widgets/news_section.dart';
import '../widgets/news_video_player.dart';

class NewsScreen extends StatefulWidget {
  final bool isActive;
  const NewsScreen({super.key, this.isActive = true});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final gu = context.watch<SettingsProvider>().isGujarati;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: cs.surfaceContainerLowest,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              floating: true,
              pinned: true,
              snap: true,
              centerTitle: true,
              elevation: 0,
              scrolledUnderElevation: 2,
              title: Text(
                gu ? 'ખેતી સમાચાર' : 'Agri News',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: -0.5,
                ),
              ),
              backgroundColor: cs.surfaceContainerLowest,
              surfaceTintColor: cs.surfaceContainerLowest,
              bottom: TabBar(
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                indicatorColor: cs.primary,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 4,
                labelColor: cs.primary,
                unselectedLabelColor: cs.onSurfaceVariant,
                onTap: (_) => HapticFeedback.selectionClick(),
                tabs: [
                  Tab(text: gu ? 'ગુજરાતી' : 'Gujarati'),
                  Tab(text: gu ? 'હિન્દી' : 'Hindi'),
                ],
              ),
            ),
            if (context.watch<SystemConfigProvider>().newsHeroMode == 'video' && context.watch<SystemConfigProvider>().newsHeroYoutubeUrl.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: NewsVideoPlayer(
                    youtubeUrl: context.read<SystemConfigProvider>().newsHeroYoutubeUrl,
                    isActive: widget.isActive,
                  ),
                ),
              ),
          ],
          body: TabBarView(
            children: [
              _NewsList(isGujarati: true, isActive: widget.isActive),
              _NewsList(isGujarati: false, isActive: widget.isActive),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsList extends StatelessWidget {
  final bool isGujarati;
  final bool isActive;
  const _NewsList({required this.isGujarati, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context.read<NewsProvider>().fetchNews(forceRefresh: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: NewsSection(
              isVertical: true, 
              showLabel: false,
              forcedLanguage: isGujarati ? 'gu' : 'hi',
              isActive: isActive,
              hideVideoHero: true,
            ),
          ),
        ],
      ),
    );
  }
}
