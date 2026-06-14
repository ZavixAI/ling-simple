import 'package:flutter/foundation.dart';
import 'package:ling/src/shared/i18n/ling_strings_en.dart';
import 'package:ling/src/shared/i18n/ling_strings_zh.dart';

typedef LingToolLabelRefreshCallback =
    void Function(String localeCode, String toolName);

class LingStrings {
  const LingStrings(this.localeCode);

  static final Map<String, Map<String, String>> _runtimeToolLabels =
      <String, Map<String, String>>{};
  static final Set<String> _missingRuntimeToolLabelRequests = <String>{};
  static LingToolLabelRefreshCallback? _onMissingToolLabel;

  static void registerToolLabels(
    String localeCode,
    Map<String, String> labels,
  ) {
    final localeKey = _toolLabelLocaleKey(localeCode);
    if (labels.isEmpty) {
      return;
    }
    _runtimeToolLabels[localeKey] = Map<String, String>.unmodifiable(labels);
  }

  static void configureMissingToolLabelRefresh(
    LingToolLabelRefreshCallback? callback,
  ) {
    _onMissingToolLabel = callback;
  }

  @visibleForTesting
  static void resetRuntimeToolLabelsForTesting() {
    _runtimeToolLabels.clear();
    _missingRuntimeToolLabelRequests.clear();
    _onMissingToolLabel = null;
  }

  final String localeCode;

  Map<String, String> get _values => isZh ? lingZhStrings : lingEnStrings;

  bool get isZh => localeCode.toLowerCase().startsWith('zh');

  String _text(String key) => _values[key] ?? key;

  static String _toolLabelLocaleKey(String localeCode) {
    return localeCode.trim().toLowerCase().startsWith('zh') ? 'zh' : 'en';
  }

  String get loginBadge => _text('loginBadge');
  String get loginWelcomeLead => _text('loginWelcomeLead');
  String get loginWelcomeBrand => 'Ling.';
  String get loginRhythmTagline => _text('loginRhythmTagline');
  String get loginHeroTitle => _text('loginHeroTitle');
  String get loginHeroDescription => _text('loginHeroDescription');
  String get loginDescription => _text('loginDescription');
  String get loginFeatureScheduling => _text('loginFeatureScheduling');
  String get loginFeatureCalendarSync => _text('loginFeatureCalendarSync');
  String get loginFeatureVoice => _text('loginFeatureVoice');
  String get phoneNumber => _text('phoneNumber');
  String get countryCode => _text('countryCode');
  String get identityLabel => _text('identityLabel');
  String get emailAddress => _text('emailAddress');
  String get phonePlaceholder => _text('phonePlaceholder');
  String get emailPlaceholder => _text('emailPlaceholder');
  String get verificationCode => _text('verificationCode');
  String get verificationCodePlaceholder =>
      _text('verificationCodePlaceholder');
  String get resendCode => _text('resendCode');
  String get loginAction => _text('loginAction');
  String get oneClickLoginAction => _text('oneClickLoginAction');
  String get otherSignInMethodsTitle => _text('otherSignInMethodsTitle');
  String get appleSignInAction => _text('appleSignInAction');
  String get appleBrandName => 'Apple';
  String get wechatSignInAction => _text('wechatSignInAction');
  String get emailLoginAction => _text('emailLoginAction');
  String get backToLoginMethods => _text('backToLoginMethods');
  String get verificationCodeHint => _text('verificationCodeHint');
  String get orContinueWith => _text('orContinueWith');
  String get continueWithPhone => _text('continueWithPhone');
  String get continueWithEmail => _text('continueWithEmail');
  String get continueWithPhoneShort => _text('continueWithPhoneShort');
  String get continueWithEmailShort => _text('continueWithEmailShort');
  String get oneClickPhoneShort => _text('oneClickPhoneShort');
  String get otherPhoneShort => _text('otherPhoneShort');
  String get emailCodeLoginHint => _text('emailCodeLoginHint');
  String get sending => _text('sending');
  String get sendPhoneVerificationCode => _text('sendPhoneVerificationCode');
  String get sendEmailVerificationCode => _text('sendEmailVerificationCode');
  String bindingRetryInSeconds(int seconds) =>
      isZh ? '${seconds}s 后重试' : 'Retry in ${seconds}s';
  String get oneClickPhoneAuth => _text('oneClickPhoneAuth');
  String get oneClickPhonePreparing => _text('oneClickPhonePreparing');
  String get oneClickPhoneRecommended => _text('oneClickPhoneRecommended');
  String get oneClickPhoneAuthDescription =>
      _text('oneClickPhoneAuthDescription');
  String get oneClickPhoneAuthing => _text('oneClickPhoneAuthing');
  String get appleSignInAuthing => _text('appleSignInAuthing');
  String get wechatSignInAuthing => _text('wechatSignInAuthing');
  String get phoneCodeLoginUnsupported => _text('phoneCodeLoginUnsupported');
  String get orUseAnotherPhoneNumber => _text('orUseAnotherPhoneNumber');
  String get otherPhoneLogin => _text('otherPhoneLogin');
  String get otherPhoneLoginTitle => _text('otherPhoneLoginTitle');
  String get otherPhoneLoginHint => _text('otherPhoneLoginHint');
  String get backToOneClickLogin => _text('backToOneClickLogin');
  String get oneClickPhoneUnavailable => _text('oneClickPhoneUnavailable');
  String get oneClickPhoneUnconfigured => _text('oneClickPhoneUnconfigured');
  String get oneClickAgreementRequiredTitle =>
      _text('oneClickAgreementRequiredTitle');
  String get oneClickAgreementRequiredMessage =>
      _text('oneClickAgreementRequiredMessage');
  String get agreeAndContinueAction => _text('agreeAndContinueAction');
  String get thinkAgainAction => _text('thinkAgainAction');
  String get agreementReadAndAcceptPrefix =>
      _text('agreementReadAndAcceptPrefix');
  String get agreementConnector => _text('agreementConnector');
  String get privacyAgreementTitle => _text('privacyAgreementTitle');
  String get securityAgreementTitle => _text('securityAgreementTitle');
  String get closeAction => _text('closeAction');
  String get gotItAction => _text('gotItAction');
  String get switchedToOtherPhoneNumber => _text('switchedToOtherPhoneNumber');
  String get oneClickPhoneAuthFailed => _text('oneClickPhoneAuthFailed');
  String get appleSignInFailed => _text('appleSignInFailed');
  String get appleSignInAccountRequired => _text('appleSignInAccountRequired');
  String get wechatSignInFailed => _text('wechatSignInFailed');
  String get appleSignInUnavailable => _text('appleSignInUnavailable');
  String get wechatSignInUnavailable => _text('wechatSignInUnavailable');
  String get appleSignInCancelled => _text('appleSignInCancelled');
  String get wechatSignInCancelled => _text('wechatSignInCancelled');
  String get signingIn => _text('signingIn');
  String get verifyAndEnter => _text('verifyAndEnter');
  String debugCodeLabel(String code) =>
      isZh ? '本地调试验证码: $code' : 'Local debug code: $code';

  String get forceUpdateTitle => _text('forceUpdateTitle');
  String get forceUpdateAction => _text('forceUpdateAction');

