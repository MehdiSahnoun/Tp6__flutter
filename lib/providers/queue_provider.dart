import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/client.dart';
import '../models/queue_state.dart';
import '../models/sync_status.dart';
import '../repositories/queue_repository.dart';
import '../services/geolocation_service.dart';
import '../services/sync_service.dart';
import '../storage/local_queue_storage.dart';

class QueueProvider extends ChangeNotifier {
  final QueueRepository _repository;
  final GeolocationService _geolocationService;
  final SyncService? _syncService;
  final SupabaseClient? _supabase;

  final List<Client> _clients = [];
  QueueState _state = QueueState.initial;
  String? _errorMessage;
  int _page = 0;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  RealtimeChannel? _channel;

  List<Client> get clients => List.unmodifiable(_clients);
  QueueState get state => _state;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;

  QueueProvider(
    this._repository,
    this._geolocationService, {
    SyncService? syncService,
    SupabaseClient? supabase,
  })  : _syncService = syncService,
        _supabase = supabase ?? Supabase.instance.client;

  // Constructor for testing
  QueueProvider.forTesting(
    SupabaseClient supabase, {
    QueueRepository? repository,
    GeolocationService? geolocationService,
    SyncService? syncService,
    LocalQueueStorage? localStorage,
  })  : _supabase = supabase,
        _repository = repository ??
            QueueRepository(supabase, localStorage: localStorage),
        _geolocationService = geolocationService ?? GeolocationService(),
        _syncService = syncService;

  Future<void> initialize() async {
    await fetchInitialQueue();
    _setupRealtimeSubscription();
    await _syncPendingLocally();
  }

  Future<void> fetchInitialQueue() async {
    _state = QueueState.loading;
    _page = 0;
    _hasMore = true;
    notifyListeners();
    try {
      final data = await _repository.fetchPage(offset: 0, limit: _pageSize);
      _clients.clear();
      _clients.addAll(data);
      _state = _clients.isEmpty ? QueueState.empty : QueueState.loaded;
      if (data.length < _pageSize) _hasMore = false;
    } catch (e) {
      _errorMessage = 'Failed to load queue';
      _state = QueueState.error;
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      _page++;
      final newClients = await _repository.fetchPage(
        offset: _page * _pageSize,
        limit: _pageSize,
      );
      final existingIds = _clients.map((c) => c.id).toSet();
      final uniqueNewClients = newClients.where((c) => !existingIds.contains(c.id));
      _clients.addAll(uniqueNewClients);
      if (newClients.length < _pageSize) _hasMore = false;
    } catch (_) {
      _page--;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> refreshQueue() async {
    _state = QueueState.refreshing;
    notifyListeners();
    await fetchInitialQueue();
  }

  void handleRealtimeInsert(Client client) {
    final exists = _clients.any((c) => c.id == client.id);
    if (!exists) {
      _clients.insert(0, client);
      if (_state == QueueState.empty) _state = QueueState.loaded;
      notifyListeners();
    }
  }

  void _setupRealtimeSubscription() {
    if (_supabase == null) return;
    _channel = _supabase!
        .channel('clients_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'clients',
          callback: (payload) {
            final newRecord = payload.newRecord;
            final client = Client.fromSupabaseMap(newRecord);
            handleRealtimeInsert(client);
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

  Future<void> _syncPendingLocally() async {
    if (_syncService != null) {
      await _syncService.synchronize();
    }
  }

  Future<void> addClient(String name) async {
    if (name.trim().isEmpty) return;

    final position = await _geolocationService.getCurrentPosition();

    final newClient = Client(
      id: const Uuid().v4(),
      name: name.trim(),
      lat: position?.latitude,
      lng: position?.longitude,
      locationAccuracy: position?.accuracy,
      createdAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );

    // Save locally immediately
    await _repository.saveClientLocally(newClient);

    // Update UI instantly
    _clients.insert(0, newClient);
    if (_state == QueueState.empty) _state = QueueState.loaded;
    notifyListeners();

    // Attempt sync (non-blocking for UX)
    if (_syncService != null) {
      unawaited(_syncService.synchronize());
    }
  }

  Future<void> removeClient(String id) async {
    await _repository.deleteClient(id);
    _clients.removeWhere((client) => client.id == id);
    if (_clients.isEmpty) _state = QueueState.empty;
    notifyListeners();
  }

  Future<void> nextClient() async {
    if (_clients.isEmpty) return;
    final firstClient = _clients.first;
    await removeClient(firstClient.id);
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _repository.dispose();
    super.dispose();
  }
}