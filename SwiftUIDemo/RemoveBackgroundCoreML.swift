import UIKit
import CoreML

// 语义分割的质量标识，用于驱动 SwiftUI 的自适应界面
enum SegmentationQuality {
    case noForeground
    case lowConfidence
    case balancedSubject
    case subjectDominatesFrame

    var displayTitle: String {
        switch self {
        case .noForeground:
            return "未检测到前景"
        case .lowConfidence:
            return "主体不明确"
        case .balancedSubject:
            return "主体清晰"
        case .subjectDominatesFrame:
            return "主体过大"
        }
    }
}

// 对分割结果进行包装，便于 UI 层统一消费
struct SegmentationResult {
    let originalImage: UIImage
    let backgroundImage: UIImage
    let finalImage: UIImage
    let maskPreview: UIImage
    let foregroundRatio: Double
    let quality: SegmentationQuality
}

// 定义一个枚举类型，用于标识移除背景的结果类型
enum RemoveBackroundResult {
    case background
    case finalImage
}

extension UIImage {

    // 兼容旧接口：基于新的分割结果返回不同图像
    func removeBackground(returnResult: RemoveBackroundResult) -> UIImage? {
        guard let result = segmentForeground() else { return nil }
        switch returnResult {
        case .finalImage:
            return result.finalImage
        case .background:
            return result.backgroundImage
        }
    }

    // 对图像执行前景分割并返回结构化结果
    func segmentForeground() -> SegmentationResult? {
        guard let model = getDeepLabV3Model() else { return nil }

        let targetSize = CGSize(width: 513, height: 513)
        let resizedImage = resized(to: targetSize, scale: 1)

        guard let pixelBuffer = resizedImage.pixelBuffer(width: Int(targetSize.width), height: Int(targetSize.height)),
              let outputPredictionImage = try? model.prediction(image: pixelBuffer),
              let outputImage = outputPredictionImage.semanticPredictions.image(min: 0, max: 1, axes: (0, 0, 1)),
              let outputCIImage = CIImage(image: outputImage),
              let maskImage = outputCIImage.removeWhitePixels(),
              let maskBlurImage = maskImage.applyBlurEffect() else { return nil }

        let context = CIContext(options: nil)
        guard let resizedCIImage = CIImage(image: resizedImage),
              let compositedImage = resizedCIImage.composite(with: maskBlurImage),
              let maskCGImage = context.createCGImage(maskImage, from: maskImage.extent) else { return nil }

        let finalImage = UIImage(ciImage: compositedImage)
            .resized(to: CGSize(width: size.width, height: size.height))
        let backgroundImage = UIImage(
            ciImage: maskBlurImage,
            scale: scale,
            orientation: imageOrientation
        ).resized(to: CGSize(width: size.width, height: size.height))
        let maskPreview = UIImage(cgImage: maskCGImage, scale: scale, orientation: imageOrientation)
            .resized(to: CGSize(width: size.width, height: size.height))
        let coverage = maskForegroundCoverage(maskImage: maskImage)
        let quality = determineQuality(from: coverage)

        return SegmentationResult(
            originalImage: self,
            backgroundImage: backgroundImage,
            finalImage: finalImage,
            maskPreview: maskPreview,
            foregroundRatio: coverage,
            quality: quality
        )
    }

    // 获取DeepLabV3的机器学习模型
    private func getDeepLabV3Model() -> DeepLabV3? {
        do {
            let config = MLModelConfiguration()
            return try DeepLabV3(configuration: config)
        } catch {
            print("ww: \(error)") // 捕获并打印错误信息
            return nil
        }
    }

}

extension CIImage {

    // 去除图像中的白色像素
    func removeWhitePixels() -> CIImage? {
        let chromaCIFilter = chromaKeyFilter()
        chromaCIFilter?.setValue(self, forKey: kCIInputImageKey) // 将当前图像作为输入
        return chromaCIFilter?.outputImage // 返回处理后的图像
    }