  String get appSubtitle => _text('appSubtitle');
  String get introAssistant => _text('introAssistant');
  String get emptyConversationLead => _text('emptyConversationLead');
  String get emptyConversationBrand => 'Ling.';
  String get emptyConversationDescription =>
      _text('emptyConversationDescription');
  String get quickPromptPlanToday => _text('quickPromptPlanToday');
  String get quickPromptAddReminder => _text('quickPromptAddReminder');
  String get quickPromptFindTime => _text('quickPromptFindTime');
  String get quickPromptCaptureIdea => _text('quickPromptCaptureIdea');
  String get quickPromptArrangeIdeas => _text('quickPromptArrangeIdeas');
  String get quickPromptOrganizeRecentIdeasWeb =>
      _text('quickPromptOrganizeRecentIdeasWeb');
  String get quickPromptMergeIdeas => _text('quickPromptMergeIdeas');
  String get quickPromptOpenSchedule => _text('quickPromptOpenSchedule');
  String get quickPromptReviewWeek => _text('quickPromptReviewWeek');
  String get quickPromptTodayImage => _text('quickPromptTodayImage');
  String get quickPromptFutureLetter => _text('quickPromptFutureLetter');
  String get quickPromptOneMinutePodcast =>
      _text('quickPromptOneMinutePodcast');
  String get quickPromptPrivateRitual => _text('quickPromptPrivateRitual');
  String get quickPromptDreamPoster => _text('quickPromptDreamPoster');
  String get quickPromptTodayNarration => _text('quickPromptTodayNarration');
  String get quickPromptReadImage => _text('quickPromptReadImage');
  String get quickPromptSummarizeContent =>
      _text('quickPromptSummarizeContent');
  String get quickPromptMakeDecision => _text('quickPromptMakeDecision');
  String get quickPromptDraftMessage => _text('quickPromptDraftMessage');
  String get quickPromptDailyHotBrief => _text('quickPromptDailyHotBrief');
  String get quickPromptAiNews => _text('quickPromptAiNews');
  String get quickPromptTrendRadar => _text('quickPromptTrendRadar');
  String get quickPromptHotWebReport => _text('quickPromptHotWebReport');
  String get quickPromptProductsToday => _text('quickPromptProductsToday');
  String get quickPromptInspirationBoard =>
      _text('quickPromptInspirationBoard');
  String get quickPromptPlanTodaySubmit => _text('quickPromptPlanTodaySubmit');
  String get quickPromptAddReminderSubmit =>
      _text('quickPromptAddReminderSubmit');
  String get quickPromptFindTimeSubmit => _text('quickPromptFindTimeSubmit');
  String get quickPromptCaptureIdeaSubmit =>
      _text('quickPromptCaptureIdeaSubmit');
  String get quickPromptArrangeIdeasSubmit =>
      _text('quickPromptArrangeIdeasSubmit');
  String get quickPromptOrganizeRecentIdeasWebSubmit =>
      _text('quickPromptOrganizeRecentIdeasWebSubmit');
  String get quickPromptMergeIdeasSubmit =>
      _text('quickPromptMergeIdeasSubmit');
  String get quickPromptOpenScheduleSubmit =>
      _text('quickPromptOpenScheduleSubmit');
  String get quickPromptReviewWeekSubmit =>
      _text('quickPromptReviewWeekSubmit');
  String get quickPromptTodayImageSubmit =>
      _text('quickPromptTodayImageSubmit');
  String get quickPromptFutureLetterSubmit =>
      _text('quickPromptFutureLetterSubmit');
  String get quickPromptOneMinutePodcastSubmit =>
      _text('quickPromptOneMinutePodcastSubmit');
  String get quickPromptPrivateRitualSubmit =>
      _text('quickPromptPrivateRitualSubmit');
  String get quickPromptDreamPosterSubmit =>
      _text('quickPromptDreamPosterSubmit');
  String get quickPromptTodayNarrationSubmit =>
      _text('quickPromptTodayNarrationSubmit');
  String get quickPromptReadImageSubmit => _text('quickPromptReadImageSubmit');
  String get quickPromptSummarizeContentSubmit =>
      _text('quickPromptSummarizeContentSubmit');
  String get quickPromptMakeDecisionSubmit =>
      _text('quickPromptMakeDecisionSubmit');
  String get quickPromptDraftMessageSubmit =>
      _text('quickPromptDraftMessageSubmit');
  String get quickPromptDailyHotBriefSubmit =>
      _text('quickPromptDailyHotBriefSubmit');
  String get quickPromptAiNewsSubmit => _text('quickPromptAiNewsSubmit');
  String get quickPromptTrendRadarSubmit =>
      _text('quickPromptTrendRadarSubmit');
  String get quickPromptHotWebReportSubmit =>
      _text('quickPromptHotWebReportSubmit');
  String get quickPromptProductsTodaySubmit =>
      _text('quickPromptProductsTodaySubmit');
  String get quickPromptInspirationBoardSubmit =>
      _text('quickPromptInspirationBoardSubmit');
  String get quickPromptContextualPrefix =>
      _text('quickPromptContextualPrefix');
  String get scrollToBottom => _text('scrollToBottom');
  String get starterTaskCaptureIdea => _text('starterTaskCaptureIdea');
  String get starterTaskCaptureIdeaSubtitle =>
      _text('starterTaskCaptureIdeaSubtitle');
  String get starterTaskCaptureIdeaSubmit =>
      _text('starterTaskCaptureIdeaSubmit');
  String get starterTaskArrangeIdeas => _text('starterTaskArrangeIdeas');
  String get starterTaskArrangeIdeasSubtitle =>
      _text('starterTaskArrangeIdeasSubtitle');
  String get starterTaskArrangeIdeasSubmit =>
      _text('starterTaskArrangeIdeasSubmit');
  String get starterTaskAddReminder => _text('starterTaskAddReminder');
  String get starterTaskAddReminderSubtitle =>
      _text('starterTaskAddReminderSubtitle');
  String get starterTaskAddReminderSubmit =>
      _text('starterTaskAddReminderSubmit');
  String get starterTaskPlanToday => _text('starterTaskPlanToday');
  String get starterTaskPlanTodaySubtitle =>
      _text('starterTaskPlanTodaySubtitle');
  String get starterTaskPlanTodaySubmit => _text('starterTaskPlanTodaySubmit');
  String get next7Days => _text('next7Days');
  String get viewMonth => _text('viewMonth');
  String get scheduleTab => _text('scheduleTab');
  String get intentsTab => _text('intentsTab');
  String get mailboxTab => _text('mailboxTab');
  String get lingLettersMailboxLabel => _text('lingLettersMailboxLabel');
  String get mailboxAllFilter => _text('mailboxAllFilter');
  String get mailboxUnreadFilter => _text('mailboxUnreadFilter');
  String get mailboxReadFilter => _text('mailboxReadFilter');
  String get switchToMonthView => _text('switchToMonthView');
  String get switchToWeekView => _text('switchToWeekView');
  String get calendarTodayAction => _text('calendarTodayAction');
  String get emptyIntentList => _text('emptyIntentList');
  String get emptyLingLetters => _text('emptyLingLetters');
  String get inactiveIdeasAction => _text('inactiveIdeasAction');
  String get inactiveIdeasTitle => _text('inactiveIdeasTitle');
  String get inactiveIdeasEmpty => _text('inactiveIdeasEmpty');
  String get inactiveIdeasLoading => _text('inactiveIdeasLoading');
  String inactiveIdeaStatusLabel(String status) {
    switch (status.trim()) {
      case 'expired':
        return isZh ? '待确认' : 'Needs review';
      case 'scheduled':
        return isZh ? '已日程化' : 'Scheduled';
      case 'completed':
        return isZh ? '已完成' : 'Completed';
      case 'cancelled':
        return isZh ? '已取消' : 'Cancelled';
      default:
        return status.trim();
    }
  }

  String get ideasRangeLabel => _text('ideasRangeLabel');
  String get ideasDetailsTitle => _text('ideasDetailsTitle');
  String get ideasEditTitle => _text('ideasEditTitle');
  String get ideasDescriptionLabel => _text('ideasDescriptionLabel');
  String get ideasTimeHintLabel => _text('ideasTimeHintLabel');
  String get ideasLocationHintLabel => _text('ideasLocationHintLabel');
  String get ideasTimeWindowLabel => _text('ideasTimeWindowLabel');
  String get ideasDurationLabel => _text('ideasDurationLabel');
  String get ideasRecordLabel => _text('ideasRecordLabel');
  String get ideasTimezoneLabel => _text('ideasTimezoneLabel');
  String get ideasTimeExpressionLabel => _text('ideasTimeExpressionLabel');
  String get ideasOnboardingLabel => _text('ideasOnboardingLabel');
  String get ideasMoreLabel => _text('ideasMoreLabel');
  String get ideasTypeLabel => _text('ideasTypeLabel');
  String get ideasStatusLabel => _text('ideasStatusLabel');
  String get ideasSourceLabel => _text('ideasSourceLabel');
  String get ideasCreatedAtLabel => _text('ideasCreatedAtLabel');
  String get ideasUpdatedAtLabel => _text('ideasUpdatedAtLabel');
  String get ideasSaveAction => _text('ideasSaveAction');
  String get ideasDeleteAction => _text('ideasDeleteAction');
  String get ideasDeleteConfirmTitle => _text('ideasDeleteConfirmTitle');
  String ideasDeleteConfirmMessage(String title) =>
      isZh ? '确认删除“$title”吗？' : 'Delete "$title"?';
  String get ideasTitleRequired => _text('ideasTitleRequired');
  String get schedule => _text('schedule');
  String get todaysSchedule => _text('todaysSchedule');
  String get emptySchedule => _text('emptySchedule');

