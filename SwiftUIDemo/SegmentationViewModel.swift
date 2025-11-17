//
//  SegmentationViewModel.swift
//  SwiftUIDemo
//
//  Created by 吴伟 on 10/2/24.
//

import SwiftUI

enum SegmentationUIState {
    case idle
    case processing
    case ready(SegmentationResult)
    case needsRetake(SegmentationResult)
    case failed(message: String)
}

@MainActor
final class SegmentationViewModel: ObservableObject {
    @Published var pickedImage: UIImage?
    @Published var uiState: SegmentationUIState = .idle

    private var segmentationTask: Task<Void, Never>?

    func updatePickedImage(_ image: UIImage?) {
        pickedImage = image
        guard let image else {
            uiState = .idle
            segmentationTask?.cancel()
            return
        }
        process(image: image)
    }

    func processCurrentImage() {
        guard let image = pickedImage else { return }
        process(image: image)
    }

    private func process(image: UIImage) {
        segmentationTask?.cancel()
        uiState = .processing

        segmentationTask = Task.detached(priority: .userInitiated) { [weak self] in
            let result = image.segmentForeground()
            if Task.isCancelled { return }

            await MainActor.run {
                guard let self else { return }
                guard let result else {
                    self.uiState = .failed(message: "语义分割失败，请重试")
                    return
                }

                switch result.quality {
                case .balancedSubject:
                    self.uiState = .ready(result)
                case .subjectDominatesFrame, .lowConfidence:
                    self.uiState = .needsRetake(result)
                case .noForeground:
                    self.uiState = .failed(message: "未检测到主体，请重新选择图片")
                }
            }
        }
    }
}