    // 使用给定的掩码图像进行图像合成
    func composite(with mask: CIImage) -> CIImage? {
        return CIFilter(
            name: "CISourceOutCompositing",
            parameters: [
                kCIInputImageKey: self,
                kCIInputBackgroundImageKey: mask
            ]
        )?.outputImage // 返回合成后的图像
    }

    // 对图像应用模糊效果
    func applyBlurEffect() -> CIImage? {
        let context = CIContext(options: nil)
        let clampFilter = CIFilter(name: "CIAffineClamp")!
        clampFilter.setDefaults()
        clampFilter.setValue(self, forKey: kCIInputImageKey)

        // 使用高斯模糊滤镜进行模糊处理
        guard let currentFilter = CIFilter(name: "CIGaussianBlur") else { return nil }
        currentFilter.setValue(clampFilter.outputImage, forKey: kCIInputImageKey)
        currentFilter.setValue(2, forKey: "inputRadius") // 设置模糊半径
        guard let output = currentFilter.outputImage,
              let cgimg = context.createCGImage(output, from: extent) else { return nil }

        return CIImage(cgImage: cgimg) // 返回模糊后的图像
    }

    // 创建一个色度键滤镜，以便移除特定颜色的像素
    // 此部分代码经过修改，源自Apple的文档
    private func chromaKeyFilter() -> CIFilter? {
        let size = 64
        var cubeRGB = [Float]()

        // 生成色度键的颜色立方体数据
        for z in 0 ..< size {
            let blue = CGFloat(z) / CGFloat(size - 1)
            for y in 0 ..< size {
                let green = CGFloat(y) / CGFloat(size - 1)
                for x in 0 ..< size {
                    let red = CGFloat(x) / CGFloat(size - 1)
                    let brightness = getBrightness(red: red, green: green, blue: blue)
                    let alpha: CGFloat = brightness == 1 ? 0 : 1 // 亮度为1时，透明度设为0
                    cubeRGB.append(Float(red * alpha))
                    cubeRGB.append(Float(green * alpha))
                    cubeRGB.append(Float(blue * alpha))
                    cubeRGB.append(Float(alpha))
                }
            }
        }

        // 创建色度键滤镜
        let data = Data(buffer: UnsafeBufferPointer(start: &cubeRGB, count: cubeRGB.count))
        let colorCubeFilter = CIFilter(
            name: "CIColorCube",
            parameters: [
                "inputCubeDimension": size,
                "inputCubeData": data
            ]
        )
        return colorCubeFilter // 返回创建的滤镜
    }

    // 获取给定RGB颜色的亮度
    // 此部分代码经过修改，源自Apple的文档
    private func getBrightness(red: CGFloat, green: CGFloat, blue: CGFloat) -> CGFloat {
        let color = UIColor(red: red, green: green, blue: blue, alpha: 1)
        var brightness: CGFloat = 0
        color.getHue(nil, saturation: nil, brightness: &brightness, alpha: nil) // 获取颜色的亮度
        return brightness // 返回亮度值
    }

}

// 计算掩码前景覆盖率（0...1）
private func maskForegroundCoverage(maskImage: CIImage) -> Double {
    let areaFilter = CIFilter(name: "CIAreaAverage")
    areaFilter?.setValue(maskImage, forKey: kCIInputImageKey)
    areaFilter?.setValue(CIVector(cgRect: maskImage.extent), forKey: kCIInputExtentKey)
    guard let averageOutput = areaFilter?.outputImage else { return 0 }

    var bitmap = [UInt8](repeating: 0, count: 4)
    let context = CIContext(options: nil)
    context.render(
        averageOutput,
        toBitmap: &bitmap,
        rowBytes: 4,
        bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
        format: .RGBA8,
        colorSpace: nil
    )

    return Double(bitmap[3]) / 255.0
}

// 根据覆盖率简单推断语义分割质量
private func determineQuality(from coverage: Double) -> SegmentationQuality {
    switch coverage {
    case ..<0.05:
        return .noForeground
    case 0.05..<0.15:
        return .lowConfidence
    case 0.15..<0.65:
        return .balancedSubject
    default:
        return .subjectDominatesFrame
    }
}
