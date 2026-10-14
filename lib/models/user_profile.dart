/// Felhasználói profil modell a Rescue Platformhoz.

class User {
  final String id;
  final String email;
  final String displayName;

  const User({
    required this.id,
    required this.email,
    required this.displayName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'display_name': displayName,
  };
}

class UserProfile {
  final User user;
  final String? contactPhone;
  final int version;

  const UserProfile({
    required this.user,
    this.contactPhone,
    this.version = 1,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>? ?? {};
    return UserProfile(
      user: User.fromJson(userJson),
      contactPhone: json['contact_phone']?.toString(),
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'user': user.toJson(),
    'contact_phone': contactPhone,
    'version': version,
  };
}
