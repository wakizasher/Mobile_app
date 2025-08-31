import 'package:flutter/foundation.dart';

import '../models/friend_request.dart';
import '../services/social_service.dart';

class FriendRequestsProvider extends ChangeNotifier {
  final SocialService _social;
  FriendRequestsProvider(this._social);

  List<FriendRequest> requests = [];
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      requests = await _social.friendRequests();
    } catch (e) {
      error = 'Failed to load friend requests';
      requests = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> send(int toUserId) async {
    try {
      final fr = await _social.sendFriendRequest(toUserId: toUserId);
      // If already exists, backend returns existing; ensure list reflects it
      final idx = requests.indexWhere((r) => r.id == fr.id);
      if (idx >= 0) {
        requests[idx] = fr;
      } else {
        requests.insert(0, fr);
      }
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> accept(int id) async {
    final updated = await _social.updateFriendRequestStatus(id: id, action: 'accept');
    final idx = requests.indexWhere((r) => r.id == id);
    if (idx >= 0) {
      requests[idx] = updated;
      notifyListeners();
    }
  }

  Future<void> decline(int id) async {
    final updated = await _social.updateFriendRequestStatus(id: id, action: 'decline');
    final idx = requests.indexWhere((r) => r.id == id);
    if (idx >= 0) {
      requests[idx] = updated;
      notifyListeners();
    }
  }
}