  String hiUser(String name) => isZh ? '你好，$name！' : 'Hi, $name!';
  String get userFallback => _text('userFallback');
  String get noPhone => _text('noPhone');
  String get noEmail => _text('noEmail');
  String identitiesCount(int count) => isZh ? '身份 $count' : 'Identities $count';
  String get settingsTitle => _text('settingsTitle');
  String get settingsPoweredBySage => _text('settingsPoweredBySage');
  String get accountSecuritySectionTitle =>
      _text('accountSecuritySectionTitle');
  String get calendarNotificationSectionTitle =>
      _text('calendarNotificationSectionTitle');
  String get calendarSectionTitle => _text('calendarSectionTitle');
  String get notificationsTitle => _text('notificationsTitle');
  String get permissionsTitle => _text('permissionsTitle');
  String get locationPermissionTitle => _text('locationPermissionTitle');
  String get microphonePermissionTitle => _text('microphonePermissionTitle');
  String get speechPermissionTitle => _text('speechPermissionTitle');
  String get photoPermissionTitle => _text('photoPermissionTitle');
  String get calendarProviderSectionTitle =>
      _text('calendarProviderSectionTitle');
  String get generalSectionTitle => _text('generalSectionTitle');
  String get generalSubtitle => _text('generalSubtitle');
  String get localImageCacheTitle => _text('localImageCacheTitle');
  String get localImageCacheCalculating => _text('localImageCacheCalculating');
  String get clearLocalImageCacheAction => _text('clearLocalImageCacheAction');
  String get localImageCacheCleared => _text('localImageCacheCleared');
  String get agentMemoryTitle => _text('agentMemoryTitle');
  String get agentMemorySubtitle => _text('agentMemorySubtitle');
  String get agentMemoryDocFallbackTitle =>
      _text('agentMemoryDocFallbackTitle');
  String get agentMemoryFileFallbackTitle =>
      _text('agentMemoryFileFallbackTitle');
  String get agentMemoryLoadingTitle => _text('agentMemoryLoadingTitle');
  String get agentMemoryLoadingBody => _text('agentMemoryLoadingBody');
  String get agentMemoryLoadFailedTitle => _text('agentMemoryLoadFailedTitle');
  String get agentMemoryLoadFailedBody => _text('agentMemoryLoadFailedBody');
  String get agentMemoryEmptyTitle => _text('agentMemoryEmptyTitle');
  String get agentMemoryEmptyBody => _text('agentMemoryEmptyBody');
  String get agentMemoryHighlightsTitle => _text('agentMemoryHighlightsTitle');
  String get agentMemoryFilesTitle => _text('agentMemoryFilesTitle');
  String get agentMemoryIntroBody => _text('agentMemoryIntroBody');
  String get agentMemoryDocMissingTitle => _text('agentMemoryDocMissingTitle');
  String get agentMemoryDocMissingBody => _text('agentMemoryDocMissingBody');
  String get agentMemoryFileMissingTitle =>
      _text('agentMemoryFileMissingTitle');
  String get agentMemoryFileMissingBody => _text('agentMemoryFileMissingBody');
  String get agentMemoryFileOpeningTitle =>
      _text('agentMemoryFileOpeningTitle');
  String get agentMemoryFileOpeningBody => _text('agentMemoryFileOpeningBody');
  String get agentMemoryFilePreviewFailedTitle =>
      _text('agentMemoryFilePreviewFailedTitle');
  String get agentMemoryFilePreviewFailedBody =>
      _text('agentMemoryFilePreviewFailedBody');
  String get agentMemoryEmptyFolder => _text('agentMemoryEmptyFolder');
  String agentMemoryFileCount(int count) =>
      isZh ? '$count 个文件' : '$count file${count == 1 ? '' : 's'}';
  String get agentMemoryDirectoryLoadFailed =>
      _text('agentMemoryDirectoryLoadFailed');
  String get agentMemoryOpenFullContent => _text('agentMemoryOpenFullContent');
  String get agentMemoryDocNotCreated => _text('agentMemoryDocNotCreated');
  String get agentMemoryEmptyDocument => _text('agentMemoryEmptyDocument');
  String get agentMemoryTruncatedNotice => _text('agentMemoryTruncatedNotice');
  String get agentMemoryMarkdownIntroSection =>
      _text('agentMemoryMarkdownIntroSection');
  String get agentMemoryMarkdownFallbackSection =>
      _text('agentMemoryMarkdownFallbackSection');
  String get quietHoursTitle => _text('quietHoursTitle');
  String get quietHoursSubtitle => _text('quietHoursSubtitle');
  String get quietHoursStartLabel => _text('quietHoursStartLabel');
  String get quietHoursEndLabel => _text('quietHoursEndLabel');
  String quietHoursRange(String start, String end) =>
      isZh ? '$start - $end' : '$start – $end';
  String get quietHoursPickerTitle => _text('quietHoursPickerTitle');
  String get quietHoursSaveAction => _text('quietHoursSaveAction');
  String get quietHoursCancelAction => _text('quietHoursCancelAction');
  String get aboutSupportSectionTitle => _text('aboutSupportSectionTitle');
  String get aboutLingTitle => _text('aboutLingTitle');
  String get aboutLingSubtitle => _text('aboutLingSubtitle');
  String get aboutLingReviewAction => _text('aboutLingReviewAction');
  String get aboutLingFeedbackAction => _text('aboutLingFeedbackAction');
  String get aboutLingReviewSheetTitle => _text('aboutLingReviewSheetTitle');
  String get aboutLingReviewEncourageAction =>
      _text('aboutLingReviewEncourageAction');
  String get aboutLingReviewIssueAction => _text('aboutLingReviewIssueAction');
  String get aboutLingFeedbackSheetTitle =>
      _text('aboutLingFeedbackSheetTitle');
  String get aboutLingFeedbackPlaceholder =>
      _text('aboutLingFeedbackPlaceholder');
  String get aboutLingFeedbackScreenshotAction =>
      _text('aboutLingFeedbackScreenshotAction');
  String get aboutLingFeedbackRemoveScreenshotAction =>
      _text('aboutLingFeedbackRemoveScreenshotAction');
  String get aboutLingFeedbackSubmitAction =>
      _text('aboutLingFeedbackSubmitAction');
  String get aboutLingReviewUnavailable => _text('aboutLingReviewUnavailable');
  String get aboutLingFeedbackSubmitted => _text('aboutLingFeedbackSubmitted');
  String get aboutLingFeedbackEmptyError =>
      _text('aboutLingFeedbackEmptyError');
  String get membershipTitle => _text('membershipTitle');
  String get membershipRootSubtitle => _text('membershipRootSubtitle');
  String get membershipInactiveStatus => _text('membershipInactiveStatus');
  String get membershipActiveStatus => _text('membershipActiveStatus');
  String get membershipProAccessTitle => _text('membershipProAccessTitle');
  String get membershipProAccessSubtitle =>
      _text('membershipProAccessSubtitle');
  String membershipExpiresAt(String value) =>
      isZh ? '到期时间 $value' : 'Expires $value';
  String get membershipCancelAtPeriodEnd =>
      _text('membershipCancelAtPeriodEnd');
  String get membershipSubscriptionTitle =>
      _text('membershipSubscriptionTitle');
  String get membershipSubscriptionSubtitle =>
      _text('membershipSubscriptionSubtitle');
  String get membershipFreeTierLabel => _text('membershipFreeTierLabel');
  String get membershipProTierLabel => _text('membershipProTierLabel');
  String get membershipRecurringLabel => _text('membershipRecurringLabel');
  String get membershipOneTimeLabel => _text('membershipOneTimeLabel');
  String get membershipMonthLabel => _text('membershipMonthLabel');
  String get membershipQuarterLabel => _text('membershipQuarterLabel');
  String get membershipYearLabel => _text('membershipYearLabel');
  String membershipDailyChatLimit(int count) =>
      isZh ? '每日 $count 次对话' : '$count chats per day';
  String get membershipUnlimitedDailyChat =>
      _text('membershipUnlimitedDailyChat');
  String get membershipFeatureCore => _text('membershipFeatureCore');
  String get membershipFeatureAdvanced => _text('membershipFeatureAdvanced');
  String get membershipFeatureFutureUnlock =>
      _text('membershipFeatureFutureUnlock');
  String get membershipFreeFeatureSchedule =>
      _text('membershipFreeFeatureSchedule');
  String get membershipFreeFeatureIdea => _text('membershipFreeFeatureIdea');
  String get membershipFreeFeatureLimitedChat =>
      _text('membershipFreeFeatureLimitedChat');
  String get membershipProFeatureUnlimitedChat =>
      _text('membershipProFeatureUnlimitedChat');
  String get membershipProFeatureImageInput =>
      _text('membershipProFeatureImageInput');
  String get membershipProFeatureAllTools =>
      _text('membershipProFeatureAllTools');
  String get membershipProFeaturePriority =>
      _text('membershipProFeaturePriority');
  String get membershipUpgradeHeroTitle => _text('membershipUpgradeHeroTitle');
  String get membershipUpgradeHeroBody => _text('membershipUpgradeHeroBody');
  String get membershipUpgradeBenefitChat =>
      _text('membershipUpgradeBenefitChat');
  String get membershipUpgradeBenefitImageInput =>
      _text('membershipUpgradeBenefitImageInput');
  String get membershipUpgradeBenefitMemory =>
      _text('membershipUpgradeBenefitMemory');
  String get membershipUpgradeAction => _text('membershipUpgradeAction');
  String get membershipLingSurfaceGateTitle =>
      _text('membershipLingSurfaceGateTitle');
  String get membershipLingSurfaceGateBody =>
      _text('membershipLingSurfaceGateBody');
  String get membershipComparisonTitle => _text('membershipComparisonTitle');
  String get membershipCurrentPlan => _text('membershipCurrentPlan');
  String get membershipProMonthlyPrice => _text('membershipProMonthlyPrice');
  String get membershipOpenAction => _text('membershipOpenAction');
  String get membershipPurchaseAction => _text('membershipPurchaseAction');
  String get membershipStartRecurringAction =>
      _text('membershipStartRecurringAction');
  String get membershipPrivacyPolicyLink =>
      _text('membershipPrivacyPolicyLink');
  String get membershipTermsOfUseLink => _text('membershipTermsOfUseLink');
  String get membershipAlreadyActiveAction =>
      _text('membershipAlreadyActiveAction');
  String get membershipAlreadyActiveSubtitle =>
      _text('membershipAlreadyActiveSubtitle');
  String get membershipServerConfigErrorTitle =>
      _text('membershipServerConfigErrorTitle');
  String get membershipServerConfigErrorMessage =>
      _text('membershipServerConfigErrorMessage');
  String get membershipRestorePurchases => _text('membershipRestorePurchases');
  String get membershipManageSubscription =>
      _text('membershipManageSubscription');
  String get membershipPurchaseSuccess => _text('membershipPurchaseSuccess');
  String get membershipPurchasePending => _text('membershipPurchasePending');
  String get membershipRestoreSuccess => _text('membershipRestoreSuccess');
  String get membershipNoRestorablePurchases =>
      _text('membershipNoRestorablePurchases');
  String get membershipLinkedToAnotherAccount =>
      _text('membershipLinkedToAnotherAccount');
  String get membershipPlanLoading => _text('membershipPlanLoading');
  String get membershipPlanRetry => _text('membershipPlanRetry');
  String get membershipUnsupportedPlatform =>
      _text('membershipUnsupportedPlatform');
  String get membershipQuotaExhaustedTitle =>
      _text('membershipQuotaExhaustedTitle');
  String get membershipQuotaExhaustedMessage =>
      _text('membershipQuotaExhaustedMessage');
  String get membershipRequiredMessage => _text('membershipRequiredMessage');
  String get membershipViewPlansAction => _text('membershipViewPlansAction');
  String get signInMethodsTitle => _text('signInMethodsTitle');
  String get signInMethodsSubtitle => _text('signInMethodsSubtitle');
  String get currentTimezoneTitle => _text('currentTimezoneTitle');
  String get timezoneFollowsDevice => _text('timezoneFollowsDevice');
  String get timezoneReadonlyHint => _text('timezoneReadonlyHint');
  String get connectionStatusTitle => _text('connectionStatusTitle');
  String get syncedEventsTitle => _text('syncedEventsTitle');
  String get viewLatestDocument => _text('viewLatestDocument');
  String get privacyAgreementSubtitle => _text('privacyAgreementSubtitle');
  String get securityAgreementSubtitle => _text('securityAgreementSubtitle');
  String get aboutLingIntroduction => _text('aboutLingIntroduction');
  String boundItemsSummary(int count) =>
      isZh ? '已绑定 $count 项' : '$count linked';
  String get noBoundItemsSummary => _text('noBoundItemsSummary');
  String get simplifiedChinese => _text('simplifiedChinese');
  String get englishLanguage => _text('englishLanguage');
  String appVersionLabel(String version) =>
      isZh ? '版本 $version' : 'Version $version';
  String get account => _text('account');
  String get calendarTitle => _text('calendarTitle');
  String get accountInfo => _text('accountInfo');
  String get settingsSubtitle => _text('settingsSubtitle');
  String get appearance => _text('appearance');
  String get appearanceSubtitle => _text('appearanceSubtitle');
  String get followSystem => _text('followSystem');
  String get followSystemSubtitle => _text('followSystemSubtitle');
  String get lightTheme => _text('lightTheme');
  String get lightThemeSubtitle => _text('lightThemeSubtitle');
  String get darkTheme => _text('darkTheme');
  String get darkThemeSubtitle => _text('darkThemeSubtitle');
  String get timezoneTitle => _text('timezoneTitle');
  String get timezoneSubtitle => _text('timezoneSubtitle');
  String get identitiesTitle => _text('identitiesTitle');
  String get identitiesSubtitle => _text('identitiesSubtitle');
  String get accountAccess => _text('accountAccess');
  String get accountAccessSubtitle => _text('accountAccessSubtitle');
  String get accountSettings => _text('accountSettings');
  String get voicePreferences => _text('voicePreferences');
  String get privacy => _text('privacy');
  String get helpFeedback => _text('helpFeedback');
  String get accountSettingsSubtitle => _text('accountSettingsSubtitle');
  String get voicePreferencesSubtitle => _text('voicePreferencesSubtitle');
  String get privacySubtitle => _text('privacySubtitle');
  String get helpFeedbackSubtitle => _text('helpFeedbackSubtitle');
  String get bindPhoneDescription => _text('bindPhoneDescription');
  String get bindEmailDescription => _text('bindEmailDescription');
  String get bindPhoneTitle => _text('bindPhoneTitle');
  String get bindEmailTitle => _text('bindEmailTitle');
  String get boundCanUseForSignIn => _text('boundCanUseForSignIn');
  String get unboundStatus => _text('unboundStatus');
  String get boundStatus => _text('boundStatus');
  String get bindPhone => _text('bindPhone');
  String get bindEmail => _text('bindEmail');
  String get bindAppleIdentity => _text('bindAppleIdentity');
  String get bindWeChatIdentity => _text('bindWeChatIdentity');
  String get appleSignInMethodTitle => _text('appleSignInMethodTitle');
  String get appleSignInMethodSubtitle => _text('appleSignInMethodSubtitle');
  String get wechatSignInMethodTitle => _text('wechatSignInMethodTitle');
  String get wechatSignInMethodSubtitle => _text('wechatSignInMethodSubtitle');
  String get dataSourcesTitle => _text('dataSourcesTitle');
  String get calendarNotificationsTitle => _text('calendarNotificationsTitle');
  String get calendarNotificationsSubtitle =>
      _text('calendarNotificationsSubtitle');
  String get calendarNotificationsDisabled =>
      _text('calendarNotificationsDisabled');
  String get calendarNotificationPermissionTitle =>
      _text('calendarNotificationPermissionTitle');

