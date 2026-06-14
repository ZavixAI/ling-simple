import 'package:ling/src/core/network/json_payload_codec.dart';

enum ChatQuickPromptMode {
  direct,
  needsInput;

  static ChatQuickPromptMode parse(String? value) {
    return switch ((value ?? '').trim()) {
      'direct' => ChatQuickPromptMode.direct,
      _ => ChatQuickPromptMode.needsInput,
    };
  }

  String get wireName => switch (this) {
    ChatQuickPromptMode.direct => 'direct',
    ChatQuickPromptMode.needsInput => 'needs_input',
  };
}

class ChatQuickPromptOption {
  const ChatQuickPromptOption({
    required this.id,
    required this.label,
    required this.mode,
    required this.prompt,
    this.hint = '',
  });

  factory ChatQuickPromptOption.fromJson(Map<String, dynamic> json) {
    return ChatQuickPromptOption(
      id: (json['id'] ?? '').toString().trim(),
      label: (json['label'] ?? '').toString().trim(),
      mode: ChatQuickPromptMode.parse(json['mode']?.toString()),
      prompt: (json['prompt'] ?? '').toString().trim(),
      hint: (json['hint'] ?? '').toString().trim(),
    );
  }

  final String id;
  final String label;
  final ChatQuickPromptMode mode;
  final String prompt;
  final String hint;

  bool get isValid =>
      id.trim().isNotEmpty &&
      label.trim().isNotEmpty &&
      prompt.trim().isNotEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'label': label,
    'mode': mode.wireName,
    'prompt': prompt,
    if (hint.trim().isNotEmpty) 'hint': hint,
  };
}

class ChatQuickPromptBundle {
  const ChatQuickPromptBundle({
    required this.version,
    required this.cacheTtlSeconds,
    required this.prompts,
  });

  factory ChatQuickPromptBundle.fromJson(Object? value) {
    final json = asJsonMap(value);
    final prompts = <ChatQuickPromptOption>[
      for (final item in json['prompts'] as List<dynamic>? ?? const [])
        if (item is Map)
          ChatQuickPromptOption.fromJson(Map<String, dynamic>.from(item)),
    ].where((prompt) => prompt.isValid).toList(growable: false);
    return ChatQuickPromptBundle(
      version: (json['version'] ?? '').toString().trim(),
      cacheTtlSeconds:
          (json['cache_ttl_seconds'] as num?)?.toInt() ?? 12 * 60 * 60,
      prompts: prompts,
    );
  }

  final String version;
  final int cacheTtlSeconds;
  final List<ChatQuickPromptOption> prompts;

  Duration get cacheTtl =>
      Duration(seconds: cacheTtlSeconds <= 0 ? 12 * 60 * 60 : cacheTtlSeconds);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'cache_ttl_seconds': cacheTtlSeconds,
    'prompts': prompts.map((prompt) => prompt.toJson()).toList(),
  };
}
