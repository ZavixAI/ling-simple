import AVFoundation
import Foundation

final class DashScopeAudioRecordingStore {
  private var recordingFile: AVAudioFile?
  private var recordingPreviewURL: URL?

  func prepare(format: AVAudioFormat, sessionID: UUID) throws {
    let directory = try recordingDirectory()
    let url = directory.appendingPathComponent("\(sessionID.uuidString).caf")
    recordingPreviewURL = url
    recordingFile = try AVAudioFile(forWriting: url, settings: format.settings)
  }

  func write(_ buffer: AVAudioPCMBuffer) {
    guard let recordingFile, buffer.frameLength > 0 else {
      return
    }
    do {
      try recordingFile.write(from: buffer)
    } catch {
      self.recordingFile = nil
    }
  }

  func finalize() -> String? {
    let audioPath = recordingPreviewURL?.path
    reset()
    return audioPath
  }

  func reset() {
    recordingFile = nil
    recordingPreviewURL = nil
  }

  private func recordingDirectory() throws -> URL {
    let baseDirectory = try FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd"
    let day = formatter.string(from: Date())
    let directory = baseDirectory
      .appendingPathComponent("ling-voice-recordings", isDirectory: true)
      .appendingPathComponent("install", isDirectory: true)
      .appendingPathComponent(day, isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    return directory
  }
}
