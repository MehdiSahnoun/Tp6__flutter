import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:waiting_room_app/storage/local_queue_storage.dart';
import 'package:waiting_room_app/models/sync_status.dart';

void main() {
  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  test('saveClient adds a record to the database', () async {
    final storage = LocalQueueStorage(inMemory: true);
    await storage.saveClient({
      'id': 'test-123',
      'name': 'Alice',
      'lat': 40.71,
      'lng': -74.00,
      'created_at': '2024-01-01T00:00:00Z',
      'sync_status': SyncStatus.synced.name,
    });
    final clients = await storage.getClients();
    expect(clients.length, 1);
    expect(clients[0]['name'], 'Alice');
    await storage.close();
  });

  test('getClients returns all clients ordered by created_at DESC', () async {
    final storage = LocalQueueStorage(inMemory: true);
    await storage.saveClient({
      'id': '1',
      'name': 'Bob',
      'lat': 1.0,
      'lng': 2.0,
      'created_at': '2024-01-02T00:00:00Z',
      'sync_status': SyncStatus.synced.name,
    });
    await storage.saveClient({
      'id': '2',
      'name': 'Alice',
      'lat': 3.0,
      'lng': 4.0,
      'created_at': '2024-01-01T00:00:00Z',
      'sync_status': SyncStatus.synced.name,
    });
    final clients = await storage.getClients();
    expect(clients.length, 2);
    expect(clients[0]['name'], 'Bob');
    expect(clients[1]['name'], 'Alice');
    await storage.close();
  });

  test('getPendingClients returns only pending and failed records', () async {
    final storage = LocalQueueStorage(inMemory: true);
    await storage.saveClient({
      'id': '1',
      'name': 'Pending',
      'lat': null,
      'lng': null,
      'created_at': '2024-01-01T00:00:00Z',
      'sync_status': SyncStatus.pending.name,
    });
    await storage.saveClient({
      'id': '2',
      'name': 'Synced',
      'lat': null,
      'lng': null,
      'created_at': '2024-01-02T00:00:00Z',
      'sync_status': SyncStatus.synced.name,
    });
    final pending = await storage.getPendingClients();
    expect(pending.length, 1);
    expect(pending[0]['name'], 'Pending');
    await storage.close();
  });

  test('updateSyncStatus updates the sync_status field', () async {
    final storage = LocalQueueStorage(inMemory: true);
    await storage.saveClient({
      'id': 'test-123',
      'name': 'Alice',
      'lat': 40.71,
      'lng': -74.00,
      'created_at': '2024-01-01T00:00:00Z',
      'sync_status': SyncStatus.pending.name,
    });
    await storage.updateSyncStatus('test-123', SyncStatus.synced);
    final clients = await storage.getClients();
    expect(clients[0]['sync_status'], SyncStatus.synced.name);
    await storage.close();
  });
}