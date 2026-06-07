import Foundation

final class SpeechRecognitionService {
    let sampleRate: Int

    private let offlineRecognizer: SherpaOnnxOfflineRecognizer?
    private let vad: SherpaOnnxVoiceActivityDetectorWrapper?

    var isRecognizerAvailable: Bool {
        offlineRecognizer != nil
    }

    var isVadAvailable: Bool {
        vad != nil
    }

    init(sampleRate: Int = 16000) {
        self.sampleRate = sampleRate
        self.offlineRecognizer = Self.makeOfflineRecognizer(sampleRate: sampleRate)
        self.vad = Self.makeVad(sampleRate: sampleRate)
    }

    func resetVad() {
        vad?.reset()
    }

    func recognize(samples: [Float]) -> String {
        recognizeSegments(samples: samples).joined(separator: " | ")
    }

    func recognizeSegments(samples: [Float]) -> [String] {
        guard let offlineRecognizer = offlineRecognizer, !samples.isEmpty else {
            return []
        }

        let speechSegments = splitSpeechSegments(samples)
        return speechSegments.compactMap { segment in
            let text = offlineRecognizer
                .decode(samples: segment, sampleRate: sampleRate)
                .text
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return text.isEmpty ? nil : text
        }
    }

    private static func makeOfflineRecognizer(sampleRate: Int) -> SherpaOnnxOfflineRecognizer? {
        guard hasNonStreamingSenseVoiceFunASRNanoInt820251217() else {
            print("SenseVoice recognizer is disabled: missing model.int8.onnx or tokens.txt.")
            return nil
        }

        let modelConfig = getNonStreamingSenseVoiceFunASRNanoInt820251217()
        let featConfig = sherpaOnnxFeatureConfig(
            sampleRate: sampleRate,
            featureDim: 80
        )

        var config = sherpaOnnxOfflineRecognizerConfig(
            featConfig: featConfig,
            modelConfig: modelConfig,
            decodingMethod: "greedy_search",
            maxActivePaths: 4
        )

        return SherpaOnnxOfflineRecognizer(config: &config)
    }

    private static func makeVad(sampleRate: Int) -> SherpaOnnxVoiceActivityDetectorWrapper? {
        guard hasSileroVadModel() else {
            print("VAD is disabled: missing silero_vad.onnx.")
            return nil
        }

        var config = getSileroVadModelConfig(sampleRate: sampleRate)
        return SherpaOnnxVoiceActivityDetectorWrapper(
            config: &config,
            buffer_size_in_seconds: 30
        )
    }

    private func splitSpeechSegments(_ samples: [Float]) -> [[Float]] {
        guard let vad = vad else {
            return [samples]
        }

        vad.reset()

        let windowSize = BundledVADModel.sileroWindowSize
        for offset in stride(from: 0, to: samples.count, by: windowSize) {
            let end = min(offset + windowSize, samples.count)
            vad.acceptWaveform(samples: Array(samples[offset..<end]))
        }

        vad.flush()

        var segments: [[Float]] = []
        while !vad.isEmpty() {
            let segment = vad.front()
            if segment.n > 0 {
                let padding = sampleRate
                let start = max(segment.start - padding, 0)
                let end = min(segment.start + segment.n + padding, samples.count)
                segments.append(Array(samples[start..<end]))
            }
            vad.pop()
        }
        vad.clear()

        return segments.isEmpty ? [samples] : segments
    }
}
