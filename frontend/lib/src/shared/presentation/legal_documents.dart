import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/presentation/adaptive_controls.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';

enum LingLegalDocumentType { privacy, security }

const EdgeInsets lingLegalDocumentDialogPadding = EdgeInsets.fromLTRB(
  24,
  52,
  24,
  18,
);
const EdgeInsets lingLegalDocumentInlinePadding = EdgeInsets.fromLTRB(
  24,
  28,
  24,
  24,
);

String lingLegalDocumentTitle(LingStrings strings, LingLegalDocumentType type) {
  return switch (type) {
    LingLegalDocumentType.privacy => strings.privacyAgreementTitle,
    LingLegalDocumentType.security => strings.securityAgreementTitle,
  };
}

String lingLegalDocumentMarkdown(
  LingStrings strings,
  LingLegalDocumentType type,
) {
  if (strings.isZh) {
    return switch (type) {
      LingLegalDocumentType.privacy => _privacyMarkdownZh,
      LingLegalDocumentType.security => _securityMarkdownZh,
    };
  }
  return switch (type) {
    LingLegalDocumentType.privacy => _privacyMarkdownEn,
    LingLegalDocumentType.security => _securityMarkdownEn,
  };
}

Future<void> showLingLegalDocumentDialog({
  required BuildContext context,
  required LingStrings strings,
  required LingLegalDocumentType type,
}) {
  final palette = context.palette;
  return showDialog<void>(
    context: context,
    barrierColor: palette.scrim.withValues(alpha: 0.28),
    builder: (dialogContext) {
      return _LingLegalDocumentDialog(strings: strings, type: type);
    },
  );
}

class _LingLegalDocumentDialog extends StatelessWidget {
  const _LingLegalDocumentDialog({required this.strings, required this.type});

