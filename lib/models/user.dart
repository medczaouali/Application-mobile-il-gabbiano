
class User {
  int? id;
  String name;
  String email;
  String password;
  String phone;
  String address;
  double? latitude;
  double? longitude;
  String role;
  String? profileImage;
  int isBanned; // 0 = not banned, 1 = banned

  User({
    this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.phone,
    this.address = '',
  this.latitude,
  this.longitude,
    this.role = 'client',
    this.profileImage,
    this.isBanned = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'phone': phone,
  'address': address,
  'address_lat': latitude,
  'address_lng': longitude,
      'role': role,
      'profile_image': profileImage,
      'isBanned': isBanned,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      password: map['password'],
      phone: map['phone'],
  address: map['address'] ?? '',
  latitude: map['address_lat'] != null ? (map['address_lat'] as num).toDouble() : null,
  longitude: map['address_lng'] != null ? (map['address_lng'] as num).toDouble() : null,
      role: map['role'],
      profileImage: map['profile_image'],
      isBanned: map['isBanned'] ?? 0,
    );
  }
}
