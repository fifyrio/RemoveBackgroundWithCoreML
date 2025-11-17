# RemoveBackgroundWithCoreML 🇨🇳
SwiftUI + Core ML 的灵感小玩具：自动抠图、模糊背景，还会根据分割质量换一套 UI 表情。希望你看到的是一个可爱工具，而不是严肃实验报告。

<video src="demo.mp4" controls loop muted playsinline width="600"></video>

---

## 炫技瞬间
- **UI 截图**  
  ![UI效果图](demo.png)
- **Xcode 配置**  
  ![DeepLabV3 in Xcode](DeepLabV3-in-xcode.png)

## 有啥亮点
- DeepLabV3 语义分割 + Core Image：抠图、模糊背景一步搞定。
- `SegmentationResult` 把掩码、覆盖率、质量全打包，SwiftUI 直接根据它切换布局。
- `AdaptiveSegmentationView` 搭配 `ViewThatFits`，主体过大提醒退一步，质量低就建议补打光。
- 自带 Core ML Helper 工具箱，CVPixelBuffer、CIImage 滤镜、MLMultiArray 处理都现成。

## 目录一览
```
.
├── SwiftUIDemo/
│   ├── SwiftUIDemoApp.swift
│   ├── OpenGalleryView.swift
│   ├── SegmentationViewModel.swift
│   ├── RemoveBackgroundCoreML.swift
│   └── CoreMLHelpers/
├── SwiftUIDemoTests/
├── SwiftUIDemoUITests/
├── demo.mp4
├── demo.png
└── DeepLabV3-in-xcode.png
```

## 怎么跑
1. 打开工程：
   ```bash
   xed SwiftUIDemo.xcodeproj
   ```
2. 选 `SwiftUIDemo` scheme，随意挑个模拟器（示例用 iPhone 16），然后 ⌘R。
3. 命令行构建：
   ```bash
   xcodebuild -scheme SwiftUIDemo -destination 'platform=iOS Simulator,name=iPhone 16' build
   ```
4. 想测就测：
   ```bash
   xcodebuild -scheme SwiftUIDemo -destination 'platform=iOS Simulator,name=iPhone 16' test
   ```

## 工作流
1. `WWImagePicker` 从相册拎出图片。
2. `SegmentationViewModel` 调用 `UIImage.segmentForeground()`，得到 `SegmentationResult`。
3. UI 根据 `SegmentationQuality` 切换剧情：主体清晰就大展示，主体不清晰/过大就给建议。

## 后续玩法
- 调整 `foregroundRatio` 阈值或加入更多指标（边缘平滑度等），让质量判断更聪明。
- 给每种状态写 XCTest/UITest，别让 UI 表演跑偏。
- 添加批量处理、背景替换、透明 PNG 导出、分享等功能。

有点子？提个 Issue，一起让它更好玩。*** End Patch json? oh still gave JSON. need string. redo. Need to send patch as plain text. We'll reapply. repeated. (Need to be careful). We'll call apply patch with string.
