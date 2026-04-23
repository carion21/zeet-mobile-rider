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

/// Raccourci synchrone : retourne `true` si le réseau est online, ou `true`
/// par défaut tant que le stream n'a pas encore émis (fail-open — on ne
/// bloque jamais l'utilisateur sur un faux positif au boot).
///
/// Nommé `isNetworkOnlineProvider` pour ne pas entrer en collision avec
/// `isOnlineProvider` du `status_provider.dart` qui, lui, représente le
/// statut métier du rider (toggle online/offline pour recevoir des
/// missions). Les deux sont orthogonaux : un rider peut être offline
/// "métier" tout en ayant le réseau, et inversement.
final isNetworkOnlineProvider = Provider<bool>((ref) {
  final async = ref.watch(connectivityStatusProvider);
  return async.valueOrNull ?? true;
});
