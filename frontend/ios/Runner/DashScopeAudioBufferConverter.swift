import AVFoundation
import Foundation

enum DashScopeAudioBufferConverter {
  static func inputFormat(from inputNode: AVAudioInputNode) throws -> AVAudioFormat {
    let inputFormat = inputNode.outputFormat(forBus: 0)
    guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
      throw error(
        code: "microphone_unavailable",
        message: "Microphone input is unavailable on this simulator."
      )
    }
    return inputFormat
  }

  static func recognitionFormat() throws -> AVAudioFormat {
    guard let format = AVAudioFormat(
      commonFormat: .pcmFormatInt16,
      sampleRate: 16000,
      channels: 1,
      interleaved: true
    ) else {
      throw error(code: "audio_format_error", message: "Unable to create ASR audio format.")
    }
    return format
  }

  static func makeConverter(
    from inputFormat: AVAudioFormat,
    to outputFormat: AVAudioFormat
  ) throws -> AVAudioConverter {
    guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
      throw error(code: "audio_format_error", message: "Unable to convert microphone audio.")
    }
    return converter
  }

  static func pcmData(
    from inputBuffer: AVAudioPCMBuffer,
    using converter: AVAudioConverter,
    to outputFormat: AVAudioFormat
  ) -> Data? {
    guard let convertedBuffer = convert(inputBuffer, using: converter, to: outputFormat),
      let channelData = convertedBuffer.int16ChannelData
    else {
      return nil
    }

    let byteCount = Int(convertedBuffer.frameLength)
      * Int(convertedBuffer.format.channelCount)
      * MemoryLayout<Int16>.size
    guard byteCount > 0 else {
      return nil
    }
    return Data(bytes: channelData[0], count: byteCount)
  }

  private static func convert(
    _ inputBuffer: AVAudioPCMBuffer,
    using converter: AVAudioConverter,
    to outputFormat: AVAudioFormat
  ) -> AVAudioPCMBuffer? {
    let sampleRateRatio = outputFormat.sampleRate / inputBuffer.format.sampleRate
    let estimatedFrameCapacity = AVAudioFrameCount(
      max(1, ceil(Double(inputBuffer.frameLength) * sampleRateRatio))
    )
    guard let outputBuffer = AVAudioPCMBuffer(
      pcmFormat: outputFormat,
      frameCapacity: estimatedFrameCapacity
    ) else {
      return nil
    }

    var error: NSError?
    var didProvideInput = false
    let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
      if didProvideInput {
        outStatus.pointee = .noDataNow
        return nil
      }
      didProvideInput = true
      outStatus.pointee = .haveData
      return inputBuffer
    }
    if error != nil {
      return nil
    }
    switch status {
    case .haveData, .inputRanDry, .endOfStream:
      return outputBuffer.frameLength > 0 ? outputBuffer : nil
    case .error:
      return nil
    @unknown default:
      return nil
    }
  }

  private static func error(code: String, message: String) -> NSError {
    NSError(
      domain: "DashScopeAudioBufferConverter",
      code: 0,
      userInfo: [
        NSLocalizedDescriptionKey: message,
        "code": code,
      ]
    )
  }
}
