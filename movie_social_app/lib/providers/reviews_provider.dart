import 'package:flutter/foundation.dart';

import '../models/review.dart';
import '../services/social_service.dart';

class ReviewsProvider extends ChangeNotifier {
  final SocialService _social;
  ReviewsProvider(this._social);

  final Map<String, List<Review>> _cache = {};
  final Set<String> _loading = {};
  final Map<String, String> _errors = {};

  List<Review> reviewsFor(String imdbId) => _cache[imdbId] ?? const [];
  bool isLoading(String imdbId) => _loading.contains(imdbId);
  String? errorFor(String imdbId) => _errors[imdbId];

  Future<void> load(String imdbId) async {
    if (_loading.contains(imdbId)) return;
    _loading.add(imdbId);
    _errors.remove(imdbId);
    notifyListeners();
    try {
      final list = await _social.reviews(imdbId: imdbId);
      _cache[imdbId] = list;
    } catch (e) {
      _errors[imdbId] = 'Failed to load reviews';
    } finally {
      _loading.remove(imdbId);
      notifyListeners();
    }
  }

  Future<void> submit({required String imdbId, required String content, int? rating}) async {
    try {
      await _social.addReview(imdbId: imdbId, content: content, rating: rating);
      await load(imdbId);
    } catch (e) {
      _errors[imdbId] = 'Failed to submit review';
      notifyListeners();
      rethrow;
    }
  }
}
