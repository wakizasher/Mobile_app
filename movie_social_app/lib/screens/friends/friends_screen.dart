import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/friends_provider.dart';
import '../../providers/user_search_provider.dart';
import '../../providers/friend_requests_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/friendship.dart';
import '../../models/user.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _RequestsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final reqProv = context.watch<FriendRequestsProvider>();
    final user = context.watch<AuthProvider>().currentUser;
    if (reqProv.loading) {
      return const SizedBox(height: 56, child: Center(child: CircularProgressIndicator()));
    }
    if (reqProv.error != null) {
      return Text(reqProv.error!, style: TextStyle(color: Theme.of(context).colorScheme.error));
    }
    final uid = user?.id ?? -1;
    final received = reqProv.requests.where((r) => r.status == 'pending' && r.toUser.id == uid).toList();
    final sent = reqProv.requests.where((r) => r.status == 'pending' && r.fromUser.id == uid).toList();

    if (received.isEmpty && sent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (received.isNotEmpty) ...[
          Text('Requests to you', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: received.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final fr = received[i];
                final u = fr.fromUser;
                return ListTile(
                  leading: _Avatar(url: u.avatarUrl),
                  title: Text(u.displayName ?? u.username),
                  subtitle: Text('@${u.username}'),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          await context.read<FriendRequestsProvider>().decline(fr.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Declined request')));
                          }
                        },
                        child: const Text('Decline'),
                      ),
                      FilledButton(
                        onPressed: () async {
                          await context.read<FriendRequestsProvider>().accept(fr.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Accepted request')));
                            // Refresh friends list
                            await context.read<FriendsProvider>().load();
                          }
                        },
                        child: const Text('Accept'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (sent.isNotEmpty) ...[
          Text('Requests you sent', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sent.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final fr = sent[i];
                final u = fr.toUser;
                return ListTile(
                  leading: _Avatar(url: u.avatarUrl),
                  title: Text(u.displayName ?? u.username),
                  subtitle: Text('@${u.username}'),
                  trailing: const Text('Pending'),
                );
              },
            ),
          ),
        ],
      ],
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
      radius: 20,
      backgroundImage: hasUrl ? NetworkImage(url!) : null,
      child: hasUrl ? null : const Icon(Icons.person_outline),
    );
  }
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _lastQuery = '';
  DateTime _lastTypeAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FriendsProvider>().load();
      context.read<FriendRequestsProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FriendsProvider>();
    final search = context.watch<UserSearchProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search users by name or @username',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (q) {
                _lastQuery = q;
                _lastTypeAt = DateTime.now();
                // simple debounce ~300ms
                final prov = context.read<UserSearchProvider>();
                Future.delayed(const Duration(milliseconds: 320), () {
                  final elapsed = DateTime.now().difference(_lastTypeAt).inMilliseconds;
                  if (_lastQuery.trim().isEmpty) {
                    prov.clear();
                    return;
                  }
                  if (elapsed >= 300 && _lastQuery == _searchController.text) {
                    prov.search(_lastQuery);
                  }
                });
              },
            ),
          ),
          if (_searchController.text.trim().isNotEmpty)
            Expanded(
              child: _SearchResults(
                results: search.results,
                loading: search.loading,
                error: search.error,
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    context.read<FriendsProvider>().load(),
                    context.read<FriendRequestsProvider>().load(),
                  ]);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  children: [
                    // Friend Requests Sections
                    _RequestsSection(),
                    const SizedBox(height: 12),

                    // Friends Section
                    if (provider.loading)
                      const Center(child: CircularProgressIndicator())
                    else if (provider.error != null)
                      _ErrorState(message: provider.error!, onRetry: () => provider.load())
                    else if (provider.friends.isEmpty)
                      const _EmptyState()
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: provider.friends.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final f = provider.friends[index];
                          return _FriendTile(friendship: f);
                        },
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friendship});
  final Friendship friendship;

  @override
  Widget build(BuildContext context) {
    final u = friendship.friend;
    return ListTile(
      leading: _Avatar(url: u.avatarUrl),
      title: Text(u.displayName ?? u.username),
      subtitle: Text('@${u.username}'),
      onTap: () {},
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.results, required this.loading, required this.error});
  final List<AppUser> results;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return _ErrorState(message: error!, onRetry: () {});
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No users found', style: Theme.of(context).textTheme.bodyLarge),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final u = results[i];
        return ListTile(
          leading: _Avatar(url: u.avatarUrl),
          title: Text(u.displayName ?? u.username),
          subtitle: Text('@${u.username}'),
          trailing: FilledButton(
            onPressed: () async {
              try {
                await context.read<FriendRequestsProvider>().send(u.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Friend request sent to @${u.username}')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to send request to @${u.username}')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text('No friends yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'When you add friends, they will appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(message, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
