// ignore_for_file: avoid_print
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  // Configure FFI
  sqfliteFfiInit();
  final dbFactory = databaseFactoryFfi;

  final dirPath = r'C:\Users\cucho\projects\ichamba\BDUsuarios';
  final dbFile = p.join(dirPath, 'ichamba.db');

  // Ensure directory exists
  final dir = Directory(dirPath);
  if (!dir.existsSync()) {
    print('Creating directory: $dirPath');
    dir.createSync(recursive: true);
  }

  print('Opening database at: $dbFile');
  final db = await dbFactory.openDatabase(
    dbFile,
    options: OpenDatabaseOptions(
      version: 2,
      onCreate: (db, version) async {
        print('Creating tables...');
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
      },
    ),
  );

  // Ensure table exists (in case DB existed but lacked columns)
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

  // Insert users
  final id1 = await db.insert('users', {
    'name': 'Carlos',
    'first_name': 'Carlos',
    'last_name': 'Gonzalez',
    'address': 'Calle Falsa 123',
    'neighborhood': 'Centro',
    'phone': '555-1234',
  });

  final id2 = await db.insert('users', {
    'name': 'Juan',
    'first_name': 'Juan',
    'last_name': 'Rodriguez',
    'address': 'Av Siempre Viva 742',
    'neighborhood': 'Norte',
    'phone': '555-5678',
  });

  print('Inserted users with ids: $id1, $id2');

  final users = await db.query('users');
  print('Current users in DB:');
  for (var u in users) {
    print(u);
  }

  await db.close();
  print('Database closed.');
}
