import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/favorites_provider.dart';
import '../../providers/social_stats_provider.dart';
import '../../providers/social_actions_provider.dart';
import '../../widgets/loading_shimmer.dart';
import '../../widgets/movie_card.dart';
import '../../models/favorite.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final fav = context.read<FavoritesProvider>();
      await fav.loadLocal();
      // Attempt server sync (if online and authenticated)
      await fav.syncFromServer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FavoritesProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: provider.loading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Column(children: [LoadingShimmer(width: double.infinity), SizedBox(height: 8), LoadingShimmer(width: double.infinity)]),
            )
          : RefreshIndicator(
              onRefresh: () => provider.syncFromServer(),
              child: ListView.separated(
                itemCount: provider.favorites.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                padding: const EdgeInsets.all(12),
                itemBuilder: (context, index) {
                  final f = provider.favorites[index];
                  return _FavoriteListItem(favorite: f);
                },
              ),
            ),
    );
  }
}

class _FavoriteListItem extends StatefulWidget {
  const _FavoriteListItem({required this.favorite});
  final Favorite favorite;

  @override
  State<_FavoriteListItem> createState() => _FavoriteListItemState();
}

class _FavoriteListItemState extends State<_FavoriteListItem> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SocialStatsProvider>().load(widget.favorite.movie.imdbId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<SocialStatsProvider>();
    final actions = context.read<SocialActionsProvider>();
    final imdbId = widget.favorite.movie.imdbId;
    final s = stats.statsFor(imdbId);
    final loading = stats.isLoading(imdbId);
    final error = stats.errorFor(imdbId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MovieCard(
          movie: widget.favorite.movie,
          onTap: () => context.push('/movie/$imdbId'),
        ),
        const SizedBox(height: 8),
        if (loading)
          const Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (error != null)
          Row(
            children: [
              Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 18),
              const SizedBox(width: 6),
              Text(error, style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              TextButton.icon(
                onPressed: () => stats.load(imdbId),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          )
        else if (s != null)
          Row(
            children: [
              _StatChip(icon: Icons.thumb_up, label: s.likes.toString()),
              const SizedBox(width: 8),
              _StatChip(icon: Icons.favorite, label: s.favorites.toString()),
              const SizedBox(width: 8),
              _StatChip(icon: Icons.rate_review, label: s.reviews.toString()),
            ],
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            IconButton(
              tooltip: 'Like',
              icon: const Icon(Icons.thumb_up_outlined),
              onPressed: () async {
                final stats = context.read<SocialStatsProvider>();
                final messenger = ScaffoldMessenger.of(context);
                await actions.toggleLike(imdbId);
                await stats.load(imdbId);
                messenger.showSnackBar(const SnackBar(content: Text('Updated like')));
              },
            ),
            IconButton(
              tooltip: 'Comment',
              icon: const Icon(Icons.mode_comment_outlined),
              onPressed: () => context.push('/movie/$imdbId'),
            ),
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.share_outlined),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share coming soon')));
              },
            ),
            const Spacer(),
            Text(
              'Added on ${widget.favorite.createdAt.split('T').first}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
