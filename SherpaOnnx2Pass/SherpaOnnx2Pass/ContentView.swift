//
//  ContentView.swift
//  SherpaOnnx2Pass
//
//  Created by fangjun on 2023/9/11.
//

import SwiftUI

struct ContentView: View {
    @StateObject var sherpaOnnxVM = SherpaOnnxViewModel()

    var body: some View {
        VStack(spacing: 22) {
            header

            transcriptView

            Spacer()

            bottomControls
        }
        .padding()
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Streaming ASR")
                    .font(.largeTitle.weight(.semibold))
                Text(headerSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 7) {
                Image(systemName: sherpaOnnxVM.uiState.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Text(sherpaOnnxVM.uiState.title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(stateColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(stateColor.opacity(0.12))
            .clipShape(Capsule())
        }
    }

    private var transcriptView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 26) {
                finalTranscriptSection
                livePartialSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var finalTranscriptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Final transcript")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if sherpaOnnxVM.visibleFinalTranscript.isEmpty {
                Text(emptyFinalText)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(sherpaOnnxVM.visibleFinalTranscript) { segment in
                        Text(segment.text)
                            .font(.title3)
                            .lineSpacing(5)
                            .foregroundStyle(Color.primary)
                            .textSelection(.enabled)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        sherpaOnnxVM.highlightedSegmentID == segment.id
                                        ? stateColor.opacity(0.16)
                                        : Color.clear
                                    )
                            )
                            .animation(.easeOut(duration: 0.25), value: sherpaOnnxVM.highlightedSegmentID)
                    }
                }
            }
        }
    }

    private var livePartialSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live partial")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(livePartialText)
                .font(.title3)
                .lineSpacing(5)
                .foregroundStyle(sherpaOnnxVM.livePartial.isEmpty ? Color.secondary.opacity(0.7) : Color.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 14) {
            WaveformView(state: sherpaOnnxVM.uiState)

            Button {
                toggleRecorder()
            } label: {
                Label(buttonTitle, systemImage: buttonSystemImage)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(buttonTint)
        }
    }

    private var headerSubtitle: String {
        switch sherpaOnnxVM.uiState {
        case .idle:
            return "点击开始"
        case .listening:
            return "Zipformer 480ms"
        case .speaking:
            return "实时识别中"
        case .finalized:
            return "一句话已定稿"
        }
    }

    private var emptyFinalText: String {
        sherpaOnnxVM.uiState == .idle ? "点击开始" : "等待第一句话定稿"
    }

    private var livePartialText: String {
        if !sherpaOnnxVM.livePartial.isEmpty {
            return sherpaOnnxVM.livePartial
        }

        switch sherpaOnnxVM.uiState {
        case .idle:
            return " "
        case .listening:
            return "正在听..."
        case .speaking:
            return " "
        case .finalized:
            return " "
        }
    }

    private var buttonTitle: String {
        sherpaOnnxVM.uiState == .idle ? "Start" : "Stop"
    }

    private var buttonSystemImage: String {
        sherpaOnnxVM.uiState == .idle ? "mic.fill" : "stop.fill"
    }

    private var buttonTint: Color {
        sherpaOnnxVM.uiState == .idle ? .blue : .red
    }

    private var stateColor: Color {
        switch sherpaOnnxVM.uiState {
        case .idle:
            return .gray
        case .listening:
            return .blue
        case .speaking:
            return .green
        case .finalized:
            return .orange
        }
    }

    private func toggleRecorder() {
        sherpaOnnxVM.toggleRecorder()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
