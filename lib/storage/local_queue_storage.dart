import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/sync_status.dart';

class LocalQueueStorage {
  Database? _database;
  final bool _inMemory;

  LocalQueueStorage({bool inMemory = false}) : _inMemory = inMemory;

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (_inMemory) {
      _database = await openDatabase(
        ':memory:',
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
CREATE TABLE clients (
id TEXT PRIMARY KEY,
name TEXT NOT NULL,
lat REAL,
lng REAL,
location_accuracy_m REAL,
created_at TEXT NOT NULL,
sync_status TEXT NOT NULL
)
''');
        },
      );
    } else {
      final path = join(await getDatabasesPath(), 'waiting_queue.db');
      _database = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
CREATE TABLE clients (
id TEXT PRIMARY KEY,
name TEXT NOT NULL,
lat REAL,
lng REAL,
location_accuracy_m REAL,
created_at TEXT NOT NULL,
sync_status TEXT NOT NULL
)
''');
        },
      );
    }
    return _database!;
  }

  Future<void> saveClient(Map<String, dynamic> client) async {
    final db = await database;
    await db.insert(
      'clients',
      client,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getClients() async {
    final db = await database;
    return db.query('clients', orderBy: 'created_at DESC, id DESC');
  }

  /// Fetches both 'pending' and 'failed' records for retry logic
  Future<List<Map<String, dynamic>>> getPendingClients() async {
    final db = await database;
    return db.query(
      'clients',
      where: 'sync_status = ? OR sync_status = ?',
      whereArgs: ['pending', 'failed'],
      orderBy: 'created_at ASC, id ASC',
    );
  }

  Future<void> updateSyncStatus(String id, SyncStatus status) async {
    final db = await database;
    await db.update(
      'clients',
      {'sync_status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}