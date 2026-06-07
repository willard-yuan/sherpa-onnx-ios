import Foundation

enum TranscriptTextNormalizer {
    static func normalize(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)

        result = result.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )

        result = result.replacingOccurrences(
            of: #"^[,，。！？!?\.;；:：、\s]+"#,
            with: "",
            options: .regularExpression
        )

        result = result.replacingOccurrences(
            of: #"(?<=\p{Han})\s+(?=\p{Han})"#,
            with: "",
            options: .regularExpression
        )

        result = result.replacingOccurrences(
            of: #"\s+([，。！？；：、])"#,
            with: "$1",
            options: .regularExpression
        )

        result = result.replacingOccurrences(
            of: #"([，。！？；：、])\s+(?=\p{Han})"#,
            with: "$1",
            options: .regularExpression
        )

        result = result.replacingOccurrences(
            of: #"\s+([,.!?;:])"#,
            with: "$1",
            options: .regularExpression
        )

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
