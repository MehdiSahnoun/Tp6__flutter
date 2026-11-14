import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:waiting_room_app/local_queue_service.dart';

void main() {
  setUpAll(() {
    // Use in-memory database for tests
    databaseFactory = databaseFactoryFfi;
  });

  test('insertClientLocally adds a record to the database', () async {
    final service = LocalQueueService(inMemory: true);
    await service.insertClientLocally({
      'id': 'test-123',
      'name': 'Alice',
      'lat': 40.71,
      'lng': -74.00,
      'created_at': '2024-01-01T00:00:00Z',
      'is_synced': 0,
    });
    final clients = await service.getUnsyncedClients();
    expect(clients.length, 1);
    expect(clients[0]['name'], 'Alice');
    await service.close();
  });

  test('getClients returns all clients ordered by created_at', () async {
    final service = LocalQueueService(inMemory: true);
    await service.insertClientLocally({
      'id': '1',
      'name': 'Bob',
      'lat': 1.0,
      'lng': 2.0,
      'created_at': '2024-01-02T00:00:00Z',
      'is_synced': 0,
    });
    await service.insertClientLocally({
      'id': '2',
      'name': 'Alice',
      'lat': 3.0,
      'lng': 4.0,
      'created_at': '2024-01-01T00:00:00Z',
      'is_synced': 0,
    });
    final clients = await service.getClients();
    expect(clients.length, 2);
    expect(clients[0]['name'], 'Alice');
    expect(clients[1]['name'], 'Bob');
    await service.close();
  });

  test('markClientAsSynced updates is_synced to 1', () async {
    final service = LocalQueueService(inMemory: true);
    await service.insertClientLocally({
      'id': 'test-123',
      'name': 'Alice',
      'lat': 40.71,
      'lng': -74.00,
      'created_at': '2024-01-01T00:00:00Z',
      'is_synced': 0,
    });
    await service.markClientAsSynced('test-123');
    final unsynced = await service.getUnsyncedClients();
    expect(unsynced.length, 0);
    await service.close();
  });
}