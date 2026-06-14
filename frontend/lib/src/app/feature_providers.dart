import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ling/src/core/analytics/analytics_repository.dart';
import 'package:ling/src/core/analytics/analytics_tracker.dart';
import 'package:ling/src/core/platform/bridges/device_context_bridge.dart';
import 'package:ling/src/core/providers.dart';
import 'package:ling/src/core/storage/push_device_id_store.dart';
import 'package:ling/src/features/auth/data/bridges/aliyun_number_auth_bridge.dart';
import 'package:ling/src/features/auth/data/bridges/apple_sign_in_bridge.dart';
import 'package:ling/src/features/auth/data/bridges/wechat_login_bridge.dart';
import 'package:ling/src/features/auth/data/repositories/auth_repository.dart';
import 'package:ling/src/features/auth/data/repositories/profile_repository.dart';
import 'package:ling/src/features/auth/data/storage/auth_session_store.dart';
import 'package:ling/src/features/calendar/data/bridges/apple_calendar_bridge.dart';
import 'package:ling/src/features/calendar/data/bridges/calendar_provider_app_launcher.dart';
import 'package:ling/src/features/calendar/data/bridges/external_calendar_oauth_bridge.dart';
import 'package:ling/src/features/calendar/data/repositories/apple_calendar_sync_repository.dart';
import 'package:ling/src/features/calendar/data/repositories/calendar_integration_repository.dart';
import 'package:ling/src/features/calendar/data/repositories/calendar_repository.dart';
import 'package:ling/src/features/chat/data/agent_file_repository.dart';
import 'package:ling/src/features/chat/data/agent_file_save_service.dart';
import 'package:ling/src/features/chat/data/apple_speech_recognition_bridge.dart';
import 'package:ling/src/features/chat/data/chat_repository.dart';
import 'package:ling/src/features/chat/data/conversation_attachment_save_service.dart';
import 'package:ling/src/features/chat/data/native_camera_picker_bridge.dart';
import 'package:ling/src/features/chat/data/shared_image_receive_bridge.dart';
import 'package:ling/src/features/membership/data/bridges/membership_payment_bridge.dart';
import 'package:ling/src/features/membership/data/repositories/membership_repository.dart';
import 'package:ling/src/features/settings/data/bridges/calendar_notification_bridge.dart';
import 'package:ling/src/features/settings/data/bridges/photo_library_permission_bridge.dart';
import 'package:ling/src/features/settings/data/bridges/review_request_bridge.dart';
import 'package:ling/src/shared/i18n/tool_label_repository.dart';

final authSessionStoreProvider = Provider<AuthSessionStore>((ref) {
  return AuthSessionStore(secureStore: ref.read(secureStorageProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(apiClient: ref.read(apiClientProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    apiClient: ref.read(apiClientProvider),
    cacheStore: ref.read(jsonCacheStoreProvider),
    database: ref.read(appDatabaseProvider),
    localPersistencePolicy: ref.read(localPersistencePolicyProvider),
    privateAssetCacheStore: ref.read(privateAssetCacheStoreProvider),
    agentFileCacheStore: ref.read(agentFileCacheStoreProvider),
  );
});

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository(
    apiClient: ref.read(apiClientProvider),
    cacheStore: ref.read(jsonCacheStoreProvider),
    database: ref.read(appDatabaseProvider),
    localPersistencePolicy: ref.read(localPersistencePolicyProvider),
  );
});

final calendarIntegrationRepositoryProvider =
    Provider<CalendarIntegrationRepository>((ref) {
      return CalendarIntegrationRepository(
        apiClient: ref.read(apiClientProvider),
      );
    });

final appleCalendarSyncRepositoryProvider =
    Provider<AppleCalendarSyncRepository>((ref) {
      return AppleCalendarSyncRepository(
        apiClient: ref.read(apiClientProvider),
      );
    });

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    apiClient: ref.read(apiClientProvider),
    database: ref.read(appDatabaseProvider),
    cacheStore: ref.read(jsonCacheStoreProvider),
    localPersistencePolicy: ref.read(localPersistencePolicyProvider),
  );
});

final toolLabelRepositoryProvider = Provider<ToolLabelRepository>((ref) {
  return ToolLabelRepository(
    apiClient: ref.read(apiClientProvider),
    cacheStore: ref.read(jsonCacheStoreProvider),
  );
});

