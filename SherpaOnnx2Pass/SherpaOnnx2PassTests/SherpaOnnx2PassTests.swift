import XCTest
@testable import SherpaOnnx2Pass

final class SherpaOnnx2PassTests: XCTestCase {
    func testRecognizesChineseFixture() throws {
        let service = makeService()
        let audio = try readFixture("zh")

        let text = service.recognize(samples: audio.samples)
        print("zh.wav => \(text)")

        XCTAssertFalse(text.isEmpty)
        XCTAssertChineseFixtureText(text)
    }

    func testRecognizesEnglishFixture() throws {
        let service = makeService()
        let audio = try readFixture("en")

        let text = service.recognize(samples: audio.samples)
        print("en.wav => \(text)")

        XCTAssertFalse(text.isEmpty)
        XCTAssertEnglishFixtureText(text)
    }

    func testVadSplitsCombinedFixturesAndUsesPipeDelimiter() throws {
        let service = makeService()
        let zh = try readFixture("zh")
        let en = try readFixture("en")
        let silence = [Float](repeating: 0, count: service.sampleRate)
        let samples = zh.samples + silence + en.samples

        let segments = service.recognizeSegments(samples: samples)
        let text = segments.joined(separator: " | ")
        print("combined segments => \(segments)")
        print("combined text => \(text)")

        XCTAssertEqual(segments.count, 2)
        XCTAssertTrue(text.contains(" | "))
        XCTAssertChineseFixtureText(segments[0])
        XCTAssertEnglishFixtureText(segments[1])
    }

    private func makeService() -> SpeechRecognitionService {
        XCTAssertTrue(hasNonStreamingSenseVoiceFunASRNanoInt820251217())
        XCTAssertTrue(hasSileroVadModel())

        let service = SpeechRecognitionService()
        XCTAssertTrue(service.isRecognizerAvailable)
        XCTAssertTrue(service.isVadAvailable)
        return service
    }

    private func readFixture(_ name: String) throws -> SherpaOnnxWaveWrapper {
        let directory = "\(BundledASRModel.senseVoiceFunASRNanoInt820251217)/test_wavs"
        let path = try XCTUnwrap(
            Bundle.main.path(forResource: name, ofType: "wav", inDirectory: directory)
                ?? Bundle.main.path(forResource: name, ofType: "wav"),
            "\(name).wav should be copied into the app test host bundle"
        )
        let audio = SherpaOnnxWaveWrapper.readWave(filename: path)

        XCTAssertEqual(audio.sampleRate, 16000)
        XCTAssertGreaterThan(audio.numSamples, 0)
        return audio
    }

    private func XCTAssertMatches(
        _ text: String,
        _ pattern: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertNotNil(
            text.range(of: pattern, options: .regularExpression),
            "Expected '\(text)' to match /\(pattern)/",
            file: file,
            line: line
        )
    }

    private func XCTAssertChineseFixtureText(
        _ text: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertMatches(text, #"\p{Han}"#, file: file, line: line)
        XCTAssertMatches(text, #"九点"#, file: file, line: line)
        XCTAssertMatches(text, #"五点"#, file: file, line: line)
    }

    private func XCTAssertEnglishFixtureText(
        _ text: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let lowercased = text.lowercased()
        XCTAssertTrue(lowercased.contains("tribal"), file: file, line: line)
        XCTAssertTrue(lowercased.contains("fifty pieces"), file: file, line: line)
    }
}
