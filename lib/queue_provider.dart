import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:waiting_room_app/models/client.dart';

class QueueProvider extends ChangeNotifier {
  final List<Client> _clients = [];
  List<Client> get clients => _clients;

  SupabaseClient? _supabase;
  RealtimeChannel? _channel;

  QueueProvider() : _supabase = Supabase.instance.client {
    _fetchInitialClients();
    _setupRealtimeSubscription();
  }

  // Constructor for testing
  QueueProvider.forTesting(SupabaseClient supabase) : _supabase = supabase, super();

  Future<void> _fetchInitialClients() async {
    try {
      final response = await _supabase!
          .from('clients')
          .select()
          .order('created_at');

      _clients.clear();
      _clients.addAll((response as List).map((e) => Client.fromMap(e as Map<String, dynamic>)));
      notifyListeners();
    } catch (e) {
      print('Error fetching clients: $e');
    }
  }

  void _setupRealtimeSubscription() {
    _channel = _supabase!
        .channel('clients_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'clients',
          callback: (payload) {
            final newClient = Client.fromMap(payload.newRecord);
            _clients.add(newClient);
            _clients.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            notifyListeners();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'clients',
          callback: (payload) {
            final deletedId = payload.oldRecord['id'];
            _clients.removeWhere((client) => client.id == deletedId);
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

    try {
      await _supabase!.from('clients').insert({'name': name.trim()});
      print('Client added: $name');
    } catch (e) {
      print('Failed to add client: $e');
    }
  }

  Future<void> removeClient(String id) async {
    try {
      await _supabase!.from('clients').delete().match({'id': id});
      print('Client removed: $id');
    } catch (e) {
      print('Failed to remove client: $e');
    }
  }

  Future<void> nextClient() async {
    if (_clients.isEmpty) {
      print('Queue is empty!');
      return;
    }

    final firstClient = _clients.first;
    await removeClient(firstClient.id);
    print('Next client: ${firstClient.name}');
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}