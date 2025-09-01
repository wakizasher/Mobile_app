import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/movie.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/movies_provider.dart';
import '../../providers/social_actions_provider.dart';
import '../../providers/social_stats_provider.dart';
import '../../providers/reviews_provider.dart';
import '../../widgets/loading_shimmer.dart';
import '../../providers/social_post_provider.dart';

class MovieDetailScreen extends StatefulWidget {
  final String imdbId;
  const MovieDetailScreen({super.key, required this.imdbId});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _SocialPostSection extends StatelessWidget {
  const _SocialPostSection({required this.imdbId});
  final String imdbId;

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<SocialPostProvider>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Social Posts', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (prov.loading)
              const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
            else if (prov.error != null)
              Row(
                children: [
                  Expanded(child: Text(prov.error!)),
                  TextButton(
                    onPressed: () => prov.generate(imdbId: imdbId),
                    child: const Text('Retry'),
                  ),
                ],
              )
            else if (prov.posts.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => prov.generate(imdbId: imdbId),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generate Posts'),
                ),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final platform in const ['twitter', 'instagram', 'facebook'])
                    if ((prov.posts[platform] ?? '').trim().isNotEmpty)
                      _PlatformPostCard(platform: platform, text: prov.posts[platform]!.trim()),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => prov.generate(imdbId: imdbId),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Regenerate'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlatformPostCard extends StatelessWidget {
  const _PlatformPostCard({required this.platform, required this.text});
  final String platform;
  final String text;

