import 'dart:async';
import 'package:bonsoir/bonsoir.dart';

class ServiceDiscovery {
  static const String serviceType = '_ofc._tcp';

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;

  final _servicesController =
      StreamController<List<BonsoirService>>.broadcast();
  Stream<List<BonsoirService>> get servicesStream =>
      _servicesController.stream;

  final List<BonsoirService> _foundServices = [];

  Future<void> advertise({
    required String name,
    required int port,
    int currentPlayers = 1,
    int maxPlayers = 3,
  }) async {
    final service = BonsoirService(
      name: name,
      type: serviceType,
      port: port,
      attributes: {'players': '$currentPlayers/$maxPlayers'},
    );
    _broadcast = BonsoirBroadcast(service: service);
    await _broadcast!.start();
  }

  Future<void> startDiscovery() async {
    _discovery = BonsoirDiscovery(type: serviceType);
    _discovery!.eventStream!.listen((event) {
      if (event is BonsoirDiscoveryServiceResolvedEvent) {
        _foundServices.add(event.service);
        _servicesController.add(List.from(_foundServices));
      } else if (event is BonsoirDiscoveryServiceLostEvent) {
        _foundServices.removeWhere((s) => s.name == event.service.name);
        _servicesController.add(List.from(_foundServices));
      }
    });
    await _discovery!.start();
  }

  Future<void> stop() async {
    await _broadcast?.stop();
    _broadcast = null;
    await _discovery?.stop();
    _discovery = null;
    _foundServices.clear();
    await _servicesController.close();
  }
}
