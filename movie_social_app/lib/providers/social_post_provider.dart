import 'package:flutter/foundation.dart';

import '../services/social_service.dart';

class SocialPostProvider extends ChangeNotifier {
  final SocialService _social;
  SocialPostProvider(this._social);

  bool loading = false;
  String? error;

  // Platform-specific generated posts
  Map<String, String> posts = const {};
  // Currently selected platform (twitter, instagram, facebook)
  String selectedPlatform = 'twitter';
  // Editable text bound to the UI text field
  String editedText = '';

  String get currentText => editedText;

  void _setInitialSelection() {
    // Prefer the first platform that has non-empty content
    for (final p in const ['twitter', 'instagram', 'facebook']) {
      final t = (posts[p] ?? '').trim();
      if (t.isNotEmpty) {
        selectedPlatform = p;
        editedText = t;
        return;
      }
    }
    selectedPlatform = 'twitter';
    editedText = (posts['twitter'] ?? '').trim();
  }

  void selectPlatform(String platform) {
    if (selectedPlatform == platform) return;
    selectedPlatform = platform;
    editedText = (posts[platform] ?? '').trim();
    notifyListeners();
  }

  void setEditedText(String text) {
    editedText = text;
    notifyListeners();
  }

  void clear() {
    loading = false;
    error = null;
    posts = const {};
    selectedPlatform = 'twitter';
    editedText = '';
    notifyListeners();
  }

  Future<void> generate({required String imdbId, Map<String, dynamic>? preferences}) async {
    loading = true;
    error = null;
    posts = const {};
    editedText = '';
    notifyListeners();
    try {
      final res = await _social.generateSocialPost(imdbId: imdbId, preferences: preferences);
      posts = res.map((k, v) => MapEntry(k, (v).trim()));
      _setInitialSelection();
    } catch (e) {
      error = 'Failed to generate post';
      posts = const {};
      editedText = '';
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
