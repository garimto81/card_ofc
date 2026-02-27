import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bonsoir/bonsoir.dart' show BonsoirService;
import '../../network/discovery.dart';
import '../../providers/network_game_provider.dart'
    show NetworkConnectionState, NetworkGameNotifier, networkGameNotifierProvider;
import 'game_screen.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  final _discovery = ServiceDiscovery();
  List<BonsoirService> _services = [];
  final _ipController = TextEditingController();
  final _nameController = TextEditingController(text: 'Player');
  bool _discoveryStarted = false;

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  void _startDiscovery() {
    if (_discoveryStarted) return;
    _discoveryStarted = true;
    _discovery.servicesStream.listen((services) {
      if (mounted) setState(() => _services = services);
    });
    _discovery.startDiscovery();
  }

  @override
  void dispose() {
    _discovery.stop();
    _ipController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _hostGame() async {
    final name = _nameController.text.trim().isEmpty
        ? 'Host'
        : _nameController.text.trim();
    final notifier = ref.read(networkGameNotifierProvider.notifier);
    await notifier.hostGame(name);
  }

  Future<void> _joinGame(String host, int port) async {
    final name = _nameController.text.trim().isEmpty
        ? 'Player'
        : _nameController.text.trim();
    final notifier = ref.read(networkGameNotifierProvider.notifier);
    await notifier.joinGame(host, port, name);
  }

  void _startGame() {
    ref.read(networkGameNotifierProvider.notifier).startNetworkGame();
  }

  @override
  Widget build(BuildContext context) {
    final networkState = ref.watch(networkGameNotifierProvider);

    // Auto-navigate to GameScreen when gameState arrives
    ref.listen(networkGameNotifierProvider, (prev, next) {
      if (next.gameState != null && prev?.gameState == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const GameScreen()),
        );
      }
    });

    final isHosting = networkState.connectionState == NetworkConnectionState.hosting;
    final isConnected =
        networkState.connectionState == NetworkConnectionState.connected;
    final isConnecting =
        networkState.connectionState == NetworkConnectionState.connecting;
    final hasError = networkState.connectionState == NetworkConnectionState.error;
    final isInLobby = !isHosting && !isConnected;

    return Scaffold(
      backgroundColor: Colors.teal[900],
      appBar: AppBar(
        title: const Text('LAN Lobby'),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(networkGameNotifierProvider.notifier).disconnect();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Player name input
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Your Name',
                labelStyle: TextStyle(color: Colors.teal[300]),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.teal[400]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.teal[200]!),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Error message
            if (hasError && networkState.errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        networkState.errorMessage!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

            // Hosting state
            if (isHosting) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal[700],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.wifi_tethering,
                        color: Colors.white, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Hosting Game',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Waiting for players...',
                      style: TextStyle(color: Colors.teal[200]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Players: ${ref.read(networkGameNotifierProvider.notifier).serverPlayerCount}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed:
                          ref.read(networkGameNotifierProvider.notifier)
                                      .serverPlayerCount >=
                                  2
                              ? _startGame
                              : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Game'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Connected (client) state
            if (isConnected) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal[700],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Connected',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Waiting for host to start the game...',
                      style: TextStyle(color: Colors.teal[200]),
                    ),
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(color: Colors.white),
                  ],
                ),
              ),
            ],

            // Connecting state
            if (isConnecting) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal[700],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'Connecting...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],

            // Host/Join buttons (only when disconnected)
            if (isInLobby && !isConnecting && !hasError) ...[
              ElevatedButton.icon(
                onPressed: _hostGame,
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('Host Game'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 24),
              // Manual IP input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ipController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'IP:Port (e.g. 192.168.1.5:8080)',
                        hintStyle: TextStyle(color: Colors.teal[300]),
                        border: const OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.teal[400]!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final parts = _ipController.text.split(':');
                      if (parts.length == 2) {
                        _joinGame(
                            parts[0], int.tryParse(parts[1]) ?? 8080);
                      }
                    },
                    child: const Text('Join'),
                  ),
                ],
              ),
            ],

            // Re-try button when error
            if (hasError) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ref
                      .read(networkGameNotifierProvider.notifier)
                      .disconnect();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Back to Lobby'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Discovered games list (only when not hosting/connected)
            if (isInLobby && !isConnecting && !hasError) ...[
              Text(
                'Discovered Games',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[200],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _services.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                                color: Colors.teal),
                            const SizedBox(height: 12),
                            Text(
                              'Searching for games...',
                              style: TextStyle(color: Colors.teal[300]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _services.length,
                        itemBuilder: (context, index) {
                          final service = _services[index];
                          final players =
                              service.attributes['players'] ?? '?';
                          return Card(
                            color: Colors.teal[700],
                            child: ListTile(
                              leading: const Icon(Icons.wifi,
                                  color: Colors.white),
                              title: Text(
                                service.name,
                                style:
                                    const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                '${service.host}:${service.port} ($players players)',
                                style:
                                    TextStyle(color: Colors.teal[200]),
                              ),
                              trailing: ElevatedButton(
                                onPressed: () => _joinGame(
                                  service.host ?? '',
                                  service.port,
                                ),
                                child: const Text('Join'),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ] else
              const Spacer(),
          ],
        ),
      ),
    );
  }
}
