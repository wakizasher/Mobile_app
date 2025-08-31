import 'package:flutter/foundation.dart';

import '../models/movie.dart';
import '../services/movie_service.dart';

class RecommendationsProvider extends ChangeNotifier {
  final MovieService _service;
  RecommendationsProvider(this._service);

  List<Movie> items = [];
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      items = await _service.recommendations();
    } catch (e) {
      error = 'Failed to load recommendations';
      items = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
