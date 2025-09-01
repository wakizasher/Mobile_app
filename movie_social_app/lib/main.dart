import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/constants/env.dart';

// STEP 4 wiring: Providers, Router, Services
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'core/storage/local_db.dart';
import 'core/storage/secure_storage.dart';
import 'core/network/dio_client.dart';
import 'services/movie_service.dart';
import 'services/social_service.dart';
import 'providers/auth_provider.dart';
import 'providers/movies_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/social_actions_provider.dart';
import 'providers/friends_provider.dart';
import 'providers/friend_requests_provider.dart';
import 'providers/recommendations_provider.dart';
import 'providers/social_stats_provider.dart';
import 'providers/reviews_provider.dart';
import 'providers/user_search_provider.dart';
import 'providers/movie_nights_provider.dart';
import 'providers/social_post_provider.dart';

// Screens (aliased to avoid name collisions with placeholder widgets below)
import 'screens/home/home_screen.dart' as hs;
import 'screens/search/search_screen.dart' as ss;
import 'screens/favorites/favorites_screen.dart' as fs;
import 'screens/profile/profile_screen.dart' as ps;
import 'screens/friends/friends_screen.dart' as frs;
import 'screens/movie/movie_detail_screen.dart' as ms;
import 'screens/auth/login_screen.dart' as auth_login;
import 'screens/auth/register_screen.dart' as auth_register;
import 'screens/movie_nights/movie_nights_screen.dart' as mns;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Fallback silently if .env is missing
  }
  await LocalDatabase.init();
  runApp(const AppRoot());
}

class MinimalApp extends StatelessWidget {
  const MinimalApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Delegate to AppRoot which sets up Providers + GoRouter.
    return const AppRoot();
  }
}

/// Simple wrapper used by tests (widget_test.dart) to build the app.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => const AppRoot();
}

/// Shell scaffold that shows a persistent bottom navigation bar for the main tabs
class MainShellScaffold extends StatelessWidget {
  const MainShellScaffold({super.key, required this.child});

  final Widget child;

  int _indexForLocation(String location) {
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/nights')) return 2;
    if (location.startsWith('/favorites')) return 3;
    if (location.startsWith('/profile')) return 4;
    if (location.startsWith('/friends')) return 4;
    return 0; // default to home
  }

  @override
  Widget build(BuildContext context) {
    final locationPath = GoRouterState.of(context).uri.path;
    final currentIndex = _indexForLocation(locationPath);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/home');
              break;
            case 1:
              context.go('/search');
              break;
            case 2:
              context.go('/nights');
              break;
            case 3:
              context.go('/favorites');
              break;
            case 4:
              context.go('/profile');
              break;
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), selectedIcon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.event), selectedIcon: Icon(Icons.event), label: 'Nights'),
          NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Favorites'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

