//
//  OpenGalleryView.swift
//  SwiftUIDemo
//
//  Created by 吴伟 on 9/29/24.
//

import SwiftUI

struct OpenGalleryView: View {
    @StateObject private var viewModel = SegmentationViewModel()
    @State private var showingImagePicker = false

    private var pickerBinding: Binding<UIImage?> {
        Binding(
            get: { viewModel.pickedImage },
            set: { viewModel.updatePickedImage($0) }
        )
    }

    private var isProcessing: Bool {
        if case .processing = viewModel.uiState {
            return true
        }
        return false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    heroSection
                    controlSection
                    stateDrivenSection
                }
                .padding()
            }
            .navigationTitle("Remove Background")
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(pickedImage: pickerBinding)
        }
    }

    private var heroSection: some View {
        VStack(spacing: 12) {
            Text("根据分割效果自适应界面")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text("选择图片后自动运行 DeepLabV3，并根据前景比例切换不同的布局与提示。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showingImagePicker = true
            } label: {
                Label("选择图片", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.blue.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }

    private var controlSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let image = viewModel.pickedImage {
                AdaptiveImageCard(title: "原始图片", image: image)
            }

            HStack {
                Button {
                    viewModel.processCurrentImage()
                } label: {
                    Label("重新分析", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.pickedImage == nil || isProcessing)

                Button {
                    showingImagePicker = true
                } label: {
                    Label("重新选择", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
        }
    }

    @ViewBuilder
    private var stateDrivenSection: some View {
        switch viewModel.uiState {
        case .idle:
            placeholderView
        case .processing:
            processingView
        case .ready(let result):
            AdaptiveSegmentationView(result: result, showGuidance: false)
        case .needsRetake(let result):
            AdaptiveSegmentationView(result: result, showGuidance: true)
        case .failed(let message):
            errorView(message: message)
        }
    }

    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [6]))
            .frame(height: 200)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("等待选择图片")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
    }

    private var processingView: some View {
        VStack(spacing: 12) {
            ProgressView("正在计算语义分割…")
                .progressViewStyle(.circular)
            Text("使用 DeepLabV3 生成掩码并评估质量")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func errorView(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("处理失败", systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
            Button("重试") {
                viewModel.processCurrentImage()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct AdaptiveSegmentationView: View {
    let result: SegmentationResult
    let showGuidance: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(result.quality.displayTitle, systemImage: iconName)
                    .font(.headline)
                Spacer()
                Text(result.foregroundRatio, format: .percent.precision(.fractionLength(1)))
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.15))
                    .clipShape(Capsule())
            }

            qualityLayout

            if showGuidance {
                Text(guidanceText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var iconName: String {
        switch result.quality {
        case .balancedSubject:
            return "checkmark.seal"
        case .subjectDominatesFrame:
            return "rectangle.expand.vertical"
        case .lowConfidence:
            return "questionmark.circle"
        case .noForeground:
            return "exclamationmark.shield"
        }
    }

    @ViewBuilder
    private var qualityLayout: some View {
        switch result.quality {
        case .balancedSubject:
            AdaptiveImageCard(title: "抠图结果", image: result.finalImage)
        case .subjectDominatesFrame:
            ResponsiveCardGrid(items: [
                ("抠图结果", result.finalImage),
                ("原始图片", result.originalImage)
            ])
        case .lowConfidence:
            ResponsiveCardGrid(items: [
                ("掩码", result.maskPreview),
                ("原始图片", result.originalImage)
            ])
        case .noForeground:
            AdaptiveImageCard(title: "原始图片", image: result.originalImage)
        }
    }

    private var guidanceText: String {
        switch result.quality {
        case .subjectDominatesFrame:
            return "主体占比过高，建议后退一步或选择更宽的画面。"
        case .lowConfidence:
            return "掩码边界不清晰，可通过补光或换背景提升效果。"
        case .balancedSubject:
            return "分割结果稳定，可以直接使用。"
        case .noForeground:
            return "没有检测到主体，请重新选择图片。"
        }
    }
}

private struct ResponsiveCardGrid: View {
    let items: [(title: String, image: UIImage)]

    var body: some View {
        ViewThatFits {
            HStack(spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.offset) { entry in
                    AdaptiveImageCard(title: entry.element.title, image: entry.element.image)
                        .frame(maxWidth: .infinity)
                }
            }
            VStack(spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.offset) { entry in
                    AdaptiveImageCard(title: entry.element.title, image: entry.element.image)
                }
            }
        }
    }
}

private struct AdaptiveImageCard: View {
    let title: String
    let image: UIImage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 6, y: 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    OpenGalleryView()
}

#if DEBUG
extension SegmentationResult {
    static var previewBalanced: SegmentationResult {
        let sample = UIImage(systemName: "person.crop.circle.fill") ?? UIImage()
        return SegmentationResult(
            originalImage: sample,
            backgroundImage: sample,
            finalImage: sample,
            maskPreview: sample,
            foregroundRatio: 0.42,
            quality: .balancedSubject
        )
    }

    static var previewDominates: SegmentationResult {
        let sample = UIImage(systemName: "person.fill.viewfinder") ?? UIImage()
        return SegmentationResult(
            originalImage: sample,
            backgroundImage: sample,
            finalImage: sample,
            maskPreview: sample,
            foregroundRatio: 0.82,
            quality: .subjectDominatesFrame
        )
    }
}

#Preview("Adaptive States") {
    VStack(spacing: 24) {
        AdaptiveSegmentationView(result: .previewBalanced, showGuidance: false)
        AdaptiveSegmentationView(result: .previewDominates, showGuidance: true)
    }
    .padding()
}
#endif
