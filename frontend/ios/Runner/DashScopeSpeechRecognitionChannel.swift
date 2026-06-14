import AVFoundation
import Flutter
import UIKit

final class DashScopeSpeechRecognitionChannel: NSObject, FlutterStreamHandler {
  private let methodChannel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel
  private let audioEngine = AVAudioEngine()
  private let audioSendQueue = DispatchQueue(label: "ling.speech.asr.audio")
  private let recordingStore = DashScopeAudioRecordingStore()
  private let audioSessionController = DashScopeAudioSessionController()

  private var eventSink: FlutterEventSink?
  private var webSocketTask: URLSessionWebSocketTask?
  private var urlSession: URLSession?
  private var startupTask: Task<Void, Never>?
  private var keepAliveTimer: Timer?
  private var previewPlayer: AVAudioPlayer?

  private var activeSessionID = UUID()
  private var isActive = false
  private var isStopping = false
  private var canSendAudio = false
  private var transcriptAccumulator = DashScopeTranscriptAccumulator()

  private struct RecognitionConfig {
    let locale: String
    let apiKey: String
  }

  init(messenger: FlutterBinaryMessenger) {
    methodChannel = FlutterMethodChannel(
      name: "ling/apple_speech_recognition",
      binaryMessenger: messenger
    )
    eventChannel = FlutterEventChannel(
      name: "ling/apple_speech_recognition/events",
      binaryMessenger: messenger
    )
    super.init()
    methodChannel.setMethodCallHandler(handle)
    eventChannel.setStreamHandler(self)
  }

  deinit {
    activeSessionID = UUID()
    tearDownSessionResources()
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getAuthorizationState":
      getAuthorizationState(result: result)
    case "requestMicrophonePermission":
      requestMicrophonePermission(result: result)
    case "startRecognition":
      startRecognition(call: call, result: result)
    case "stopRecognition":
      stopRecognition(result: result)
    case "cancelRecognition":
      cancelRecognition(result: result)
    case "getPreviewDuration":
      getPreviewDuration(call: call, result: result)
    case "playPreview":
      playPreview(call: call, result: result)
    case "stopPreview":
      stopPreview(result: result)
    case "openSystemSettings":
      openSystemSettings(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func startRecognition(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard !isActive, startupTask == nil else {
      complete(
        result,
        value: FlutterError(
          code: "busy",
          message: "Speech recognition is already running.",
          details: nil
        )
      )
      return
    }

    let config: RecognitionConfig
    do {
      config = try recognitionConfig(from: call)
    } catch {
      complete(result, value: flutterError(from: error))
      return
    }

    startupTask = Task { [weak self] in
      guard let self else {
        return
      }
      defer {
        self.startupTask = nil
      }
      do {
        try await self.ensureMicrophonePermission()
        try Task.checkCancellation()
        try self.startRealtimeRecognition(config: config)
        self.complete(result, value: nil)
      } catch is CancellationError {
        self.resetSessionState(emitCancelled: false)
        self.complete(result, value: nil)
      } catch {
        self.resetSessionState(emitCancelled: false)
        self.complete(result, value: self.flutterError(from: error))
      }
    }
  }

  private func stopRecognition(result: @escaping FlutterResult) {
    guard isActive else {
      result(nil)
      return
    }

    isStopping = true
    canSendAudio = false
    emitEvent(type: "processing", transcript: transcriptAccumulator.latestTranscript, message: nil)
    stopAudioCapture()
    sendClientEvent(type: "input_audio_buffer.commit")
    result(nil)
  }

  private func cancelRecognition(result: @escaping FlutterResult) {
    resetSessionState(emitCancelled: true)
    result(nil)
  }

  private func playPreview(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let url = DashScopeAudioPreviewLoader.previewURL(from: call) else {
      result(0.0)
      return
    }

    if DashScopeAudioPreviewLoader.isRemotePreviewURL(url) {
      playRemotePreview(url: url, result: result)
      return
    }

    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
      try audioSession.setActive(true, options: [])
      previewPlayer?.stop()
      let player = try AVAudioPlayer(contentsOf: url)
      previewPlayer = player
      player.prepareToPlay()
      if player.play() {
        result(player.duration)
      } else {
        result(
          FlutterError(
            code: "preview_play_failed",
            message: "Audio preview could not start.",
            details: nil
          )
        )
      }
    } catch {
      result(flutterError(from: error))
    }
  }

  private func getPreviewDuration(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let url = DashScopeAudioPreviewLoader.previewURL(from: call) else {
      result(0.0)
      return
    }

    if DashScopeAudioPreviewLoader.isRemotePreviewURL(url) {
      DashScopeAudioPreviewLoader.loadRemotePreviewData(url: url) { [weak self] outcome in
        guard let self else {
          result(0.0)
          return
        }
        switch outcome {
        case .success(let data):
          do {
            let player = try AVAudioPlayer(data: data)
            result(player.duration)
          } catch {
            result(self.flutterError(from: error))
          }
        case .failure(let error):
          result(self.flutterError(from: error))
        }
      }
      return
    }

    do {
      let player = try AVAudioPlayer(contentsOf: url)
      result(player.duration)
    } catch {
      result(flutterError(from: error))
    }
  }

  private func stopPreview(result: FlutterResult) {
    previewPlayer?.stop()
    previewPlayer = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    result(nil)
  }

  private func playRemotePreview(url: URL, result: @escaping FlutterResult) {
    DashScopeAudioPreviewLoader.loadRemotePreviewData(url: url) { [weak self] outcome in
      guard let self else {
        result(0.0)
        return
      }
      switch outcome {
      case .success(let data):
        do {
          let audioSession = AVAudioSession.sharedInstance()
          try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
          try audioSession.setActive(true, options: [])
          self.previewPlayer?.stop()
          let player = try AVAudioPlayer(data: data)
          self.previewPlayer = player
          player.prepareToPlay()
          if player.play() {
            result(player.duration)
          } else {
            result(
              FlutterError(
                code: "preview_play_failed",
                message: "Audio preview could not start.",
                details: nil
              )
            )
          }
        } catch {
          result(self.flutterError(from: error))
        }
      case .failure(let error):
        result(self.flutterError(from: error))
      }
    }
  }

  private func getAuthorizationState(result: FlutterResult) {
    let audioStatus = AVAudioSession.sharedInstance().recordPermission
    switch audioStatus {
    case .granted:
      result("granted")
    case .denied:
      result("denied")
    case .undetermined:
      result("not_determined")
    @unknown default:
      result("restricted")
    }
  }

  private func requestMicrophonePermission(result: @escaping FlutterResult) {
    let audioSession = AVAudioSession.sharedInstance()
    switch audioSession.recordPermission {
    case .granted:
      result("granted")
    case .denied:
      result("denied")
    case .undetermined:
      audioSession.requestRecordPermission { allowed in
        DispatchQueue.main.async {
          result(allowed ? "granted" : "denied")
        }
      }
    @unknown default:
      result("restricted")
    }
  }

  private func openSystemSettings(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard let url = URL(string: UIApplication.openSettingsURLString) else {
        result(nil)
        return
      }
      UIApplication.shared.open(url, options: [:]) { _ in
        result(nil)
      }
    }
  }

