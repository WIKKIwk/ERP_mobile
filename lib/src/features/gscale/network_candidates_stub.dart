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

Future<List<String>> collectCandidateHosts() async {
  return const ['gscale.local'];
}

Future<List<String>> collectSubnetCandidateHosts() async {
  return const [];
}

Future<List<DiscoveryAnnouncement>> discoverAnnouncements({
  required int port,
  required Duration timeout,
}) async {
  return const [];
}
