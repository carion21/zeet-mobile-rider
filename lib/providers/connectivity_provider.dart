// lib/providers/connectivity_provider.dart
//
// Provider Riverpod de connectivité — wrap le service mutualisé
// `ZeetConnectivity` exposé par le package `zeet_ui`. Alimente le
// `ConnectivityBanner` depuis `home/index.dart` (quickwin QW2 vague 3).
//
// Usage :
// ```dart
// final status = ref.watch(connectivityStatusProvider);
// final online = status.maybeWhen(data: (v) => v, orElse: () => true);
// ConnectivityBanner(isOnline: online);
// ```

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zeet_ui/zeet_ui.dart';

/// `Stream<bool>` — `true` si au moins une interface réseau est active.
///
/// Émet l'état initial dès l'abonnement, puis un nouvel event à chaque
/// changement détecté par `connectivity_plus` (wifi, mobile, ethernet,
/// vpn, none).
final connectivityStatusProvider = StreamProvider<bool>((ref) {
  final zc = ZeetConnectivity();
  ref.onDispose(zc.dispose);
  return zc.stream;
});
