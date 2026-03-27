/// Modeles representant les missions du rider cote API.
/// Correspond aux reponses de `GET /v1/rider/missions`, `GET /v1/rider/missions/:id`, etc.
///
/// IMPORTANT : Parsing tres defensif. Tous les champs sont nullable sauf `id`.
/// L'API peut renvoyer des structures variables (int ou objet pour les relations).

// ---------------------------------------------------------------------------
// Sous-objets
// ---------------------------------------------------------------------------

/// Adresse (pickup ou dropoff).
class MissionAddress {
  final String? label;
  final String? street;
  final String? city;
  final String? district;
  final double? lat;
  final double? lng;

  const MissionAddress({
    this.label,
    this.street,
    this.city,
    this.district,
    this.lat,
    this.lng,
  });

  factory MissionAddress.fromJson(Map<String, dynamic> json) {
    return MissionAddress(
      label: json['label'] as String? ?? json['address'] as String?,
      street: json['street'] as String?,
      city: json['city'] as String?,
      district: json['district'] as String?,
      lat: _parseDouble(json['lat'] ?? json['latitude']),
      lng: _parseDouble(json['lng'] ?? json['longitude']),
    );
  }

  /// Retourne l'adresse la plus lisible possible.
  String get displayAddress {
    if (label != null && label!.isNotEmpty) return label!;
    final parts = <String>[
      if (street != null && street!.isNotEmpty) street!,
      if (district != null && district!.isNotEmpty) district!,
      if (city != null && city!.isNotEmpty) city!,
    ];
    return parts.isNotEmpty ? parts.join(', ') : 'Adresse inconnue';
  }
}

/// Partenaire (restaurant) lie a une mission.
class MissionPartner {
  final int? id;
  final String? name;
  final String? phone;
  final String? logo;
  final MissionAddress? address;

  const MissionPartner({
    this.id,
    this.name,
    this.phone,
    this.logo,
    this.address,
  });

  factory MissionPartner.fromJson(Map<String, dynamic> json) {
    MissionAddress? address;
    if (json['address'] is Map<String, dynamic>) {
      address = MissionAddress.fromJson(json['address'] as Map<String, dynamic>);
    }

    return MissionPartner(
      id: json['id'] as int?,
      name: json['name'] as String? ?? json['business_name'] as String?,
      phone: json['phone'] as String?,
      logo: json['logo'] as String?,
      address: address,
    );
  }
}

/// Client lie a une mission.
class MissionCustomer {
  final int? id;
  final String? firstname;
  final String? lastname;
  final String? phone;
  final MissionAddress? address;

  const MissionCustomer({
    this.id,
    this.firstname,
    this.lastname,
    this.phone,
    this.address,
  });

  String get fullName {
    final parts = <String>[
      if (firstname != null && firstname!.isNotEmpty) firstname!,
      if (lastname != null && lastname!.isNotEmpty) lastname!,
    ];
    return parts.isNotEmpty ? parts.join(' ') : 'Client';
  }

  factory MissionCustomer.fromJson(Map<String, dynamic> json) {
    MissionAddress? address;
    if (json['address'] is Map<String, dynamic>) {
      address = MissionAddress.fromJson(json['address'] as Map<String, dynamic>);
    } else if (json['delivery_address'] is Map<String, dynamic>) {
      address = MissionAddress.fromJson(json['delivery_address'] as Map<String, dynamic>);
    }

    return MissionCustomer(
      id: json['id'] as int?,
      firstname: json['firstname'] as String?,
      lastname: json['lastname'] as String?,
      phone: json['phone'] as String?,
      address: address,
    );
  }
}

/// Item de commande dans une mission.
class MissionOrderItem {
  final int? id;
  final String? name;
  final int? quantity;
  final double? price;

  const MissionOrderItem({
    this.id,
    this.name,
    this.quantity,
    this.price,
  });

