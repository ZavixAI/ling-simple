import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ling/src/app/feature_providers.dart';
import 'package:ling/src/core/network/api_exception.dart';
import 'package:ling/src/core/platform/bridges/device_context_bridge.dart';
import 'package:ling/src/core/platform/models/notification_models.dart';
import 'package:ling/src/core/platform/push_transport.dart';
import 'package:ling/src/core/storage/push_device_id_store.dart';
import 'package:ling/src/features/auth/application/auth_session_coordinator.dart';
import 'package:ling/src/features/auth/application/auth_state.dart';
import 'package:ling/src/features/auth/data/repositories/auth_repository.dart';
import 'package:ling/src/features/auth/models/user_models.dart';
import 'package:ling/src/features/settings/data/bridges/calendar_notification_bridge.dart';
import 'package:ling/src/shared/i18n/ling_locale.dart';
import 'package:ling/src/shared/models/calendar_notification_models.dart';

class AuthController extends Notifier<AuthState> {
  AuthSessionCoordinator get _coordinator =>
      ref.read(authSessionCoordinatorProvider);
  AuthRepository get _authRepository => ref.read(authRepositoryProvider);
  PushDeviceIdStore get _pushDeviceIdStore =>
      ref.read(pushDeviceIdStoreProvider);
  CalendarNotificationBridge get _notificationBridge =>
      ref.read(calendarNotificationBridgeProvider);
  DeviceContextBridge get _deviceContextBridge =>
      ref.read(deviceContextBridgeProvider);

  @override
  AuthState build() {
    _coordinator.onAutoRefreshFailed = () {
      state = const AuthStateUnauthenticated();
    };
    return const AuthStateRestoring();
  }

  Future<void> restoreSession() async {
    state = const AuthStateRestoring();
    state = await _coordinator.restore();
  }

  Future<void> completeSignIn(AuthBundle bundle) async {
    state = await _coordinator.completeSignIn(bundle);
    ref.read(analyticsTrackerProvider).startNewClientSession();
    await ref.read(analyticsTrackerProvider).flush();
  }

  Future<ChallengeResult> requestEmailChallenge(
    String email, {
    String purpose = 'login',
  }) async {
    return _authRepository.requestEmailChallenge(email, purpose: purpose);
  }

  Future<ChallengeResult> requestSmsChallenge(
    String phone, {
    String? phoneAreaCode,
    String purpose = 'login',
  }) async {
    return _authRepository.requestSmsChallenge(
      phone,
      phoneAreaCode: phoneAreaCode,
      purpose: purpose,
    );
  }

  Future<void> signInWithEmailCode({
    required String email,
    required String code,
  }) async {
    final pushDevice = await _buildRequiredLoginPushDevice();
    final bundle = await _authRepository.exchangeEmailCode(
      email: email,
      code: code,
      pushDevice: pushDevice,
    );
    await completeSignIn(bundle);
  }

  Future<void> signInWithSmsCode({
    required String phone,
    String? phoneAreaCode,
    String? challengeId,
    required String code,
  }) async {
    final pushDevice = await _buildRequiredLoginPushDevice();
    final bundle = await _authRepository.exchangeSmsCode(
      phone: phone,
      phoneAreaCode: phoneAreaCode,
      challengeId: challengeId,
      code: code,
      pushDevice: pushDevice,
    );
    await completeSignIn(bundle);
  }

  Future<void> signInWithAliyunOneClickToken(String token) async {
    final pushDevice = await _buildRequiredLoginPushDevice();
    final bundle = await _authRepository.exchangeAliyunOneClickToken(
      token,
      pushDevice: pushDevice,
    );
    await completeSignIn(bundle);
  }