/// Root widget that wires Providers and GoRouter, and bootstraps auth.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late final SecureTokenStorage _storage;
  late final ApiClient _client;
  bool _bootstrapped = false;
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    _storage = SecureTokenStorage();
    _client = ApiClient(tokenStorage: _storage);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(_storage, _client)),
        ChangeNotifierProvider(create: (_) => MoviesProvider(MovieService(client: _client))),
        ChangeNotifierProvider(create: (_) => FavoritesProvider(SocialService(client: _client))),
        ChangeNotifierProvider(create: (_) => SocialActionsProvider(_client)),
        ChangeNotifierProvider(create: (_) => FriendsProvider(SocialService(client: _client))),
        ChangeNotifierProvider(create: (_) => FriendRequestsProvider(SocialService(client: _client))),
        ChangeNotifierProvider(create: (_) => RecommendationsProvider(MovieService(client: _client))),
        ChangeNotifierProvider(create: (_) => SocialStatsProvider(SocialService(client: _client))),
        ChangeNotifierProvider(create: (_) => ReviewsProvider(SocialService(client: _client))),
        ChangeNotifierProvider(create: (_) => UserSearchProvider(SocialService(client: _client))),
        ChangeNotifierProvider(create: (_) => MovieNightsProvider(SocialService(client: _client))),
        ChangeNotifierProvider(create: (_) => SocialPostProvider(SocialService(client: _client))),
      ],
      child: Builder(
        builder: (context) {
          // Kick off auth bootstrap once after providers are available
          if (!_bootstrapped) {
            _bootstrapped = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<AuthProvider>().bootstrap();
              // Preload favorites from local DB for instant UI state
              context.read<FavoritesProvider>().loadLocal();
            });
          }

          final auth = context.watch<AuthProvider>();
          // Reset dataLoaded when user logs out, so next login triggers loads again
          if (auth.status != AuthStatus.authenticated && _dataLoaded) {
            _dataLoaded = false;
          }
          if (auth.status == AuthStatus.authenticated && !_dataLoaded) {
            _dataLoaded = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              // Sync server data once authenticated
              final favoritesProvider = context.read<FavoritesProvider>();
              final friendsProvider = context.read<FriendsProvider>();
              final friendRequestsProvider = context.read<FriendRequestsProvider>();
              final recommendationsProvider = context.read<RecommendationsProvider>();
              final movieNightsProvider = context.read<MovieNightsProvider>();
              await favoritesProvider.syncFromServer();
              friendsProvider.load();
              friendRequestsProvider.load();
              recommendationsProvider.load();
              movieNightsProvider.load();
            });
          }
          final router = GoRouter(
            initialLocation: '/home',
            refreshListenable: auth,
            redirect: (context, state) {
              final status = auth.status;
              final loggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';
              if (status == AuthStatus.unknown) return null; // wait until decided
              final isAuthed = status == AuthStatus.authenticated;
              if (!isAuthed && !loggingIn) return '/login';
              if (isAuthed && loggingIn) return '/home';
              return null;
            },
            routes: [
              GoRoute(path: '/login', builder: (context, state) => const auth_login.LoginScreen()),
              GoRoute(path: '/register', builder: (context, state) => const auth_register.RegisterScreen()),
              ShellRoute(
                builder: (context, state, child) => MainShellScaffold(child: child),
                routes: [
                  GoRoute(path: '/home', builder: (context, state) => const hs.HomeScreen()),
                  GoRoute(path: '/search', builder: (context, state) => const ss.SearchScreen()),
                  GoRoute(path: '/favorites', builder: (context, state) => const fs.FavoritesScreen()),
                  GoRoute(path: '/nights', builder: (context, state) => const mns.MovieNightsScreen()),
                  GoRoute(path: '/profile', builder: (context, state) => const ps.ProfileScreen()),
                  GoRoute(path: '/friends', builder: (context, state) => const frs.FriendsScreen()),
                ],
              ),
              GoRoute(
                path: '/movie/:imdbId',
                builder: (context, state) => ms.MovieDetailScreen(
                  imdbId: state.pathParameters['imdbId']!,
                ),
              ),
            ],
          );

          return MaterialApp.router(
            title: 'Movie Social',
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF141414), // Netflix dark gray
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFFE50914), // Netflix red
                secondary: Color(0xFFB81D24),
                surface: Color(0xFF141414),
                onSurface: Colors.white,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                foregroundColor: Colors.white,
              ),
              cardColor: const Color(0xFF1F1F1F),
              navigationBarTheme: const NavigationBarThemeData(
                backgroundColor: Color(0xFF000000),
                indicatorColor: Color(0x33FFFFFF),
                labelTextStyle: WidgetStatePropertyAll(
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
                iconTheme: WidgetStatePropertyAll(IconThemeData(color: Colors.white)),
              ),
            ),
            routerConfig: router,
          );
        },
      ),
    );
  }
}

