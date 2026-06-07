import XCTest
@testable import SherpaOnnx2Pass

final class SherpaOnnx2PassTests: XCTestCase {
    func testTranscriptTextNormalizerKeepsCaseAndCleansSpacing() {
        XCTAssertEqual(
            TranscriptTextNormalizer.normalize("昨 天 是 Monday ， today is 礼 拜 二"),
            "昨天是 Monday， today is 礼拜二"
        )
        XCTAssertEqual(
            TranscriptTextNormalizer.normalize("。 这 是 第 一 种 ， What's your name ?"),
            "这是第一种， What's your name?"
        )
    }

    func testStreamingModelResourcesAreBundled() {
        XCTAssertTrue(hasStreamingXASR480msZhEnPunctInt820260605())
        XCTAssertTrue(hasSileroVadModel())
    }

    func testStreamingRecognizerEmitsTextForFixture() throws {
        let service = makeService()
        let audio = try readStreamingFixture("0")

        let text = recognize(audio.samples, using: service)
        print("streaming 0.wav => \(text)")

        XCTAssertFalse(text.isEmpty)
        XCTAssertContainsRecognitionCharacters(text)
    }

    func testVadEndpointPipelineFinalizesMultipleFixtures() throws {
        let service = makeService()
        let first = try readStreamingFixture("0")
        let second = try readStreamingFixture("1")
        let silence = [Float](repeating: 0, count: service.sampleRate)

        var finalized: [String] = []
        let samples = first.samples + silence + second.samples
        for chunk in samples.chunked(into: 1024) {
            let updates = service.accept(samples: chunk)
            finalized.append(
                contentsOf: updates.compactMap { $0.finalizedText }.filter { !$0.isEmpty }
            )
        }

        if let lastUpdate = service.finishCurrentUtterance(),
           let finalizedText = lastUpdate.finalizedText,
           !finalizedText.isEmpty {
            finalized.append(finalizedText)
        }

        let text = finalized.joined(separator: "\n")
        print("streaming combined segments => \(finalized)")
        print("combined text => \(text)")

        XCTAssertGreaterThanOrEqual(finalized.count, 2)
        XCTAssertFalse(text.contains(" | "))
        finalized.forEach { XCTAssertContainsRecognitionCharacters($0) }
    }

    private func makeService() -> StreamingRecognitionService {
        XCTAssertTrue(hasStreamingXASR480msZhEnPunctInt820260605())
        XCTAssertTrue(hasSileroVadModel())

        let service = StreamingRecognitionService()
        XCTAssertTrue(service.isRecognizerAvailable)
        XCTAssertTrue(service.isVadAvailable)
        return service
    }

    private func recognize(
        _ samples: [Float],
        using service: StreamingRecognitionService
    ) -> String {
        var lastPartial = ""
        var finalized: [String] = []

        for chunk in samples.chunked(into: 1024) {
            for update in service.accept(samples: chunk) {
                if let finalizedText = update.finalizedText,
                   !finalizedText.isEmpty {
                    finalized.append(finalizedText)
                }
                if !update.partialText.isEmpty {
                    lastPartial = update.partialText
                }
            }
        }

        if let update = service.finishCurrentUtterance() {
            if let finalizedText = update.finalizedText,
               !finalizedText.isEmpty {
                finalized.append(finalizedText)
            }
            if !update.partialText.isEmpty {
                lastPartial = update.partialText
            }
        }

        return finalized.last ?? lastPartial
    }

    private func readStreamingFixture(_ name: String) throws -> SherpaOnnxWaveWrapper {
        let directory = "\(BundledStreamingASRModel.xASR480msZhEnPunctInt820260605)/test_wavs"
        let path = try XCTUnwrap(
            Bundle.main.path(forResource: name, ofType: "wav", inDirectory: directory)
                ?? Bundle.main.path(forResource: name, ofType: "wav")
                ?? sourceFixturePath(name),
            "\(name).wav should exist in the test bundle or source fixture directory"
        )
        let audio = SherpaOnnxWaveWrapper.readWave(filename: path)

        XCTAssertEqual(audio.sampleRate, 16000)
        XCTAssertGreaterThan(audio.numSamples, 0)
        return audio
    }

    private func sourceFixturePath(_ name: String) -> String? {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(BundledStreamingASRModel.xASR480msZhEnPunctInt820260605)
            .appendingPathComponent("test_wavs")
            .appendingPathComponent("\(name).wav")

        return FileManager.default.fileExists(atPath: url.path) ? url.path : nil
    }

    private func XCTAssertContainsRecognitionCharacters(
        _ text: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertNotNil(
            text.range(of: #"[\p{Han}A-Za-z0-9]"#, options: .regularExpression),
            "Expected '\(text)' to contain recognized characters",
            file: file,
            line: line
        )
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { start in
            Array(self[start..<Swift.min(start + size, count)])
        }
    }
}
