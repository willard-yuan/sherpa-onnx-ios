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
    @Published var livePartial: String = ""
    @Published var isSpeaking: Bool = false

    var sentences: [String] = []

    var audioEngine: AVAudioEngine? = nil
    var streamingRecognitionService: StreamingRecognitionService? = nil

    let maxSentence: Int = 10
    private let sampleRate = 16000
    private let audioQueue = DispatchQueue(label: "SherpaOnnx2Pass.audio")

    var results: String {
        if sentences.isEmpty && livePartial.isEmpty {
            return ""
        }

        let start = max(sentences.count - maxSentence, 0)
        let finalized = sentences.enumerated()
            .map { (index, s) in "\(index): \(s)" }[start...]
            .joined(separator: "\n")

        guard !livePartial.isEmpty else {
            return finalized
        }

        let partial = "\(sentences.count): \(livePartial)"
        return finalized.isEmpty ? partial : finalized + "\n" + partial
    }

    func updateLabel() {
        DispatchQueue.main.async {
            self.subtitles = self.results
        }
    }

    init() {
        initStreamingRecognitionService()
        initRecorder()
    }

    private func initStreamingRecognitionService() {
        streamingRecognitionService = StreamingRecognitionService(sampleRate: sampleRate)
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
                    self.processAudioSamples(array)
                }
            }
        }
    }

    public func toggleRecorder() {
        if status == .stop {
            startRecorder()
        } else {
            stopRecorder()
        }
    }

    private func startRecorder() {
        sentences = []
        livePartial = ""
        isSpeaking = false
        audioQueue.sync {
            self.streamingRecognitionService?.reset()
        }
        DispatchQueue.main.async {
            self.subtitles = "Listening..."
        }

        do {
            try self.audioEngine?.start()
            status = .recording
        } catch let error as NSError {
            print("Got an error starting audioEngine: \(error.domain), \(error)")
            subtitles = "Failed to start microphone."
        }
        print("started")
    }

    private func stopRecorder() {
        audioEngine?.stop()
        status = .stop
        audioQueue.async {
            guard let update = self.streamingRecognitionService?.finishCurrentUtterance() else {
                DispatchQueue.main.async {
                    self.livePartial = ""
                    self.isSpeaking = false
                    self.subtitles = self.results
                }
                return
            }

            self.applyStreamingUpdate(update)
        }
        print("stopped")
    }

    private func processAudioSamples(_ samples: [Float]) {
        guard let streamingRecognitionService = streamingRecognitionService,
              streamingRecognitionService.isRecognizerAvailable else {
            applyUnavailableRecognizerMessage()
            return
        }

        let updates = streamingRecognitionService.accept(samples: samples)
        updates.forEach { update in
            applyStreamingUpdate(update)
        }
    }

    private func applyStreamingUpdate(_ update: StreamingRecognitionUpdate) {
        DispatchQueue.main.async {
            self.isSpeaking = update.isSpeaking

            if let finalizedText = update.finalizedText,
               !finalizedText.isEmpty {
                self.sentences.append(finalizedText)
                self.livePartial = ""
                print(finalizedText)
            } else {
                self.livePartial = update.partialText
            }

            self.subtitles = self.results
        }
    }

    private func applyUnavailableRecognizerMessage() {
        DispatchQueue.main.async {
            self.livePartial = "Streaming Zipformer recognizer is not available."
            self.subtitles = self.results
        }
    }
}