  factory MissionOrderItem.fromJson(Map<String, dynamic> json) {
    // Le nom peut venir de product.name ou de product_name_snapshot
    String? name;
    final product = json['product'];
    if (product is Map<String, dynamic>) {
      name = product['name'] as String?;
    }
    name ??= json['product_name_snapshot'] as String? ?? json['name'] as String?;

    return MissionOrderItem(
      id: json['id'] as int?,
      name: name,
      quantity: json['quantity'] as int?,
      price: _parseDouble(json['total_price'] ?? json['unit_price'] ?? json['price']),
    );
  }
}

/// Montants de la commande.
class MissionAmounts {
  final double? subtotal;
  final double? deliveryFee;
  final double? total;
  final double? riderEarning;

  const MissionAmounts({
    this.subtotal,
    this.deliveryFee,
    this.total,
    this.riderEarning,
  });

  factory MissionAmounts.fromJson(Map<String, dynamic> json) {
    return MissionAmounts(
      subtotal: _parseDouble(json['subtotal'] ?? json['sub_total']),
      deliveryFee: _parseDouble(json['delivery_fee'] ?? json['delivery_amount']),
      total: _parseDouble(json['total'] ?? json['total_amount']),
      riderEarning: _parseDouble(json['rider_earning'] ?? json['rider_fee']),
    );
  }
}

/// Commande liee a une mission.
class MissionOrder {
  final int? id;
  final String? reference;
  final String? status;
  final MissionPartner? partner;
  final MissionCustomer? customer;
  final List<MissionOrderItem> items;
  final MissionAmounts? amounts;
  final String? note;
  final int? itemCount;

  const MissionOrder({
    this.id,
    this.reference,
    this.status,
    this.partner,
    this.customer,
    this.items = const [],
    this.amounts,
    this.note,
    this.itemCount,
  });

  factory MissionOrder.fromJson(Map<String, dynamic> json) {
    // Partner
    MissionPartner? partner;
    final partnerRaw = json['partner'];
    if (partnerRaw is Map<String, dynamic>) {
      partner = MissionPartner.fromJson(partnerRaw);
    }

    // Customer
    MissionCustomer? customer;
    final customerRaw = json['customer'] ?? json['client'];
    if (customerRaw is Map<String, dynamic>) {
      customer = MissionCustomer.fromJson(customerRaw);
    }

    // Items
    List<MissionOrderItem> items = [];
    final itemsRaw = json['items'] ?? json['order_items'];
    if (itemsRaw is List) {
      items = itemsRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => MissionOrderItem.fromJson(e))
          .toList();
    }

    // Amounts
    MissionAmounts? amounts;
    final amountsRaw = json['amounts'];
    if (amountsRaw is Map<String, dynamic>) {
      amounts = MissionAmounts.fromJson(amountsRaw);
    } else {
      // Les montants peuvent etre au meme niveau que l'order
      amounts = MissionAmounts.fromJson(json);
    }

    return MissionOrder(
      id: json['id'] as int?,
      reference: json['reference'] as String? ?? json['order_number'] as String?,
      status: json['status'] as String?,
      partner: partner,
      customer: customer,
      items: items,
      amounts: amounts,
      note: json['note'] as String? ?? json['customer_note'] as String?,
      itemCount: json['item_count'] as int? ?? items.length,
    );
  }
}

// ---------------------------------------------------------------------------
// Mission (liste et detail)
// ---------------------------------------------------------------------------

/// Mission de livraison (vue liste).
class Mission {
  final int id;
  final String? status;
  final MissionOrder? order;
  final MissionAddress? pickupAddress;
  final MissionAddress? dropoffAddress;
  final double? distance;
  final int? estimatedTime;
  final double? riderFee;
  final String? createdAt;
  final String? updatedAt;
  final String? pickupOtp;
  final String? deliveryOtp;

  const Mission({
    required this.id,
    this.status,
    this.order,
    this.pickupAddress,
    this.dropoffAddress,
    this.distance,
    this.estimatedTime,
    this.riderFee,
    this.createdAt,
    this.updatedAt,
    this.pickupOtp,
    this.deliveryOtp,
  });

  /// Nom du restaurant (raccourci).
  String get partnerName => order?.partner?.name ?? 'Restaurant';

  /// Nom du client (raccourci).
  String get customerName => order?.customer?.fullName ?? 'Client';

  /// Telephone du client.
  String? get customerPhone => order?.customer?.phone;