class MainNav extends StatefulWidget {
  const MainNav({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _index = 0;

  static const _titles = ['Home', 'Search', 'Favorites', 'Profile'];

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      const HomeScreen(),
      const SearchScreen(),
      const FavoritesScreen(),
      ProfileScreen(onLogout: widget.onLogout),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(
        index: _index,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class TestPage extends StatelessWidget {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Second Screen')),
      body: const Center(child: Text('Navigation Works!')),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final movies = [
      {
        'title': 'The Last Horizon',
        'year': 2021,
        'rating': 8.2,
        'poster': 'https://via.placeholder.com/300x450?text=Horizon',
      },
      {
        'title': 'Neon Nights',
        'year': 2020,
        'rating': 7.5,
        'poster': 'https://via.placeholder.com/300x450?text=Neon+Nights',
      },
      {
        'title': 'Echoes in Time',
        'year': 2019,
        'rating': 7.9,
        'poster': 'https://via.placeholder.com/300x450?text=Echoes',
      },
      {
        'title': 'Midnight Road',
        'year': 2022,
        'rating': 8.1,
        'poster': 'https://via.placeholder.com/300x450?text=Midnight+Road',
      },
      {
        'title': 'Quantum Drift',
        'year': 2018,
        'rating': 7.2,
        'poster': 'https://via.placeholder.com/300x450?text=Quantum+Drift',
      },
      {
        'title': 'Silent River',
        'year': 2017,
        'rating': 7.0,
        'poster': 'https://via.placeholder.com/300x450?text=Silent+River',
      },
      {
        'title': 'Crimson Sky',
        'year': 2016,
        'rating': 6.8,
        'poster': 'https://via.placeholder.com/300x450?text=Crimson+Sky',
      },
      {
        'title': 'Hidden Path',
        'year': 2023,
        'rating': 8.4,
        'poster': 'https://via.placeholder.com/300x450?text=Hidden+Path',
      },
      {
        'title': 'Stardust Echo',
        'year': 2015,
        'rating': 7.1,
        'poster': 'https://via.placeholder.com/300x450?text=Stardust+Echo',
      },
      {
        'title': 'Paper Dreams',
        'year': 2014,
        'rating': 6.9,
        'poster': 'https://via.placeholder.com/300x450?text=Paper+Dreams',
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final desiredCardWidth = 160.0;
        final count = (width / desiredCardWidth).floor();
        final crossAxisCount = count.clamp(2, 6);
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.62,
          ),
          itemCount: movies.length,
          itemBuilder: (context, index) {
            final m = movies[index];
            return _MovieCard(
              title: m['title'] as String,
              year: m['year'] as int,
              rating: (m['rating'] as num).toDouble(),
              poster: m['poster'] as String,
            );
          },
        );
      },
    );
  }
}

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final popular = ['Dune', 'Oppenheimer', 'The Batman', 'Avatar', 'Interstellar', 'Inception'];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search movies',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Popular searches', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final term in popular)
                FilterChip(
                  label: Text(term),
                  onSelected: (_) {},
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border, size: 64, color: color.primary),
            const SizedBox(height: 12),
            Text('No favorites yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Save movies to your favorites to see them here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundImage: NetworkImage('https://via.placeholder.com/150?text=User'),
          ),
          const SizedBox(height: 12),
          Text('John Doe', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '@johndoe',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(child: _StatCard(label: 'Favorites', value: '12')),
              SizedBox(width: 12),
              Expanded(child: _StatCard(label: 'Reviews', value: '3')),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('About', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Movie enthusiast. Love sci-fi and thrillers.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logged out')),
                );
                onLogout();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------- AUTH ---------------------------
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loggedIn = false;
  bool _showRegister = false;

  final _storage = const FlutterSecureStorage();

  void _handleLoginSuccess(Map<String, dynamic> tokens) async {
    // Store tokens but do NOT auto-validate on startup
    if (tokens.containsKey('access')) {
      await _storage.write(key: 'access_token', value: tokens['access'] as String);
    }
    if (tokens.containsKey('refresh')) {
      await _storage.write(key: 'refresh_token', value: tokens['refresh'] as String);
    }
    if (tokens.containsKey('token')) {
      await _storage.write(key: 'token', value: tokens['token'] as String);
    }
    setState(() => _loggedIn = true);
  }

  Future<void> _logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'token');
    setState(() => _loggedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loggedIn) {
      return _showRegister
          ? RegisterScreen(
              onRegistered: () {
                setState(() => _showRegister = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Registration successful. Please login.')),
                );
              },
              onSwitchToLogin: () => setState(() => _showRegister = false),
            )
          : LoginScreen(
              onLoginSuccess: _handleLoginSuccess,
              onSwitchToRegister: () => setState(() => _showRegister = true),
            );
    }
    return MainNav(onLogout: _logout);
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoginSuccess, required this.onSwitchToRegister});

  final void Function(Map<String, dynamic> tokens) onLoginSuccess;
  final VoidCallback onSwitchToRegister;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController(); // email or username
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await _AuthApi.login(identifier: _idController.text.trim(), password: _passwordController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged in')));
      widget.onLoginSuccess(res);
    } on DioException catch (e) {
      final msg = e.response?.data is Map && (e.response?.data['detail'] != null)
          ? e.response?.data['detail'].toString()
          : 'Login failed';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg ?? 'Login failed')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _idController,
                    decoration: const InputDecoration(
                      labelText: 'Email or Username',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Login'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading ? null : widget.onSwitchToRegister,
                    child: const Text("Don't have an account? Register"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.onRegistered, required this.onSwitchToLogin});

  final VoidCallback onRegistered;
  final VoidCallback onSwitchToLogin;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _AuthApi.register(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      widget.onRegistered();
    } on DioException catch (e) {
      final msg = e.response?.data is Map && (e.response?.data['detail'] != null)
          ? e.response?.data['detail'].toString()
          : 'Registration failed';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg ?? 'Registration failed')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(v.trim())) return 'Invalid email';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) => (v != _passwordController.text) ? 'Passwords do not match' : null,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Register'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading ? null : widget.onSwitchToLogin,
                    child: const Text('Already have an account? Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthApi {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  static Future<Map<String, dynamic>> login({required String identifier, required String password}) async {
    // Send either email or username based on format
    final isEmail = identifier.contains('@');
    final payload = isEmail
        ? {'email': identifier, 'password': password}
        : {'username': identifier, 'password': password};
    final res = await _dio.post('auth/login/', data: payload);
    if (res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    return {'token': res.data.toString()};
  }

  static Future<void> register({required String username, required String email, required String password}) async {
    final payload = {'username': username, 'email': email, 'password': password};
    await _dio.post('auth/register/', data: payload);
  }
}

class _MovieCard extends StatelessWidget {
  const _MovieCard({required this.title, required this.year, required this.rating, required this.poster});

  final String title;
  final int year;
  final double rating;
  final String poster;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Image.network(
                poster,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade300,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '$year',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(rating.toStringAsFixed(1), style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    return Card(
      elevation: 1,
      color: color.surfaceContainerHighest.withValues(alpha: 0.6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: color.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
