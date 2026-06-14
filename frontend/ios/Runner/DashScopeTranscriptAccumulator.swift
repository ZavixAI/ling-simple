import Foundation

struct DashScopeTranscriptAccumulator {
  private(set) var latestTranscript = ""
  private var committedTranscript = ""
  private var partialTranscript = ""

  mutating func reset() {
    latestTranscript = ""
    committedTranscript = ""
    partialTranscript = ""
  }

  func currentTranscript() -> String {
    mergedTranscript(base: committedTranscript, addition: partialTranscript)
  }

  mutating func acceptPartial(_ transcript: String) -> String? {
    let normalizedTranscript = normalize(transcript)
    guard !normalizedTranscript.isEmpty else {
      return nil
    }
    partialTranscript = liveTranscript(forIncomingTranscript: normalizedTranscript)
    let current = currentTranscript()
    guard !current.isEmpty else {
      return nil
    }
    latestTranscript = current
    return current
  }

  mutating func commit(_ transcript: String) -> String? {
    let normalizedTranscript = normalize(transcript)
    guard !normalizedTranscript.isEmpty else {
      return nil
    }
    committedTranscript = mergedTranscript(
      base: committedTranscript,
      addition: normalizedTranscript
    )
    partialTranscript = ""
    latestTranscript = currentTranscript()
    return latestTranscript
  }

  private func liveTranscript(forIncomingTranscript transcript: String) -> String {
    let normalizedTranscript = normalize(transcript)
    guard !normalizedTranscript.isEmpty, !committedTranscript.isEmpty else {
      return normalizedTranscript
    }
    guard normalizedTranscript != committedTranscript else {
      return ""
    }
    if normalizedTranscript.hasPrefix(committedTranscript) {
      let startIndex = normalizedTranscript.index(
        normalizedTranscript.startIndex,
        offsetBy: committedTranscript.count
      )
      return normalize(String(normalizedTranscript[startIndex...]))
    }
    return normalizedTranscript
  }

  private func normalize(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func mergedTranscript(base: String, addition: String) -> String {
    let left = normalize(base)
    let right = normalize(addition)

    if left.isEmpty {
      return right
    }
    if right.isEmpty {
      return left
    }
    if left.contains(right) {
      return left
    }
    if right.contains(left) {
      return right
    }
    if right.hasPrefix(left) {
      return right
    }
    if left.hasSuffix(right) {
      return left
    }

    let maxOverlap = min(left.count, right.count)
    if maxOverlap > 0 {
      for overlap in stride(from: maxOverlap, through: 1, by: -1) {
        let leftSuffixStart = left.index(left.endIndex, offsetBy: -overlap)
        let rightPrefixEnd = right.index(right.startIndex, offsetBy: overlap)
        if left[leftSuffixStart...] == right[..<rightPrefixEnd] {
          return left + right[rightPrefixEnd...]
        }
      }
    }

    if shouldInsertSpace(between: left, and: right) {
      return "\(left) \(right)"
    }
    return left + right
  }

  private func shouldInsertSpace(between left: String, and right: String) -> Bool {
    guard let leftScalar = left.unicodeScalars.last,
      let rightScalar = right.unicodeScalars.first
    else {
      return false
    }

    guard !CharacterSet.whitespacesAndNewlines.contains(leftScalar),
      !CharacterSet.whitespacesAndNewlines.contains(rightScalar)
    else {
      return false
    }

    return CharacterSet.alphanumerics.contains(leftScalar) &&
      CharacterSet.alphanumerics.contains(rightScalar)
  }
}
