import 'dart:math' as math;

class ChatVoiceTranscriptNormalizer {
  const ChatVoiceTranscriptNormalizer._();

  static const int _minimumExactDuplicateLength = 6;
  static const int _minimumInlineDuplicateLength = 3;

  static String collapseRepeated(String value) {
    var result = value.trim();
    if (result.length < 4) {
      return result;
    }

    var didCollapse = true;
    while (didCollapse) {
      didCollapse = false;
      for (
        var prefixLength = result.length ~/ 2;
        prefixLength >= 2;
        prefixLength -= 1
      ) {
        final prefix = result.substring(0, prefixLength).trim();
        if (prefix.isEmpty) {
          continue;
        }
        final remainder = result.substring(prefixLength);
        final separatorLength = _leadingSeparatorLength(remainder);
        final secondPrefixStart = separatorLength;
        final secondPrefixEnd = secondPrefixStart + prefix.length;
        if (remainder.length < secondPrefixEnd ||
            remainder.substring(secondPrefixStart, secondPrefixEnd) != prefix) {
          continue;
        }

        final tail = remainder.substring(secondPrefixEnd).trimLeft();
        final isWholeDuplicate = tail.isEmpty;
        final hasSeparator = separatorLength > 0;
        if (!_shouldCollapseDuplicate(
          prefixLength: prefix.length,
          hasSeparator: hasSeparator,
          isWholeDuplicate: isWholeDuplicate,
        )) {
          continue;
        }
        result = _join(prefix, tail);
        didCollapse = true;
        break;
      }
    }

    return result;
  }

  static String collapseRepeatedPrefix({
    required String value,
    required String prefix,
  }) {
    var result = collapseRepeated(value);
    final repeated = prefix.trim();
    if (result.isEmpty || repeated.length < 2) {
      return result;
    }

    while (true) {
      final compactDuplicate = '$repeated$repeated';
      if (result.startsWith(compactDuplicate)) {
        result = '$repeated${result.substring(compactDuplicate.length)}'.trim();
        continue;
      }

      final spacedDuplicate = '$repeated $repeated';
      if (result.startsWith(spacedDuplicate)) {
        final tail = result.substring(spacedDuplicate.length).trimLeft();
        result = tail.isEmpty ? repeated : '$repeated $tail';
        continue;
      }

      return result;
    }
  }

  static String mergeFragments({
    required String previousTranscript,
    required String nextTranscript,
  }) {
    final left = previousTranscript.trim();
    final right = collapseRepeatedPrefix(value: nextTranscript, prefix: left);

    if (left.isEmpty) {
      return right;
    }
    if (right.isEmpty) {
      return left;
    }
    if (left.contains(right) || left.endsWith(right)) {
      return left;
    }
    if (right.contains(left) || right.startsWith(left)) {
      return right;
    }

    final maxOverlap = math.min(left.length, right.length);
    for (var overlap = maxOverlap; overlap > 0; overlap -= 1) {
      if (left.substring(left.length - overlap) ==
          right.substring(0, overlap)) {
        return '${left.substring(0, left.length - overlap)}$right';
      }
    }

    return _join(left, right);
  }

  static String chooseFinalTranscript({
    required String finalTranscript,
    required String fallbackTranscript,
  }) {
    final fallback = collapseRepeated(fallbackTranscript);
    final normalizedFinal = collapseRepeated(finalTranscript);
    if (normalizedFinal.isEmpty) {
      return fallback;
    }
    if (fallback.isNotEmpty &&
        fallback != normalizedFinal &&
        fallback.contains(normalizedFinal)) {
      return fallback;
    }
    final repairedFinal = _repairShortFinalTranscript(
      fallbackTranscript: fallback,
      finalTranscript: normalizedFinal,
    );
    if (repairedFinal != null) {
      return repairedFinal;
    }
    return normalizedFinal;
  }

  static bool _shouldCollapseDuplicate({
    required int prefixLength,
    required bool hasSeparator,
    required bool isWholeDuplicate,
  }) {
    if (isWholeDuplicate) {
      return prefixLength >= _minimumExactDuplicateLength;
    }
    if (hasSeparator) {
      return prefixLength >= 2;
    }
    return prefixLength >= _minimumInlineDuplicateLength;
  }

