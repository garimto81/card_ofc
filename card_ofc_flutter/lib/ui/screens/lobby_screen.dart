import 'package:flutter/material.dart';
import 'package:bonsoir/bonsoir.dart' show BonsoirService;
import '../../network/discovery.dart';
import '../../network/game_client.dart';
import '../../network/game_server.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _discovery = ServiceDiscovery();
  List<BonsoirService> _services = [];
  bool _isHost = false;
  GameServer? _server;
  final _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _discovery.servicesStream.listen((services) {
      if (mounted) setState(() => _services = services);
    });
    _discovery.startDiscovery();
  }

  @override
  void dispose() {
    _discovery.stop();
    _server?.stop();
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _hostGame() async {
    final server = GameServer();
    final port = await server.start();
    _server = server;
    setState(() => _isHost = true);
    await _discovery.advertise(name: 'OFC Game', port: port);
  }

  void _joinGame(String host, int port) {
    final client = GameClient();
    client.connect(host, port);
    client.joinGame('Player');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal[900],
      appBar: AppBar(
        title: const Text('LAN Lobby'),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _isHost ? null : _hostGame,
              icon: const Icon(Icons.wifi_tethering),
              label: Text(_isHost ? 'Hosting...' : 'Host Game'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 24),
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
                      _joinGame(parts[0], int.tryParse(parts[1]) ?? 8080);
                    }
                  },
                  child: const Text('Join'),
                ),
              ],
            ),
            const SizedBox(height: 24),
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
                      child: Text(
                        'Searching...',
                        style: TextStyle(color: Colors.teal[300]),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _services.length,
                      itemBuilder: (context, index) {
                        final service = _services[index];
                        return Card(
                          color: Colors.teal[700],
                          child: ListTile(
                            title: Text(
                              service.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              '${service.host}:${service.port}',
                              style: TextStyle(color: Colors.teal[200]),
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
          ],
        ),
      ),
    );
  }
}
