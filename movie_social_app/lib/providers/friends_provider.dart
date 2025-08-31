import 'package:flutter/foundation.dart';

import '../models/friendship.dart';
import '../services/social_service.dart';

class FriendsProvider extends ChangeNotifier {
  final SocialService _social;
  FriendsProvider(this._social);

  List<Friendship> friends = [];
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      friends = await _social.friends();
    } catch (e) {
      error = 'Failed to load friends';
      friends = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
