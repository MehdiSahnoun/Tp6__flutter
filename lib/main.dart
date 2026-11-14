import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:waiting_room_app/queue_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file
  await dotenv.load(fileName: ".env");

  // Initialize Supabase with environment variables
  final supabaseUrl = dotenv.env['SUPABASE_URL']!;
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Sign in anonymously
  try {
    final authResponse = await Supabase.instance.client.auth.signInAnonymously();
    print('Signed in anonymously as user: ${authResponse.user?.id}');
  } catch (e) {
    print('Failed to sign in anonymously: $e');
  }

  final queueProvider = QueueProvider();
  runApp(
    ChangeNotifierProvider.value(
      value: queueProvider,
      child: const WaitingRoomApp(),
    ),
  );
}

class WaitingRoomApp extends StatelessWidget {
  const WaitingRoomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waiting Room',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const WaitingRoomScreen(),
    );
  }
}

class WaitingRoomScreen extends StatelessWidget {
  const WaitingRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final queueProvider = context.watch<QueueProvider>();
    final TextEditingController controller = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Waiting Room'),
        centerTitle: true,
        actions: [
          IconButton(
            key: const Key('nextClientButton'),
            icon: const Icon(Icons.skip_next),
            onPressed: () {
              context.read<QueueProvider>().nextClient();
            },
            tooltip: 'Next Client',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Input Field
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(hintText: 'Enter name'),
                    onSubmitted: (name) {
                      context.read<QueueProvider>().addClient(name);
                      controller.clear();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (controller.text.isNotEmpty) {
                      context.read<QueueProvider>().addClient(controller.text);
                      controller.clear();
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Queue List
            Expanded(
              child: Consumer<QueueProvider>(
                builder: (context, provider, _) {
                  if (provider.clients.isEmpty) {
                    return const Center(child: Text('No one in queue yet...'));
                  }

                  return ListView.builder(
                    itemCount: provider.clients.length,
                    itemBuilder: (context, index) {
                      final client = provider.clients[index];
                      final lat = client['lat'];
                      final lng = client['lng'];
                      final locationText = lat == null || lng == null
                          ? '📍 Location not captured'
                          : '📍 ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(client['name'] as String),
                          subtitle: Text(
                            locationText,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              context.read<QueueProvider>().removeClient(client['id'] as String);
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // Next Button
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                context.read<QueueProvider>().nextClient();
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next Client'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}