  private func recognitionConfig(from call: FlutterMethodCall) throws -> RecognitionConfig {
    let args = call.arguments as? [String: Any]
    let locale = ((args?["locale"] as? String) ?? Locale.preferredLanguages.first ?? "zh-CN")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let apiKey = ((Bundle.main.object(forInfoDictionaryKey: "DashScopeAPIKey") as? String) ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard !apiKey.isEmpty else {
      throw channelError(
        code: "asr_unconfigured",
        message: "Speech recognition is not configured."
      )
    }
    return RecognitionConfig(
      locale: locale.isEmpty ? "zh-CN" : locale,
      apiKey: apiKey
    )
  }

  private func ensureMicrophonePermission() async throws {
    let audioSession = AVAudioSession.sharedInstance()
    switch audioSession.recordPermission {
    case .granted:
      return
    case .denied:
      throw channelError(
        code: "microphone_denied",
        message: "Microphone access is required."
      )
    case .undetermined:
      let granted = await withCheckedContinuation {
        (continuation: CheckedContinuation<Bool, Never>) in
        audioSession.requestRecordPermission { allowed in
          continuation.resume(returning: allowed)
        }
      }
      guard granted else {
        throw channelError(
          code: "microphone_denied",
          message: "Microphone access is required."
        )
      }
    @unknown default:
      throw channelError(
        code: "microphone_unavailable",
        message: "Microphone permission is unavailable."
      )
    }
  }

  private func startRealtimeRecognition(config: RecognitionConfig) throws {
    guard let url = DashScopeSpeechRecognitionConfig.recognitionURL() else {
      throw channelError(code: "asr_unconfigured", message: "Speech recognition gateway is invalid.")
    }

    let sessionID = UUID()
    prepareSessionState(sessionID: sessionID)
    try audioSessionController.configureForRecording()
    try installAudioTap(sessionID: sessionID)

    var request = URLRequest(url: url)
    request.timeoutInterval = 10
    request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
    let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
    let task = session.webSocketTask(with: request)
    urlSession = session
    webSocketTask = task
    task.resume()
    receiveWebSocketMessages(sessionID: sessionID)
    startKeepAlive()
    sendSessionUpdate(config: config)
    try audioEngine.start()
  }

  private func isCurrentSession(_ sessionID: UUID) -> Bool {
    isActive && activeSessionID == sessionID
  }

  private func sendSessionUpdate(config: RecognitionConfig) {
    sendClientEvent(
      type: "session.update",
      fields: [
        "session": [
          "input_audio_format": "pcm",
          "sample_rate": 16000,
          "input_audio_transcription": [
            "language": DashScopeSpeechRecognitionConfig.language(from: config.locale),
          ],
          "turn_detection": NSNull(),
        ],
      ]
    )
  }

  private func sendAudioChunk(_ data: Data) {
    sendClientEvent(
      type: "input_audio_buffer.append",
      fields: [
        "audio": data.base64EncodedString(),
      ]
    )
  }

  private func sendClientEvent(type: String, fields: [String: Any] = [:]) {
    var message: [String: Any] = [
      "event_id": DashScopeSpeechRecognitionConfig.makeProtocolID(),
      "type": type,
    ]
    fields.forEach { message[$0.key] = $0.value }
    do {
      let data = try JSONSerialization.data(withJSONObject: message, options: [])
      let text = String(data: data, encoding: .utf8) ?? "{}"
      webSocketTask?.send(.string(text)) { [weak self] error in
        if let error {
          self?.handlePipelineError(error)
        }
      }
    } catch {
      handlePipelineError(error)
    }
  }

  private func receiveWebSocketMessages(sessionID: UUID) {
    webSocketTask?.receive { [weak self] result in
      guard let self, self.isCurrentSession(sessionID) else {
        return
      }
      switch result {
      case let .success(message):
        self.handleWebSocketMessage(message)
        if self.isCurrentSession(sessionID) {
          self.receiveWebSocketMessages(sessionID: sessionID)
        }
      case let .failure(error):
        self.handlePipelineError(error)
      }
    }
  }

  private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) {
    let data: Data?
    switch message {
    case let .string(text):
      data = text.data(using: .utf8)
    case let .data(value):
      data = value
    @unknown default:
      data = nil
    }
    guard let data,
      let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return
    }
    let type = (root["type"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

    switch type {
    case "session.updated":
      canSendAudio = true
      emitEvent(type: "listening", transcript: nil, message: nil)
    case "conversation.item.input_audio_transcription.text":
      let text = root["text"] as? String ?? ""
      let stash = root["stash"] as? String ?? ""
      if let current = transcriptAccumulator.acceptPartial(text + stash) {
        emitEvent(type: "partial_result", transcript: current, message: nil)
      }
    case "conversation.item.input_audio_transcription.completed":
      guard let current = transcriptAccumulator.commit(root["transcript"] as? String ?? "") else {
        sendClientEvent(type: "session.finish")
        return
      }
      emitEvent(type: "partial_result", transcript: current, message: nil)
      sendClientEvent(type: "session.finish")
    case "session.finished":
      let finalTranscript = transcriptAccumulator.currentTranscript()
      let audioPath = recordingStore.finalize()
      emitEvent(
        type: "final_result",
        transcript: finalTranscript,
        message: nil,
        audioPath: audioPath
      )
      resetSessionState(emitCancelled: false)
    case "conversation.item.input_audio_transcription.failed", "error":
      let message = dashScopeErrorMessage(from: root)
      handleRecognitionError(message: message)
    default:
      return
    }
  }

  private func startKeepAlive() {
    keepAliveTimer?.invalidate()
    DispatchQueue.main.async { [weak self] in
      guard let self else {
        return
      }
      self.keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) {
        [weak self] _ in
        self?.webSocketTask?.sendPing { error in
          if let error {
            self?.handlePipelineError(error)
          }
        }
      }
    }
  }

