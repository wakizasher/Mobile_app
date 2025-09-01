import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/movie_nights_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/movie_night.dart';
import 'dart:async';
import '../../providers/movies_provider.dart';
import '../../models/movie.dart';
import '../../providers/user_search_provider.dart';
import '../../models/user.dart';
import 'movie_night_detail_screen.dart';

class MovieNightsScreen extends StatelessWidget {
  const MovieNightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Movie Nights')),
      body: const _MovieNightsBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
    );
  }
  
}

class _MovieNightsBody extends StatelessWidget {
  const _MovieNightsBody();

  @override
  Widget build(BuildContext context) {
    return Consumer<MovieNightsProvider>(
      builder: (context, prov, _) {
        if (prov.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (prov.error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(prov.error!, style: const TextStyle(color: Colors.redAccent)),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => context.read<MovieNightsProvider>().load(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        final nights = prov.nights;
        if (nights.isEmpty) {
          return const _EmptyState();
        }
        return RefreshIndicator(
          onRefresh: () async => context.read<MovieNightsProvider>().load(),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: nights.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final n = nights[index];
              return _NightTile(night: n);
            },
          ),
        );
      },
    );
  }
}

class _NightTile extends StatelessWidget {
  const _NightTile({required this.night});

  final MovieNight night;

  bool _isJoined(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return false;
    // Consider "joined" only if organizer or participation is accepted.
    if (user.id == night.organizer.id) return true;
    return night.participants.any((p) => p.user.id == user.id && p.status == 'accepted');
  }

  @override
  Widget build(BuildContext context) {
    final joined = _isJoined(context);
    final prov = context.watch<MovieNightsProvider>();
    final isJoining = prov.joiningIds.contains(night.id);
    final isLeaving = prov.leavingIds.contains(night.id);
    final color = Theme.of(context).colorScheme;
    final currentUser = context.read<AuthProvider>().currentUser;
    final isOrganizer = currentUser != null && currentUser.id == night.organizer.id;
    // Determine current user's participation status (if any)
    String? myStatus;
    if (currentUser != null) {
      for (final p in night.participants) {
        if (p.user.id == currentUser.id) {
          myStatus = p.status;
          break;
        }
      }
    }
    final bool isInvitePending = myStatus == 'invited' || myStatus == 'maybe';
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MovieNightDetailScreen(initial: night),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    night.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    night.status,
                    style: TextStyle(color: color.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (night.scheduledDate != null)
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
            if (night.location != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(night.location!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.group_outlined, size: 16),
                const SizedBox(width: 6),
                Text('${night.participants.length} going'),
                const Spacer(),
                if (!joined)
                  OutlinedButton.icon(
                    onPressed: isJoining
                        ? null
                        : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final prov = context.read<MovieNightsProvider>();
                          await prov.join(night.id);
                          if (!context.mounted) return;
                          messenger.showSnackBar(
                            SnackBar(content: Text(prov.error == null ? (isInvitePending ? 'Invitation accepted' : 'Join requested') : 'Failed to join movie night')),
                          );
                        },
                    icon: isJoining
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.event_available),
                    label: Text(isJoining ? (isInvitePending ? 'Accepting...' : 'Joining...') : (isInvitePending ? 'Accept' : 'Join')),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: isLeaving
                        ? null
                        : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Leave movie night?'),
                              content: Text('Are you sure you want to leave "${night.title}"?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Leave')),
                              ],
                            ),
                          );
                          if (confirmed == true && context.mounted) {
                            final messenger = ScaffoldMessenger.of(context);
                            final prov = context.read<MovieNightsProvider>();
                            await prov.leave(night.id);
                            if (!context.mounted) return;
                            messenger.showSnackBar(
                              SnackBar(content: Text(prov.error == null ? 'Left movie night' : 'Failed to leave movie night')),
                            );
                          }
                        },
                    icon: isLeaving
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.event_busy),
                    label: Text(isLeaving ? 'Leaving...' : 'Leave'),
                  ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: (joined && !isJoining && !isLeaving) ? () => _showVoteDialog(context, night.id) : null,
                  icon: const Icon(Icons.how_to_vote),
                  label: const Text('Vote'),
                ),
                if (isOrganizer) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showInviteDialog(context, night),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Invite'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event, size: 64, color: color.primary),
            const SizedBox(height: 12),
            Text('No movie nights yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Create a movie night and invite friends to join!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _showCreateSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Movie Night'),
            ),
          ],
        ),
      ),
    );
  }
}

