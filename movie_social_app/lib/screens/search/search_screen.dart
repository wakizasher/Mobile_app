import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/movies_provider.dart';
import '../../widgets/loading_shimmer.dart';
import '../../widgets/movie_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryCtrl = TextEditingController();

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MoviesProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryCtrl,
                    decoration: const InputDecoration(hintText: 'Search movies...'),
                    onSubmitted: (q) => context.read<MoviesProvider>().search(q.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => context.read<MoviesProvider>().search(_queryCtrl.text.trim()),
                  child: const Icon(Icons.search),
                )
              ],
            ),
          ),
          Expanded(
            child: provider.searching
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(children: [LoadingShimmer(width: double.infinity), SizedBox(height: 8), LoadingShimmer(width: double.infinity)]),
                  )
                : provider.searchError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(provider.searchError!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () => context.read<MoviesProvider>().search(_queryCtrl.text.trim()),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : (provider.searchResults.isEmpty && _queryCtrl.text.trim().isNotEmpty)
                        ? const Center(child: Text('No results'))
                        : ListView.builder(
                            itemCount: provider.searchResults.length,
                            itemBuilder: (context, index) {
                              final movie = provider.searchResults[index];
                              return MovieCard(
                                movie: movie,
                                onTap: () => context.push('/movie/${movie.imdbId}')
                              );
                            },
                          ),
          )
        ],
      ),
    );
  }
}
