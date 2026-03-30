class AuthUserEntity {
  final String id;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool emailVerified;
  final List<String> providerIds;

  const AuthUserEntity({
    required this.id,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.emailVerified,
    required this.providerIds,
  });

  AuthUserEntity copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    bool? emailVerified,
    List<String>? providerIds,
  }) {
    return AuthUserEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      emailVerified: emailVerified ?? this.emailVerified,
      providerIds: providerIds ?? this.providerIds,
    );
  }
}
