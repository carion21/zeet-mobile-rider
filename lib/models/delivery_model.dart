// lib/models/delivery_model.dart

class Delivery {
  final String id;
  final String customerName;
  final String customerPhone;
  final String restaurantName;
  final String pickupAddress;
  final String deliveryAddress;
  final String status; // 'new', 'accepted', 'picked_up', 'delivered'
  final double distance; // en km
  final int estimatedTime; // en minutes
  final double deliveryFee; // Frais de livraison en FCFA
  final String orderDetails;
  final DateTime createdAt;

  const Delivery({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.restaurantName,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.status,
    required this.distance,
    required this.estimatedTime,
    required this.deliveryFee,
    required this.orderDetails,
    required this.createdAt,
  });

  Delivery copyWith({
    String? id,
    String? customerName,
    String? customerPhone,
    String? restaurantName,
    String? pickupAddress,
    String? deliveryAddress,
    String? status,
    double? distance,
    int? estimatedTime,
    double? deliveryFee,
    String? orderDetails,
    DateTime? createdAt,
  }) {
    return Delivery(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      restaurantName: restaurantName ?? this.restaurantName,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      status: status ?? this.status,
      distance: distance ?? this.distance,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      orderDetails: orderDetails ?? this.orderDetails,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
