//
//  SherpaOnnxViewModel.swift
//  SherpaOnnx
//
//  Created by knight on 2023/4/5.
//

import Foundation
import AVFoundation

enum Status {
    case stop
    case recording
}

class SherpaOnnxViewModel: ObservableObject {
    @Published var status: Status = .stop
    @Published var subtitles: String = ""

    var sentences: [String] = []
    var recordedSamples: [Float] = []

    var audioEngine: AVAudioEngine? = nil
    var offlineRecognizer: SherpaOnnxOfflineRecognizer? = nil
    var vad: SherpaOnnxVoiceActivityDetectorWrapper? = nil

    var lastSentence: String = ""
    let maxSentence: Int = 10
    private let sampleRate = 16000
    private let audioQueue = DispatchQueue(label: "SherpaOnnx2Pass.audio")

    var results: String {
        if sentences.isEmpty && lastSentence.isEmpty {
            return ""
        }
        if sentences.isEmpty {
            return "0: \(lastSentence.lowercased())"
        }

        let start = max(sentences.count - maxSentence, 0)
        if lastSentence.isEmpty {
            return sentences.enumerated().map { (index, s) in "\(index): \(s.lowercased())" }[start...]
                .joined(separator: "\n")
        } else {
            return sentences.enumerated().map { (index, s) in "\(index): \(s.lowercased())" }[start...]
                .joined(separator: "\n") + "\n\(sentences.count): \(lastSentence.lowercased())"
        }
    }

    func updateLabel() {
        DispatchQueue.main.async {
            self.subtitles = self.results
        }
    }

    init() {
        initOfflineRecognizer()
        initVad()
        initRecorder()
    }

    private func initOfflineRecognizer() {
        guard hasNonStreamingSenseVoiceFunASRNanoInt820251217() else {
            print("SenseVoice recognizer is disabled: missing model.int8.onnx or tokens.txt.")
            return
        }

        let modelConfig = getNonStreamingSenseVoiceFunASRNanoInt820251217()

        let featConfig = sherpaOnnxFeatureConfig(
            sampleRate: sampleRate,
            featureDim: 80)

        var config = sherpaOnnxOfflineRecognizerConfig(
            featConfig: featConfig,
            modelConfig: modelConfig,
            decodingMethod: "greedy_search",
            maxActivePaths: 4
        )
        offlineRecognizer = SherpaOnnxOfflineRecognizer(config: &config)
    }

    private func initVad() {
        guard hasSileroVadModel() else {
            print("VAD is disabled: missing silero_vad.onnx.")
            return
        }

        var config = getSileroVadModelConfig()
        vad = SherpaOnnxVoiceActivityDetectorWrapper(
            config: &config,
            buffer_size_in_seconds: 30
        )
    }

    private func initRecorder() {
        print("init recorder")
        audioEngine = AVAudioEngine()
        let inputNode = self.audioEngine?.inputNode
        let bus = 0
        let inputFormat = inputNode?.outputFormat(forBus: bus)
        let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000, channels: 1,
            interleaved: false)!

        let converter = AVAudioConverter(from: inputFormat!, to: outputFormat)!

        inputNode!.installTap(
            onBus: bus,
            bufferSize: 1024,
            format: inputFormat
        ) {
            (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            var newBufferAvailable = true

            let inputCallback: AVAudioConverterInputBlock = {
                inNumPackets, outStatus in
                if newBufferAvailable {
                    outStatus.pointee = .haveData
                    newBufferAvailable = false

                    return buffer
                } else {
                    outStatus.pointee = .noDataNow
                    return nil
                }
            }

            let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: outputFormat,
                frameCapacity:
                    AVAudioFrameCount(outputFormat.sampleRate)
                * buffer.frameLength
                / AVAudioFrameCount(buffer.format.sampleRate))!

            var error: NSError?
            let _ = converter.convert(
                to: convertedBuffer,
                error: &error, withInputFrom: inputCallback)

            // TODO(fangjun): Handle status != haveData

            let array = convertedBuffer.array()
            if !array.isEmpty {
                self.audioQueue.async {
                    self.recordedSamples.append(contentsOf: array)
                }
            }
        }
    }

    public func toggleRecorder() {
        if status == .stop {
            startRecorder()
            status = .recording
        } else {
            stopRecorder()
            status = .stop
        }
    }

    private func startRecorder() {
        lastSentence = ""
        sentences = []
        audioQueue.sync {
            self.recordedSamples = []
            self.vad?.reset()
        }
        DispatchQueue.main.async {
            self.subtitles = "Recording..."
        }

        do {
            try self.audioEngine?.start()
        } catch let error as NSError {
            print("Got an error starting audioEngine: \(error.domain), \(error)")
        }
        print("started")
    }

    private func stopRecorder() {
        audioEngine?.stop()
        audioQueue.async {
            let samples = self.recordedSamples
            self.recordedSamples = []
            self.decodeRecordedAudio(samples)
        }
        print("stopped")
    }

    private func decodeRecordedAudio(_ samples: [Float]) {
        guard !samples.isEmpty else {
            DispatchQueue.main.async {
                self.lastSentence = ""
                self.subtitles = self.results
            }
            return
        }

        guard let offlineRecognizer = offlineRecognizer else {
            DispatchQueue.main.async {
                self.lastSentence = "SenseVoice recognizer is not available."
                self.subtitles = self.results
            }
            return
        }

        let segmentTexts = decodeSpeechSegments(samples, using: offlineRecognizer)
        let text = segmentTexts.joined(separator: " | ")

        DispatchQueue.main.async {
            self.lastSentence = ""
            if !text.isEmpty {
                self.sentences.append(text)
                print(text)
            }
            self.subtitles = self.results
        }
    }

    private func decodeSpeechSegments(
        _ samples: [Float],
        using offlineRecognizer: SherpaOnnxOfflineRecognizer
    ) -> [String] {
        guard let vad = vad else {
            let text = recognize(samples, using: offlineRecognizer)
            return text.isEmpty ? [] : [text]
        }

        vad.reset()
        vad.acceptWaveform(samples: samples)
        vad.flush()

        var texts: [String] = []
        while !vad.isEmpty() {
            let segment = vad.front()
            let text = recognize(segment.samples, using: offlineRecognizer)
            if !text.isEmpty {
                texts.append(text)
            }
            vad.pop()
        }
        vad.clear()

        return texts
    }

    private func recognize(
        _ samples: [Float],
        using offlineRecognizer: SherpaOnnxOfflineRecognizer
    ) -> String {
        offlineRecognizer
            .decode(samples: samples, sampleRate: sampleRate)
            .text
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