  /// Section header above the system-notification permission row (distinct from row label).
  String get calendarSettingsAlertsSectionTitle =>
      _text('calendarSettingsAlertsSectionTitle');
  String get appleCalendarRowTitle => _text('appleCalendarRowTitle');
  String get feishuCalendarRowTitle => _text('feishuCalendarRowTitle');
  String get dingtalkCalendarRowTitle => _text('dingtalkCalendarRowTitle');
  String get defaultNotificationStyleTitle =>
      _text('defaultNotificationStyleTitle');
  String get calendarWriteBackSectionTitle =>
      _text('calendarWriteBackSectionTitle');
  String get calendarAppleWriteBackTitle =>
      _text('calendarAppleWriteBackTitle');
  String get calendarAppleWriteBackSubtitle =>
      _text('calendarAppleWriteBackSubtitle');
  String get calendarAppleWriteBackPermissionHint =>
      _text('calendarAppleWriteBackPermissionHint');
  String get calendarProviderSyncSubtitle =>
      _text('calendarProviderSyncSubtitle');
  String get calendarProviderReadAccessTitle =>
      _text('calendarProviderReadAccessTitle');
  String get calendarProviderWriteBackTitle =>
      _text('calendarProviderWriteBackTitle');
  String get calendarProviderWriteBackUnavailable =>
      _text('calendarProviderWriteBackUnavailable');
  String get calendarProviderWriteBackNeedsAuth =>
      _text('calendarProviderWriteBackNeedsAuth');
  String get calendarProviderWriteBackOn =>
      _text('calendarProviderWriteBackOn');
  String get calendarProviderWriteBackOff =>
      _text('calendarProviderWriteBackOff');
  String get calendarProviderSyncedEvents =>
      _text('calendarProviderSyncedEvents');
  String get calendarProviderLastSyncedAt =>
      _text('calendarProviderLastSyncedAt');
  String get calendarProviderNeverSynced =>
      _text('calendarProviderNeverSynced');
  String get calendarProviderSyncError => _text('calendarProviderSyncError');
  String get calendarProviderAccountLabel =>
      _text('calendarProviderAccountLabel');
  String get calendarNotificationPermissionDescription =>
      _text('calendarNotificationPermissionDescription');
  String get calendarNotificationEnablePermission =>
      _text('calendarNotificationEnablePermission');
  String get calendarNotificationPermissionRequiredTitle =>
      _text('calendarNotificationPermissionRequiredTitle');
  String get calendarNotificationPermissionRequiredMessage =>
      _text('calendarNotificationPermissionRequiredMessage');
  String get calendarNotificationUnauthorizedSubtitle =>
      _text('calendarNotificationUnauthorizedSubtitle');
  String get openSystemSettings => _text('openSystemSettings');
  String get oneTapEnablePermissions => _text('oneTapEnablePermissions');
  String get calendarNotificationChannelTitle =>
      _text('calendarNotificationChannelTitle');
  String get calendarNotificationChannelLingLocal =>
      _text('calendarNotificationChannelLingLocal');
  String get calendarNotificationChannelAppleCalendar =>
      _text('calendarNotificationChannelAppleCalendar');
  String get calendarNotificationChannelAppleCalendarHint =>
      _text('calendarNotificationChannelAppleCalendarHint');
  String get calendarNotificationMethodTitle =>
      _text('calendarNotificationMethodTitle');
  String get calendarNotificationLeadTimeTitle =>
      _text('calendarNotificationLeadTimeTitle');
  String get calendarNotificationAtStartTitle =>
      _text('calendarNotificationAtStartTitle');
  String get calendarNotificationEnabledTitle =>
      _text('calendarNotificationEnabledTitle');
  String get calendarNotificationEnabledDescription =>
      _text('calendarNotificationEnabledDescription');
  String get calendarNotificationBackgroundHint =>
      _text('calendarNotificationBackgroundHint');
  String get calendarNotificationModeBannerSound =>
      _text('calendarNotificationModeBannerSound');
  String get calendarNotificationModeBannerOnly =>
      _text('calendarNotificationModeBannerOnly');
  String get calendarNotificationModeSilent =>
      _text('calendarNotificationModeSilent');
  String get notificationOptionEnabled => _text('notificationOptionEnabled');
  String get notificationOptionDisabled => _text('notificationOptionDisabled');
  String get notificationPermissionGranted =>
      _text('notificationPermissionGranted');
  String get notificationPermissionUnauthorized =>
      _text('notificationPermissionUnauthorized');
  String get notificationPermissionDenied =>
      _text('notificationPermissionDenied');
  String get notificationPermissionNotDetermined =>
      _text('notificationPermissionNotDetermined');
  String get notificationPermissionUnsupported =>
      _text('notificationPermissionUnsupported');
  String get calendarAccessAuthorized => _text('calendarAccessAuthorized');
  String get calendarAccessUnauthorized => _text('calendarAccessUnauthorized');
  String notifyBeforeMinutes(int minutes) =>
      isZh ? '提前 $minutes 分钟' : '$minutes minutes before';
  String notificationStartsInMinutesBody(int minutes) =>
      isZh ? '将在 $minutes 分钟后开始' : 'Starts in $minutes minutes';
  String get notificationStartsNowBody => _text('notificationStartsNowBody');
  String get phoneAlreadyBound => _text('phoneAlreadyBound');
  String get emailAlreadyBound => _text('emailAlreadyBound');
  String get phoneAlreadyInUse => _text('phoneAlreadyInUse');
  String get emailAlreadyInUse => _text('emailAlreadyInUse');
  String get appleIdentityAlreadyInUse => _text('appleIdentityAlreadyInUse');
  String get wechatIdentityAlreadyInUse => _text('wechatIdentityAlreadyInUse');
  String get bindingVerificationCodeInvalid =>
      _text('bindingVerificationCodeInvalid');
  String get bindingRequestTooFrequent => _text('bindingRequestTooFrequent');
  String get phoneVerificationCodeSendFailed =>
      _text('phoneVerificationCodeSendFailed');
  String get emailVerificationCodeSendFailed =>
      _text('emailVerificationCodeSendFailed');
  String get phoneBoundSuccess => _text('phoneBoundSuccess');
  String get emailBoundSuccess => _text('emailBoundSuccess');
  String get appleIdentityBoundSuccess => _text('appleIdentityBoundSuccess');
  String get wechatIdentityBoundSuccess => _text('wechatIdentityBoundSuccess');
  String get phoneBindingFailed => _text('phoneBindingFailed');
  String get emailBindingFailed => _text('emailBindingFailed');
  String get appleIdentityBindingFailed => _text('appleIdentityBindingFailed');
  String get wechatIdentityBindingFailed =>
      _text('wechatIdentityBindingFailed');
  String get completeBinding => _text('completeBinding');
  String get bindingInProgress => _text('bindingInProgress');
  String get accountSafety => _text('accountSafety');
  String get accountSafetySubtitle => _text('accountSafetySubtitle');
  String get signOut => _text('signOut');
  String get signOutConfirmMessage => _text('signOutConfirmMessage');
  String get signOutSubtitle => _text('signOutSubtitle');
  String get languageTitle => _text('languageTitle');
  String get languageSubtitle => _text('languageSubtitle');
  String get preferredInputModeTitle => _text('preferredInputModeTitle');
  String get preferredInputModeText => _text('preferredInputModeText');
  String get preferredInputModeVoice => _text('preferredInputModeVoice');
  String get themeFixed => _text('themeFixed');
  String get deleteAccountTitle => _text('deleteAccountTitle');
  String get deleteAccountDescription => _text('deleteAccountDescription');
  String get deleteAccountConfirmMessage =>
      _text('deleteAccountConfirmMessage');
  String get deleteAccountAction => _text('deleteAccountAction');
  String get deleteAccountSuccess => _text('deleteAccountSuccess');

