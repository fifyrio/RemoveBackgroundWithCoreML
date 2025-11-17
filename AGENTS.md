# Repository Guidelines

## Project Structure & Module Organization
The SwiftUI app lives in `SwiftUIDemo/` with `SwiftUIDemoApp.swift` bootstrapping `OpenGalleryView`. Scene-specific files (e.g., `RemoveBackgroundCoreML.swift`, `WWImagePicker.swift`) sit beside shared assets in `Assets.xcassets` and storyboard-free previews in `Preview Content/`. Machine-learning glue code (pixel-buffer helpers, Core ML bridging, async wrappers) is isolated under `SwiftUIDemo/CoreMLHelpers/`, while the pre-trained `DeepLabV3.mlmodel` remains at the project root for easy updates. Tests mirror Apple’s default layout: `SwiftUIDemoTests/` for unit coverage and `SwiftUIDemoUITests/` for end-to-end interactions.

## Build, Test, and Development Commands
Use the Xcode scheme `SwiftUIDemo` for every workflow. Typical local automation commands:
- `xed SwiftUIDemo.xcodeproj` — open the workspace in Xcode when editing the UI or asset catalogs.
- `xcodebuild -scheme SwiftUIDemo -destination 'platform=iOS Simulator,name=iPhone 15' build` — compile the app with the latest simulator SDK and validate Core ML model integration.
- `xcodebuild -scheme SwiftUIDemo -destination 'platform=iOS Simulator,name=iPhone 15' test` — run unit + UI tests headlessly; add `-enableCodeCoverage YES` when auditing coverage.

## Coding Style & Naming Conventions
Follow Swift API Design Guidelines: types in UpperCamelCase, methods/properties in lowerCamelCase, and prefer expressive argument labels (`processMask(for image:)`). Indent using four spaces and group extensions by type (`UIImage+RawBytes.swift`). Keep pure SwiftUI views struct-based and mark Core ML helper APIs internal unless shared. When touching code-gen-heavy files (e.g., `.mlmodel`), avoid manual edits and rely on Model Compiler output.

## Testing Guidelines
Write XCTest cases that reflect user-visible flows: isolate Core ML preprocessing logic in `SwiftUIDemoTests`, and drive simulated gallery imports and mask rendering through `SwiftUIDemoUITests`. Name tests `test<Action>_<Expectation>()` for clarity (`testSegmentationProducesTransparentBackground()`). Run the full matrix with `xcodebuild … test` before pushing, and fail early on regression by asserting mask sizes, pixel-buffer orientation, and SwiftUI view states.

## Commit & Pull Request Guidelines
Commits are short, imperative summaries (`add logo`, `add comments`). Group related changes per feature (e.g., helper + view), and keep the diff small enough for review in Xcode’s comparison. PRs should include: a concise description of the change, linked issue or context, screenshots/simulator recordings when UI changes are visible, and notes on Core ML model replacements (model version, source). Tag any new assets or large binaries in the description so reviewers can verify licensing.
