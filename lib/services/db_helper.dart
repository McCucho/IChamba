import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DBHelper {
  static const _dbFileName = 'ichamba.db';
  static const _prefDbPathKey = 'db_path';
  static const _dbVersion = 2;

  // Web fallback keys
  static const _prefUsersKey = 'users_list_json';
  static const _prefNextIdKey = 'users_next_id';

  static Database? _db;
  static bool _webFallback = false;

  static Future<void> init() async {
    if (_db != null || _webFallback) return;

    // Shared prefs to read custom db path
    final prefs = await SharedPreferences.getInstance();
    String? customPath = prefs.getString(_prefDbPathKey);

    // If no custom path in prefs, check environment or project file (only on non-web)
    if (!kIsWeb && (customPath == null || customPath.isEmpty)) {
      try {
        // environment variable
        final envPath = Platform.environment['ICHAMBA_DB_DIR'];
        if (envPath != null && envPath.isNotEmpty) {
          customPath = envPath;
          await prefs.setString(_prefDbPathKey, customPath);
        } else {
          // project file fallback
          final file = File(p.join(Directory.current.path, '.ichamba_db_path'));
          if (await file.exists()) {
            final content = (await file.readAsString()).trim();
            if (content.isNotEmpty) {
              customPath = content;
              await prefs.setString(_prefDbPathKey, customPath);
            }
          }
        }
      } catch (e) {
        // ignore environment/file read errors
      }
    }

    // Web: use SharedPreferences fallback (persistent via browser storage)
    if (kIsWeb) {
      _webFallback = true;
      // ensure next id exists
      if (!prefs.containsKey(_prefNextIdKey)) {
        await prefs.setInt(_prefNextIdKey, 1);
      }
      return;
    }

    String dbPath;

    if (customPath != null && customPath.isNotEmpty) {
      dbPath = p.join(customPath, _dbFileName);
    } else {
      // Desktop / Mobile: default to application documents directory
      final docs = await getApplicationDocumentsDirectory();
      dbPath = p.join(docs.path, _dbFileName);
    }

    // Use ffi factory on desktop for better compatibility
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      var databaseFactory = databaseFactoryFfi;
      _db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: _dbVersion,
          onCreate: (db, version) async {
            await _createTables(db);
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            if (oldVersion < 2 && newVersion >= 2) {
              try {
                await db.execute(
                  'ALTER TABLE users ADD COLUMN first_name TEXT',
                );
              } catch (_) {}
              try {
                await db.execute('ALTER TABLE users ADD COLUMN last_name TEXT');
              } catch (_) {}
              try {
                await db.execute('ALTER TABLE users ADD COLUMN address TEXT');
              } catch (_) {}
              try {
                await db.execute(
                  'ALTER TABLE users ADD COLUMN neighborhood TEXT',
                );
              } catch (_) {}
              try {
                await db.execute('ALTER TABLE users ADD COLUMN phone TEXT');
              } catch (_) {}
            }
          },
        ),
      );
    } else {
      // Mobile platforms
      _db = await openDatabase(
        dbPath,
        version: _dbVersion,
        onCreate: (db, version) async {
          await _createTables(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2 && newVersion >= 2) {
            try {
              await db.execute('ALTER TABLE users ADD COLUMN first_name TEXT');
            } catch (_) {}
            try {
              await db.execute('ALTER TABLE users ADD COLUMN last_name TEXT');
            } catch (_) {}
            try {
              await db.execute('ALTER TABLE users ADD COLUMN address TEXT');
            } catch (_) {}
            try {
              await db.execute(
                'ALTER TABLE users ADD COLUMN neighborhood TEXT',
              );
            } catch (_) {}
            try {
              await db.execute('ALTER TABLE users ADD COLUMN phone TEXT');
            } catch (_) {}
          }
        },
      );
    }
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        first_name TEXT,
        last_name TEXT,
        address TEXT,
        neighborhood TEXT,
        phone TEXT
      );
    ''');
  }

  static Future<int> createUser(String name) async {
    await init();
    if (_webFallback) {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefUsersKey);
      List<dynamic> users = jsonStr != null
          ? json.decode(jsonStr) as List<dynamic>
          : [];
      int nextId = prefs.getInt(_prefNextIdKey) ?? 1;
      final user = {'id': nextId, 'name': name};
      users.add(user);
      await prefs.setString(_prefUsersKey, json.encode(users));
      await prefs.setInt(_prefNextIdKey, nextId + 1);
      return nextId;
    }

    return await _db!.insert('users', {'name': name});
  }

  static Future<Map<String, Object?>?> getUser(int id) async {
    await init();
    if (_webFallback) {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefUsersKey);
      if (jsonStr == null) return null;
      final users = json.decode(jsonStr) as List<dynamic>;
      final found = users.firstWhere(
        (u) => (u['auth_id'] as int) == id,
        orElse: () => null,
      );
      if (found == null) return null;
      return Map<String, Object?>.from(found as Map);
    }

    final res = await _db!.query('users', where: 'id = ?', whereArgs: [id]);
    if (res.isEmpty) return null;
    return res.first;
  }

  static Future<List<Map<String, Object?>>> getAllUsers() async {
    await init();
    if (_webFallback) {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefUsersKey);
      if (jsonStr == null) return [];
      final users = json.decode(jsonStr) as List<dynamic>;
      return users.map((u) => Map<String, Object?>.from(u as Map)).toList();
    }

    return await _db!.query('users');
  }

  static Future<int> updateUser(int id, Map<String, Object?> fields) async {
    await init();
    if (_webFallback) {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefUsersKey);
      List<dynamic> users = jsonStr != null
          ? json.decode(jsonStr) as List<dynamic>
          : [];
      for (var u in users) {
        if ((u['auth_id'] as int) == id) {
          fields.forEach((k, v) => u[k] = v);
          break;
        }
      }
      await prefs.setString(_prefUsersKey, json.encode(users));
      return id;
    }

    await _db!.update('users', fields, where: 'id = ?', whereArgs: [id]);
    return id;
  }

  static Future<void> setCustomDbDirectory(String dirPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefDbPathKey, dirPath);
    // Ensure directory exists
    try {
      final d = Directory(dirPath);
      if (!d.existsSync()) {
        d.createSync(recursive: true);
      }
    } catch (e) {
      // ignore, init will fail later if necessary
      debugPrint('Failed to create directory $dirPath: $e');
    }

    // Re-init DB at new location
    await _close();
    // If web, nothing to re-init, but keep prefs
    await init();
  }

  static Future<String?> getCurrentDbPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefDbPathKey);
  }

  /// Returns full path to the DB file when not using web fallback.
  static Future<String?> getDbFilePath() async {
    final prefs = await SharedPreferences.getInstance();
    if (kIsWeb) return null;
    final customPath = prefs.getString(_prefDbPathKey);
    if (customPath != null && customPath.isNotEmpty) {
      return p.join(customPath, _dbFileName);
    }
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, _dbFileName);
  }

  static Future<void> _close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
