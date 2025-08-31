import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/movies_provider.dart';
import '../../widgets/loading_shimmer.dart';
// Removed old vertical list MovieCard in favor of Netflix-style rows.

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MoviesProvider>().loadPopular();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MoviesProvider>();
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: provider.loadingPopular
          ? const _HomeLoading()
          : provider.popularError != null
              ? _HomeError(message: provider.popularError!, onRetry: () => context.read<MoviesProvider>().loadPopular())
              : RefreshIndicator(
                  onRefresh: () => provider.loadPopular(),
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _HeroBanner(
                          title: provider.popular.isNotEmpty ? (provider.popular.first.title ?? provider.popular.first.imdbId) : 'Featured',
                          backdropUrl: provider.popular.isNotEmpty ? (provider.popular.first.poster ?? '') : '',
                          onPlay: provider.popular.isNotEmpty
                              ? () => context.push('/movie/${provider.popular.first.imdbId}')
                              : null,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text('Popular on Movie Social', style: Theme.of(context).textTheme.titleLarge),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 220,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: provider.popular.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final m = provider.popular[index];
                              return _PosterTile(
                                title: m.title ?? m.imdbId,
                                posterUrl: m.poster ?? '',
                                onTap: () => context.push('/movie/${m.imdbId}'),
                              );
                            },
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                ),
    );
  }
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          // Banner skeleton
          SizedBox(height: 56),
          LoadingShimmer(height: 220, width: double.infinity),
          SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: LoadingShimmer(height: 20, width: 160),
          ),
          SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: LoadingShimmer(height: 180)),
                SizedBox(width: 12),
                Expanded(child: LoadingShimmer(height: 180)),
                SizedBox(width: 12),
                Expanded(child: LoadingShimmer(height: 180)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.title, required this.backdropUrl, this.onPlay});
  final String title;
  final String backdropUrl;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (backdropUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: backdropUrl,
              fit: BoxFit.cover,
            )
          else
            Container(color: Colors.black),
          // Gradient overlay
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xCC000000), Color(0x00000000)],
              ),
            ),
          ),
          // Title + actions
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Play'),
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(color.primary),
                    foregroundColor: const WidgetStatePropertyAll(Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterTile extends StatelessWidget {
  const _PosterTile({required this.title, required this.posterUrl, this.onTap});
  final String title;
  final String posterUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Material(
          color: const Color(0xFF1F1F1F),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (posterUrl.isNotEmpty)
                  CachedNetworkImage(imageUrl: posterUrl, fit: BoxFit.cover)
                else
                  Container(color: Colors.grey.shade800),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    color: const Color(0x99000000),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