final agentFileRepositoryProvider = Provider<AgentFileRepository>((ref) {
  return AgentFileRepository(
    apiClient: ref.read(apiClientProvider),
    cacheStore: ref.read(agentFileCacheStoreProvider),
  );
});

final agentFileCacheStoreProvider = Provider<AgentFileCacheStore>((ref) {
  return const DefaultAgentFileCacheStore();
});

final agentFileSaveBridgeProvider = Provider<AgentFileSaveBridge>(
  (ref) => MethodChannelAgentFileSaveBridge(),
);

final agentFileSaveServiceProvider = Provider<AgentFileSaveService>((ref) {
  return AgentFileSaveService(bridge: ref.read(agentFileSaveBridgeProvider));
});

final membershipRepositoryProvider = Provider<MembershipRepository>((ref) {
  return MembershipRepository(apiClient: ref.read(apiClientProvider));
});

final membershipPaymentBridgeProvider = Provider<MembershipPaymentBridge>((
  ref,
) {
  return MethodChannelMembershipPaymentBridge();
});

final appleCalendarBridgeProvider = Provider<AppleCalendarBridge>(
  (ref) => MethodChannelAppleCalendarBridge(),
);

final calendarNotificationBridgeProvider = Provider<CalendarNotificationBridge>(
  (ref) => MethodChannelCalendarNotificationBridge(),
);

final photoLibraryPermissionBridgeProvider =
    Provider<PhotoLibraryPermissionBridge>(
      (ref) => MethodChannelPhotoLibraryPermissionBridge(),
    );

final deviceContextBridgeProvider = Provider<DeviceContextBridge>(
  (ref) => MethodChannelDeviceContextBridge(),
);

final aliyunNumberAuthBridgeProvider = Provider<AliyunNumberAuthBridge>(
  (ref) => MethodChannelAliyunNumberAuthBridge(),
);

final appleSignInBridgeProvider = Provider<AppleSignInBridge>(
  (ref) => MethodChannelAppleSignInBridge(),
);

final appleSpeechRecognitionBridgeProvider =
    Provider<AppleSpeechRecognitionBridge>(
      (ref) => MethodChannelAppleSpeechRecognitionBridge(),
    );

final weChatLoginBridgeProvider = Provider<WeChatLoginBridge>(
  (ref) => MethodChannelWeChatLoginBridge(),
);

final externalCalendarOAuthBridgeProvider =
    Provider<ExternalCalendarOAuthBridge>(
      (ref) => MethodChannelExternalCalendarOAuthBridge(),
    );

final reviewRequestBridgeProvider = Provider<ReviewRequestBridge>(
  (ref) => MethodChannelReviewRequestBridge(),
);

final calendarProviderAppLauncherProvider =
    Provider<CalendarProviderAppLauncher>(
      (ref) => const UrlLauncherCalendarProviderAppLauncher(),
    );

final nativeCameraPickerBridgeProvider = Provider<NativeCameraPickerBridge>(
  (ref) => MethodChannelNativeCameraPickerBridge(),
);

final sharedImageReceiveBridgeProvider = Provider<SharedImageReceiveBridge>(
  (ref) => MethodChannelSharedImageReceiveBridge(),
);

final conversationAttachmentSaveBridgeProvider =
    Provider<ConversationAttachmentSaveBridge>(
      (ref) => MethodChannelConversationAttachmentSaveBridge(),
    );

final conversationAttachmentSaveServiceProvider =
    Provider<ConversationAttachmentSaveService>((ref) {
      final service = ConversationAttachmentSaveService(
        bridge: ref.read(conversationAttachmentSaveBridgeProvider),
      );
      ref.onDispose(service.dispose);
      return service;
    });

final imagePickerProvider = Provider<ImagePicker>((ref) => ImagePicker());

final pushDeviceIdStoreProvider = Provider<PushDeviceIdStore>((ref) {
  return PushDeviceIdStore(preferencesStore: ref.read(preferencesProvider));
});

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(apiClient: ref.read(apiClientProvider));
});

final analyticsTrackerProvider = Provider<AnalyticsTracker>((ref) {
  final tracker = AnalyticsTracker(
    database: ref.read(appDatabaseProvider),
    repository: ref.read(analyticsRepositoryProvider),
    pushDeviceIdStore: ref.read(pushDeviceIdStoreProvider),
  );
  ref.onDispose(tracker.dispose);
  return tracker;
});
