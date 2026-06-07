import Foundation

enum RecognitionUIState: Equatable {
    case idle
    case listening
    case speaking
    case finalized

    var title: String {
        switch self {
        case .idle:
            return "Idle"
        case .listening:
            return "Listening"
        case .speaking:
            return "Speaking"
        case .finalized:
            return "Finalized"
        }
    }

    var systemImage: String {
        switch self {
        case .idle:
            return "mic"
        case .listening:
            return "mic.fill"
        case .speaking:
            return "waveform"
        case .finalized:
            return "checkmark"
        }
    }
}

struct TranscriptSegment: Identifiable, Equatable {
    let id: UUID
    let text: String
    let createdAt: Date

    init(id: UUID = UUID(), text: String, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
    }
}
