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
        VStack(spacing: 18) {
            header

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 12) {
                    if sherpaOnnxVM.subtitles.isEmpty {
                        Text("Ready")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(sherpaOnnxVM.subtitles)
                            .font(.system(.body, design: .rounded))
                            .lineSpacing(8)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            Button {
                toggleRecorder()
            } label: {
                Label(
                    sherpaOnnxVM.status == .stop ? "Start" : "Stop",
                    systemImage: sherpaOnnxVM.status == .stop ? "mic.fill" : "stop.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Streaming ASR")
                    .font(.largeTitle.weight(.semibold))
                Text(sherpaOnnxVM.status == .recording ? "Zipformer 480ms" : "Idle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Circle()
                .fill(sherpaOnnxVM.isSpeaking ? Color.green : Color.gray.opacity(0.45))
                .frame(width: 14, height: 14)
                .accessibilityLabel(sherpaOnnxVM.isSpeaking ? "Speaking" : "Silent")
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