  /// Telephone du restaurant.
  String? get partnerPhone => order?.partner?.phone;

  /// Adresse de retrait lisible.
  String get pickupAddressDisplay =>
      pickupAddress?.displayAddress ??
      order?.partner?.address?.displayAddress ??
      'Adresse de retrait';

  /// Adresse de livraison lisible.
  String get dropoffAddressDisplay =>
      dropoffAddress?.displayAddress ??
      order?.customer?.address?.displayAddress ??
      'Adresse de livraison';

  /// Frais de livraison pour le rider.
  double get fee => riderFee ?? order?.amounts?.riderEarning ?? order?.amounts?.deliveryFee ?? 0;

  /// Nombre d'articles.
  String get itemCountText {
    final count = order?.itemCount ?? order?.items.length ?? 0;
    return '$count article${count > 1 ? 's' : ''}';
  }

  /// Reference de la commande.
  String get orderReference => order?.reference ?? '#$id';

  factory Mission.fromJson(Map<String, dynamic> json) {
    // ID : peut etre int ou string
    final id = json['id'] is int
        ? json['id'] as int
        : int.tryParse(json['id'].toString()) ?? 0;

    // Order
    MissionOrder? order;
    final orderRaw = json['order'];
    if (orderRaw is Map<String, dynamic>) {
      order = MissionOrder.fromJson(orderRaw);
    }

    // Pickup address
    MissionAddress? pickupAddress;
    final pickupRaw = json['pickup_address'] ?? json['pickup'];
    if (pickupRaw is Map<String, dynamic>) {
      pickupAddress = MissionAddress.fromJson(pickupRaw);
    }

    // Dropoff address
    MissionAddress? dropoffAddress;
    final dropoffRaw = json['dropoff_address'] ?? json['dropoff'] ?? json['delivery_address'];
    if (dropoffRaw is Map<String, dynamic>) {
      dropoffAddress = MissionAddress.fromJson(dropoffRaw);
    }

    return Mission(
      id: id,
      status: json['status'] as String?,
      order: order,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      distance: _parseDouble(json['distance']),
      estimatedTime: json['estimated_time'] as int? ?? json['estimated_duration'] as int?,
      riderFee: _parseDouble(json['rider_fee'] ?? json['delivery_fee']),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      pickupOtp: json['pickup_otp'] as String?,
      deliveryOtp: json['delivery_otp'] as String?,
    );
  }

  Mission copyWith({
    int? id,
    String? status,
    MissionOrder? order,
    MissionAddress? pickupAddress,
    MissionAddress? dropoffAddress,
    double? distance,
    int? estimatedTime,
    double? riderFee,
    String? createdAt,
    String? updatedAt,
    String? pickupOtp,
    String? deliveryOtp,
  }) {
    return Mission(
      id: id ?? this.id,
      status: status ?? this.status,
      order: order ?? this.order,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      distance: distance ?? this.distance,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      riderFee: riderFee ?? this.riderFee,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pickupOtp: pickupOtp ?? this.pickupOtp,
      deliveryOtp: deliveryOtp ?? this.deliveryOtp,
    );
  }
}

// ---------------------------------------------------------------------------
// Transitions / Actions (reference)
// ---------------------------------------------------------------------------

/// Transition possible pour un statut de livraison.
class DeliveryTransition {
  final String? from;
  final String? to;
  final String? label;

  const DeliveryTransition({this.from, this.to, this.label});

  factory DeliveryTransition.fromJson(Map<String, dynamic> json) {
    return DeliveryTransition(
      from: json['from'] as String?,
      to: json['to'] as String?,
      label: json['label'] as String? ?? json['name'] as String?,
    );
  }
}

/// Action possible sur une commande.
class OrderAction {
  final String? action;
  final String? label;
  final String? status;

  const OrderAction({this.action, this.label, this.status});

  factory OrderAction.fromJson(Map<String, dynamic> json) {
    return OrderAction(
      action: json['action'] as String?,
      label: json['label'] as String? ?? json['name'] as String?,
      status: json['status'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

/// Parse un champ en double (gere int, double, et String).
double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
