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
    var speechRecognitionService: SpeechRecognitionService? = nil

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
        initSpeechRecognitionService()
        initRecorder()
    }

    private func initSpeechRecognitionService() {
        speechRecognitionService = SpeechRecognitionService(sampleRate: sampleRate)
    }

    private func initRecorder() {
        print("init recorder")
        audioEngine = AVAudioEngine()
        guard let inputNode = self.audioEngine?.inputNode else {
            print("Audio recorder is disabled: missing input node.")
            return
        }

        let bus = 0
        let inputFormat = inputNode.outputFormat(forBus: bus)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            print("Audio recorder is disabled: invalid input format \(inputFormat).")
            return
        }

        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(sampleRate),
            channels: 1,
            interleaved: false
        ) else {
            print("Audio recorder is disabled: failed to create output format.")
            return
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            print("Audio recorder is disabled: failed to create audio converter.")
            return
        }

        inputNode.installTap(
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
            self.speechRecognitionService?.resetVad()
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

        guard let speechRecognitionService = speechRecognitionService,
              speechRecognitionService.isRecognizerAvailable else {
            DispatchQueue.main.async {
                self.lastSentence = "SenseVoice recognizer is not available."
                self.subtitles = self.results
            }
            return
        }

        let text = speechRecognitionService.recognize(samples: samples)

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
