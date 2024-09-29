import UIKit
import CoreML

// 定义一个枚举类型，用于标识移除背景的结果类型
enum RemoveBackroundResult {
    case background
    case finalImage
}

extension UIImage {

    // 移除图像的背景并返回处理结果
    func removeBackground(returnResult: RemoveBackroundResult) -> UIImage? {
        // 获取DeepLabV3模型，如果获取失败，则返回nil
        guard let model = getDeepLabV3Model() else { return nil }
        
        // 设置要处理的图像尺寸
        let width: CGFloat = 513
        let height: CGFloat = 513
        
        // 将图像调整到指定尺寸
        let resizedImage = resized(to: CGSize(width: height, height: height), scale: 1)
        
        // 创建像素缓冲区，进行模型预测，获得语义分割结果，处理得到掩码和模糊效果
        guard let pixelBuffer = resizedImage.pixelBuffer(width: Int(width), height: Int(height)),
              let outputPredictionImage = try? model.prediction(image: pixelBuffer),
              let outputImage = outputPredictionImage.semanticPredictions.image(min: 0, max: 1, axes: (0, 0, 1)),
              let outputCIImage = CIImage(image: outputImage),
              let maskImage = outputCIImage.removeWhitePixels(),
              let maskBlurImage = maskImage.applyBlurEffect() else { return nil }

        // 根据传入的returnResult，返回不同的结果
        switch returnResult {
        case .finalImage:
            // 组合模糊掩码和调整过尺寸的原始图像，并返回最终图像
            guard let resizedCIImage = CIImage(image: resizedImage),
                  let compositedImage = resizedCIImage.composite(with: maskBlurImage) else { return nil }
            let finalImage = UIImage(ciImage: compositedImage)
                .resized(to: CGSize(width: size.width, height: size.height))
            return finalImage
        case .background:
            // 返回模糊掩码作为背景图像
            let finalImage = UIImage(
                ciImage: maskBlurImage,
                scale: scale,
                orientation: self.imageOrientation
            ).resized(to: CGSize(width: size.width, height: size.height))
            return finalImage
        }
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
