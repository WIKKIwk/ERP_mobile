import 'package:erpnext_stock_mobile/src/features/gscale/gscale_mobile_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'mergeDiscoveryResults keeps current servers when fast scan is empty',
    () {
      final current = DiscoveryResult(
        servers: [_server('192.168.1.4', 'rp-scale')],
        candidateCount: 1,
      );

      final merged = mergeDiscoveryResults(
        current: current,
        next: const DiscoveryResult(
          servers: <DiscoveredServer>[],
          candidateCount: 5,
        ),
        keepCurrentWhenNextEmpty: true,
      );

      expect(merged.servers, hasLength(1));
      expect(merged.servers.single.endpoint.host, '192.168.1.4');
    },
  );

  test('mergeDiscoveryResults replaces duplicate server with fresh result', () {
    final current = DiscoveryResult(
      servers: [_server('192.168.1.4', 'rp-scale', latencyMs: 90)],
      candidateCount: 1,
    );
    final next = DiscoveryResult(
      servers: [_server('gscale.local', 'rp-scale', latencyMs: 12)],
      candidateCount: 5,
    );

    final merged = mergeDiscoveryResults(
      current: current,
      next: next,
      keepCurrentWhenNextEmpty: true,
    );

    expect(merged.servers, hasLength(1));
    expect(merged.servers.single.endpoint.host, 'gscale.local');
    expect(merged.servers.single.latencyMs, 12);
  });

  test('mergeDiscoveryResults shows verified scan before stale cached server',
      () {
    final current = DiscoveryResult(
      servers: [_server('192.168.1.4', 'cached-rps', latencyMs: 1)],
      candidateCount: 1,
    );
    final next = DiscoveryResult(
      servers: [_server('192.168.1.103', 'rp-scale', latencyMs: 12)],
      candidateCount: 5,
    );

    final merged = mergeDiscoveryResults(
      current: current,
      next: next,
      keepCurrentWhenNextEmpty: true,
    );

    expect(merged.servers, hasLength(2));
    expect(merged.servers.first.endpoint.host, '192.168.1.103');
    expect(merged.servers.last.endpoint.host, '192.168.1.4');
  });

  test(
    'mergeDiscoveryResults can clear servers after confirmed empty scans',
    () {
      final current = DiscoveryResult(
        servers: [_server('192.168.1.4', 'rp-scale')],
        candidateCount: 1,
      );

      final merged = mergeDiscoveryResults(
        current: current,
        next: const DiscoveryResult(
          servers: <DiscoveredServer>[],
          candidateCount: 5,
        ),
        keepCurrentWhenNextEmpty: false,
      );

      expect(merged.servers, isEmpty);
    },
  );

  test('driverUrlForRs uses 5070 Tailscale address for RS print requests', () {
    final server = _server('192.168.1.114', '5070');

    expect(driverUrlForRs(server), 'http://100.117.62.18:39117');
  });

  test('driverUrlForRs keeps non-5070 endpoint unchanged', () {
    final server = _server('192.168.1.114', 'lab-scale');

    expect(driverUrlForRs(server), 'http://192.168.1.114:39117');
  });
}

DiscoveredServer _server(String host, String serverRef, {int latencyMs = 1}) {
  return DiscoveredServer(
    endpoint: ServerEndpoint(
      host: host,
      port: 39117,
      baseUrl: 'http://$host:39117',
    ),
    handshake: ServerHandshake(
      serverName: 'gscale',
      displayName: 'RP Scale',
      role: 'operator',
      serverRef: serverRef,
    ),
    latencyMs: latencyMs,
  );
}
