import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../models/movie_night.dart';
import '../services/social_service.dart';

class MovieNightsProvider extends ChangeNotifier {
  final SocialService _social;

  MovieNightsProvider(this._social);

  List<MovieNight> nights = [];
  bool loading = false;
  String? error;
  final Set<int> joiningIds = <int>{};
  final Set<int> leavingIds = <int>{};

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      nights = await _social.movieNights();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<MovieNight?> create({
    required String title,
    String? description,
    DateTime? scheduledDate,
    String? location,
    int? maxParticipants,
  }) async {
    error = null;
    try {
      final night = await _social.createMovieNight(
        title: title,
        description: description,
        scheduledDate: scheduledDate,
        location: location,
        maxParticipants: maxParticipants,
      );
      nights.insert(0, night);
      notifyListeners();
      return night;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> refreshDetail(int id) async {
    try {
      final detail = await _social.movieNightDetail(id);
      final idx = nights.indexWhere((n) => n.id == id);
      if (idx >= 0) {
        nights[idx] = detail;
      } else {
        nights.insert(0, detail);
      }
      notifyListeners();
    } catch (_) {
      // ignore detail refresh failures silently
    }
  }

  Future<void> join(int id) async {
    error = null;
    joiningIds.add(id);
    notifyListeners();
    try {
      await _social.joinMovieNight(id);
      await refreshDetail(id);
    } catch (e) {
      error = e.toString();
      notifyListeners();
    } finally {
      joiningIds.remove(id);
      notifyListeners();
    }
  }

  Future<void> leave(int id) async {
    error = null;
    leavingIds.add(id);
    notifyListeners();
    try {
      await _social.leaveMovieNight(id);
      // Remove the night from the in-memory list once the user leaves
      nights.removeWhere((n) => n.id == id);
      notifyListeners();
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      // Treat 404 (not participating), 200 or 204 (no content) as success
      if (status == 404 || status == 200 || status == 204) {
        nights.removeWhere((n) => n.id == id);
        notifyListeners();
        return;
      }
      if (status == 403) {
        // Friendly error: organizer cannot leave
        String message = 'Organizer cannot leave their own movie night.';
        final data = e.response?.data;
        if (data is Map<String, dynamic>) {
          final d = data['detail'];
          if (d is String && d.isNotEmpty) message = d;
        }
        error = message;
        notifyListeners();
        return;
      }
      error = e.message ?? 'Failed to leave movie night';
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    } finally {
      leavingIds.remove(id);
      notifyListeners();
    }
  }

  Future<void> vote({required int id, required String imdbId}) async {
    error = null;
    try {
      await _social.voteMovieNight(id: id, imdbId: imdbId);
      await refreshDetail(id);
    } on DioException catch (e) {
      // Friendly message on permission errors
      final status = e.response?.statusCode ?? 0;
      if (status == 403) {
        String? serverDetail;
        final data = e.response?.data;
        if (data is Map<String, dynamic>) {
          final d = data['detail'];
          if (d is String) serverDetail = d;
        }
        error = serverDetail ?? 'You must accept the invitation before voting.';
        notifyListeners();
        return;
      }
      // Retry once on transient timeouts
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        try {
          await Future.delayed(const Duration(milliseconds: 350));
          await _social.voteMovieNight(id: id, imdbId: imdbId);
          await refreshDetail(id);
          return;
        } catch (_) {}
      }
      error = e.message ?? 'Failed to submit vote';
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> invite({required int id, required int userId}) async {
    error = null;
    try {
      await _social.inviteToMovieNight(id: id, userId: userId);
      await refreshDetail(id);
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