void _showInviteDialog(BuildContext context, MovieNight night) {
  final searchCtrl = TextEditingController();
  // reset previous search state
  context.read<UserSearchProvider>().clear();

  showDialog(
    context: context,
    builder: (context) {
      Timer? debouncer;
      final invitedIds = <int>{};
      final invitingIds = <int>{};

      void onChanged(String q) {
        debouncer?.cancel();
        debouncer = Timer(const Duration(milliseconds: 300), () {
          context.read<UserSearchProvider>().search(q);
        });
      }

      return StatefulBuilder(
        builder: (context, setState) {
          final usersProv = context.watch<UserSearchProvider>();
          final hasQuery = searchCtrl.text.trim().isNotEmpty;
          return AlertDialog(
            title: const Text('Invite friends'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchCtrl,
                    onChanged: (q) {
                      setState(() {});
                      onChanged(q);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Search users',
                      hintText: 'Type a name or @username',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: !hasQuery
                        ? const Text('Start typing to search users')
                        : usersProv.loading
                            ? const SizedBox(height: 64, child: Center(child: CircularProgressIndicator()))
                            : usersProv.results.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Text('No users found'),
                                  )
                                : ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 320),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      itemCount: usersProv.results.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1),
                                      itemBuilder: (context, i) {
                                        final AppUser u = usersProv.results[i];
                                        final alreadyParticipant = night.participants.any((p) => p.user.id == u.id);
                                        final isSelf = context.read<AuthProvider>().currentUser?.id == u.id;
                                        final isInvited = invitedIds.contains(u.id) || alreadyParticipant;
                                        final isInviting = invitingIds.contains(u.id);
                                        return ListTile(
                                          leading: const CircleAvatar(child: Icon(Icons.person)),
                                          title: Text(u.username),
                                          subtitle: u.email != null ? Text(u.email!) : null,
                                          trailing: OutlinedButton(
                                            onPressed: (isInvited || isInviting || isSelf)
                                                ? null
                                                : () async {
                                                    setState(() => invitingIds.add(u.id));
                                                    final ok = await context.read<MovieNightsProvider>().invite(id: night.id, userId: u.id);
                                                    if (!context.mounted) return;
                                                    setState(() {
                                                      invitingIds.remove(u.id);
                                                      if (ok) invitedIds.add(u.id);
                                                    });
                                                    final messenger = ScaffoldMessenger.of(context);
                                                    messenger.showSnackBar(
                                                      SnackBar(content: Text(ok ? 'Invite sent to @${u.username}' : 'Failed to invite @${u.username}')),
                                                    );
                                                  },
                                            child: Text(isInvited
                                                ? 'Invited'
                                                : isInviting
                                                    ? 'Inviting...'
                                                    : 'Invite'),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
            ],
          );
        },
      );
    },
  );
}

void _showVoteDialog(BuildContext context, int nightId) {
  final searchCtrl = TextEditingController();
  showDialog(
    context: context,
    builder: (context) {
      Timer? debouncer;
      bool submitting = false;
      String selectedImdbId = '';

      void onChanged(String q) {
        debouncer?.cancel();
        debouncer = Timer(const Duration(milliseconds: 300), () {
          if (q.trim().isEmpty) {
            // Do nothing; UI will show hint when empty
            return;
          }
          context.read<MoviesProvider>().search(q.trim());
        });
      }

      Widget resultTile(BuildContext context, Movie m) {
        final title = (m.title ?? m.imdbId);
        final year = (m.year != null && m.year!.isNotEmpty) ? ' (${m.year})' : '';
        final poster = m.poster ?? '';
        return ListTile(
          leading: poster.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    poster,
                    width: 44,
                    height: 66,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
                  ),
                )
              : const Icon(Icons.local_movies_outlined),
          title: Text('$title$year'),
          subtitle: Text(m.imdbId, style: Theme.of(context).textTheme.bodySmall),
          onTap: submitting
              ? null
              : () async {
                  if (submitting) return;
                  selectedImdbId = m.imdbId;
                  submitting = true;
                  final prov = context.read<MovieNightsProvider>();
                  await prov.vote(id: nightId, imdbId: selectedImdbId);
                  if (!context.mounted) return;
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    SnackBar(content: Text(prov.error == null ? 'Vote submitted' : 'Failed to submit vote')),
                  );
                  if (prov.error == null && context.mounted) {
                    Navigator.of(context).pop();
                  } else {
                    submitting = false;
                  }
                },
        );
      }

      return StatefulBuilder(
        builder: (context, setState) {
          final moviesProv = context.watch<MoviesProvider>();
          final hasQuery = searchCtrl.text.trim().isNotEmpty;
          return AlertDialog(
            title: const Text('Vote for a movie'),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchCtrl,
                    onChanged: (q) {
                      setState(() {});
                      onChanged(q);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Search movies',
                      hintText: 'Type a title (e.g., The Dark Knight)',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: !hasQuery
                        ? const Text('Start typing to search for movies')
                        : moviesProv.searching
                            ? const SizedBox(height: 64, child: Center(child: CircularProgressIndicator()))
                            : moviesProv.searchResults.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Text('No movies found'),
                                  )
                                : ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 320),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      itemCount: moviesProv.searchResults.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1),
                                      itemBuilder: (context, i) => resultTile(context, moviesProv.searchResults[i]),
                                    ),
                                  ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
            ],
          );
        },
      );
    },
  );
}