  static String? _repairShortFinalTranscript({
    required String fallbackTranscript,
    required String finalTranscript,
  }) {
    if (fallbackTranscript.isEmpty ||
        finalTranscript.isEmpty ||
        finalTranscript.length >= fallbackTranscript.length ||
        finalTranscript.length < 3) {
      return null;
    }

    final threshold = math.max(1, finalTranscript.length ~/ 3);
    String? bestCandidate;
    var bestDistance = threshold + 1;
    var bestSuffixLength = -1;

    for (var start = 0; start < fallbackTranscript.length; start += 1) {
      final suffix = fallbackTranscript.substring(start);
      if (suffix.isEmpty ||
          suffix.length > finalTranscript.length + threshold ||
          finalTranscript.length > suffix.length + threshold) {
        continue;
      }
      if (!_hasUsefulAnchor(suffix: suffix, finalTranscript: finalTranscript)) {
        continue;
      }

      final distance = _boundedEditDistance(suffix, finalTranscript, threshold);
      if (distance > threshold) {
        continue;
      }

      final suffixLength = suffix.length;
      if (distance < bestDistance ||
          (distance == bestDistance && suffixLength > bestSuffixLength)) {
        bestDistance = distance;
        bestSuffixLength = suffixLength;
        bestCandidate =
            '${fallbackTranscript.substring(0, start)}'
            '$finalTranscript';
      }
    }

    return bestCandidate;
  }

  static bool _hasUsefulAnchor({
    required String suffix,
    required String finalTranscript,
  }) {
    final maxAnchor = math.min(
      2,
      math.min(suffix.length, finalTranscript.length),
    );
    for (var anchorLength = maxAnchor; anchorLength >= 1; anchorLength -= 1) {
      if (suffix.substring(0, anchorLength) ==
          finalTranscript.substring(0, anchorLength)) {
        return true;
      }
      if (suffix.substring(suffix.length - anchorLength) ==
          finalTranscript.substring(finalTranscript.length - anchorLength)) {
        return true;
      }
    }
    return false;
  }

  static int _boundedEditDistance(String left, String right, int maxDistance) {
    if ((left.length - right.length).abs() > maxDistance) {
      return maxDistance + 1;
    }

    var previous = List<int>.generate(right.length + 1, (index) => index);
    for (var leftIndex = 1; leftIndex <= left.length; leftIndex += 1) {
      final current = List<int>.filled(right.length + 1, 0);
      current[0] = leftIndex;
      var rowMinimum = current[0];
      for (var rightIndex = 1; rightIndex <= right.length; rightIndex += 1) {
        final substitutionCost =
            left.codeUnitAt(leftIndex - 1) == right.codeUnitAt(rightIndex - 1)
            ? 0
            : 1;
        final deletion = previous[rightIndex] + 1;
        final insertion = current[rightIndex - 1] + 1;
        final substitution = previous[rightIndex - 1] + substitutionCost;
        final value = math.min(math.min(deletion, insertion), substitution);
        current[rightIndex] = value;
        rowMinimum = math.min(rowMinimum, value);
      }
      if (rowMinimum > maxDistance) {
        return maxDistance + 1;
      }
      previous = current;
    }
    return previous[right.length];
  }

  static int _leadingSeparatorLength(String value) {
    var length = 0;
    for (final codeUnit in value.codeUnits) {
      final character = String.fromCharCode(codeUnit);
      if (!_isDuplicateSeparator(character)) {
        break;
      }
      length += 1;
    }
    return length;
  }

  static bool _isDuplicateSeparator(String value) {
    return value.trim().isEmpty || RegExp(r'^[,，.。!！?？、;；:：]$').hasMatch(value);
  }

  static String _join(String left, String right) {
    if (right.isEmpty) {
      return left;
    }
    final leftTail = left.substring(left.length - 1);
    final rightHead = right.substring(0, 1);
    if (RegExp(r'^[A-Za-z0-9]$').hasMatch(leftTail) &&
        RegExp(r'^[A-Za-z0-9]$').hasMatch(rightHead)) {
      return '$left $right';
    }
    return '$left$right';
  }
}
