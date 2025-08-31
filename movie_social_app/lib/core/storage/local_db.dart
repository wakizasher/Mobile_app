import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// SQLite initialization with FFI for desktop.
class LocalDatabase {
  static Database? _db;

  static Future<void> init() async {
    if (_db != null) return;

    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'movie_social.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE favorites (
            imdb_id TEXT PRIMARY KEY,
            movie_json TEXT NOT NULL,
            created_at TEXT NOT NULL
          );
        ''');
      },
    );
  }

  static Database get db {
    final db = _db;
    if (db == null) {
      throw StateError('LocalDatabase not initialized. Call LocalDatabase.init() first.');
    }
    return db;
  }
}

class FavoritesDao {
  static Future<void> upsertFavorite({required String imdbId, required Map<String, dynamic> movie, required DateTime createdAt}) async {
    await LocalDatabase.db.insert(
      'favorites',
      {
        'imdb_id': imdbId,
        'movie_json': jsonEncode(movie),
        'created_at': createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> removeFavorite(String imdbId) async {
    await LocalDatabase.db.delete('favorites', where: 'imdb_id = ?', whereArgs: [imdbId]);
  }

  static Future<List<Map<String, dynamic>>> listFavorites() async {
    final rows = await LocalDatabase.db.query('favorites', orderBy: 'created_at DESC');
    return rows.map((r) {
      final movieJson = jsonDecode(r['movie_json'] as String) as Map<String, dynamic>;
      return {
        'imdb_id': r['imdb_id'],
        'movie': movieJson,
        'created_at': r['created_at'],
      };
    }).toList();
  }

  static Future<bool> isFavorite(String imdbId) async {
    final rows = await LocalDatabase.db.query('favorites', where: 'imdb_id = ?', whereArgs: [imdbId], limit: 1);
    return rows.isNotEmpty;
  }
}