void _showCreateSheet(BuildContext context) {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final dateCtrl = TextEditingController();
  final locCtrl = TextEditingController();
  final maxCtrl = TextEditingController();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      bool submitting = false;
      final padding = MediaQuery.of(context).viewInsets + const EdgeInsets.all(16);
      return StatefulBuilder(builder: (context, setState) {
        return Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Create Movie Night', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.title)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.notes_outlined)),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: dateCtrl,
                decoration: const InputDecoration(
                  labelText: 'Scheduled Date (YYYY-MM-DD HH:MM) optional',
                  prefixIcon: Icon(Icons.schedule),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: locCtrl,
                decoration: const InputDecoration(labelText: 'Location (optional)', prefixIcon: Icon(Icons.place_outlined)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: maxCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Max participants (optional)', prefixIcon: Icon(Icons.group_outlined)),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: submitting
                    ? null
                    : () async {
                        final title = titleCtrl.text.trim();
                        if (title.isEmpty) return;
                        setState(() => submitting = true);
                        DateTime? dt;
                        if (dateCtrl.text.trim().isNotEmpty) {
                          final t = dateCtrl.text.trim().replaceFirst(' ', 'T');
                          dt = DateTime.tryParse(t);
                        }
                        final max = int.tryParse(maxCtrl.text.trim());
                        final created = await context.read<MovieNightsProvider>().create(
                              title: title,
                              description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                              scheduledDate: dt,
                              location: locCtrl.text.trim().isEmpty ? null : locCtrl.text.trim(),
                              maxParticipants: max,
                            );
                        setState(() => submitting = false);
                        if (created != null && context.mounted) Navigator.of(context).pop();
                      },
                icon: const Icon(Icons.check),
                label: Text(submitting ? 'Creating...' : 'Create'),
              ),
            ],
          ),
        );
      });
    },
  );
}