  final LingStrings strings;
  final LingLegalDocumentType type;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 640),
            child: LingGlassSurface(
              key: Key('legal_document_dialog_${type.name}'),
              radius: 28,
              tone: LingGlassSurfaceTone.elevated,
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Scrollbar(
                          child: SingleChildScrollView(
                            padding: lingLegalDocumentDialogPadding,
                            child: LingLegalDocumentBody(
                              strings: strings,
                              type: type,
                              useDialogPalette: true,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                        child: LingAdaptiveFilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          minHeight: 48,
                          borderRadius: BorderRadius.circular(14),
                          child: Text(strings.gotItAction),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: LingGlassIconButton(
                      key: const Key('legal_document_close_button'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icons.close_rounded,
                      iconSize: 26,
                      semanticLabel: strings.closeAction,
                      iconColor: palette.textPrimary.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LingLegalDocumentBody extends StatelessWidget {
  const LingLegalDocumentBody({
    super.key,
    required this.strings,
    required this.type,
    this.useDialogPalette = false,
  });

  final LingStrings strings;
  final LingLegalDocumentType type;
  final bool useDialogPalette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final foreground = useDialogPalette
        ? palette.textPrimary
        : theme.colorScheme.onSurface;
    final bodyColor = useDialogPalette
        ? palette.textSecondary
        : theme.colorScheme.onSurface.withValues(alpha: 0.76);

    return MarkdownBody(
      data: lingLegalDocumentMarkdown(strings, type),
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        h1: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: foreground,
          height: 1.2,
        ),
        h2: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: foreground,
          height: 1.4,
        ),
        p: TextStyle(
          fontSize: 13,
          height: 1.75,
          color: bodyColor,
          fontWeight: FontWeight.w500,
        ),
        listBullet: TextStyle(fontSize: 13, height: 1.75, color: bodyColor),
        blockSpacing: 14,
      ),
    );
  }
}

const String _privacyMarkdownZh = '''
# 隐私协议

更新日期：2026年4月7日

## 1. 适用范围

本协议适用于 Ling 当前版本提供的账号登录、AI 对话、日历同步、提醒通知、语音输入等功能。你使用 Ling，即表示你理解并同意本协议所述的数据处理方式。

## 2. 我们可能收集的信息

- **账号与身份信息**：例如邮箱地址、手机号、验证码登录结果、本机号码一键认证返回的必要校验结果。
- **日历与提醒信息**：例如你主动同步、创建、修改或删除的日程，提醒时间，以及相关的日历偏好设置。
- **对话与语音信息**：例如你输入给 Ling 的文本、语音转写结果，以及为了完成任务所需的上下文内容。
- **设备与运行信息**：例如设备生成的标识、推送令牌、时区、语言、权限状态、应用版本和必要的错误日志。
- **你主动提供的资料**：例如你自行上传的其他资料。

## 3. 我们如何使用这些信息

- 完成登录认证、账号绑定、会话维持和账号恢复。
- 提供 AI 对话、日历整理、提醒通知、语音输入等核心功能。
- 在你授权后读取或写回系统日历，帮助你完成排程同步。
- 维护应用稳定性，排查故障，识别异常请求，提升产品体验。
- 满足法律法规要求，处理安全、审计与合规相关事项。

## 4. 信息共享与第三方服务

我们不会出售你的个人信息。为了完成功能，我们可能在必要范围内调用第三方能力，包括但不限于 Apple Calendar / EventKit、Apple Push Notification service，以及阿里云号码认证、语音转写、邮件或对象存储等基础设施服务。

## 5. 存储与保留

- 我们会尽量采用传输加密、访问控制和最小化留存等方式保护数据。
- 设备侧的会话令牌等敏感信息会优先存放在系统提供的安全存储能力中。
- 我们仅在实现业务功能、履行法定义务或处理争议所需的期限内保留相关信息。
- 当你注销账户后，我们会按照产品逻辑和适用规则删除或匿名化可清理的数据；法律法规另有要求的除外。

## 6. 系统权限说明

Ling 可能会申请日历、通知、麦克风、相册或相机等系统权限，用于对应功能。你可以随时在系统设置中关闭相关权限，但对应功能可能无法继续使用。

## 7. 你的管理权利

你可以通过应用内操作或系统设置，管理登录方式、关闭系统权限、退出当前会话，或申请删除账户。对于当前版本尚未提供自助入口的事项，你可以通过应用内反馈或官方对外联系方式与我们联系。

## 8. 协议更新

如果 Ling 的功能、服务范围或适用法律发生变化，我们可能更新本协议。更新后的版本会在应用内展示，并自发布时或页面说明的日期起生效。
''';

const String _securityMarkdownZh = '''
# 安全协议

更新日期：2026年4月7日

## 1. 安全目标

我们希望在合理范围内保护你的账号、日历、提醒、对话内容和上传资料，降低未经授权访问、泄露、篡改或丢失的风险。

## 2. 我们采取的安全措施

- 对网络传输过程尽量采用加密通道。
- 对设备侧会话令牌等敏感信息优先使用系统安全存储。
- 按照业务需要控制数据访问范围，仅向有必要的系统或服务开放权限。
- 对异常请求、错误日志和安全风险进行必要监测、排查与修复。
- 在账号登录、验证码校验、本机号码认证等环节使用相应的身份验证机制。

## 3. 你的安全义务

为了更好地保护你的账号与数据，你同意妥善保管手机、邮箱、验证码、登录状态和其他身份凭证，不通过非官方方式共享验证码或令牌，并为设备开启锁屏密码、Face ID、Touch ID 等系统级防护。

## 4. 风险提示

尽管我们会持续改进安全能力，但互联网环境并不存在绝对安全。因设备被破解、网络异常、第三方基础设施中断，或你主动向他人披露验证码、截图、共享设备等行为，都可能带来安全风险。

## 5. 安全事件处理

当我们发现可能影响服务或数据安全的事件时，会尽快进行隔离、评估、修复与复盘；在法律法规要求或确有必要时，我们会通过应用内通知、公告或其他合理方式告知你。

## 6. 协议更新与生效

本协议会随产品能力和安全实践的变化进行更新。更新后的版本发布后即对新使用行为生效；如继续使用 Ling，即视为你接受更新后的内容。
''';

const String _privacyMarkdownEn = '''
# Privacy Policy

Last updated: April 7, 2026

## 1. Scope

This policy applies to Ling features such as account sign-in, AI chat, calendar sync, notifications, and voice input. By using Ling, you acknowledge the data practices described here.

## 2. Information We May Collect

- **Account and identity data** such as email address, phone number, verification results, and the minimum data needed for one-tap phone authentication.
- **Calendar and notification data** such as events you sync, create, edit, or delete, notification timing, and calendar preferences.
- **Chat and voice data** such as text you send to Ling, speech transcripts, and task context needed to fulfill your request.
- **Device and runtime data** such as a device-generated identifier, push token, timezone, locale, permission state, app version, and necessary error logs.
- **Content you choose to provide** such as other uploaded material.

## 3. How We Use Information

- To authenticate sign-in, bind account methods, maintain sessions, and support account recovery.
- To provide AI chat, planning, notifications, voice input, and related product features.
- To read from or write to the system calendar after you grant permission.
- To maintain stability, investigate failures, detect abnormal requests, and improve the product.
- To meet legal, compliance, audit, and security requirements when applicable.

## 4. Sharing and Third-Party Services

We do not sell personal information. To operate the service, we may rely on Apple Calendar / EventKit, Apple Push Notification service, Alibaba Cloud authentication, speech transcription, email services, object storage, and similar infrastructure providers when necessary.

## 5. Storage and Retention

- We seek to protect data through encrypted transport, access controls, and data minimization.
- Sensitive local credentials such as session tokens are stored with platform-provided secure storage when available.
- We keep information only for as long as needed to provide the service, satisfy legal obligations, or resolve disputes.
- If you delete your account, we will delete or anonymize data that can be cleared under the product workflow and applicable rules, unless retention is legally required.

## 6. Permission Notice

Ling may request calendar, notification, microphone, photo, or camera access for related features. You can revoke those permissions in system settings, but related features may stop working.

## 7. Your Choices

You can manage sign-in methods, revoke system permissions, sign out, or request account deletion through in-app controls or system settings. For items that do not yet have a self-service flow, you can contact us through in-app feedback or an official support channel.

## 8. Policy Updates

We may update this policy when Ling changes, our service scope changes, or the law requires it. The updated version will be shown in the app and becomes effective on publication or on the date stated in the notice.
''';

const String _securityMarkdownEn = '''
# Security Agreement

Last updated: April 7, 2026

## 1. Security Goal

We aim to protect your account, calendar data, notifications, chat content, and uploaded materials with reasonable safeguards designed to reduce the risk of unauthorized access, disclosure, alteration, or loss.

## 2. Security Measures We Use

- We seek to use encrypted channels for network transmission.
- Sensitive local credentials such as session tokens are stored with platform secure storage when available.
- Access to data is limited according to operational need.
- We perform necessary monitoring, troubleshooting, and remediation for abnormal requests, errors, and security risks.
- We use verification-based sign-in and related identity checks for account access flows.

## 3. Your Security Responsibilities

You agree to keep your phone, email account, verification codes, and sign-in state secure, avoid sharing codes or tokens through unofficial channels, and enable device-level safeguards such as a passcode, Face ID, or Touch ID.

## 4. Risk Notice

No internet-connected service can guarantee absolute security. Risks may still arise from a compromised device, malware, network failures, third-party infrastructure interruptions, or user actions such as sharing verification codes or screenshots.

## 5. Security Incident Response

If we discover an event that may affect service or data security, we will work to contain, assess, fix, and review it. When required by law or reasonably necessary, we may notify you through the app, a public notice, or another suitable channel.

## 6. Updates and Effect

This agreement may be updated as Ling evolves and our security practices improve. The updated version applies to future use after publication. Continued use of Ling means you accept the updated terms.
''';
