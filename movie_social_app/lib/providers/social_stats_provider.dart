import 'package:flutter/foundation.dart';

import '../models/social_stats.dart';
import '../services/social_service.dart';

class SocialStatsProvider extends ChangeNotifier {
  final SocialService _social;
  SocialStatsProvider(this._social);

  final Map<String, SocialStats> _cache = {};
  final Set<String> _loading = {};
  final Map<String, String> _errors = {};

  SocialStats? statsFor(String imdbId) => _cache[imdbId];
  bool isLoading(String imdbId) => _loading.contains(imdbId);
  String? errorFor(String imdbId) => _errors[imdbId];

  Future<void> load(String imdbId) async {
    if (_loading.contains(imdbId)) return;
    _loading.add(imdbId);
    _errors.remove(imdbId);
    notifyListeners();
    try {
      final s = await _social.socialStats(imdbId);
      _cache[imdbId] = s;
    } catch (e) {
      _errors[imdbId] = 'Failed to load stats';
    } finally {
      _loading.remove(imdbId);
      notifyListeners();
    }
  }
}