  Future<void> signInWithAppleIdentityToken({
    required String identityToken,
    String? authorizationCode,
    Map<String, dynamic>? fullName,
  }) async {
    final pushDevice = await _buildRequiredLoginPushDevice();
    final bundle = await _authRepository.exchangeAppleIdentityToken(
      identityToken: identityToken,
      pushDevice: pushDevice,
      authorizationCode: authorizationCode,
      fullName: fullName,
    );
    await completeSignIn(bundle);
  }

  Future<void> signInWithWeChatAuthCode(String authCode) async {
    final pushDevice = await _buildRequiredLoginPushDevice();
    final bundle = await _authRepository.exchangeWeChatAuthCode(
      authCode,
      pushDevice: pushDevice,
    );
    await completeSignIn(bundle);
  }

  Future<void> refreshSession({String? refreshTokenOverride}) async {
    final currentState = state;
    if (currentState.session != null) {
      state = AuthStateRefreshing(currentState.session!);
    } else {
      state = const AuthStateRestoring();
    }
    state = await _coordinator.refresh(
      currentState: currentState,
      refreshTokenOverride: refreshTokenOverride,
    );
  }

  Future<void> updateProfile(UserProfile profile) async {
    final currentSession = state.session;
    if (currentSession == null) {
      return;
    }
    state = AuthStateAuthenticated(currentSession.copyWith(profile: profile));
  }

  Future<void> updateAccountBundle(AccountBundle bundle) async {
    final currentSession = state.session;
    if (currentSession == null) {
      return;
    }
    state = AuthStateAuthenticated(
      currentSession.copyWith(
        profile: bundle.profile,
        identities: bundle.identities,
      ),
    );
  }

  Future<void> signOut() async {
    await _coordinator.signOut();
    state = const AuthStateUnauthenticated();
  }

  Future<PushDeviceRegistrationRequest> _buildRequiredLoginPushDevice() async {
    final deviceId = (await _pushDeviceIdStore.getOrCreate()).trim();
    final registration = await _notificationBridge
        .registerRemoteNotifications();
    final pushToken = registration?.pushToken.trim() ?? '';
    if (deviceId.isEmpty || registration == null || pushToken.isEmpty) {
      throw ApiException(message: 'Push device registration is required');
    }

    DeviceContextSnapshot? deviceContext;
    try {
      deviceContext = await _deviceContextBridge.getLatestContext(
        startTracking: false,
      );
    } catch (_) {
      deviceContext = null;
    }
    final timezone = (deviceContext?.timezone ?? '').trim();
    final notificationPermission = await _notificationBridge
        .getPermissionState();
    final pushTransport = resolvePushTransportInfo(
      registrationTransport: registration.transport,
    );
    return PushDeviceRegistrationRequest(
      deviceId: deviceId,
      platform: pushTransport.platform,
      transport: pushTransport.transport,
      pushToken: pushToken,
      appBundleId: registration.appBundleId?.trim(),
      apnsEnvironment: registration.apnsEnvironment?.trim(),
      locale: resolveSystemLingLocaleCode(),
      timezone: timezone.isEmpty ? null : timezone,
      formattedAddress: deviceContext?.formattedAddress,
      name: deviceContext?.name,
      thoroughfare: deviceContext?.thoroughfare,
      subThoroughfare: deviceContext?.subThoroughfare,
      subLocality: deviceContext?.subLocality,
      locality: deviceContext?.locality,
      subAdministrativeArea: deviceContext?.subAdministrativeArea,
      city: deviceContext?.city,
      administrativeArea: deviceContext?.administrativeArea,
      postalCode: deviceContext?.postalCode,
      country: deviceContext?.country,
      isoCountryCode: deviceContext?.isoCountryCode,
      areasOfInterest: deviceContext?.areasOfInterest,
      latitude: deviceContext?.latitude,
      longitude: deviceContext?.longitude,
      accuracyMeters: deviceContext?.accuracyMeters,
      capturedAt: deviceContext?.capturedAt,
      notificationsEnabled:
          notificationPermission == CalendarNotificationPermissionState.granted,
    );
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
