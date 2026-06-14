import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var initializedBinaryMessengerId: ObjectIdentifier?
  private var appleCalendarChannel: AppleCalendarChannel?
  private var calendarNotificationChannel: CalendarNotificationChannel?
  private var deviceContextChannel: DeviceContextChannel?
  private var aliyunNumberAuthChannel: AliyunNumberAuthChannel?
  private var appleSignInChannel: AppleSignInChannel?
  private var appleMembershipPaymentChannel: AppleMembershipPaymentChannel?
  private var dashScopeSpeechRecognitionChannel: DashScopeSpeechRecognitionChannel?
  private var photoLibraryPermissionChannel: PhotoLibraryPermissionChannel?
  private var nativeCameraPickerChannel: NativeCameraPickerChannel?
  private var weChatSDKChannel: WeChatSDKChannel?
  private var externalCalendarOAuthChannel: ExternalCalendarOAuthChannel?
  private var conversationAttachmentSaveChannel: ConversationAttachmentSaveChannel?
  private var nativeShareChannel: NativeShareChannel?
  private var socialShareSDKChannel: SocialShareSDKChannel?
  private var reviewRequestChannel: ReviewRequestChannel?
  private var sharedImageReceiveChannel: SharedImageReceiveChannel?
  private var deepLinkChannel: DeepLinkChannel?
  private var appRuntimeChannel: AppRuntimeChannel?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    print("[Ling][iOS][SceneDelegate] willConnectTo begin")
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    print("[Ling][iOS][SceneDelegate] willConnectTo after super")
    initializeChannelsIfPossible(reason: "willConnectTo")
    if !connectionOptions.urlContexts.isEmpty,
      sharedImageReceiveChannel?.handleOpenURLContexts(connectionOptions.urlContexts) == true
    {
      return
    }
    for userActivity in connectionOptions.userActivities {
      if deepLinkChannel?.handleContinue(userActivity) == true {
        return
      }
    }
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    print("[Ling][iOS][SceneDelegate] sceneDidBecomeActive")
    initializeChannelsIfPossible(reason: "sceneDidBecomeActive")
  }

  private func initializeChannelsIfPossible(reason: String) {
    guard let controller = flutterViewController() else {
      print(
        "[Ling][iOS][SceneDelegate] \(reason) could not find FlutterViewController yet"
      )
      return
    }
    print("[Ling][iOS][SceneDelegate] \(reason) resolved FlutterViewController")
    let messengerObject = controller.binaryMessenger as AnyObject
    let messengerId = ObjectIdentifier(messengerObject)
    if initializedBinaryMessengerId != messengerId {
      appleCalendarChannel = nil
      calendarNotificationChannel = nil
      deviceContextChannel = nil
      aliyunNumberAuthChannel = nil
      appleSignInChannel = nil
      appleMembershipPaymentChannel = nil
      dashScopeSpeechRecognitionChannel = nil
      photoLibraryPermissionChannel = nil
      nativeCameraPickerChannel = nil
      weChatSDKChannel = nil
      externalCalendarOAuthChannel = nil
      conversationAttachmentSaveChannel = nil
      nativeShareChannel = nil
      socialShareSDKChannel = nil
      reviewRequestChannel = nil
      sharedImageReceiveChannel = nil
      deepLinkChannel = nil
      appRuntimeChannel = nil
      initializedBinaryMessengerId = nil
    }

    var didInitializeAnyChannel = false
    if appleCalendarChannel == nil {
      appleCalendarChannel = AppleCalendarChannel(messenger: controller.binaryMessenger)
      didInitializeAnyChannel = true
    }
    if calendarNotificationChannel == nil {
      calendarNotificationChannel = CalendarNotificationChannel(
        messenger: controller.binaryMessenger
      )
      didInitializeAnyChannel = true
    }
    if deviceContextChannel == nil {
      deviceContextChannel = DeviceContextChannel(
        messenger: controller.binaryMessenger
      )
      didInitializeAnyChannel = true
    }
    if aliyunNumberAuthChannel == nil {
      aliyunNumberAuthChannel = AliyunNumberAuthChannel(
        messenger: controller.binaryMessenger
      )
      didInitializeAnyChannel = true
    }
    if appleSignInChannel == nil {
      appleSignInChannel = AppleSignInChannel(
        messenger: controller.binaryMessenger,
        presentationAnchorProvider: { [weak self] in self?.window }
      )
      didInitializeAnyChannel = true
    }
    if appleMembershipPaymentChannel == nil {
      appleMembershipPaymentChannel = AppleMembershipPaymentChannel(
        messenger: controller.binaryMessenger
      )
      didInitializeAnyChannel = true
    }
    if dashScopeSpeechRecognitionChannel == nil {
      dashScopeSpeechRecognitionChannel = DashScopeSpeechRecognitionChannel(
        messenger: controller.binaryMessenger
      )
      didInitializeAnyChannel = true
    }
    if photoLibraryPermissionChannel == nil {
      photoLibraryPermissionChannel = PhotoLibraryPermissionChannel(
        messenger: controller.binaryMessenger
      )
      didInitializeAnyChannel = true
    }
    if nativeCameraPickerChannel == nil {
      nativeCameraPickerChannel = NativeCameraPickerChannel(
        messenger: controller.binaryMessenger,
        presenter: controller
      )
      didInitializeAnyChannel = true
    }
    if weChatSDKChannel == nil {
      weChatSDKChannel = WeChatSDKChannel(
        messenger: controller.binaryMessenger
      )
      didInitializeAnyChannel = true
    }
    if externalCalendarOAuthChannel == nil {
      externalCalendarOAuthChannel = ExternalCalendarOAuthChannel(
        messenger: controller.binaryMessenger,
        presentationAnchorProvider: { [weak self] in self?.window }
      )
      didInitializeAnyChannel = true
    }
    if conversationAttachmentSaveChannel == nil {
      conversationAttachmentSaveChannel = ConversationAttachmentSaveChannel(
        messenger: controller.binaryMessenger,
        presenter: controller
      )
      didInitializeAnyChannel = true
    }
    if nativeShareChannel == nil {
      nativeShareChannel = NativeShareChannel(
        messenger: controller.binaryMessenger,
        presenter: controller
      )
      didInitializeAnyChannel = true
    }
    if socialShareSDKChannel == nil {
      socialShareSDKChannel = SocialShareSDKChannel(messenger: controller.binaryMessenger)
      didInitializeAnyChannel = true
    }
    if reviewRequestChannel == nil {
      reviewRequestChannel = ReviewRequestChannel(
        messenger: controller.binaryMessenger,
        windowProvider: { [weak self] in self?.window }
      )
      didInitializeAnyChannel = true
    }
    if sharedImageReceiveChannel == nil {
      sharedImageReceiveChannel = SharedImageReceiveChannel(
        messenger: controller.binaryMessenger
      )
      didInitializeAnyChannel = true
    }
    if deepLinkChannel == nil {
      deepLinkChannel = DeepLinkChannel(messenger: controller.binaryMessenger)
      didInitializeAnyChannel = true
    }
    if appRuntimeChannel == nil {
      appRuntimeChannel = AppRuntimeChannel(
        messenger: controller.binaryMessenger
      )
      didInitializeAnyChannel = true
    }
    if didInitializeAnyChannel {
      initializedBinaryMessengerId = messengerId
      print("[Ling][iOS][SceneDelegate] channels initialized")
    } else {
      print("[Ling][iOS][SceneDelegate] channels already initialized")
    }
  }

  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    initializeChannelsIfPossible(reason: "openURLContexts")
    if externalCalendarOAuthChannel?.handleOpenURLContexts(URLContexts) == true {
      return
    }
    if weChatSDKChannel?.handleOpenURLContexts(URLContexts) == true {
      return
    }
    if socialShareSDKChannel?.handleOpenURLContexts(URLContexts) == true {
      return
    }
    if sharedImageReceiveChannel?.handleOpenURLContexts(URLContexts) == true {
      return
    }
    super.scene(scene, openURLContexts: URLContexts)
  }

  override func scene(
    _ scene: UIScene,
    continue userActivity: NSUserActivity
  ) {
    initializeChannelsIfPossible(reason: "continueUserActivity")
    if externalCalendarOAuthChannel?.handleContinue(userActivity) == true {
      return
    }
    if weChatSDKChannel?.handleContinue(userActivity) == true {
      return
    }
    if socialShareSDKChannel?.handleContinue(userActivity) == true {
      return
    }
    if deepLinkChannel?.handleContinue(userActivity) == true {
      return
    }
    super.scene(scene, continue: userActivity)
  }

  private func flutterViewController(
    from root: UIViewController? = nil
  ) -> FlutterViewController? {
    let candidate = root ?? window?.rootViewController
    if let controller = candidate as? FlutterViewController {
      return controller
    }
    if let navigationController = candidate as? UINavigationController {
      return flutterViewController(
        from: navigationController.visibleViewController ?? navigationController.topViewController
      )
    }
    if let tabBarController = candidate as? UITabBarController {
      return flutterViewController(from: tabBarController.selectedViewController)
    }
    if let presentedController = candidate?.presentedViewController {
      return flutterViewController(from: presentedController)
    }
    return nil
  }
}