  String get aiSuggestion => _text('aiSuggestion');
  String get aiPlannedEvent => _text('aiPlannedEvent');
  String get confirm => _text('confirm');
  String get modify => _text('modify');
  String get modifyReserved => _text('modifyReserved');
  String get tbd => _text('tbd');
  String get untitled => _text('untitled');
  String get allDay => _text('allDay');
  String get eventDetails => _text('eventDetails');
  String get eventTimeLabel => _text('eventTimeLabel');
  String get eventLocationLabel => _text('eventLocationLabel');
  String get eventMeetingLabel => _text('eventMeetingLabel');
  String get eventPlaceMeetingLabel => _text('eventPlaceMeetingLabel');
  String get eventCategoryLabel => _text('eventCategoryLabel');
  String get eventStatusLabel => _text('eventStatusLabel');
  String get eventTimeShapeLabel => _text('eventTimeShapeLabel');
  String get eventTimezoneLabel => _text('eventTimezoneLabel');
  String get eventDescriptionLabel => _text('eventDescriptionLabel');
  String get eventRecordLabel => _text('eventRecordLabel');
  String get eventInsightsLabel => _text('eventInsightsLabel');
  String get eventPreparationLabel => _text('eventPreparationLabel');
  String get eventInsightPrepHintsLabel => _text('eventInsightPrepHintsLabel');
  String get eventInsightRiskFlagsLabel => _text('eventInsightRiskFlagsLabel');
  String get eventRepeatsLabel => _text('eventRepeatsLabel');
  String get eventMoreLabel => _text('eventMoreLabel');
  String get eventSourceLabel => _text('eventSourceLabel');
  String get eventSyncLabel => _text('eventSyncLabel');
  String get eventAttendeesLabel => _text('eventAttendeesLabel');
  String get eventFocusModeLabel => _text('eventFocusModeLabel');
  String get eventCreatedAtLabel => _text('eventCreatedAtLabel');
  String get eventUpdatedAtLabel => _text('eventUpdatedAtLabel');
  String get eventOccurrenceLabel => _text('eventOccurrenceLabel');
  String emptyDayNote({
    required bool isToday,
    required bool isTomorrow,
    DateTime? date,
  }) {
    final variantSeed = date == null
        ? 0
        : date.year + date.month + date.day + date.weekday;
    final variant = variantSeed % 8;
    if (isZh) {
      if (isToday) {
        const todayNotes = <String>[
          '今天暂时没有安排，留一点空白也不错。',
          '今天还空着，可以慢一点，也可以随时叫我帮你记一件事。',
          '今天没有固定日程，正好给自己一点弹性。',
          '今天的时间还很松，你想安排什么再告诉我就好。',
        ];
        return todayNotes[variant % todayNotes.length];
      }
      if (isTomorrow) {
        const tomorrowNotes = <String>[
          '明天还没有安排，需要我帮你先记上一件事吗？',
          '明天留白中，如果有计划，可以随时告诉 Ling。',
        ];
        return tomorrowNotes[variant % tomorrowNotes.length];
      }
      const generalNotes = <String>[
        '这一天还没有安排，享受一点留白。',
        '这一天暂时空着，想补计划时告诉 Ling 就好。',
        '目前没有排程，也许这是给自己喘口气的一天。',
        '这一天还是空白的，之后想起什么我都可以帮你记下。',
      ];
      return generalNotes[variant % generalNotes.length];
    }
    if (isToday) {
      const todayNotes = <String>[
        'Nothing planned for today. A little breathing room is nice.',
        'Today is still open. Tell Ling anytime if you want to add something.',
        'No fixed plans today. Keeping some flexibility feels good.',
        'Today is light so far. You can always ask Ling to add something later.',
      ];
      return todayNotes[variant % todayNotes.length];
    }
    if (isTomorrow) {
      const tomorrowNotes = <String>[
        'Tomorrow is open. Want Ling to add something?',
        'Tomorrow is still clear. Ling can help you fill it in anytime.',
      ];
      return tomorrowNotes[variant % tomorrowNotes.length];
    }
    const generalNotes = <String>[
      'No plans here yet. Enjoy the open space.',
      'This day is still open. Ling can help you fill it in anytime.',
      'Nothing scheduled for now. Maybe that little bit of room is a good thing.',
      'This one is still blank. If something comes up, Ling can log it for you.',
    ];
    return generalNotes[variant % generalNotes.length];
  }

