const String preferredInputModeText = 'text';
const String preferredInputModeVoice = 'voice';

String normalizePreferredInputMode(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  return switch (normalized) {
    preferredInputModeVoice => preferredInputModeVoice,
    preferredInputModeText => preferredInputModeText,
    _ => preferredInputModeText,
  };
}

bool prefersVoiceInput(String? value) {
  return normalizePreferredInputMode(value) == preferredInputModeVoice;
}
