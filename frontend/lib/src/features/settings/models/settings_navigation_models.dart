enum LingSettingsPageId {
  root,
  accountSecurity,
  calendar,
  notifications,
  permissions,
  signInMethods,
  accountSafety,
  bindPhone,
  bindEmail,
  general,
  appearance,
  fontSize,
  language,
  preferredInputMode,
  timezoneInfo,
  aboutLing,
  privacy,
  security,
}

int lingSettingsPageDepth(LingSettingsPageId page) {
  return switch (page) {
    LingSettingsPageId.root => 0,
    LingSettingsPageId.accountSecurity ||
    LingSettingsPageId.calendar ||
    LingSettingsPageId.notifications ||
    LingSettingsPageId.permissions ||
    LingSettingsPageId.signInMethods ||
    LingSettingsPageId.accountSafety ||
    LingSettingsPageId.general ||
    LingSettingsPageId.aboutLing => 1,
    LingSettingsPageId.bindPhone ||
    LingSettingsPageId.bindEmail ||
    LingSettingsPageId.appearance ||
    LingSettingsPageId.fontSize ||
    LingSettingsPageId.language ||
    LingSettingsPageId.preferredInputMode ||
    LingSettingsPageId.timezoneInfo ||
    LingSettingsPageId.privacy ||
    LingSettingsPageId.security => 2,
  };
}

int computeLingSettingsPageDirection({
  required LingSettingsPageId currentPage,
  required LingSettingsPageId nextPage,
}) {
  final currentDepth = lingSettingsPageDepth(currentPage);
  final nextDepth = lingSettingsPageDepth(nextPage);
  if (nextDepth == currentDepth) {
    return nextPage.index > currentPage.index ? 1 : -1;
  }
  return nextDepth > currentDepth ? 1 : -1;
}

LingSettingsPageId lingSettingsBackTargetFor(LingSettingsPageId page) {
  return switch (page) {
    LingSettingsPageId.root => LingSettingsPageId.root,
    LingSettingsPageId.appearance ||
    LingSettingsPageId.fontSize ||
    LingSettingsPageId.language ||
    LingSettingsPageId.preferredInputMode ||
    LingSettingsPageId.timezoneInfo => LingSettingsPageId.general,
    LingSettingsPageId.privacy ||
    LingSettingsPageId.security => LingSettingsPageId.aboutLing,
    LingSettingsPageId.signInMethods ||
    LingSettingsPageId.accountSafety => LingSettingsPageId.accountSecurity,
    LingSettingsPageId.bindPhone ||
    LingSettingsPageId.bindEmail => LingSettingsPageId.signInMethods,
    LingSettingsPageId.accountSecurity ||
    LingSettingsPageId.calendar ||
    LingSettingsPageId.notifications ||
    LingSettingsPageId.permissions ||
    LingSettingsPageId.general ||
    LingSettingsPageId.aboutLing => LingSettingsPageId.root,
  };
}