  private func prepareSessionState(sessionID: UUID) {
    tearDownSessionResources()
    activeSessionID = sessionID
    isActive = true
    isStopping = false
    canSendAudio = false
    transcriptAccumulator.reset()
    recordingStore.reset()
  }

  private func resetSessionState(emitCancelled: Bool) {
    let shouldEmitCancelled = emitCancelled && isActive
    startupTask?.cancel()
    startupTask = nil
    activeSessionID = UUID()
    isActive = false
    isStopping = false
    canSendAudio = false
    transcriptAccumulator.reset()
    tearDownSessionResources()
    audioSessionController.restore()

    if shouldEmitCancelled {
      emitEvent(type: "cancelled", transcript: nil, message: nil)
    }
  }

  private func tearDownSessionResources() {
    keepAliveTimer?.invalidate()
    keepAliveTimer = nil
    stopAudioCapture()
    webSocketTask?.cancel(with: .normalClosure, reason: nil)
    webSocketTask = nil
    urlSession?.invalidateAndCancel()
    urlSession = nil
    recordingStore.reset()
  }

  private func stopAudioCapture() {
    if audioEngine.inputNode.numberOfInputs > 0 {
      audioEngine.inputNode.removeTap(onBus: 0)
    }
    if audioEngine.isRunning {
      audioEngine.stop()
    }
    audioEngine.reset()
  }