  String get sourceLing => 'Ling';
  String intentTypeLabel(String type) {
    switch (type.trim()) {
      case 'travel':
        return isZh ? '出行' : 'Travel';
      case 'goal':
        return isZh ? '目标' : 'Goal';
      case 'task':
        return isZh ? '待办' : 'Task';
      case 'plan':
      case 'loose_plan':
        return isZh ? '计划' : 'Plan';
      case 'task_lead':
        return isZh ? '任务线索' : 'Task lead';
      case 'meeting':
        return isZh ? '会议' : 'Meeting';
      case 'reflection':
        return isZh ? '感悟' : 'Reflection';
      case 'quote':
        return isZh ? '摘录' : 'Quote';
      case 'memo':
        return isZh ? '备忘' : 'Memo';
      case 'question':
        return isZh ? '问题' : 'Question';
      default:
        return isZh ? '想法' : 'Idea';
    }
  }

  String intentStatusLabel(String status) {
    switch (status.trim()) {
      case 'clarifying':
        return isZh ? '待澄清' : 'Clarifying';
      case 'ready':
        return isZh ? '可执行' : 'Ready';
      case 'recorded':
        return isZh ? '已收纳' : 'Recorded';
      case 'scheduled':
        return isZh ? '已日程化' : 'Scheduled';
      case 'completed':
        return isZh ? '已完成' : 'Completed';
      case 'cancelled':
        return isZh ? '已取消' : 'Cancelled';
      case 'expired':
        return isZh ? '已过期' : 'Expired';
      case 'deleted':
        return isZh ? '已删除' : 'Deleted';
      default:
        return isZh ? '已记录' : 'Captured';
    }
  }

  String get sourceApple => _text('sourceApple');
  String get sourceAppleHoliday => _text('sourceAppleHoliday');
  String get sageReturnedError => _text('sageReturnedError');

  String get connectCalendar => _text('connectCalendar');
  String appleCalendarAvailable(int calendarCount, int eventCount) => isZh
      ? 'Apple Calendar 已在当前设备可用。共检测到 $calendarCount 个日历、$eventCount 条本地事件，Ling 可以把它们作为排程上下文。'
      : 'Apple Calendar is available on this device. $calendarCount calendars and $eventCount local events are ready for Ling.';
  String appleCalendarConnectedNoSync(int calendarCount) => isZh
      ? 'Apple Calendar 已连接。当前检测到 $calendarCount 个本地日历，但 Ling 不会默认读取或同步原生日历数据，只有在你手动同步后才会作为上下文使用。'
      : 'Apple Calendar is connected. $calendarCount local calendars are available, but Ling will not read or sync native calendar data until you sync manually.';
  String appleCalendarSynced(int calendarCount, int eventCount) => isZh
      ? 'Apple Calendar 已手动同步到 Ling。当前共检测到 $calendarCount 个日历、$eventCount 条本地事件。'
      : 'Apple Calendar has been manually synced to Ling. $calendarCount calendars and $eventCount local events are currently available.';
  String get connectCalendarDesc => _text('connectCalendarDesc');
  String get appleCalendarDataSourceHint =>
      _text('appleCalendarDataSourceHint');
  String appleCalendarDataSourceConnected(int eventCount) =>
      isZh ? '已同步 $eventCount 条本机事件' : '$eventCount local events synced';
  String get appleCalendarDataSourceEmpty =>
      _text('appleCalendarDataSourceEmpty');
  String get appleCalendarPermissionPromptTitle =>
      _text('appleCalendarPermissionPromptTitle');
  String get appleCalendarFirstLaunchPermissionPromptTitle =>
      _text('appleCalendarFirstLaunchPermissionPromptTitle');
  String get appleCalendarFirstLaunchPermissionPromptMessage =>
      _text('appleCalendarFirstLaunchPermissionPromptMessage');
  String get appleCalendarFirstLaunchSettingsMessage =>
      _text('appleCalendarFirstLaunchSettingsMessage');
  String get appleCalendarPermissionPromptMessage =>
      _text('appleCalendarPermissionPromptMessage');
  String get appleCalendarPermissionSettingsMessage =>
      _text('appleCalendarPermissionSettingsMessage');
  String get connected => _text('connected');
  String get permissionDenied => _text('permissionDenied');
  String get notConnected => _text('notConnected');
  String get notSyncedToLing => _text('notSyncedToLing');
  String get iosOnly => _text('iosOnly');
  String calendarsCount(int count) => isZh ? '$count 个日历' : '$count calendars';
  String eventsCount(int count) => isZh ? '$count 条事件' : '$count events';
  String get refreshAppleContext => _text('refreshAppleContext');
  String get refreshAppleSync => _text('refreshAppleSync');
  String get syncAppleCalendarToLing => _text('syncAppleCalendarToLing');
  String get stopAppleCalendarSync => _text('stopAppleCalendarSync');
  String get enableAppleCalendar => _text('enableAppleCalendar');
  String get authorizeCalendarProvider => _text('authorizeCalendarProvider');
  String get refreshCalendarProvider => _text('refreshCalendarProvider');
  String get retryCalendarProvider => _text('retryCalendarProvider');
  String get disconnectCalendarProvider => _text('disconnectCalendarProvider');
  String get syncingCalendarProvider => _text('syncingCalendarProvider');
  String get syncFailedCalendarProvider => _text('syncFailedCalendarProvider');
  String get calendarProviderUnavailable =>
      _text('calendarProviderUnavailable');
  String get lastSyncedAtTitle => _text('lastSyncedAtTitle');
  String get syncErrorTitle => _text('syncErrorTitle');

