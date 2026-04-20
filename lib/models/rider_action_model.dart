// lib/models/rider_action_model.dart
//
// Modele canonique d'action rider expose par les endpoints :
//   - GET /v1/rider/orders/actions?status=...
//   - GET /v1/rider/deliveries/actions?status=...
//
// Source : ORDERS_RIDER_FLOW.md §3.7 / §3.8.
//
// Une action porte un `key` stable utilise pour le mapping UI -> handler.
// Le `type = 'transition' | 'info' | ...` permet de distinguer les boutons
// d'action de simples affichages.

class RiderAction {
  final String key;            // ex: 'accept-mission', 'collect', 'deliver'
  final String label;          // libelle humain pour afficher (fallback)
  final String type;           // 'transition' | 'info' | ...
  final String? method;        // 'POST', 'PATCH', 'GET' (info)
  final String? endpoint;      // chemin canonique (debug uniquement)
  final List<String> requiredFields; // ex: ['otp_code'], ['reason']

  const RiderAction({
    required this.key,
    required this.label,
    required this.type,
    this.method,
    this.endpoint,
    this.requiredFields = const <String>[],
  });

  factory RiderAction.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw =
        (json['required_fields'] as List<dynamic>? ?? const <dynamic>[]);
    return RiderAction(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      type: json['type']?.toString() ?? 'transition',
      method: json['method']?.toString(),
      endpoint: json['endpoint']?.toString(),
      requiredFields:
          raw.map((e) => e.toString()).toList(growable: false),
    );
  }

  /// Indique si l'action requiert un OTP.
  bool get requiresOtp => requiredFields.contains('otp_code');

  /// Indique si l'action requiert un motif.
  bool get requiresReason => requiredFields.contains('reason');

  @override
  String toString() => 'RiderAction(key=$key, type=$type)';
}
