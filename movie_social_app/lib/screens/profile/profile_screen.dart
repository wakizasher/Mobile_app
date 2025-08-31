import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/friend_requests_provider.dart';
import '../../providers/user_search_provider.dart';
import '../../providers/recommendations_provider.dart';
import '../../providers/social_post_provider.dart';
import '../../models/user.dart';
import '../../models/friend_request.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final favorites = context.watch<FavoritesProvider>();
    final friends = context.watch<FriendsProvider>();
    final reqs = context.watch<FriendRequestsProvider>();
    final recs = context.watch<RecommendationsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: RefreshIndicator(
        onRefresh: () async {
          final fav = context.read<FavoritesProvider>();
          final fr = context.read<FriendsProvider>();
          final reqp = context.read<FriendRequestsProvider>();
          final recp = context.read<RecommendationsProvider>();
          await fav.syncFromServer();
          await fr.load();
          await reqp.load();
          await recp.load();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (user != null) _ProfileHeader(user: user),
              const SizedBox(height: 16),
              _QuickStats(
                favorites: favorites.favorites.length,
                friends: friends.friends.length,
                requests: reqs.requests.where((r) => r.status == 'pending').length,
                onFavoritesTap: () => context.push('/favorites'),
                onFriendsTap: () => context.push('/friends'),
              ),
              const SizedBox(height: 24),

              // Friend Requests
              if (reqs.loading)
                const Center(child: CircularProgressIndicator())
              else if (reqs.error != null)
                Text(reqs.error!, style: TextStyle(color: Theme.of(context).colorScheme.error))
              else if (reqs.requests.any((r) => r.status == 'pending' && r.toUser.id == (user?.id ?? -1)))
                _FriendRequestsList(
                  requests: reqs.requests
                      .where((r) => r.status == 'pending' && r.toUser.id == (user?.id ?? -1))
                      .toList(),
                  onAccept: (id) async {
                    final reqp = context.read<FriendRequestsProvider>();
                    final fr = context.read<FriendsProvider>();
                    await reqp.accept(id);
                    // Refresh friends on accept
                    await fr.load();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Friend request accepted')),
                      );
                    }
                  },
                  onDecline: (id) async {
                    final reqp = context.read<FriendRequestsProvider>();
                    await reqp.decline(id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Friend request declined')),
                      );
                    }
                  },
                )
              else
                const SizedBox.shrink(),

              // Friends section removed per requirements. Friend count is still shown in Quick Stats
              // and the friend search section is retained below.

              const SizedBox(height: 24),
              Text('Find Friends', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const _FriendSearchSection(),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Favorites', style: Theme.of(context).textTheme.titleMedium),
                  if (favorites.loading)
                    const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              const SizedBox(height: 8),
              if (favorites.favorites.isEmpty && !favorites.loading)
                Text('No favorites yet', style: Theme.of(context).textTheme.bodyMedium)
              else
                _MovieGrid(
                  posters: favorites.favorites.map((f) => f.movie.poster ?? '').toList(),
                ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recommended for you', style: Theme.of(context).textTheme.titleMedium),
                  if (recs.loading)
                    const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              const SizedBox(height: 8),
              if (recs.error != null)
                Text(recs.error!, style: TextStyle(color: Theme.of(context).colorScheme.error))
              else if (recs.items.isEmpty && !recs.loading)
                Text('No recommendations yet', style: Theme.of(context).textTheme.bodyMedium)
              else
                _MovieGrid(
                  posters: recs.items.map((m) => m.poster ?? '').toList(),
                ),

              const SizedBox(height: 32),
              // AI Social Post Generator
              Text('Create AI Social Post', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const _SocialPostGenerator(),

              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => context.read<AuthProvider>().logout(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendSearchSection extends StatefulWidget {
  const _FriendSearchSection();

  @override
  State<_FriendSearchSection> createState() => _FriendSearchSectionState();
}

class _FriendSearchSectionState extends State<_FriendSearchSection> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debouncer;
  final Set<int> _sendingUserIds = <int>{};

  @override
  void dispose() {
    _debouncer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debouncer?.cancel();
    _debouncer = Timer(const Duration(milliseconds: 300), () {
      context.read<UserSearchProvider>().search(q);
    });
  }

  Future<void> _sendRequest(AppUser user) async {
    setState(() => _sendingUserIds.add(user.id));
    try {
      await context.read<FriendRequestsProvider>().send(user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Friend request sent to @${user.username}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send friend request')),
      );
    } finally {
      if (mounted) setState(() => _sendingUserIds.remove(user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final search = context.watch<UserSearchProvider>();
    final friendsProvider = context.watch<FriendsProvider>();
    final auth = context.watch<AuthProvider>();

    final friendIds = friendsProvider.friends.map((f) => f.friend.id).toSet();
    final pendingOutgoing = context.watch<FriendRequestsProvider>().requests.where((r) =>
        r.status == 'pending' && r.fromUser.id == auth.currentUser?.id).map((r) => r.toUser.id).toSet();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Search users by name or username',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: search.query.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          context.read<UserSearchProvider>().clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            if (search.loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ))
            else if (search.error != null)
              Text(search.error!, style: theme.textTheme.bodyMedium?.copyWith(color: color.error))
            else if (search.results.isEmpty && search.query.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No users found', style: theme.textTheme.bodyMedium),
              )
            else if (search.results.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Type to search for friends', style: theme.textTheme.bodyMedium?.copyWith(color: color.onSurfaceVariant)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: search.results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final u = search.results[i];
                  final isMe = u.id == auth.currentUser?.id;
                  final isFriend = friendIds.contains(u.id);
                  final requested = pendingOutgoing.contains(u.id);
                  return ListTile(
                    leading: _Avatar(url: u.avatarUrl),
                    title: Text(u.displayName?.isNotEmpty == true ? u.displayName! : u.username),
                    subtitle: Text('@${u.username}', style: theme.textTheme.bodySmall?.copyWith(color: color.onSurfaceVariant)),
                    trailing: isMe
                        ? const SizedBox.shrink()
                        : isFriend
                            ? const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Chip(label: Text('Friends')),
                              )
                            : requested
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Chip(label: Text('Requested')),
                                  )
                                : FilledButton.icon(
                                    onPressed: _sendingUserIds.contains(u.id) ? null : () => _sendRequest(u),
                                    icon: _sendingUserIds.contains(u.id)
                                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Icon(Icons.person_add_alt_1),
                                    label: const Text('Add Friend'),
                                  ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundImage: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
              ? NetworkImage(user.avatarUrl!)
              : null,
          child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
              ? const Icon(Icons.person_outline, size: 40)
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (user.displayName?.isNotEmpty ?? false) ? user.displayName! : user.username,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text('@${user.username}', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              if (user.bio != null && user.bio!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(user.bio!, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickStats extends StatelessWidget {
  const _QuickStats({
    required this.favorites,
    required this.friends,
    required this.requests,
    this.onFavoritesTap,
    this.onFriendsTap,
  });
  final int favorites;
  final int friends;
  final int requests;
  final VoidCallback? onFavoritesTap;
  final VoidCallback? onFriendsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    Widget tile({required String label, required String value, VoidCallback? onTap}) => Expanded(
          child: Card(
            elevation: 1,
            color: color.surfaceContainerHighest.withValues(alpha: 0.6),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: color.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    return Row(
      children: [
        tile(label: 'Favorites', value: favorites.toString(), onTap: onFavoritesTap),
        const SizedBox(width: 12),
        tile(label: 'Friends', value: friends.toString(), onTap: onFriendsTap),
        const SizedBox(width: 12),
        tile(label: 'Requests', value: requests.toString()),
      ],
    );
  }
}

class _FriendRequestsList extends StatelessWidget {
  const _FriendRequestsList({required this.requests, required this.onAccept, required this.onDecline});
  final List<FriendRequest> requests;
  final Future<void> Function(int id) onAccept;
  final Future<void> Function(int id) onDecline;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Friend Requests', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final r in requests)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    _Avatar(url: r.fromUser.avatarUrl),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.fromUser.displayName ?? r.fromUser.username,
                              style: Theme.of(context).textTheme.bodyLarge),
                          Text('@${r.fromUser.username}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    TextButton(onPressed: () => onDecline(r.id), child: const Text('Decline')),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: () => onAccept(r.id), child: const Text('Accept')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MovieGrid extends StatelessWidget {
  const _MovieGrid({required this.posters});
  final List<String> posters;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final desiredCardWidth = 120.0;
        final count = (width / desiredCardWidth).floor();
        final crossAxisCount = count.clamp(2, 6);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2 / 3,
          ),
          itemCount: posters.length,
          itemBuilder: (context, index) {
            final url = posters[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                color: const Color(0xFF1F1F1F),
                child: url.isNotEmpty
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.image_not_supported)),
                      )
                    : const Center(child: Icon(Icons.image_not_supported)),
              ),
            );
          },
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.isNotEmpty;
    return CircleAvatar(
      radius: 36,
      backgroundImage: hasUrl ? NetworkImage(url!) : null,
      child: hasUrl ? null : const Icon(Icons.person_outline),
    );
  }
}

class _SocialPostGenerator extends StatefulWidget {
  const _SocialPostGenerator();

  @override
  State<_SocialPostGenerator> createState() => _SocialPostGeneratorState();
}

class _SocialPostGeneratorState extends State<_SocialPostGenerator> {
  String? _selectedImdbId;
  final TextEditingController _promptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Try to pick a default favorite after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final favs = context.read<FavoritesProvider>().favorites;
      if (favs.isNotEmpty && _selectedImdbId == null) {
        setState(() => _selectedImdbId = favs.first.movie.imdbId);
      }
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final favProvider = context.watch<FavoritesProvider>();
    final postProvider = context.watch<SocialPostProvider>();
    final favs = favProvider.favorites;

    if (favs.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Add some favorites to generate a social post about them.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedImdbId,
              items: [
                for (final f in favs)
                  DropdownMenuItem(
                    value: f.movie.imdbId,
                    child: Text((f.movie.title ?? f.movie.imdbId) + (f.movie.year != null ? ' (${f.movie.year})' : '')),
                  ),
              ],
              onChanged: postProvider.loading ? null : (v) => setState(() => _selectedImdbId = v),
              decoration: const InputDecoration(labelText: 'Movie'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _promptController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Optional prompt (tone, style, hashtags...)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: (postProvider.loading || _selectedImdbId == null)
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await context
                              .read<SocialPostProvider>()
                              .generate(
                                  imdbId: _selectedImdbId!,
                                  preferences: _promptController.text.trim().isEmpty
                                      ? null
                                      : {'style': _promptController.text.trim()});
                          if (postProvider.error == null) {
                            messenger.showSnackBar(const SnackBar(content: Text('Post generated')));
                          }
                        },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generate'),
                ),
                const SizedBox(width: 12),
                if (postProvider.loading)
                  const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            if (postProvider.error != null) ...[
              const SizedBox(height: 8),
              Text(postProvider.error!, style: theme.textTheme.bodyMedium?.copyWith(color: color.error)),
            ],
            if (postProvider.currentText.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Result', style: theme.textTheme.titleSmall),
                  IconButton(
                    tooltip: 'Copy',
                    icon: const Icon(Icons.copy),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await Clipboard.setData(ClipboardData(text: postProvider.currentText));
                      messenger.showSnackBar(const SnackBar(content: Text('Copied')));
                    },
                  ),
                ],
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  postProvider.currentText,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
