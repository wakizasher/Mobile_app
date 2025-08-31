import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/social_service.dart';

class UserSearchProvider extends ChangeNotifier {
  final SocialService _social;
  UserSearchProvider(this._social);

  List<AppUser> results = [];
  bool loading = false;
  String? error;
  String query = '';

  void clear() {
    results = [];
    error = null;
    loading = false;
    query = '';
    notifyListeners();
  }

  Future<void> search(String q) async {
    final trimmed = q.trim();
    query = q;
    if (trimmed.isEmpty) {
      clear();
      return;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      results = await _social.searchUsers(trimmed);
    } catch (e) {
      error = 'Failed to search users';
      results = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
