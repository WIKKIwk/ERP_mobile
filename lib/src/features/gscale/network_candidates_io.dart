import 'dart:async';
import 'dart:convert';
import 'dart:io';

class DiscoveryAnnouncement {
  const DiscoveryAnnouncement({
    required this.host,
    required this.httpPort,
    required this.serverName,
    required this.serverRef,
    required this.displayName,
    required this.role,
    required this.latencyMs,
  });

  final String host;
  final int httpPort;
  final String serverName;
  final String serverRef;
  final String displayName;
  final String role;
  final int latencyMs;
}

const _discoveryProbeV1 = 'GSCALE_DISCOVER_V1';
const _discoveryProbeAttempts = 3;
const _discoveryProbeRetryDelay = Duration(milliseconds: 120);
const _discoverySettleDelay = Duration(milliseconds: 45);
const _fallbackMobileApiPort = 39117;

Future<List<String>> collectCandidateHosts() async {
  return const ['gscale.local'];
}

Future<List<String>> collectSubnetCandidateHosts() async {
  final hosts = <String>{};

  final interfaces = await NetworkInterface.list(
    includeLoopback: false,
    includeLinkLocal: false,
    type: InternetAddressType.IPv4,
  );

  for (final iface in interfaces) {
    for (final address in iface.addresses) {
      final host = address.address.trim();
      if (!_isPrivateIPv4(host)) {
        continue;
      }

      final parts = host.split('.');
      if (parts.length != 4) {
        continue;
      }

      final selfOctet = int.tryParse(parts[3]);
      if (selfOctet == null || selfOctet < 1 || selfOctet > 254) {
        continue;
      }

      final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
      for (var octet = 1; octet < 255; octet++) {
        if (octet == selfOctet) {
          continue;
        }
        hosts.add('$prefix.$octet');
      }
    }
  }

  final out = hosts.toList()..sort(_compareIPv4);
  return out;
}

Future<List<DiscoveryAnnouncement>> discoverAnnouncements({
  required int port,
  required Duration timeout,
}) async {
  RawDatagramSocket socket;
  try {
    socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      port,
      reuseAddress: true,
    );
  } catch (_) {
    socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
      reuseAddress: true,
    );
  }
  socket.broadcastEnabled = true;

  final stopwatch = Stopwatch()..start();
  final results = <String, DiscoveryAnnouncement>{};
  final done = Completer<void>();
  Timer? settleTimer;
  late final StreamSubscription<RawSocketEvent> sub;

  sub = socket.listen((event) {
    if (event != RawSocketEvent.read) {
      return;
    }
    final datagram = socket.receive();
    if (datagram == null) {
      return;
    }
    final payloadText = utf8.decode(datagram.data);
    dynamic payload;
    try {
      payload = jsonDecode(payloadText);
    } catch (_) {
      return;
    }
    if (payload is! Map<String, dynamic>) {
      return;
    }
    if ((payload['service']?.toString().trim() ?? '') != 'mobileapi') {
      return;
    }

    final host = datagram.address.address.trim();
    final announcement = DiscoveryAnnouncement(
      host: host,
      httpPort: _asInt(payload['http_port']) ?? _fallbackMobileApiPort,
      serverName: payload['server_name']?.toString().trim() ?? host,
      serverRef: payload['server_ref']?.toString().trim() ?? '',
      displayName: payload['display_name']?.toString().trim() ?? 'Operator',
      role: payload['role']?.toString().trim() ?? 'operator',
      latencyMs: stopwatch.elapsedMilliseconds,
    );
    final key = '${announcement.serverRef}|${announcement.serverName}|$host';
    results[key] = announcement;
    settleTimer?.cancel();
    settleTimer = Timer(_discoverySettleDelay, () {
      if (!done.isCompleted) {
        done.complete();
      }
    });
  });

  final targets = await _collectBroadcastTargets();
  final packet = utf8.encode(_discoveryProbeV1);
  Timer(timeout, () {
    if (!done.isCompleted) {
      done.complete();
    }
  });
  unawaited(_sendDiscoveryProbes(socket, targets, packet, port));

  await done.future;
  settleTimer?.cancel();
  await sub.cancel();
  socket.close();
  return results.values.toList();
}

Future<void> _sendDiscoveryProbes(
  RawDatagramSocket socket,
  List<InternetAddress> targets,
  List<int> packet,
  int port,
) async {
  for (var attempt = 0; attempt < _discoveryProbeAttempts; attempt++) {
    for (final target in targets) {
      try {
        socket.send(packet, target, port);
      } catch (_) {
        // Keep retrying other interfaces even if one route is unavailable.
      }
    }
    if (attempt != _discoveryProbeAttempts - 1) {
      await Future<void>.delayed(_discoveryProbeRetryDelay);
    }
  }
}

Future<List<InternetAddress>> _collectBroadcastTargets() async {
  final out = <InternetAddress>{InternetAddress('255.255.255.255')};
  final interfaces = await NetworkInterface.list(
    includeLoopback: false,
    includeLinkLocal: false,
    type: InternetAddressType.IPv4,
  );

  for (final iface in interfaces) {
    for (final address in iface.addresses) {
      final host = address.address.trim();
      if (!_isPrivateIPv4(host)) {
        continue;
      }
      final parts = host.split('.');
      if (parts.length != 4) {
        continue;
      }
      out.add(InternetAddress('${parts[0]}.${parts[1]}.${parts[2]}.255'));
    }
  }

  return out.toList();
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '');
}

bool _isPrivateIPv4(String host) {
  final parts = host.split('.');
  if (parts.length != 4) {
    return false;
  }

  final values = parts.map(int.tryParse).toList();
  if (values.any((value) => value == null)) {
    return false;
  }

  final first = values[0]!;
  final second = values[1]!;
  if (first == 10) {
    return true;
  }
  if (first == 172 && second >= 16 && second <= 31) {
    return true;
  }
  if (first == 192 && second == 168) {
    return true;
  }
  return false;
}

int _compareIPv4(String left, String right) {
  final leftParts = left.split('.').map(int.parse).toList();
  final rightParts = right.split('.').map(int.parse).toList();
  for (var i = 0; i < 4; i++) {
    final cmp = leftParts[i].compareTo(rightParts[i]);
    if (cmp != 0) {
      return cmp;
    }
  }
  return 0;
}
