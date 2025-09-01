import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/movie_night.dart';
import '../../models/movie_night_vote.dart';
import '../../providers/movie_nights_provider.dart';

class MovieNightDetailScreen extends StatefulWidget {
  const MovieNightDetailScreen({super.key, required this.initial});

  final MovieNight initial;

  @override
  State<MovieNightDetailScreen> createState() => _MovieNightDetailScreenState();
}

class _MovieNightDetailScreenState extends State<MovieNightDetailScreen> {
  bool _refreshedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_refreshedOnce) {
      _refreshedOnce = true;
      // Refresh detail to fetch votes if allowed and latest participants
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<MovieNightsProvider>().refreshDetail(widget.initial.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MovieNightsProvider>(
      builder: (context, prov, _) {
        final night = prov.nights.firstWhere(
          (n) => n.id == widget.initial.id,
          orElse: () => widget.initial,
        );
        final color = Theme.of(context).colorScheme;
        final votesByUser = <int, List<MovieNightVote>>{};
        for (final v in night.votes) {
          votesByUser.putIfAbsent(v.user.id, () => <MovieNightVote>[]).add(v);
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(night.title),
            actions: [
              IconButton(
                onPressed: () => prov.refreshDetail(night.id),
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => prov.refreshDetail(night.id),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Meta
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            night.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text('Organizer: @${night.organizer.username}'),
                          if (night.scheduledDate != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.schedule, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  night.scheduledDate!.toLocal().toString(),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                          if (night.location != null && night.location!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.place_outlined, size: 16),
                                const SizedBox(width: 6),
                                Text(night.location!),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        night.status,
                        style: TextStyle(color: color.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                if ((night.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(night.description!),
                ],
                const SizedBox(height: 16),
                Divider(color: color.outlineVariant),
                const SizedBox(height: 8),
                Text('Participants (${night.participants.length})', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (night.participants.isEmpty)
                  const Text('No participants yet')
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: night.participants.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = night.participants[i];
                      final pVotes = votesByUser[p.user.id] ?? const <MovieNightVote>[];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text('@${p.user.username}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Status: ${p.status}'),
                            if (pVotes.isEmpty)
                              const Text('No votes yet')
                            else
                              Wrap(
                                spacing: 6,
                                runSpacing: -6,
                                children: [
                                  for (final v in pVotes)
                                    Chip(
                                      label: Text(v.movie.title ?? v.movie.imdbId),
                                      avatar: const Icon(Icons.local_movies_outlined, size: 16),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 24),
                if (night.votes.isEmpty)
                  Text(
                    'Votes are not available to view. You may need to be the organizer or an accepted participant.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color.onSurfaceVariant),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}
