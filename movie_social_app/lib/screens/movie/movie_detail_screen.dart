import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/movie.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/movies_provider.dart';
import '../../providers/social_actions_provider.dart';
import '../../providers/social_post_provider.dart';
import '../../providers/social_stats_provider.dart';
import '../../widgets/loading_shimmer.dart';

class MovieDetailScreen extends StatefulWidget {
  final String imdbId;
  const MovieDetailScreen({super.key, required this.imdbId});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  final TextEditingController _prefsController = TextEditingController();
  final TextEditingController _postController = TextEditingController();
  String _lastAppliedPostText = '';
  bool _bootstrappedStats = false;
  bool? _liked; // local like state; null = unknown

  @override
  void dispose() {
    _prefsController.dispose();
    _postController.dispose();
    super.dispose();
  }

  void _syncPostController(SocialPostProvider spp) {
    final current = spp.currentText;
    if (current != _lastAppliedPostText) {
      final selection = _postController.selection;
      _postController.text = current;
      // try to keep cursor at end if nothing selected
      final pos = selection.baseOffset.clamp(0, _postController.text.length);
      _postController.selection = TextSelection.collapsed(offset: pos);
      _lastAppliedPostText = current;
    }
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
            child: Consumer3<FavoritesProvider, SocialStatsProvider, SocialPostProvider>(
              builder: (context, favsProv, statsProv, postProv, _) {
                _syncPostController(postProv);
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
                    _AiSocialPostSection(
                      imdbId: widget.imdbId,
                      prefsController: _prefsController,
                      postController: _postController,
                    ),
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

class _AiSocialPostSection extends StatelessWidget {
  const _AiSocialPostSection({
    required this.imdbId,
    required this.prefsController,
    required this.postController,
  });

  final String imdbId;
  final TextEditingController prefsController;
  final TextEditingController postController;

  @override
  Widget build(BuildContext context) {
    return Consumer2<SocialPostProvider, SocialActionsProvider>(
      builder: (context, spp, actions, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Social Post', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: prefsController,
                  decoration: const InputDecoration(
                    labelText: 'Preferences (optional, e.g. "funny tone, include hashtags")',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: spp.loading
                          ? null
                          : () async {
                              FocusScope.of(context).unfocus();
                              HapticFeedback.lightImpact();
                              final prefsText = prefsController.text.trim();
                              final prefs = prefsText.isEmpty ? null : {'style': prefsText};
                              await spp.generate(imdbId: imdbId, preferences: prefs);
                            },
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(spp.loading ? 'Generating…' : 'Generate'),
                    ),
                    const SizedBox(width: 12),
                    if (spp.loading) const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
                const SizedBox(height: 12),
                if (spp.posts.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final p in const ['twitter', 'instagram', 'facebook'])
                        ChoiceChip(
                          label: Text(p[0].toUpperCase() + p.substring(1)),
                          selected: spp.selectedPlatform == p,
                          onSelected: (sel) {
                            if (sel) spp.selectPlatform(p);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: postController,
                    minLines: 4,
                    maxLines: 10,
                    onChanged: spp.setEditedText,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Edit your post here…',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: spp.currentText));
                          HapticFeedback.selectionClick();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                          }
                        },
                        icon: const Icon(Icons.copy_all),
                        label: const Text('Copy'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () async {
                          // Record share to backend
                          await actions.share(imdbId: imdbId, platform: spp.selectedPlatform);
                          HapticFeedback.mediumImpact();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Shared to ${spp.selectedPlatform} (recorded)')),
                            );
                          }
                        },
                        icon: const Icon(Icons.send),
                        label: const Text('Post'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