  private func installAudioTap(sessionID: UUID) throws {
    let inputNode = audioEngine.inputNode
    let inputFormat = try DashScopeAudioBufferConverter.inputFormat(from: inputNode)
    let targetFormat = try DashScopeAudioBufferConverter.recognitionFormat()
    let converter = try DashScopeAudioBufferConverter.makeConverter(
      from: inputFormat,
      to: targetFormat
    )

    try recordingStore.prepare(format: inputFormat, sessionID: sessionID)
    inputNode.removeTap(onBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
      guard let self, self.isCurrentSession(sessionID) else {
        return
      }
      self.recordingStore.write(buffer)
      guard self.canSendAudio,
        let data = DashScopeAudioBufferConverter.pcmData(
          from: buffer,
          using: converter,
          to: targetFormat
        )
      else {
        return
      }
      self.audioSendQueue.async { [weak self] in
        guard let self, self.isCurrentSession(sessionID), self.canSendAudio else {
          return
        }
        self.sendAudioChunk(data)
      }
    }
    audioEngine.prepare()
  }

  private func handlePipelineError(_ error: Error) {
    guard isActive else {
      return
    }
    if isStopping {
      let audioPath = recordingStore.finalize()
      emitEvent(
        type: "final_result",
        transcript: transcriptAccumulator.latestTranscript,
        message: nil,
        audioPath: audioPath
      )
    } else {
      emitEvent(type: "error", transcript: nil, message: error.localizedDescription)
    }
    resetSessionState(emitCancelled: false)
  }

  private func handleRecognitionError(message: String) {
    guard isActive else {
      return
    }
    if isStopping {
      let audioPath = recordingStore.finalize()
      emitEvent(
        type: "final_result",
        transcript: transcriptAccumulator.latestTranscript,
        message: nil,
        audioPath: audioPath
      )
    } else {
      emitEvent(type: "error", transcript: nil, message: message)
    }
    resetSessionState(emitCancelled: false)
  }

  private func dashScopeErrorMessage(from root: [String: Any]) -> String {
    if let error = root["error"] as? [String: Any],
      let message = error["message"] as? String,
      !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      return message
    }
    if let message = root["message"] as? String,
      !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      return message
    }
    return "Speech recognition request failed."
  }

  private func emitEvent(
    type: String,
    transcript: String?,
    message: String?,
    audioPath: String? = nil
  ) {
    guard let eventSink else {
      return
    }

    var payload: [String: Any] = ["type": type]
    if let transcript, !transcript.isEmpty {
      payload["transcript"] = transcript
    }
    if let message, !message.isEmpty {
      payload["message"] = message
    }
    if let audioPath, !audioPath.isEmpty {
      payload["audioPath"] = audioPath
    }

    DispatchQueue.main.async {
      eventSink(payload)
    }
  }

  private func complete(_ result: @escaping FlutterResult, value: Any?) {
    DispatchQueue.main.async {
      result(value)
    }
  }

  private func channelError(code: String, message: String) -> NSError {
    NSError(
      domain: "DashScopeSpeechRecognitionChannel",
      code: 0,
      userInfo: [
        NSLocalizedDescriptionKey: message,
        "code": code,
      ]
    )
  }

  private func flutterError(from error: Error) -> FlutterError {
    let nsError = error as NSError
    let code = nsError.userInfo["code"] as? String ?? "speech_error"
    return FlutterError(code: code, message: nsError.localizedDescription, details: nil)
  }
}
