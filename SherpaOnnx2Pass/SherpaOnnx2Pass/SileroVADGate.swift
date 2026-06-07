import Foundation

enum VADGateEvent {
    case silence
    case speechStarted([Float])
    case speech([Float])
    case speechTail([Float])
    case speechEnded
}

final class SileroVADGate {
    private let sampleRate: Int
    private let windowSize: Int
    private let preRollSampleCount: Int
    private let speechEndSilenceSampleCount: Int
    private let vad: SherpaOnnxVoiceActivityDetectorWrapper?

    private var pendingSamples: [Float] = []
    private var preRollSamples: [Float] = []
    private var tailSilenceSampleCount = 0
    private var isSpeaking = false

    var isAvailable: Bool {
        vad != nil
    }

    init(sampleRate: Int = 16000) {
        self.sampleRate = sampleRate
        self.windowSize = BundledVADModel.sileroWindowSize
        self.preRollSampleCount = sampleRate / 2
        self.speechEndSilenceSampleCount = Int(Float(sampleRate) * 0.6)

        guard hasSileroVadModel() else {
            print("VAD is disabled: missing silero_vad.onnx.")
            self.vad = nil
            return
        }

        var config = getSileroVadModelConfig(sampleRate: sampleRate)
        self.vad = SherpaOnnxVoiceActivityDetectorWrapper(
            config: &config,
            buffer_size_in_seconds: 30
        )
    }

    func reset() {
        pendingSamples = []
        preRollSamples = []
        tailSilenceSampleCount = 0
        isSpeaking = false
        vad?.reset()
        vad?.clear()
    }

    func accept(samples: [Float]) -> [VADGateEvent] {
        guard !samples.isEmpty else {
            return []
        }

        guard let vad else {
            if isSpeaking {
                return [.speech(samples)]
            } else {
                isSpeaking = true
                return [.speechStarted(samples)]
            }
        }

        pendingSamples.append(contentsOf: samples)
        var events: [VADGateEvent] = []

        while pendingSamples.count >= windowSize {
            let frame = Array(pendingSamples[..<windowSize])
            pendingSamples.removeFirst(windowSize)

            vad.acceptWaveform(samples: frame)
            let speechDetected = vad.isSpeechDetected()

            if speechDetected {
                tailSilenceSampleCount = 0
                if isSpeaking {
                    events.append(.speech(frame))
                } else {
                    isSpeaking = true
                    events.append(.speechStarted(preRollSamples + frame))
                    preRollSamples = []
                }
            } else if isSpeaking {
                tailSilenceSampleCount += frame.count
                events.append(.speechTail(frame))

                if tailSilenceSampleCount >= speechEndSilenceSampleCount {
                    isSpeaking = false
                    tailSilenceSampleCount = 0
                    events.append(.speechEnded)
                }
            } else {
                appendPreRoll(frame)
                events.append(.silence)
            }
        }

        return events
    }

    private func appendPreRoll(_ samples: [Float]) {
        preRollSamples.append(contentsOf: samples)
        if preRollSamples.count > preRollSampleCount {
            preRollSamples.removeFirst(preRollSamples.count - preRollSampleCount)
        }
    }
}
