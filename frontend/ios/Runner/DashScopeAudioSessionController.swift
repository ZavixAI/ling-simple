import AVFoundation
import Foundation

final class DashScopeAudioSessionController {
  private var snapshot: Snapshot?

  private struct Snapshot {
    let category: AVAudioSession.Category
    let mode: AVAudioSession.Mode
    let options: AVAudioSession.CategoryOptions
    let routeSharingPolicy: AVAudioSession.RouteSharingPolicy
    let setActiveOptions: AVAudioSession.SetActiveOptions
  }

  func configureForRecording() throws {
    let audioSession = AVAudioSession.sharedInstance()
    if snapshot == nil {
      snapshot = Snapshot(
        category: audioSession.category,
        mode: audioSession.mode,
        options: audioSession.categoryOptions,
        routeSharingPolicy: audioSession.routeSharingPolicy,
        setActiveOptions: [.notifyOthersOnDeactivation]
      )
    }
    try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
    try audioSession.setActive(true, options: [])
  }

  func restore() {
    let audioSession = AVAudioSession.sharedInstance()
    let previousSnapshot = snapshot
    snapshot = nil

    if let previousSnapshot {
      try? audioSession.setCategory(
        previousSnapshot.category,
        mode: previousSnapshot.mode,
        policy: previousSnapshot.routeSharingPolicy,
        options: previousSnapshot.options
      )
      try? audioSession.setActive(false, options: previousSnapshot.setActiveOptions)
      return
    }

    try? audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
  }
}
