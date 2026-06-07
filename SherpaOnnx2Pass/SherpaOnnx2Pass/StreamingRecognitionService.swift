import Foundation

struct StreamingRecognitionUpdate {
    let partialText: String
    let finalizedText: String?
    let isSpeaking: Bool
}

final class StreamingRecognitionService {
    let sampleRate: Int

    private let recognizer: SherpaOnnxRecognizer?
    private let vadGate: SileroVADGate
    private var partialText = ""
    private var isSpeaking = false

    var isRecognizerAvailable: Bool {
        recognizer != nil
    }

    var isVadAvailable: Bool {
        vadGate.isAvailable
    }

    init(sampleRate: Int = 16000) {
        self.sampleRate = sampleRate
        self.recognizer = Self.makeRecognizer(sampleRate: sampleRate)
        self.vadGate = SileroVADGate(sampleRate: sampleRate)
    }

    func reset() {
        recognizer?.reset()
        vadGate.reset()
        partialText = ""
        isSpeaking = false
    }

    func accept(samples: [Float]) -> [StreamingRecognitionUpdate] {
        guard let recognizer, !samples.isEmpty else {
            return []
        }

        return vadGate.accept(samples: samples).compactMap { event in
            switch event {
            case .silence:
                isSpeaking = false
                return nil

            case .speechStarted(let speech):
                isSpeaking = true
                return acceptSpeech(speech, using: recognizer)

            case .speech(let speech):
                isSpeaking = true
                return acceptSpeech(speech, using: recognizer)

            case .speechTail(let silence):
                return acceptSpeech(silence, using: recognizer)

            case .speechEnded:
                return finishCurrentUtterance(using: recognizer)
            }
        }
    }

    func finishCurrentUtterance() -> StreamingRecognitionUpdate? {
        guard let recognizer else {
            return nil
        }

        return finishCurrentUtterance(using: recognizer)
    }

    private static func makeRecognizer(sampleRate: Int) -> SherpaOnnxRecognizer? {
        guard hasStreamingXASR480msZhEnPunctInt820260605() else {
            print("Streaming recognizer is disabled: missing X-ASR model files.")
            return nil
        }

        let modelConfig = getStreamingXASR480msZhEnPunctInt820260605()
        let featConfig = sherpaOnnxFeatureConfig(
            sampleRate: sampleRate,
            featureDim: 80
        )

        var config = sherpaOnnxOnlineRecognizerConfig(
            featConfig: featConfig,
            modelConfig: modelConfig,
            enableEndpoint: true,
            rule1MinTrailingSilence: 1.2,
            rule2MinTrailingSilence: 0.8,
            rule3MinUtteranceLength: 20,
            decodingMethod: "greedy_search",
            maxActivePaths: 4
        )

        return SherpaOnnxRecognizer(config: &config)
    }

    private func acceptSpeech(
        _ samples: [Float],
        using recognizer: SherpaOnnxRecognizer
    ) -> StreamingRecognitionUpdate? {
        guard !samples.isEmpty else {
            return nil
        }

        recognizer.acceptWaveform(samples: samples, sampleRate: sampleRate)
        decodeReadyFrames(using: recognizer)

        let text = normalizeRecognitionText(recognizer.getResult().text)
        partialText = text

        if recognizer.isEndpoint() {
            return finalize(using: recognizer)
        }

        return StreamingRecognitionUpdate(
            partialText: partialText,
            finalizedText: nil,
            isSpeaking: isSpeaking
        )
    }

    private func finishCurrentUtterance(
        using recognizer: SherpaOnnxRecognizer
    ) -> StreamingRecognitionUpdate? {
        feedEndpointPadding(using: recognizer)
        decodeReadyFrames(using: recognizer)

        if recognizer.isEndpoint() || !partialText.isEmpty {
            return finalize(using: recognizer)
        }

        recognizer.reset()
        partialText = ""
        isSpeaking = false
        return nil
    }

    private func finalize(
        using recognizer: SherpaOnnxRecognizer
    ) -> StreamingRecognitionUpdate {
        let finalText = normalizeRecognitionText(recognizer.getResult().text)
        recognizer.reset()
        partialText = ""
        isSpeaking = false

        return StreamingRecognitionUpdate(
            partialText: "",
            finalizedText: finalText.isEmpty ? nil : finalText,
            isSpeaking: false
        )
    }

    private func feedEndpointPadding(using recognizer: SherpaOnnxRecognizer) {
        let silence = [Float](repeating: 0, count: Int(Float(sampleRate) * 0.8))
        recognizer.acceptWaveform(samples: silence, sampleRate: sampleRate)
    }

    private func decodeReadyFrames(using recognizer: SherpaOnnxRecognizer) {
        while recognizer.isReady() {
            recognizer.decode()
        }
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
