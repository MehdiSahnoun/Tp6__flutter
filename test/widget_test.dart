import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:waiting_room_app/main.dart';
import 'package:waiting_room_app/queue_provider.dart';
import 'package:waiting_room_app/local_queue_service.dart';
import 'package:waiting_room_app/geolocation_service.dart';

class FakeQueueProvider extends QueueProvider {
  FakeQueueProvider() : super.forTesting(
    _MockSupabaseClient(),
    localDb: LocalQueueService(inMemory: true),
    geoService: _MockGeolocationService(),
  );

  @override
  List<Map<String, dynamic>> get clients => _fakeClients;
  final List<Map<String, dynamic>> _fakeClients = [];

  @override
  Future<void> addClient(String name) async {
    if (name.trim().isNotEmpty) {
      _fakeClients.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': name.trim(),
        'lat': 37.7749,
        'lng': -122.4194,
        'created_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      });
      notifyListeners();
    }
  }

  @override
  Future<void> removeClient(String id) async {
    _fakeClients.removeWhere((c) => c['id'] == id);
    notifyListeners();
  }

  @override
  Future<void> nextClient() async {
    if (_fakeClients.isNotEmpty) {
      _fakeClients.removeAt(0);
      notifyListeners();
    }
  }
}

class _MockSupabaseClient extends SupabaseClient {
  _MockSupabaseClient() : super('https://mock.supabase.co', 'mock-key');
}

class _MockGeolocationService extends GeolocationService {
  @override
  Future<Position?> getCurrentPosition() async {
    return Position(
      latitude: 37.7749,
      longitude: -122.4194,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      headingAccuracy: 0.0,
      altitudeAccuracy: 0.0,
    );
  }
}

void main() {
  group('WaitingRoomScreen Widget Tests', () {
    late FakeQueueProvider fakeProvider;

    setUp(() {
      fakeProvider = FakeQueueProvider();
    });

    Widget createTestWidget() {
      return ChangeNotifierProvider<QueueProvider>.value(
        value: fakeProvider,
        child: const MaterialApp(home: WaitingRoomScreen()),
      );
    }

    testWidgets('shows empty queue message when no clients', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('No one in queue yet...'), findsOneWidget);
    });

    testWidgets('shows client name in list', (WidgetTester tester) async {
      fakeProvider._fakeClients.add({
        'id': '1',
        'name': 'Alice',
        'lat': 37.7749,
        'lng': -122.4194,
        'created_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      });

      await tester.pumpWidget(createTestWidget());

      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('add client calls provider', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.byType(TextField), 'Bob');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pump();

      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('remove client removes from list', (WidgetTester tester) async {
      fakeProvider._fakeClients.add({
        'id': '1',
        'name': 'Bob',
        'lat': 37.7749,
        'lng': -122.4194,
        'created_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      });

      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.byIcon(Icons.delete));
      await tester.pump();

      expect(find.text('Bob'), findsNothing);
    });

    testWidgets('next client button removes first client', (WidgetTester tester) async {
      fakeProvider._fakeClients.addAll([
        {
          'id': '1',
          'name': 'Client A',
          'lat': 37.7749,
          'lng': -122.4194,
          'created_at': DateTime.now().toIso8601String(),
          'is_synced': 0,
        },
        {
          'id': '2',
          'name': 'Client B',
          'lat': 37.7749,
          'lng': -122.4194,
          'created_at': DateTime.now().add(const Duration(seconds: 1)).toIso8601String(),
          'is_synced': 0,
        },
      ]);

      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.byKey(const Key('nextClientButton')));
      await tester.pump();

      expect(find.text('Client A'), findsNothing);
      expect(find.text('Client B'), findsOneWidget);
    });
  });
}