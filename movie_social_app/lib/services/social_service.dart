import 'dart:async';
import '../core/constants/endpoints.dart';
import '../core/constants/env.dart';
import '../core/network/dio_client.dart';
import '../models/favorite.dart';
import '../models/review.dart';
import '../models/friendship.dart';
import '../models/friend_request.dart';
import '../models/social_stats.dart';
import '../models/user.dart';
import '../models/movie_night.dart';
import '../models/movie_night_participant.dart';

class SocialService {
  final ApiClient client;
  SocialService({required this.client});

  void _postN8nEvent(Map<String, dynamic> payload) {
    final url = Env.n8nWebhookUrl;
    if (url == null || url.isEmpty) return;
    // Fire-and-forget to avoid blocking UX
    Future.microtask(() async {
      try {
        await client.dio.post(url, data: payload);
      } catch (_) {
        // swallow errors; analytics shouldn't break core flows
      }
    });
  }

  Future<List<Favorite>> favorites() async {
    final res = await client.dio.get(Endpoints.favorites);
    final data = res.data;
    final rawList = data is List
        ? data
        : (data is Map<String, dynamic> ? (data['results'] as List? ?? []) : const []);
    final list = rawList.cast<Map<String, dynamic>>();
    return list.map(Favorite.fromJson).toList();
  }

  // --- User Search (Auth scope) ---
  Future<List<AppUser>> searchUsers(String query) async {
    final res = await client.dio.get(Endpoints.userSearch, queryParameters: {'q': query});
    final data = res.data;
    final rawList = data is List
        ? data
        : (data is Map<String, dynamic> ? (data['results'] as List? ?? []) : const []);
    final list = rawList.cast<Map<String, dynamic>>();
    return list.map(AppUser.fromJson).toList();
  }

  Future<void> addFavorite(String imdbId) async {
    await client.dio.post(Endpoints.favorites, data: {'imdb_id': imdbId});
    _postN8nEvent({
      'event': 'favorite_added',
      'imdb_id': imdbId,
      'ts': DateTime.now().toIso8601String(),
    });
  }

  Future<void> removeFavorite(String imdbId) async {
    // Backend expects DELETE at /social/favorites/<imdb_id>/
    await client.dio.delete(Endpoints.favoriteDetail(imdbId));
    _postN8nEvent({
      'event': 'favorite_removed',
      'imdb_id': imdbId,
      'ts': DateTime.now().toIso8601String(),
    });
  }

  Future<bool> toggleLike(String imdbId) async {
    final res = await client.dio.post(Endpoints.likesToggle, data: {'imdb_id': imdbId});
    final data = res.data;
    bool liked = false;
    if (data is Map<String, dynamic>) {
      liked = data['liked'] == true;
    }
    _postN8nEvent({
      'event': 'like_toggled',
      'imdb_id': imdbId,
      'liked': liked,
      'ts': DateTime.now().toIso8601String(),
    });
    return liked;
  }

  Future<List<Review>> reviews({required String imdbId}) async {
    final res = await client.dio.get(Endpoints.reviews, queryParameters: {'imdb_id': imdbId});
    final data = res.data;
    final rawList = data is List
        ? data
        : (data is Map<String, dynamic> ? (data['results'] as List? ?? []) : const []);
    final list = rawList.cast<Map<String, dynamic>>();
    return list.map(Review.fromJson).toList();
  }

  Future<void> addReview({required String imdbId, required String content, int? rating}) async {
    await client.dio.post(Endpoints.reviews, data: {
      'imdb_id': imdbId,
      'content': content,
      if (rating != null) 'rating': rating,
    });
    _postN8nEvent({
      'event': 'review_submitted',
      'imdb_id': imdbId,
      'rating': rating,
      'content': content,
      'ts': DateTime.now().toIso8601String(),
    });
  }

  // --- Friends ---
  Future<List<Friendship>> friends() async {
    final res = await client.dio.get(Endpoints.friends);
    final data = res.data;
    final rawList = data is List
        ? data
        : (data is Map<String, dynamic> ? (data['results'] as List? ?? []) : const []);
    final list = rawList.cast<Map<String, dynamic>>();
    return list.map(Friendship.fromJson).toList();
  }

  // --- Friend Requests ---
  Future<List<FriendRequest>> friendRequests() async {
    final res = await client.dio.get(Endpoints.friendRequests);
    final data = res.data;
    final rawList = data is List
        ? data
        : (data is Map<String, dynamic> ? (data['results'] as List? ?? []) : const []);
    final list = rawList.cast<Map<String, dynamic>>();
    return list.map(FriendRequest.fromJson).toList();
  }