  String get typeToLing => _text('typeToLing');
  String get sendMessage => _text('sendMessage');
  String get keyboardPlaceholder => _text('keyboardPlaceholder');
  String get aiGeneratedNotice => _text('aiGeneratedNotice');
  String get lingActivityTitle => _text('lingActivityTitle');
  String get lingMomentsTitle => _text('lingMomentsTitle');
  String get lingMomentsTab => _text('lingMomentsTab');
  String get holdToSpeakTitle => _text('holdToSpeakTitle');
  String get sendVoiceTranscript => _text('sendVoiceTranscript');
  String get voicePlaceholder => _text('voicePlaceholder');
  String get addImage => _text('addImage');
  String get chooseImageSource => _text('chooseImageSource');
  String get cancel => _text('cancel');
  String get takePhoto => _text('takePhoto');
  String get photoLibrary => _text('photoLibrary');
  String get imageUploadInProgress => _text('imageUploadInProgress');
  String get loadMoreConversationEntries =>
      isZh ? '查看更多对话' : 'Load more conversations';
  String viewMoreMessages(int count) => isZh ? '显示更多' : 'View More';
  String promptQueueCount(int count) => isZh
      ? '队列中还有 $count 条待处理消息'
      : '$count queued message${count == 1 ? '' : 's'}';
  String guidanceQueueCount(int count) =>
      isZh ? '$count 条待发送引导' : '$count queued guidance';
  String queuedImageMessage(int count) =>
      isZh ? '$count 张图片' : '$count image${count == 1 ? '' : 's'}';
  String get deleteQueuedMessage => _text('deleteQueuedMessage');
  String get applyQueuedMessageNow => _text('applyQueuedMessageNow');
  String listeningToVoice(String transcript) => isZh
      ? (transcript.isEmpty ? '正在听你说话...' : transcript)
      : (transcript.isEmpty ? 'Listening...' : transcript);
  String get processingVoice => _text('processingVoice');
  String get tapToRecord => _text('tapToRecord');
  String get tapToStopRecording => _text('tapToStopRecording');
  String get tapAgainToSend => _text('tapAgainToSend');
  String get voiceUnsupported => _text('voiceUnsupported');
  String get voicePermissionRequiredTitle =>
      _text('voicePermissionRequiredTitle');
  String get voicePermissionRequiredMessage =>
      _text('voicePermissionRequiredMessage');
  String get voicePermissionRestrictedMessage =>
      _text('voicePermissionRestrictedMessage');
  String get voiceRecognitionErrorMessage =>
      _text('voiceRecognitionErrorMessage');
  String get releaseToSend => _text('releaseToSend');
  String get emptyVoiceTranscript => _text('emptyVoiceTranscript');
  String get editEvent => _text('editEvent');
  String get saveEventChanges => _text('saveEventChanges');
  String get deleteEventAction => _text('deleteEventAction');
  String get recurringEditScopeTitle => _text('recurringEditScopeTitle');
  String get recurringEditScopeMessage => _text('recurringEditScopeMessage');
  String get recurringDeleteScopeTitle => _text('recurringDeleteScopeTitle');
  String get recurringDeleteScopeMessage =>
      _text('recurringDeleteScopeMessage');
  String get recurringScopeThisEvent => _text('recurringScopeThisEvent');
  String get recurringScopeEntireSeries => _text('recurringScopeEntireSeries');
  String get recurringScopeLabel => _text('recurringScopeLabel');
  String get recurringMutationHint => _text('recurringMutationHint');
  String get recurringSeriesRuleHint => _text('recurringSeriesRuleHint');
  String get recurringOccurrenceRuleLockedHint =>
      _text('recurringOccurrenceRuleLockedHint');
  String get recurringNoneOption => _text('recurringNoneOption');
  String get recurringDailyOption => _text('recurringDailyOption');
  String get recurringWeeklyOption => _text('recurringWeeklyOption');
  String get recurringMonthlyOption => _text('recurringMonthlyOption');
  String get recurringYearlyOption => _text('recurringYearlyOption');
  String get recurringWeeklyDaysLabel => _text('recurringWeeklyDaysLabel');
  String get recurringEventBadge => _text('recurringEventBadge');
  String deleteThisEventConfirmMessage(String title) =>
      isZh ? '确认删除“$title”这一次吗？' : 'Delete this occurrence of "$title"?';
  String deleteSeriesConfirmMessage(String title) =>
      isZh ? '确认删除“$title”整个系列吗？' : 'Delete the entire series for "$title"?';
  String get editEventDescription => _text('editEventDescription');
  String get quickAddTitleLabel => _text('quickAddTitleLabel');
  String get quickAddPlaceholder => _text('quickAddPlaceholder');
  String get quickAddDateLabel => _text('quickAddDateLabel');
  String get quickAddStartTimeLabel => _text('quickAddStartTimeLabel');
  String get quickAddEndDateLabel => _text('quickAddEndDateLabel');
  String get quickAddEndTimeLabel => _text('quickAddEndTimeLabel');
  String get quickAddDateTimePickerLabel =>
      _text('quickAddDateTimePickerLabel');
  String get quickAddDurationLabel => _text('quickAddDurationLabel');
  String agendaDurationText(String duration) =>
      isZh ? '持续时间：$duration' : 'Duration: $duration';
  String get quickAddLocationLabel => _text('quickAddLocationLabel');
  String get quickAddLocationPlaceholder =>
      _text('quickAddLocationPlaceholder');
  String get quickAddNotificationLabel => _text('quickAddNotificationLabel');
  String get quickAddNoNotification => _text('quickAddNoNotification');
  String get quickAddTimezoneLabel => _text('quickAddTimezoneLabel');
  String get quickAddTitleRequired => _text('quickAddTitleRequired');
  String get quickAddLocationRequired => _text('quickAddLocationRequired');
  String get pickTime => _text('pickTime');
  String addedToLing(String title) =>
      isZh ? '已将 $title 添加到 Ling' : 'Added $title to Ling';
  String updatedEvent(String title) => isZh ? '已更新 $title' : 'Updated $title';
  String deletedEvent(String title) => isZh ? '已删除 $title' : 'Deleted $title';
  String get toolCallProcessing => _text('toolCallProcessing');
  String get toolCallStatusRunning => _text('toolCallStatusRunning');
  String get toolCallStatusCompleted => _text('toolCallStatusCompleted');
  String get toolFlowCollapse => _text('toolFlowCollapse');
  String get toolFlowCollapsedTitle => _text('toolFlowCollapsedTitle');
  String get toolFlowRunningTitle => _text('toolFlowRunningTitle');
  String toolFlowElapsedSeconds(int seconds) => '${seconds}s';
  String toolFlowViewPrevious(int count) =>
      isZh ? '查看 $count 个步骤' : 'View $count step${count == 1 ? '' : 's'}';
  String toolFlowViewDetails(int count) =>
      isZh ? '查看 $count 个步骤' : 'View $count step${count == 1 ? '' : 's'}';
  String get calendarToolCallCreated => _text('calendarToolCallCreated');
  String get calendarToolCallUpdated => _text('calendarToolCallUpdated');
  String get calendarToolCallMetadataUpdated =>
      _text('calendarToolCallMetadataUpdated');
  String get calendarToolCallCompleted => _text('calendarToolCallCompleted');
  String get calendarToolCallDeleted => _text('calendarToolCallDeleted');
  String get calendarToolCallDeletedFallbackTitle =>
      isZh ? '已删除的日程' : 'Deleted event';
  String toolCallDisplayName(String? rawName) {
    final normalized = (rawName ?? '').trim().toLowerCase().replaceAll(
      RegExp(r'[\s\-]+'),
      '_',
    );
    final runtimeLabel =
        _runtimeToolLabels[_toolLabelLocaleKey(localeCode)]?[normalized]
            ?.trim();
    if (runtimeLabel != null && runtimeLabel.isNotEmpty) {
      return runtimeLabel;
    }
    switch (normalized) {
      case 'calendar_list_events':
        return isZh ? '读取日程' : 'calendar lookup';
      case 'calendar_create_event':
        return isZh ? '创建日程' : 'create event';
      case 'calendar_update_event':
        return isZh ? '更新日程' : 'update event';
      case 'calendar_complete_event':
        return isZh ? '完成日程' : 'complete event';
      case 'calendar_delete_event':
        return isZh ? '删除日程' : 'delete event';
      case 'travel_flight_airport_search':
        return isZh ? '查询机场' : 'search airports';
      case 'travel_flight_search':
        return isZh ? '查询航班' : 'search flights';
      case 'travel_hotel_search':
        return isZh ? '查询酒店' : 'search hotels';
      case 'travel_hotel_rooms':
        return isZh ? '查询酒店房型' : 'check hotel rooms';
      case 'load_skill':
      case 'load_skills':
        return isZh ? '加载技能' : 'load skill';
      case 'search_memory':
      case 'memory_search':
      case 'search_related_memory':
        return isZh ? '记忆搜索' : 'memory search';
      case 'chat_search_history':
      case 'conversation_history_search':
      case 'search_conversation_history':
        return isZh ? '聊天历史搜索' : 'chat history search';
      case 'fetch_webpages':
      case 'fetch_url':
        return isZh ? '获取网页内容' : 'Fetch web content';
      case 'open':
      case 'open_file':
        return isZh ? '打开文件或链接' : 'Open file or link';
      case 'read_thread_terminal':
        return isZh ? '读取终端' : 'read terminal';
      case 'open_url':
        return isZh ? '打开链接' : 'open link';
      case 'read_file':
      case 'file_read':
        return isZh ? '读取文件' : 'read file';
      case 'file_write':
      case 'write_file':
      case 'write_file_result':
      case 'file_write_result':
        return isZh ? '写入文件' : 'write file';
      case 'edit_file':
      case 'update_file':
      case 'apply_patch':
      case 'file_update':
        return isZh ? '修改文件' : 'edit file';
      case 'read_files':
        return isZh ? '读取文件' : 'read files';
      case 'write_files':
        return isZh ? '写入文件' : 'write files';
      case 'run_command':
      case 'exec_command':
      case 'execute_shell_command':
        return isZh ? '执行命令' : 'run command';
      case 'spawn_agent':
      case 'sys_spawn_agent':
        return isZh ? '创建子任务' : 'spawn agent';
      case 'delegate_task':
      case 'sys_delegate_task':
        return isZh ? '委托子任务' : 'delegate task';
      case 'sys_finish_task':
        return isZh ? '整理结果' : 'finish task';
      case 'questionnaire':
        return isZh ? '问卷收集' : 'collect questionnaire';
      case 'todo_write':
        return isZh ? '更新待办' : 'update todo';
      case 'todo_read':
        return isZh ? '读取待办' : 'read todo list';
      case 'recall_memory':
        return isZh ? '回忆记忆' : 'recall memory';
      case 'analyze_image':
        return isZh ? '理解图片' : 'understand image';
      case 'compress_conversation_history':
        return isZh ? '压缩对话历史' : 'compress chat history';
      case 'amap_geocode_address':
      case 'location_geocode_address':
        return isZh ? '地址解析为坐标' : 'geocode address';
      case 'amap_reverse_geocode':
      case 'location_reverse_geocode':
        return isZh ? '坐标解析为地址' : 'reverse geocode';
      case 'amap_search_poi':
      case 'location_search_poi':
        return isZh ? '地点搜索' : 'search places';
      case 'amap_route_plan':
      case 'location_route_plan':
        return isZh ? '路线规划' : 'route planning';
      case 'amap_weather_query':
      case 'location_weather_query':
        return isZh ? '天气查询' : 'weather lookup';
      case 'calendar_event_list':
        return isZh ? '读取日程' : 'calendar lookup';
      case 'calendar_event_create':
        return isZh ? '创建日程' : 'create event';
      case 'calendar_event_update':
        return isZh ? '更新日程' : 'update event';
      case 'calendar_event_delete':
        return isZh ? '删除日程' : 'delete event';
      default:
        if (normalized.isEmpty) {
          return isZh ? '工具调用' : 'Tool Call';
        }
        _requestMissingToolLabelRefresh(normalized);
        return _humanizeToolName(normalized);
    }
  }

