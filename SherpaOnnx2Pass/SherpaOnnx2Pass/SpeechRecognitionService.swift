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
        let texts = decodeSegments(speechSegments, using: offlineRecognizer)
        if !texts.isEmpty {
            return texts
        }

        guard let fallbackSegment = energyTrimmedSegment(samples) else {
            return []
        }

        return decodeSegments([fallbackSegment], using: offlineRecognizer)
    }

    private func decodeSegments(
        _ segments: [[Float]],
        using offlineRecognizer: SherpaOnnxOfflineRecognizer
    ) -> [String] {
        segments.compactMap { segment in
            let text = offlineRecognizer
                .decode(samples: segment, sampleRate: sampleRate)
                .text
            let normalizedText = normalizeRecognitionText(text)

            return normalizedText.isEmpty ? nil : normalizedText
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

        var ranges: [(start: Int, end: Int)] = []
        while !vad.isEmpty() {
            let segment = vad.front()
            if segment.n > 0 {
                ranges.append((segment.start, segment.start + segment.n))
            }
            vad.pop()
        }
        vad.clear()

        let padding = sampleRate
        let mergedRanges = mergeSpeechRanges(ranges, maxGap: sampleRate)
        return mergedRanges.compactMap { range in
            let start = max(range.start - padding, 0)
            let end = min(range.end + padding, samples.count)
            return end > start ? Array(samples[start..<end]) : nil
        }
    }

    private func mergeSpeechRanges(
        _ ranges: [(start: Int, end: Int)],
        maxGap: Int
    ) -> [(start: Int, end: Int)] {
        guard var current = ranges.first else {
            return []
        }

        var merged: [(start: Int, end: Int)] = []
        for range in ranges.dropFirst() {
            if range.start - current.end <= maxGap {
                current.end = max(current.end, range.end)
            } else {
                merged.append(current)
                current = range
            }
        }
        merged.append(current)

        return merged
    }

    private func energyTrimmedSegment(_ samples: [Float]) -> [Float]? {
        let frameSize = BundledVADModel.sileroWindowSize
        var frameEnergies: [(offset: Int, energy: Float)] = []
        frameEnergies.reserveCapacity(samples.count / frameSize + 1)

        for offset in stride(from: 0, to: samples.count, by: frameSize) {
            let end = min(offset + frameSize, samples.count)
            var sum: Float = 0
            for sample in samples[offset..<end] {
                sum += sample * sample
            }
            let energy = sqrt(sum / Float(max(end - offset, 1)))
            frameEnergies.append((offset, energy))
        }

        guard let peakEnergy = frameEnergies.map(\.energy).max(), peakEnergy >= 0.003 else {
            return nil
        }

        let threshold = max(peakEnergy * 0.08, 0.002)
        guard let first = frameEnergies.first(where: { $0.energy >= threshold }),
              let last = frameEnergies.last(where: { $0.energy >= threshold }) else {
            return nil
        }

        let padding = sampleRate
        let start = max(first.offset - padding, 0)
        let end = min(last.offset + frameSize + padding, samples.count)

        guard end > start else {
            return nil
        }

        return Array(samples[start..<end])
    }

    private func normalizeRecognitionText(_ text: String) -> String {
        text
            .replacingOccurrences(
                of: #"<\|[^>]+\|>"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
