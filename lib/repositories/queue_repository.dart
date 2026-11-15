import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/client.dart';
import '../models/sync_status.dart';
import '../storage/local_queue_storage.dart';

class QueueRepository {
  final SupabaseClient _supabase;
  final LocalQueueStorage _localStorage;

  QueueRepository(
    this._supabase, {
    LocalQueueStorage? localStorage,
  }) : _localStorage = localStorage ?? LocalQueueStorage();

  /// Register a client on the server using the RPC function
  Future<void> registerOnServer(Client client) async {
    await _supabase.rpc(
      'register_queue_client',
      params: {
        'p_id': client.id,
        'p_name': client.name,
        'p_lat': client.lat,
        'p_lng': client.lng,
        'p_accuracy': client.locationAccuracy,
        'p_created_at': client.createdAt.toIso8601String(),
      },
    );
  }

  /// Fetch a page of clients from Supabase
  Future<List<Client>> fetchPage({
    required int offset,
    required int limit,
  }) async {
    final response = await _supabase
        .from('clients')
        .select()
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return response
        .map((row) => Client.fromSupabaseMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Save a client locally (for offline support)
  Future<void> saveClientLocally(Client client) async {
    await _localStorage.saveClient(client.toLocalMap());
  }

  /// Get all clients from local storage
  Future<List<Client>> getClientsLocally() async {
    final records = await _localStorage.getClients();
    return records.map((r) => Client.fromLocalMap(r)).toList();
  }

  /// Get pending clients from local storage
  Future<List<Client>> getPendingClientsLocally() async {
    final records = await _localStorage.getPendingClients();
    return records.map((r) => Client.fromLocalMap(r)).toList();
  }

  /// Update sync status of a client locally
  Future<void> updateLocalSyncStatus(String id, SyncStatus status) async {
    await _localStorage.updateSyncStatus(id, status);
  }

  /// Delete a client from both server and local storage
  Future<void> deleteClient(String id) async {
    try {
      await _supabase.from('clients').delete().match({'id': id});
    } catch (_) {
      // Ignore remote deletion errors
    }
    await _localStorage.updateSyncStatus(id, SyncStatus.synced);
  }

  void dispose() {
    _localStorage.close();
  }
}