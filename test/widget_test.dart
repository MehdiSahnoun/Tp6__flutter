import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:waiting_room_app/main.dart';
import 'package:waiting_room_app/queue_provider.dart';
import 'package:waiting_room_app/models/client.dart';

class FakeQueueProvider extends QueueProvider {
  FakeQueueProvider() : super.forTesting(_MockSupabaseClient());
  
  @override
  List<Client> get clients => _fakeClients;
  final List<Client> _fakeClients = [];

  @override
  Future<void> addClient(String name) async {
    if (name.trim().isNotEmpty) {
      _fakeClients.add(Client(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name.trim(),
        createdAt: DateTime.now(),
      ));
      notifyListeners();
    }
  }

  @override
  Future<void> removeClient(String id) async {
    _fakeClients.removeWhere((c) => c.id == id);
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
      fakeProvider._fakeClients.add(Client(
        id: '1',
        name: 'Alice',
        createdAt: DateTime.now(),
      ));

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
      fakeProvider._fakeClients.add(Client(
        id: '1',
        name: 'Bob',
        createdAt: DateTime.now(),
      ));

      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.byIcon(Icons.delete));
      await tester.pump();

      expect(find.text('Bob'), findsNothing);
    });

    testWidgets('next client button removes first client', (WidgetTester tester) async {
      fakeProvider._fakeClients.addAll([
        Client(id: '1', name: 'Client A', createdAt: DateTime.now()),
        Client(id: '2', name: 'Client B', createdAt: DateTime.now().add(const Duration(seconds: 1))),
      ]);

      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.byKey(const Key('nextClientButton')));
      await tester.pump();

      expect(find.text('Client A'), findsNothing);
      expect(find.text('Client B'), findsOneWidget);
    });
  });
}