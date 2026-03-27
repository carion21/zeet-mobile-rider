/// Sous-objet representant le statut en ligne du rider.
/// Correspond au champ `rider_status` dans la reponse de `GET /v1/auth/me`.
class RiderStatus {
  final bool online;

  const RiderStatus({
    this.online = false,
  });

  factory RiderStatus.fromJson(Map<String, dynamic> json) {
    return RiderStatus(
      online: json['online'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'online': online,
    };
  }

  RiderStatus copyWith({
    bool? online,
  }) {
    return RiderStatus(
      online: online ?? this.online,
    );
  }
}

/// Modele representant un livreur (rider) connecte.
/// Correspond a la reponse de `GET /v1/auth/me` (surface "rider").
class RiderModel {
  final int id;
  final String? firstname;
  final String? lastname;
  final String phone;
  final String? email;
  final String? photo;
  final String? gender;
  final String profile;
  final String surface;
  final RiderStatus riderStatus;

  const RiderModel({
    required this.id,
    this.firstname,
    this.lastname,
    required this.phone,
    this.email,
    this.photo,
    this.gender,
    required this.profile,
    required this.surface,
    this.riderStatus = const RiderStatus(),
  });

  /// Nom complet (combine firstname + lastname).
  String get fullName {
    final parts = <String>[
      if (firstname != null && firstname!.isNotEmpty) firstname!,
      if (lastname != null && lastname!.isNotEmpty) lastname!,
    ];
    return parts.join(' ');
  }

  /// Initiales pour l'avatar (premiere lettre du prenom + premiere lettre du nom).
  String get initials {
    final parts = <String>[
      if (firstname != null && firstname!.isNotEmpty) firstname![0],
      if (lastname != null && lastname!.isNotEmpty) lastname![0],
    ];
    return parts.join().toUpperCase();
  }

  /// Indique si le rider est actuellement en ligne.
  bool get isOnline => riderStatus.online;

  factory RiderModel.fromJson(Map<String, dynamic> json) {
    return RiderModel(
      id: json['id'] as int,
      firstname: json['firstname'] as String?,
      lastname: json['lastname'] as String?,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      photo: json['photo'] as String?,
      gender: json['gender'] as String?,
      profile: json['profile'] as String? ?? 'rider',
      surface: json['surface'] as String? ?? 'rider',
      riderStatus: json['rider_status'] != null
          ? RiderStatus.fromJson(json['rider_status'] as Map<String, dynamic>)
          : const RiderStatus(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstname': firstname,
      'lastname': lastname,
      'phone': phone,
      'email': email,
      'photo': photo,
      'gender': gender,
      'profile': profile,
      'surface': surface,
      'rider_status': riderStatus.toJson(),
    };
  }

  RiderModel copyWith({
    int? id,
    String? firstname,
    String? lastname,
    String? phone,
    String? email,
    String? photo,
    String? gender,
    String? profile,
    String? surface,
    RiderStatus? riderStatus,
  }) {
    return RiderModel(
      id: id ?? this.id,
      firstname: firstname ?? this.firstname,
      lastname: lastname ?? this.lastname,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      photo: photo ?? this.photo,
      gender: gender ?? this.gender,
      profile: profile ?? this.profile,
      surface: surface ?? this.surface,
      riderStatus: riderStatus ?? this.riderStatus,
    );
  }
}