  void _requestMissingToolLabelRefresh(String toolName) {
    final callback = _onMissingToolLabel;
    if (callback == null) {
      return;
    }
    final localeKey = _toolLabelLocaleKey(localeCode);
    final requestKey = '$localeKey:$toolName';
    if (!_missingRuntimeToolLabelRequests.add(requestKey)) {
      return;
    }
    callback(localeCode, toolName);
  }

  String toolCallInlineText(String? rawName, {required bool isRunning}) {
    final label = toolCallDisplayName(rawName);
    if (isRunning) {
      return isZh ? '正在$label' : 'Running: $label';
    }
    return label;
  }

  String toolCallGroupedSummary(
    String? rawName, {
    required int count,
    required bool isRunning,
  }) {
    final normalized = (rawName ?? '').trim().toLowerCase().replaceAll(
      RegExp(r'[\s\-]+'),
      '_',
    );
    switch (normalized) {
      case 'travel_flight_airport_search':
      case 'travel_flight_search':
      case 'travel_hotel_search':
      case 'travel_hotel_rooms':
        if (count <= 1) {
          return isRunning
              ? toolCallInlineText(rawName, isRunning: true)
              : toolCallDisplayName(rawName);
        }
        return isZh
            ? '${isRunning ? '正在查询' : '已查询'} $count 次旅行信息'
            : '${isRunning ? 'Checking' : 'Checked'} travel info $count times';
      case 'app_send_notification':
      case 'app_list_notifications':
        if (count <= 1) {
          return isRunning
              ? toolCallInlineText(rawName, isRunning: true)
              : toolCallDisplayName(rawName);
        }
        return isZh
            ? '${isRunning ? '正在处理' : '已处理'} $count 个助理操作'
            : '${isRunning ? 'Working on' : 'Handled'} $count assistant actions';
      case 'read_file':
      case 'read_files':
        if (isRunning) {
          return isZh
              ? '正在浏览${count > 1 ? '$count 个文件' : '文件'}'
              : count == 1
              ? 'Browsing file'
              : 'Browsing $count files';
        }
        return isZh
            ? '已浏览 $count 个文件'
            : count == 1
            ? 'Browsed 1 file'
            : 'Browsed $count files';
      case 'file_write':
      case 'write_file':
      case 'file_write_result':
      case 'write_file_result':
      case 'write_files':
        if (isRunning) {
          return isZh
              ? '正在写入${count > 1 ? '$count 个文件' : '文件'}'
              : count == 1
              ? 'Writing file'
              : 'Writing $count files';
        }
        return isZh
            ? '已写入 $count 个文件'
            : count == 1
            ? 'Wrote 1 file'
            : 'Wrote $count files';
      case 'run_command':
      case 'exec_command':
      case 'execute_shell_command':
        if (isRunning) {
          return isZh
              ? '正在执行${count > 1 ? '$count 条命令' : '命令'}'
              : count == 1
              ? 'Running command'
              : 'Running $count commands';
        }
        return isZh
            ? '已执行 $count 条命令'
            : count == 1
            ? 'Ran 1 command'
            : 'Ran $count commands';
      default:
        final label = toolCallDisplayName(rawName);
        if (count <= 1) {
          return isRunning
              ? toolCallInlineText(rawName, isRunning: true)
              : label;
        }
        return isZh
            ? '${isRunning ? '正在' : ''}$label $count 次'
            : '${isRunning ? 'Running ' : ''}$label x$count';
    }
  }

  String toolFlowMoreSuffix(int count) {
    if (count <= 0) {
      return '';
    }
    return isZh ? '等 $count 项' : 'and $count more';
  }

  String get toolFlowLead => _text('toolFlowLead');

  String formatToolDuration(int? durationMs) {
    if (durationMs == null || durationMs <= 0) {
      return '';
    }
    if (durationMs < 1000) {
      return '${durationMs}ms';
    }
    // Use truncation instead of rounding to avoid overstating elapsed time.
    final deciSeconds = durationMs ~/ 100;
    final wholeSeconds = deciSeconds ~/ 10;
    final decimalPart = deciSeconds % 10;
    if (decimalPart == 0) {
      return '${wholeSeconds}s';
    }
    return '$wholeSeconds.${decimalPart}s';
  }

  String get copied => _text('copied');
  String get copyAction => _text('copyAction');
  String get retryAction => _text('retryAction');
  String get refreshAction => _text('refreshAction');
  String get downloadToLocal => _text('downloadToLocal');
  String get messageActionsTitle => _text('messageActionsTitle');
  String get savedToLocal => _text('savedToLocal');
  String get savedToPhotos => _text('savedToPhotos');
  String get saveFailed => _text('saveFailed');
  String get saveUnsupported => _text('saveUnsupported');

  String _humanizeToolName(String value) {
    final spaced = value
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .trim();
    if (spaced.isEmpty) {
      return isZh ? '工具调用' : 'Tool Call';
    }
    if (isZh) {
      return spaced;
    }
    final titleized = spaced
        .split(RegExp(r'\s+'))
        .map((segment) {
          if (segment.isEmpty) {
            return segment;
          }
          return '${segment[0].toUpperCase()}${segment.substring(1)}';
        })
        .join(' ');
    return titleized.toLowerCase();
  }

  String calendarToolCallCategoryLabel(String category) {
    switch (category.trim()) {
      case 'travel':
        return isZh ? '出行' : 'Travel';
      case 'meeting':
        return isZh ? '会议' : 'Meeting';
      case 'work':
        return isZh ? '工作' : 'Work';
      case 'personal':
        return isZh ? '个人' : 'Personal';
      default:
        return category.trim().isEmpty
            ? (isZh ? '日程' : 'Schedule')
            : category.trim();
    }
  }

  String deleteEventConfirmMessage(String title) => isZh
      ? '确认删除“$title”吗？这条日程会从当前列表中移除。'
      : 'Delete "$title"? This event will be removed from the current schedule.';
  String get editAction => _text('editAction');
  String get deleteAction => _text('deleteAction');
  String get moreActions => _text('moreActions');
  String get cancelAction => _text('cancelAction');
  String get holdToSpeak => _text('holdToSpeak');
  String get sageStreaming => _text('sageStreaming');
  String get dailyView => _text('dailyView');
  String get am => _text('am');
  String get pm => _text('pm');
  String minutesLabel(int minutes) => isZh ? '$minutes 分钟' : '$minutes MIN';
  String monthTitle(int year, int month) {
    if (!isZh) {
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${months[month - 1]} $year';
    }
    return '$year 年 ${month.toString().padLeft(2, '0')} 月';
  }

  String weekdayShort(int weekday) {
    const zh = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return isZh ? zh[(weekday - 1) % 7] : en[(weekday - 1) % 7];
  }

  List<String> get weekdayHeaders => isZh
      ? const ['一', '二', '三', '四', '五', '六', '日']
      : const ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  String get voiceNoteReceived => _text('voiceNoteReceived');
}
