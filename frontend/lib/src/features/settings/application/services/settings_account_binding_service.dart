import 'package:ling/src/features/auth/data/repositories/profile_repository.dart';
import 'package:ling/src/features/auth/models/user_models.dart';

class SettingsAccountBindingService {
  const SettingsAccountBindingService({required ProfileRepository repository})
    : _repository = repository;

  final ProfileRepository _repository;

  Future<ChallengeResult> requestPhoneChallenge(String phone) {
    return _repository.requestPhoneBindingChallenge(phone);
  }

  Future<ChallengeResult> requestEmailChallenge(String email) {
    return _repository.requestEmailBindingChallenge(email);
  }

  Future<AccountBundle> bindPhone({
    required String phone,
    required String challengeId,
    required String code,
  }) {
    return _repository.bindPhone(
      phone: phone,
      challengeId: challengeId,
      code: code,
    );
  }

  Future<AccountBundle> bindEmail({
    required String email,
    required String code,
  }) {
    return _repository.bindEmail(email: email, code: code);
  }

  Future<AccountBundle> bindAppleIdentity({
    required String identityToken,
    String? authorizationCode,
    Map<String, dynamic>? fullName,
  }) {
    return _repository.bindAppleIdentity(
      identityToken: identityToken,
      authorizationCode: authorizationCode,
      fullName: fullName,
    );
  }

  Future<AccountBundle> bindWeChatIdentity({required String authCode}) {
    return _repository.bindWeChatIdentity(authCode: authCode);
  }
}