  Future<FriendRequest> sendFriendRequest({required int toUserId}) async {
    final res = await client.dio.post(Endpoints.friendRequests, data: {'to_user_id': toUserId});
    return FriendRequest.fromJson(res.data as Map<String, dynamic>);
  }

  Future<FriendRequest> updateFriendRequestStatus({required int id, required String action}) async {
    final res = await client.dio.patch(Endpoints.friendRequestDetail(id), data: {'action': action});
    return FriendRequest.fromJson(res.data as Map<String, dynamic>);
  }

  // --- Social Stats (per movie) ---
  Future<SocialStats> socialStats(String imdbId) async {
    // Backend path: social/stats/<imdb_id>/
    final res = await client.dio.get(Endpoints.socialStats(imdbId));
    return SocialStats.fromJson(res.data as Map<String, dynamic>);
  }

  // --- AI Social Post Generation ---
  // Returns map with keys: twitter, instagram, facebook
  Future<Map<String, String>> generateSocialPost({
    required String imdbId,
    Map<String, dynamic>? preferences,
  }) async {
    final payload = {
      'imdb_id': imdbId,
      if (preferences != null) 'preferences': preferences,
    };
    final res = await client.dio.post(Endpoints.generateSocialPost, data: payload);
    final data = res.data;
    if (data is Map<String, dynamic>) {
      return {
        'twitter': (data['twitter'] ?? '').toString(),
        'instagram': (data['instagram'] ?? '').toString(),
        'facebook': (data['facebook'] ?? '').toString(),
      };
    }
    return const {'twitter': '', 'instagram': '', 'facebook': ''};
  }

  // --- Shares ---
  Future<void> share({required String imdbId, required String platform}) async {
    await client.dio.post(Endpoints.shares, data: {
      'imdb_id': imdbId,
      'platform': platform,
    });
  }

  // --- Movie Nights ---
  Future<List<MovieNight>> movieNights() async {
    final res = await client.dio.get(Endpoints.movieNights);
    final data = res.data;
    final rawList = data is List
        ? data
        : (data is Map<String, dynamic> ? (data['results'] as List? ?? []) : const []);
    final list = rawList.cast<Map<String, dynamic>>();
    return list.map(MovieNight.fromJson).toList();
  }

  Future<MovieNight> createMovieNight({
    required String title,
    String? description,
    DateTime? scheduledDate,
    String? location,
    int? maxParticipants,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      if (description != null) 'description': description,
      if (scheduledDate != null) 'scheduled_date': scheduledDate.toIso8601String(),
      if (location != null) 'location': location,
      if (maxParticipants != null) 'max_participants': maxParticipants,
    };
    final res = await client.dio.post(Endpoints.movieNights, data: payload);
    return MovieNight.fromJson(res.data as Map<String, dynamic>);
  }

  Future<MovieNight> movieNightDetail(int id) async {
    final res = await client.dio.get(Endpoints.movieNightDetail(id));
    return MovieNight.fromJson(res.data as Map<String, dynamic>);
  }

  Future<MovieNight> updateMovieNight({
    required int id,
    String? title,
    String? description,
    DateTime? scheduledDate,
    String? location,
    String? status,
    int? maxParticipants,
  }) async {
    final payload = <String, dynamic>{
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (scheduledDate != null) 'scheduled_date': scheduledDate.toIso8601String(),
      if (location != null) 'location': location,
      if (status != null) 'status': status,
      if (maxParticipants != null) 'max_participants': maxParticipants,
    };
    final res = await client.dio.put(Endpoints.movieNightDetail(id), data: payload);
    return MovieNight.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteMovieNight(int id) async {
    await client.dio.delete(Endpoints.movieNightDetail(id));
  }

  Future<MovieNightParticipant> joinMovieNight(int id) async {
    final res = await client.dio.post(Endpoints.movieNightJoin(id));
    return MovieNightParticipant.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> leaveMovieNight(int id) async {
    await client.dio.delete(Endpoints.movieNightJoin(id));
  }

  Future<void> voteMovieNight({required int id, required String imdbId}) async {
    await client.dio.post(Endpoints.movieNightVote(id), data: {
      // Backend expects 'movie_imdb_id' per MovieNightVoteSerializer
      'movie_imdb_id': imdbId,
    });
  }
}
