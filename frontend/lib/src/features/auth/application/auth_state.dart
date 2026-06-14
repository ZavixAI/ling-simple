import 'package:ling/src/features/auth/models/user_models.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.profile,
    required this.identities,
    this.deviceId,
    this.isNewUser = false,
  });

  final String accessToken;
  final String refreshToken;
  final UserProfile profile;
  final List<UserIdentity> identities;
  final String? deviceId;
  final bool isNewUser;

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    UserProfile? profile,
    List<UserIdentity>? identities,
    String? deviceId,
    bool? isNewUser,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      profile: profile ?? this.profile,
      identities: identities ?? this.identities,
      deviceId: deviceId ?? this.deviceId,
      isNewUser: isNewUser ?? this.isNewUser,
    );
  }
}

sealed class AuthState {
  const AuthState();

  AuthSession? get session => null;
}

class AuthStateRestoring extends AuthState {
  const AuthStateRestoring();
}

class AuthStateUnauthenticated extends AuthState {
  const AuthStateUnauthenticated();
}

class AuthStateAuthenticated extends AuthState {
  const AuthStateAuthenticated(this.currentSession);

  final AuthSession currentSession;

  @override
  AuthSession get session => currentSession;
}

class AuthStateRefreshing extends AuthState {
  const AuthStateRefreshing(this.currentSession);

  final AuthSession currentSession;

  @override
  AuthSession get session => currentSession;
}

class AuthStateFailure extends AuthState {
  const AuthStateFailure({required this.message, this.previousSession});

  final String message;
  final AuthSession? previousSession;

  @override
  AuthSession? get session => previousSession;
}
