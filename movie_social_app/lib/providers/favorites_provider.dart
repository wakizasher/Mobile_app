import 'package:flutter/foundation.dart';

import '../core/storage/local_db.dart';
import '../models/favorite.dart';
import '../models/movie.dart';
import '../services/social_service.dart';

class FavoritesProvider extends ChangeNotifier {
  final SocialService _social;
  
  FavoritesProvider(this._social);

  List<Favorite> favorites = [];
  bool loading = false;

  Future<void> loadLocal() async {
    try {
      final rows = await FavoritesDao.listFavorites();
      favorites = rows
          .map((r) => Favorite(
                movie: Movie.fromJson(r['movie'] as Map<String, dynamic>),
                createdAt: r['created_at'] as String,
              ))
          .toList();
    } catch (e) {
      // In tests, LocalDatabase.init() might not have been called. Fallback gracefully.
      debugPrint('FavoritesProvider.loadLocal: skipping local DB load: $e');
      favorites = [];
    }
    notifyListeners();
  }

  Future<void> syncFromServer() async {
    loading = true;
    notifyListeners();
    try {
      final list = await _social.favorites();
      favorites = list;
      // Upsert into local DB for offline
      for (final f in list) {
        await FavoritesDao.upsertFavorite(
          imdbId: f.movie.imdbId,
          movie: f.movie.toJson(),
          createdAt: DateTime.parse(f.createdAt),
        );
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(Movie movie) async {
    final exists = await FavoritesDao.isFavorite(movie.imdbId);
    if (exists) {
      await _social.removeFavorite(movie.imdbId);
      await FavoritesDao.removeFavorite(movie.imdbId);
      favorites.removeWhere((f) => f.movie.imdbId == movie.imdbId);
    } else {
      await _social.addFavorite(movie.imdbId);
      await FavoritesDao.upsertFavorite(
        imdbId: movie.imdbId,
        movie: movie.toJson(),
        createdAt: DateTime.now(),
      );
      favorites.insert(0, Favorite(movie: movie, createdAt: DateTime.now().toIso8601String()));
    }
    notifyListeners();
  }
}

