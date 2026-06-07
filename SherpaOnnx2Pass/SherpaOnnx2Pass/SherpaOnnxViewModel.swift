//
//  SherpaOnnxViewModel.swift
//  SherpaOnnx
//
//  Created by knight on 2023/4/5.
//

import Foundation
import AVFoundation

class SherpaOnnxViewModel: ObservableObject {
    @Published var uiState: RecognitionUIState = .idle
    @Published var finalTranscript: [TranscriptSegment] = []
    @Published var livePartial: String = ""
    @Published var highlightedSegmentID: UUID?

    var audioEngine: AVAudioEngine? = nil
    var streamingRecognitionService: StreamingRecognitionService? = nil

    let maxSentence: Int = 10
    private let sampleRate = 16000
    private let audioQueue = DispatchQueue(label: "SherpaOnnx2Pass.audio")
    private let finalizedHighlightDuration: TimeInterval = 0.6
    private var isRecording = false

    var visibleFinalTranscript: [TranscriptSegment] {
        Array(finalTranscript.suffix(maxSentence))
    }

    var isActive: Bool {
        uiState != .idle
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
        if uiState == .idle {
            startRecorder()
        } else {
            stopRecorder()
        }
    }

    private func startRecorder() {
        guard streamingRecognitionService?.isRecognizerAvailable == true else {
            finalTranscript = []
            livePartial = "Streaming Zipformer recognizer is not available."
            highlightedSegmentID = nil
            uiState = .idle
            return
        }

        finalTranscript = []
        livePartial = ""
        highlightedSegmentID = nil
        uiState = .listening
        audioQueue.sync {
            self.streamingRecognitionService?.reset()
        }

        do {
            try self.audioEngine?.start()
            isRecording = true
        } catch let error as NSError {
            print("Got an error starting audioEngine: \(error.domain), \(error)")
            isRecording = false
            uiState = .idle
            livePartial = "Failed to start microphone."
        }
        print("started")
    }

    private func stopRecorder() {
        audioEngine?.stop()
        isRecording = false
        audioQueue.async {
            guard let update = self.streamingRecognitionService?.finishCurrentUtterance() else {
                DispatchQueue.main.async {
                    self.livePartial = ""
                    self.highlightedSegmentID = nil
                    self.uiState = .idle
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
            if let finalizedText = update.finalizedText,
               !finalizedText.isEmpty {
                self.appendFinalizedText(finalizedText)
            } else {
                self.updateLivePartial(update.partialText, isSpeaking: update.isSpeaking)
            }
        }
    }

    private func appendFinalizedText(_ text: String) {
        let normalizedText = TranscriptTextNormalizer.normalize(text)
        guard !normalizedText.isEmpty else {
            livePartial = ""
            uiState = isRecording ? .listening : .idle
            return
        }

        let segment = TranscriptSegment(text: normalizedText)
        finalTranscript.append(segment)
        livePartial = ""
        highlightedSegmentID = segment.id
        uiState = .finalized
        print(normalizedText)
        scheduleFinalizedStateExit(for: segment.id)
    }

    private func updateLivePartial(_ text: String, isSpeaking: Bool) {
        let normalizedText = TranscriptTextNormalizer.normalize(text)
        livePartial = normalizedText

        if isSpeaking {
            uiState = .speaking
        } else if isRecording {
            uiState = .listening
        } else {
            uiState = .idle
        }
    }

    private func scheduleFinalizedStateExit(for segmentID: UUID) {
        DispatchQueue.main.asyncAfter(deadline: .now() + finalizedHighlightDuration) { [weak self] in
            guard let self else {
                return
            }

            if self.highlightedSegmentID == segmentID {
                self.highlightedSegmentID = nil
            }

            if self.uiState == .finalized {
                self.uiState = self.isRecording ? .listening : .idle
                self.livePartial = ""
            }
        }
    }

    private func applyUnavailableRecognizerMessage() {
        DispatchQueue.main.async {
            self.livePartial = "Streaming Zipformer recognizer is not available."
            self.uiState = self.isRecording ? .listening : .idle
        }
    }
}
