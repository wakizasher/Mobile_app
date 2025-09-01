/// API endpoint constants relative to the base URL.
class Endpoints {
  // Auth
  static const login = 'auth/login/';
  static const register = 'auth/register/';
  static const me = 'auth/me/';
  static const userSearch = 'auth/search/';
  // NOTE: Refresh endpoint is not listed in provided API. If supported, set via Env.jwtRefreshEndpoint.

  // Movies
  static const search = 'movies/search/';
  static const popular = 'movies/popular/';
  static String movieDetail(String imdbId) => 'movies/$imdbId/';

  // Social
  static const favorites = 'social/favorites/';
  static String favoriteDetail(String imdbId) => 'social/favorites/$imdbId/';
  static const likesToggle = 'social/likes/toggle/';
  static const reviews = 'social/reviews/';
  static const shares = 'social/shares/';
  static const friends = 'social/friends/';
  static const friendRequests = 'social/friend-requests/';
  static String friendRequestDetail(int id) => 'social/friend-requests/$id/';
  static const usersByGenre = 'social/users-by-genre/';
  static String socialStats(String imdbId) => 'social/stats/$imdbId/';
  static const socialGenerate = 'social/generate/';

  // Movie Nights
  static const movieNights = 'social/movie-nights/';
  static String movieNightDetail(int id) => 'social/movie-nights/$id/';
  static String movieNightJoin(int id) => 'social/movie-nights/$id/join/';
  static String movieNightInvite(int id) => 'social/movie-nights/$id/invite/';
  static String movieNightVote(int id) => 'social/movie-nights/$id/vote/';

  // AI
  static const aiRecommendations = 'ai/recommendations/';
}