  String _label() => platform[0].toUpperCase() + platform.substring(1);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 480),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    platform == 'twitter'
                        ? Icons.alternate_email
                        : (platform == 'instagram' ? Icons.camera_alt_outlined : Icons.facebook),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(_label(), style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Copy',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: text));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied to clipboard')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(text),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _bootstrappedStats = false;
  bool? _liked; // local like state; null = unknown

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('Movie Detail'),
      ),
      body: FutureBuilder<Movie>(
        future: context.read<MoviesProvider>().detail(widget.imdbId),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Column(children: [LoadingShimmer(width: double.infinity), SizedBox(height: 8), LoadingShimmer(width: double.infinity)]),
            );
          }
          if (snap.hasError || !snap.hasData) {
            return const Center(child: Text('Failed to load movie'));
          }
          final movie = snap.data!;

          // Kick off stats load once
          if (!_bootstrappedStats) {
            _bootstrappedStats = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<SocialStatsProvider>().load(widget.imdbId);
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Consumer3<FavoritesProvider, SocialStatsProvider, ReviewsProvider>(
              builder: (context, favsProv, statsProv, reviewsProv, _) {
                final favs = favsProv.favorites;
                final isFav = favs.any((f) => f.movie.imdbId == movie.imdbId);
                final stats = statsProv.statsFor(widget.imdbId);
                final statsLoading = statsProv.isLoading(widget.imdbId);
                final statsError = statsProv.errorFor(widget.imdbId);
                final likesCount = stats?.likes ?? 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((movie.poster ?? '').isNotEmpty)
                          Image.network(movie.poster!, width: 160, height: 240, fit: BoxFit.cover),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(movie.title ?? movie.imdbId, style: Theme.of(context).textTheme.headlineSmall),
                              const SizedBox(height: 6),
                              Text(movie.year ?? ''),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.icon(
                                    onPressed: () => context.read<FavoritesProvider>().toggleFavorite(movie),
                                    icon: Icon(
                                      Icons.favorite,
                                      color: isFav ? Colors.red : Colors.grey,
                                    ),
                                    label: Text(isFav ? 'Favorited' : 'Favorite'),
                                  ),
                                  _LikeButton(
                                    imdbId: widget.imdbId,
                                    initialLiked: _liked,
                                    likesCount: likesCount,
                                    loading: statsLoading,
                                    onLikedChanged: (liked) {
                                      setState(() => _liked = liked);
                                      // Refresh stats after toggle
                                      context.read<SocialStatsProvider>().load(widget.imdbId);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    if ((movie.plot ?? '').isNotEmpty) ...[
                      Text('Plot', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(movie.plot!),
                    ],
                    const SizedBox(height: 16),
                    _SocialStatsSection(
                      loading: statsLoading,
                      error: statsError,
                      likes: stats?.likes,
                      favorites: stats?.favorites,
                      reviews: stats?.reviews,
                      onRetry: () => context.read<SocialStatsProvider>().load(widget.imdbId),
                    ),
                    const SizedBox(height: 16),
                    _ReviewsSection(imdbId: widget.imdbId),
                    const SizedBox(height: 16),
                    _SocialPostSection(imdbId: widget.imdbId),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({
    required this.imdbId,
    required this.initialLiked,
    required this.likesCount,
    required this.loading,
    required this.onLikedChanged,
  });

  final String imdbId;
  final bool? initialLiked;
  final int likesCount;
  final bool loading;
  final ValueChanged<bool> onLikedChanged;

  @override
  Widget build(BuildContext context) {
    final actions = context.read<SocialActionsProvider>();
    final liked = initialLiked ?? false;
    return FilledButton.icon(
      onPressed: loading
          ? null
          : () async {
              HapticFeedback.lightImpact();
              final newLiked = await actions.toggleLike(imdbId);
              onLikedChanged(newLiked);
            },
      icon: Icon(liked ? Icons.thumb_up : Icons.thumb_up_off_alt),
      label: Text('${liked ? 'Liked' : 'Like'} • $likesCount'),
    );
  }
}

class _SocialStatsSection extends StatelessWidget {
  const _SocialStatsSection({
    required this.loading,
    required this.error,
    required this.likes,
    required this.favorites,
    required this.reviews,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final int? likes;
  final int? favorites;
  final int? reviews;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LoadingShimmer(width: 200),
          SizedBox(height: 8),
          LoadingShimmer(width: 260),
        ],
      );
    }
    if (error != null) {
      return Row(
        children: [
          Expanded(child: Text(error!)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _Stat(icon: Icons.thumb_up, label: 'Likes', value: likes ?? 0),
            const SizedBox(width: 16),
            _Stat(icon: Icons.favorite, label: 'Favorites', value: favorites ?? 0),
            const SizedBox(width: 16),
            _Stat(icon: Icons.rate_review, label: 'Reviews', value: reviews ?? 0),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text('$label: $value'),
      ],
    );
  }
}

class _ReviewsSection extends StatefulWidget {
  const _ReviewsSection({required this.imdbId});
  final String imdbId;

  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  final TextEditingController _reviewController = TextEditingController();
  int? _rating; // 1..5 optional
  bool _bootstrapped = false;
  bool _submitting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ReviewsProvider>();
    if (!_bootstrapped) {
      _bootstrapped = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ReviewsProvider>().load(widget.imdbId);
      });
    }
    final loading = prov.isLoading(widget.imdbId);
    final error = prov.errorFor(widget.imdbId);
    final reviews = prov.reviewsFor(widget.imdbId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reviews', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (loading)
              const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
            else if (error != null)
              Row(
                children: [
                  Expanded(child: Text(error)),
                  TextButton(onPressed: () => context.read<ReviewsProvider>().load(widget.imdbId), child: const Text('Retry')),
                ],
              )
            else if (reviews.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('No reviews yet. Be the first to add one!',
                    style: Theme.of(context).textTheme.bodyMedium),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reviews.length,
                separatorBuilder: (_, __) => const Divider(height: 12),
                itemBuilder: (context, i) {
                  final r = reviews[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, size: 18),
                          const SizedBox(width: 6),
                          Text(
                              '${r.user?.username ?? 'User'} • ${r.createdAt.split('T').first}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          const Spacer(),
                          // Sentiment chip (Rotten Tomatoes-like)
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Chip(
                              visualDensity: VisualDensity.compact,
                              labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                              label: Text(
                                '${r.sentiment == 'positive' ? 'Fresh' : (r.sentiment == 'negative' ? 'Rotten' : 'Mixed')}'
                                '${r.sentimentConfidence != null ? ' ${(r.sentimentConfidence! * 100).round()}%' : ''}',
                              ),
                              backgroundColor: r.sentiment == 'positive'
                                  ? Colors.green.withOpacity(0.15)
                                  : (r.sentiment == 'negative'
                                      ? Colors.red.withOpacity(0.15)
                                      : Colors.grey.withOpacity(0.15)),
                            ),
                          ),
                          if (r.rating != null)
                            Row(
                              children: [
                                const Icon(Icons.star, size: 16, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text('${r.rating}/5'),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(r.content),
                    ],
                  );
                },
              ),

            const SizedBox(height: 16),
            Text('Add a review', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                DropdownButton<int>(
                  hint: const Text('Rating'),
                  value: _rating,
                  onChanged: (v) => setState(() => _rating = v),
                  items: [
                    for (final v in [1, 2, 3, 4, 5]) DropdownMenuItem(value: v, child: Text('$v')),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _reviewController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Write your thoughts…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _submitting
                      ? null
                      : () async {
                          final text = _reviewController.text.trim();
                          if (text.isEmpty) return;
                          setState(() => _submitting = true);
                          try {
                            await context.read<ReviewsProvider>().submit(
                                  imdbId: widget.imdbId,
                                  content: text,
                                  rating: _rating,
                                );
                            _reviewController.clear();
                            setState(() => _rating = null);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Review submitted')),
                              );
                            }
                            // Refresh social stats
                            if (context.mounted) {
                              context.read<SocialStatsProvider>().load(widget.imdbId);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to submit review')),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _submitting = false);
                          }
                        },
                  child: _submitting
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Post'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
