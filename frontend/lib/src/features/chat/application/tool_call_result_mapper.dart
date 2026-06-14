import 'dart:convert';

import 'package:ling/src/features/chat/models/chat_session_models.dart';

const Set<String> _lingCalendarMutationToolFunctions = <String>{
  'calendar_create_event',
  'calendar_update_event',
  'calendar_complete_event',
  'calendar_delete_event',
};

const Set<String> _lingIgnoredToolFunctions = <String>{'turn_status'};

bool isLingCalendarMutationFunctionName(String? functionName) {
  return _lingCalendarMutationToolFunctions.contains(functionName);
}

bool isLingIgnoredToolFunctionName(String? functionName) {
  return _lingIgnoredToolFunctions.contains(functionName);
}

bool isLingIgnoredToolCallEntry(ConversationEntryDto entry) {
  if (entry.entryType != 'tool_call') {
    return false;
  }
  final functionName =
      resolveLingToolCallResultFunctionName(entry.toolResult) ?? entry.toolName;
  return isLingIgnoredToolFunctionName(functionName);
}

String? resolveLingCalendarMutationFunctionName(
  String? toolResult, {
  String? fallbackToolName,
}) {
  final resolved = resolveLingToolCallResultFunctionName(toolResult);
  if (isLingCalendarMutationFunctionName(resolved)) {
    return resolved;
  }
  final normalizedFallback = _normalizedString(fallbackToolName);
  if (isLingCalendarMutationFunctionName(normalizedFallback)) {
    return normalizedFallback;
  }
  return resolved;
}

String? resolveLingToolCallResultFunctionName(String? toolResult) {
  final payload = decodeLingToolCallResultPayload(toolResult);
  if (payload == null) {
    return null;
  }
  final directFunctionName = _normalizedString(payload['function_name']);
  if (directFunctionName != null) {
    return directFunctionName;
  }
  final directAction = _normalizedString(payload['action']);
  if (directAction != null) {
    return directAction;
  }
  final data = payload['data'];
  if (data is Map<String, dynamic>) {
    return _normalizedString(data['function_name']);
  }
  if (data is Map) {
    return _normalizedString(data['function_name']);
  }
  return null;
}

Map<String, dynamic>? decodeLingToolCallResultPayload(String? toolResult) {
  final normalized = _normalizedString(toolResult);
  if (normalized == null) {
    return null;
  }
  try {
    final decoded = jsonDecode(normalized);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {
    return null;
  }
  return null;
}

Map<String, dynamic>? decodeLingCalendarClientAction(String? toolResult) {
  final payload = decodeLingToolCallResultPayload(toolResult);
  if (payload == null) {
    return null;
  }
  final dataValue = payload['data'];
  final data = dataValue is Map<String, dynamic>
      ? dataValue
      : dataValue is Map
      ? Map<String, dynamic>.from(dataValue)
      : null;
  if (data == null) {
    return null;
  }
  final actionValue = data['client_action'];
  if (actionValue is Map<String, dynamic>) {
    return actionValue;
  }
  if (actionValue is Map) {
    return Map<String, dynamic>.from(actionValue);
  }
  return null;
}

String? _normalizedString(Object? value) {
  final normalized = '$value'.trim();
  if (value == null || normalized.isEmpty || normalized == 'null') {
    return null;
  }
  return normalized;
}
