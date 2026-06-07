import SwiftUI

struct WaveformView: View {
    let state: RecognitionUIState
    @State private var isAnimating = false

    private let barCount = 18

    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(barColor)
                    .frame(width: 4, height: height(for: index))
                    .opacity(opacity)
            }
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .animation(animation, value: isAnimating)
        .onAppear {
            isAnimating = true
        }
    }

    private var barColor: Color {
        switch state {
        case .speaking:
            return .green
        case .listening, .finalized:
            return .blue
        case .idle:
            return .gray
        }
    }

    private var opacity: Double {
        switch state {
        case .idle:
            return 0.18
        case .listening:
            return 0.45
        case .speaking:
            return 0.85
        case .finalized:
            return 0.65
        }
    }

    private var animation: Animation {
        let duration = state == .speaking ? 0.35 : 0.9
        return .easeInOut(duration: duration).repeatForever(autoreverses: true)
    }

    private func height(for index: Int) -> CGFloat {
        let center = CGFloat(barCount - 1) / 2
        let distance = abs(CGFloat(index) - center)
        let normalized = max(0, 1 - distance / center)
        let base = state == .speaking ? CGFloat(12) : CGFloat(6)
        let amplitude = state == .speaking ? CGFloat(30) : CGFloat(14)
        let phaseOffset = CGFloat(index % 4) * 3
        let pulse = isAnimating ? amplitude : amplitude * 0.35

        if state == .idle {
            return 4 + normalized * 8
        }

        return base + normalized * pulse + phaseOffset
    }
}
