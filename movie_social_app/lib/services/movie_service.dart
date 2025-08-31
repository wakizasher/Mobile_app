import 'package:dio/dio.dart';

import '../core/constants/endpoints.dart';
import '../core/constants/env.dart';
import '../core/network/dio_client.dart';
import '../models/movie.dart';

class MovieService {
  final ApiClient client;
  MovieService({required this.client});

  Future<List<Movie>> popular() async {
    final res = await client.dio.get(Endpoints.popular);
    final data = res.data;
    final rawList = data is List
        ? data
        : (data is Map<String, dynamic> ? (data['results'] as List? ?? []) : const []);
    final list = rawList.cast<Map<String, dynamic>>();
    return list.map(Movie.fromJson).toList();
  }

  Future<List<Movie>> search(String query) async {
    // Prefer backend search; fallback to OMDb direct if backend fails
    try {
      final res = await client.dio.get(Endpoints.search, queryParameters: {'q': query});
      final data = res.data;
      if (data is Map<String, dynamic>) {
        // Backend proxies OMDb and returns OMDb-shaped payload
        final search = (data['Search'] as List? ?? []).cast<Map<String, dynamic>>();
        return search
            .map((j) => Movie(
                  imdbId: j['imdbID'] as String,
                  title: j['Title'] as String?,
                  year: j['Year'] as String?,
                  poster: j['Poster'] as String?,
                  data: j,
                ))
            .toList();
      }
      if (data is List) {
        // In case backend ever returns a straight list of movies
        final list = data.cast<Map<String, dynamic>>();
        return list.map(Movie.fromJson).toList();
      }
      return const <Movie>[];
    } catch (_) {
      // OMDb fallback
      final omdb = Dio();
      final url = 'https://www.omdbapi.com/';
      final res = await omdb.get(url, queryParameters: {'apikey': Env.omdbApiKey, 's': query});
      final search = (res.data['Search'] as List? ?? []).cast<Map<String, dynamic>>();
      return search
          .map((j) => Movie(
                imdbId: j['imdbID'] as String,
                title: j['Title'] as String?,
                year: j['Year'] as String?,
                poster: j['Poster'] as String?,
                data: j,
              ))
          .toList();
    }
  }

  Future<Movie> detail(String imdbId) async {
    final res = await client.dio.get(Endpoints.movieDetail(imdbId));
    return Movie.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Movie>> recommendations() async {
    try {
      final res = await client.dio.get(Endpoints.aiRecommendations);
      final data = res.data;
      final rawList = data is List
          ? data
          : (data is Map<String, dynamic> ? (data['results'] as List? ?? []) : const []);
      final list = rawList.cast<Map<String, dynamic>>();
      final movies = list.map(Movie.fromJson).toList();
      if (movies.isEmpty) {
        // Fallback if AI returns nothing
        // ignore: avoid_print
        print('[MovieService] AI recommendations empty. Falling back to popular movies.');
        return await popular();
      }
      return movies;
    } catch (e) {
      // ignore: avoid_print
      print('[MovieService] Failed to load AI recommendations: $e. Falling back to popular movies.');
      return await popular();
    }
  }
}

