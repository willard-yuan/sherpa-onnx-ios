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

        let text = offlineRecognizer
            .decode(samples: samples, sampleRate: sampleRate)
            .text
            .trimmingCharacters(in: .whitespacesAndNewlines)

        DispatchQueue.main.async {
            self.lastSentence = ""
            if !text.isEmpty {
                self.sentences.append(text)
                print(text)
            }
            self.subtitles = self.results
        }
    }
}
