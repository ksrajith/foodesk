/// Domain model for Firestore `users` collection (optional; login still uses maps).
/// Use [UserProfile.fromMap] when you want typed fields instead of `Map<String, dynamic>`.
class UserProfile {
  const UserProfile({
    required this.id,
    this.email,
    this.name,
    this.role,
    this.accountStatus,
  });

  final String id;
  final String? email;
  final String? name;
  final String? role;
  final String? accountStatus;

  factory UserProfile.fromMap(String id, Map<String, dynamic> map) {
    return UserProfile(
      id: id,
      email: map['email'] as String?,
      name: map['name'] as String?,
      role: map['role'] as String?,
      accountStatus: map['accountStatus'] as String?,
    );
  }
}
