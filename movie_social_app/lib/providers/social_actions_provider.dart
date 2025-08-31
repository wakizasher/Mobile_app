import 'package:flutter/foundation.dart';

import '../core/network/dio_client.dart';
import '../services/social_service.dart';

class SocialActionsProvider extends ChangeNotifier {
  final SocialService _social;
  SocialActionsProvider(ApiClient client) : _social = SocialService(client: client);

  Future<bool> toggleLike(String imdbId) => _social.toggleLike(imdbId);

  Future<void> share({required String imdbId, required String platform}) => _social.share(imdbId: imdbId, platform: platform);
}
