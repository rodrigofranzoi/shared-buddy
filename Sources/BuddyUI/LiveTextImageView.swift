import AppKit
import SwiftUI
import VisionKit

/// Preview/iOS-style Live Text selection over an image (VisionKit).
/// Host the view at the fitted image size so selection stays inside the image frame.
public struct LiveTextImageView: NSViewRepresentable {
    public var image: NSImage
    @Binding public var selectedText: String
    public var isInteractionEnabled: Bool

    public init(image: NSImage, selectedText: Binding<String>, isInteractionEnabled: Bool = true) {
        self.image = image
        self._selectedText = selectedText
        self.isInteractionEnabled = isInteractionEnabled
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(selectedText: $selectedText)
    }

    public func makeNSView(context: Context) -> ContainerView {
        let container = ContainerView()
        container.wantsLayer = true
        container.layer?.masksToBounds = true

        let imageView = NSImageView()
        // Host is already aspect-fit sized by SwiftUI; stretch to that frame.
        // Do not use the image's intrinsic pixel size or Select looks zoomed/cropped.
        imageView.imageScaling = .scaleAxesIndependently
        imageView.imageAlignment = .alignCenter
        imageView.animates = false
        imageView.wantsLayer = true
        imageView.layer?.masksToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        let overlay = ImageAnalysisOverlayView()
        overlay.delegate = context.coordinator
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.preferredInteractionTypes = isInteractionEnabled ? Self.liveInteractionTypes : []
        overlay.wantsLayer = true
        overlay.layer?.masksToBounds = true
        overlay.setContentHuggingPriority(.defaultLow, for: .horizontal)
        overlay.setContentHuggingPriority(.defaultLow, for: .vertical)
        overlay.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        overlay.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        container.imageView = imageView
        container.overlayView = overlay
        container.addSubview(imageView)
        container.addSubview(overlay)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: imageView.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: imageView.bottomAnchor)
        ])

        overlay.trackingImageView = imageView
        context.coordinator.overlay = overlay
        return container
    }

    /// Text selection plus data-detector / QR interaction when Live Text is active.
    private static var liveInteractionTypes: ImageAnalysisOverlayView.InteractionTypes {
        var types: ImageAnalysisOverlayView.InteractionTypes = [.textSelection]
        types.insert(.dataDetectors)
        return types
    }

    public func updateNSView(_ container: ContainerView, context: Context) {
        context.coordinator.selectedText = $selectedText
        container.overlayView?.preferredInteractionTypes = isInteractionEnabled ? Self.liveInteractionTypes : []
        container.overlayView?.isHidden = !isInteractionEnabled
        container.layer?.masksToBounds = true
        container.imageView?.layer?.masksToBounds = true
        container.overlayView?.layer?.masksToBounds = true
        container.imageView?.imageScaling = .scaleAxesIndependently

        let imageView = container.imageView
        let previous = imageView?.image
        if previous !== image, previous?.tiffRepresentation != image.tiffRepresentation {
            imageView?.image = image
            context.coordinator.analyze(image: image)
        } else if imageView?.image == nil {
            imageView?.image = image
            context.coordinator.analyze(image: image)
        }
    }

    public final class ContainerView: NSView {
        var imageView: NSImageView?
        var overlayView: ImageAnalysisOverlayView?

        /// Let SwiftUI's `.frame` own sizing. NSImageView's intrinsic size is the
        /// full image, which otherwise expands this host and clips as a zoom-in.
        public override var intrinsicContentSize: NSSize {
            NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
        }

        public override func layout() {
            super.layout()
            layer?.masksToBounds = true
        }
    }

    @MainActor
    public final class Coordinator: NSObject, ImageAnalysisOverlayViewDelegate {
        var selectedText: Binding<String>
        weak var overlay: ImageAnalysisOverlayView?
        private let analyzer = ImageAnalyzer()
        private var analysisTask: Task<Void, Never>?
        private var analyzedImageHash: Int?

        init(selectedText: Binding<String>) {
            self.selectedText = selectedText
        }

        func analyze(image: NSImage) {
            let hash = image.tiffRepresentation?.hashValue
            if hash == analyzedImageHash, overlay?.analysis != nil { return }
            analyzedImageHash = hash
            analysisTask?.cancel()
            let analyzer = analyzer
            analysisTask = Task { [weak self] in
                let configuration = ImageAnalyzer.Configuration([.text, .machineReadableCode])
                do {
                    let analysis = try await analyzer.analyze(image, orientation: .up, configuration: configuration)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        self?.overlay?.analysis = analysis
                    }
                } catch {
                    // Analysis can fail on empty/tiny images; leave overlay without analysis.
                }
            }
        }

        public func textSelectionDidChange(_ overlayView: ImageAnalysisOverlayView) {
            if #available(macOS 14.0, *) {
                selectedText.wrappedValue = overlayView.selectedText
            }
        }
    }
}
