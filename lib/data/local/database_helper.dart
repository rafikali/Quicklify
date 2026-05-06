import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static Database? _database;
  static const String _dbName = 'quicklify.db';
  static const int _dbVersion = 1;

  DatabaseHelper._();

  static Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE downloads (
        id TEXT PRIMARY KEY,
        source_url TEXT NOT NULL,
        download_url TEXT NOT NULL,
        filename TEXT NOT NULL,
        platform TEXT NOT NULL,
        quality TEXT NOT NULL,
        task_id TEXT,
        status INTEGER DEFAULT 0,
        progress INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        completed_at INTEGER,
        file_size INTEGER
      )
    ''');
  }
}
