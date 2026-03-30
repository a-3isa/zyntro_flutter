import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../domain/entities/auth_user_entity.dart';

class AuthUserModel {
  final String id;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool emailVerified;
  final List<String> providerIds;

  const AuthUserModel({
    required this.id,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.emailVerified,
    required this.providerIds,
  });

  factory AuthUserModel.fromFirebaseUser(fb.User user) {
    return AuthUserModel(
      id: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      emailVerified: user.emailVerified,
      providerIds: user.providerData.map((info) => info.providerId).toList(),
    );
  }

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    return AuthUserModel(
      id: json['id'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      emailVerified: json['emailVerified'] as bool? ?? false,
      providerIds: (json['providerIds'] as List<dynamic>? ?? const <dynamic>[])
          .cast<String>(),
    );
  }

  factory AuthUserModel.fromEncodedJson(String source) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    return AuthUserModel.fromJson(data);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'emailVerified': emailVerified,
      'providerIds': providerIds,
    };
  }

  String toEncodedJson() {
    return jsonEncode(toJson());
  }

  AuthUserEntity toEntity() {
    return AuthUserEntity(
      id: id,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      emailVerified: emailVerified,
      providerIds: providerIds,
    );
  }
}
