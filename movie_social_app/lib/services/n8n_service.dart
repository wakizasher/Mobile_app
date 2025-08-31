/// Deprecated: No-op N8n service. Webhook calls are fully removed in favor of
/// authenticated backend API usage. This stub remains to avoid import churn.
class N8nService {
  Future<void> sendEvent(String event, Map<String, dynamic> payload) async {}
  Future<void> onUserRegistered({required String username, required String email}) async {}
  Future<void> onFavoriteAdded({required String imdbId}) async {}
  Future<void> onReviewSubmitted({required String imdbId, required String content, int? rating}) async {}
}
