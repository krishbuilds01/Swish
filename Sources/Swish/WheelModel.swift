import SwiftUI
import AppKit

public struct FormatOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let fileExtension: String
    public let uti: String
    public let category: FileCategory
    public let iconName: String
    public let accentColor: Color
    public let subtitle: String

    public init(
        displayName: String,
        fileExtension: String,
        uti: String,
        category: FileCategory,
        iconName: String,
        accentColor: Color,
        subtitle: String
    ) {
        self.id = fileExtension.lowercased()
        self.displayName = displayName
        self.fileExtension = fileExtension.lowercased()
        self.uti = uti
        self.category = category
        self.iconName = iconName
        self.accentColor = accentColor
        self.subtitle = subtitle
    }
}

public enum FileCategory: String, Sendable {
    case image = "Image"
    case document = "Document"
    case audio = "Audio"
    case video = "Video"
}

public enum ConversionPhase: Sendable {
    case idle
    case converting
    case success
}

@MainActor
public final class WheelState: ObservableObject {
    @Published public var isPresented: Bool = false
    @Published public var fileURLs: [URL] = []
    @Published public var availableFormats: [FormatOption] = []
    @Published public var hoveredIndex: Int? = nil
    @Published public var cursorAngle: Double = 0.0
    @Published public var cursorDistance: CGFloat = 0.0

    // Animation & Conversion State
    @Published public var phase: ConversionPhase = .idle
    @Published public var activeConvertingFormat: FormatOption? = nil
    @Published public var progressRotation: Double = 0.0
    @Published public var rippleScale: CGFloat = 0.7
    @Published public var rippleOpacity: Double = 0.0
    @Published public var secondRippleScale: CGFloat = 0.5
    @Published public var secondRippleOpacity: Double = 0.0

    // Unsupported File State
    @Published public var isUnsupportedFile: Bool = false
    @Published public var unsupportedMessage: String = "File not supported for conversion"

    public var isConverting: Bool {
        return phase == .converting
    }

    public var conversionSuccess: Bool {
        return phase == .success
    }

    public var selectedFormat: FormatOption? {
        if let active = activeConvertingFormat {
            return active
        }
        guard let idx = hoveredIndex, idx >= 0, idx < availableFormats.count else {
            return nil
        }
        return availableFormats[idx]
    }

    public var primaryFileName: String {
        guard let first = fileURLs.first else { return "Files" }
        return first.lastPathComponent
    }

    public var fileCountText: String? {
        if fileURLs.count > 1 {
            return "+\(fileURLs.count - 1)"
        }
        return nil
    }

    public init() {}

    public func reset() {
        hoveredIndex = nil
        cursorAngle = 0.0
        cursorDistance = 0.0
        phase = .idle
        activeConvertingFormat = nil
        progressRotation = 0.0
        rippleScale = 0.7
        rippleOpacity = 0.0
        secondRippleScale = 0.5
        secondRippleOpacity = 0.0
        isUnsupportedFile = false
        unsupportedMessage = "File not supported for conversion"
    }
}
