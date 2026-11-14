import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:waiting_room_app/local_queue_service.dart';
import 'package:waiting_room_app/geolocation_service.dart';

class QueueProvider extends ChangeNotifier {
  final SupabaseClient? _supabase;
  final LocalQueueService _localDb;
  final GeolocationService _geoService;

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> get clients => _clients;

  RealtimeChannel? _channel;

  QueueProvider()
      : _supabase = Supabase.instance.client,
        _localDb = LocalQueueService(),
        _geoService = GeolocationService() {
    initialize();
  }

  // Constructor for testing
  QueueProvider.forTesting(
    SupabaseClient supabase, {
    LocalQueueService? localDb,
    GeolocationService? geoService,
  })  : _supabase = supabase,
        _localDb = localDb ?? LocalQueueService(inMemory: true),
        _geoService = geoService ?? GeolocationService();

  Future<void> initialize() async {
    await _loadQueue();
  }

  Future<void> _loadQueue() async {
    // 1. Load from local DB immediately (offline support)
    _clients = await _localDb.getClients();
    notifyListeners();

    // 2. Sync unsynced records to Supabase
    await _syncLocalToRemote();

    // 3. Subscribe to real-time updates
    _setupRealtimeSubscription();
  }

  Future<void> _syncLocalToRemote() async {
    if (_supabase == null) return;

    final unsynced = await _localDb.getUnsyncedClients();
    bool anySynced = false;

    for (var client in unsynced) {
      try {
        final remoteClient = Map<String, dynamic>.from(client)..remove('is_synced');
        await _supabase.from('clients').upsert(remoteClient);
        await _localDb.markClientAsSynced(client['id'] as String);
        anySynced = true;
      } catch (e) {
        print('Sync failed for ${client['id']}: $e');
      }
    }

    // Refresh UI if any sync succeeded
    if (anySynced) {
      _clients = await _localDb.getClients();
      notifyListeners();
    }
  }

  void _setupRealtimeSubscription() {
    if (_supabase == null) return;

    _channel = _supabase
        .channel('clients_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'clients',
          callback: (payload) {
            final newRecord = payload.newRecord;
            // Check if already exists locally
            final exists = _clients.any((c) => c['id'] == newRecord['id']);
            if (!exists) {
              final newClient = Map<String, dynamic>.from(newRecord)
                ..addAll({'lat': newRecord['lat'], 'lng': newRecord['lng'], 'is_synced': 1});
              _clients.add(newClient);
              _clients.sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));
              // Save to local DB as synced
              unawaited(_localDb.insertClientLocally(newClient));
              notifyListeners();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'clients',
          callback: (payload) {
            final deletedId = payload.oldRecord['id'];
            _clients.removeWhere((client) => client['id'] == deletedId);
            notifyListeners();
          },
        )
        .subscribe();
  }

  Future<void> addClient(String name) async {
    if (name.trim().isEmpty) {
      print('Cannot add empty client name');
      return;
    }

    final position = await _geoService.getCurrentPosition();

    final newClient = {
      'id': const Uuid().v4(),
      'name': name.trim(),
      'lat': position?.latitude,
      'lng': position?.longitude,
      'created_at': DateTime.now().toIso8601String(),
      'is_synced': 0,
    };

    // Save locally immediately
    await _localDb.insertClientLocally(newClient);

    // Update UI instantly
    _clients.add(newClient);
    _clients.sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));
    notifyListeners();

    // Attempt sync (non-blocking for UX)
    unawaited(_syncLocalToRemote());
  }

  Future<void> removeClient(String id) async {
    if (_supabase != null) {
      try {
        await _supabase.from('clients').delete().match({'id': id});
      } catch (e) {
        print('Failed to remove client from remote: $e');
      }
    }

    // Remove from local DB
    await _localDb.markClientAsSynced(id); // Mark as synced so it doesn't try to sync
    await _localDb.close(); // Force refresh

    // Update UI
    _clients.removeWhere((client) => client['id'] == id);
    notifyListeners();
  }

  Future<void> nextClient() async {
    if (_clients.isEmpty) {
      print('Queue is empty!');
      return;
    }

    final firstClient = _clients.first;
    await removeClient(firstClient['id'] as String);
    print('Next client: ${firstClient['name']}');
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _localDb.close();
    super.dispose();
  }
}