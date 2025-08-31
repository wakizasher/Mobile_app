import 'package:flutter/foundation.dart';

import '../models/movie.dart';
import '../services/movie_service.dart';

class MoviesProvider extends ChangeNotifier {
  final MovieService _service;
  MoviesProvider(this._service);

  List<Movie> popular = [];
  List<Movie> searchResults = [];
  bool loadingPopular = false;
  bool searching = false;
  String? popularError;
  String? searchError;

  Future<void> loadPopular() async {
    loadingPopular = true;
    popularError = null;
    notifyListeners();
    try {
      popular = await _service.popular();
      popularError = null;
    } catch (e) {
      popular = [];
      popularError = 'Failed to load popular movies';
    } finally {
      loadingPopular = false;
      notifyListeners();
    }
  }

  Future<void> search(String q) async {
    searching = true;
    searchError = null;
    notifyListeners();
    try {
      searchResults = await _service.search(q);
      searchError = null;
    } catch (e) {
      searchResults = [];
      searchError = 'Search failed';
    } finally {
      searching = false;
      notifyListeners();
    }
  }

  Future<Movie> detail(String imdbId) async {
    return _service.detail(imdbId);
  }
}
