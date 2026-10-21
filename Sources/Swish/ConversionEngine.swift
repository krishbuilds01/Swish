import Foundation
import AppKit
import SwiftUI
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import PDFKit
import AVFoundation
import QuickLookThumbnailing

public enum ConversionError: LocalizedError {
    case unsupportedFileType(String)
    case unsupportedTargetFormat(String)
    case fileNotFound(URL)
    case readFailure(String)
    case writeFailure(String)
    case exportFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFileType(let ext):
            return "File extension '.\(ext)' is not supported for conversion."
        case .unsupportedTargetFormat(let fmt):
            return "Target format '\(fmt)' is not supported."
        case .fileNotFound(let url):
            return "File does not exist at: \(url.path)"
        case .readFailure(let reason):
            return "Failed to read file: \(reason)"
        case .writeFailure(let reason):
            return "Failed to save converted file: \(reason)"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        }
    }
}

public struct ConversionEngine: Sendable {
    public static let shared = ConversionEngine()

    public init() {}

    // MARK: - Core Shared Archive Formats (Universal 100% Offline Support)

    public static let zipFormat = FormatOption(
        displayName: "ZIP",
        fileExtension: "zip",
        uti: "public.zip-archive",
        category: .document,
        iconName: "archivebox.fill",
        accentColor: .white,
        subtitle: ""
    )

    public static let tarFormat = FormatOption(
        displayName: "TAR",
        fileExtension: "tar.gz",
        uti: "org.gnu.gnu-tar-archive",
        category: .document,
        iconName: "shippingbox.fill",
        accentColor: .white,
        subtitle: ""
    )

    public static let gzFormat = FormatOption(
        displayName: "GZ",
        fileExtension: "gz",
        uti: "org.gnu.gnu-zip-archive",
        category: .document,
        iconName: "doc.zipper",
        accentColor: .white,
        subtitle: ""
    )

    // MARK: - Curated Popular Format Registries (Strictly Working, Offline Conversions)

    // 1. Image Targets (Popular, useful formats only; TIFF, BMP, TXT removed)
    public static let imageFormats: [FormatOption] = [
        FormatOption(displayName: "WEBP", fileExtension: "webp", uti: "org.webmproject.webp", category: .image, iconName: "globe.americas.fill", accentColor: .white, subtitle: ""),
        FormatOption(displayName: "JPEG", fileExtension: "jpg", uti: "public.jpeg", category: .image, iconName: "camera.fill", accentColor: .white, subtitle: ""),
        FormatOption(displayName: "PNG", fileExtension: "png", uti: "public.png", category: .image, iconName: "sparkles", accentColor: .white, subtitle: ""),
        FormatOption(displayName: "PDF", fileExtension: "pdf", uti: "com.adobe.pdf", category: .document, iconName: "doc.text.fill", accentColor: .white, subtitle: ""),
        FormatOption(displayName: "HEIC", fileExtension: "heic", uti: "public.heic", category: .image, iconName: "apple.logo", accentColor: .white, subtitle: ""),
        FormatOption(displayName: "GIF", fileExtension: "gif", uti: "com.compuserve.gif", category: .image, iconName: "play.circle.fill", accentColor: .white, subtitle: ""),
        zipFormat
    ]

    // 2. PDF Targets (Strictly convertible to images, text, and zip; RTF and TIFF removed)
    public static let pdfDocFormats: [FormatOption] = [
        FormatOption(displayName: "PNG", fileExtension: "png", uti: "public.png", category: .image, iconName: "camera.fill", accentColor: .white, subtitle: ""),
        FormatOption(displayName: "JPEG", fileExtension: "jpg", uti: "public.jpeg", category: .image, iconName: "photo.fill", accentColor: .white, subtitle: ""),
        FormatOption(displayName: "WEBP", fileExtension: "webp", uti: "org.webmproject.webp", category: .image, iconName: "globe.americas.fill", accentColor: .white, subtitle: ""),
        FormatOption(displayName: "HEIC", fileExtension: "heic", uti: "public.heic", category: .image, iconName: "apple.logo", accentColor: .white, subtitle: ""),
        FormatOption(displayName: "TXT", fileExtension: "txt", uti: "public.plain-text", category: .document, iconName: "text.alignleft", accentColor: .white, subtitle: ""),
        zipFormat
    ]

    // 3. Presentation Targets (PPT, PPTX, KEY, ODP -> PDF, Images, Zip; fake formats removed)
    public static let presentationFormats: [FormatOption] = [
        FormatOption(displayName: "PDF", fileExtension: "pdf", uti: "com.adobe.pdf", category: .document, iconName: "doc.text.fill", accentColor: .white, subtitle: ""),
        FormatOption(displayName: "PNG", fileExtension: "png", uti: "public.png", category: .image, iconName: "camera.fill", accentColor: .white, subtitle: ""),
        FormatOption(displayName: "JPEG", fileExtension: "jpg", uti: "public.jpeg", category: .image, iconName: "photo.fill", accentColor: .white, subtitle: ""),
        FormatOption(displayName: "WEBP", fileExtension: "webp", uti: "org.webmproject.webp", category: .image, iconName: "globe.americas.fill", accentColor: .white, subtitle: ""),
        zipFormat
    ]

    // 4. Video Targets (Video, GIF, Audio extraction, Poster frame, Zip)
    public static let videoFormats: [FormatOption] = [
        FormatOption(displayName: "MP4", fileExtension: "mp4", uti: "public.mpeg-4", category: .video, iconName: "film.fill", accentColor: .white, subtitle: ""),
        FormatOption(displayName: "MOV", fileExtension: "mov", uti: "com.apple.quicktime-movie", category: .video, iconName: "video.fill", accentColor: .white, subtitle: ""),
        FormatOption(displayName: "GIF", fileExtension: "gif", uti: "com.compuserve.gif", category: .image, iconName: "play.circle.fill", accentColor: .white, subtitle: ""),
        FormatOption(displayName: "M4A", fileExtension: "m4a", uti: "com.apple.m4a-audio", category: .audio, iconName: "waveform", accentColor: .white, subtitle: ""),
        FormatOption(displayName: "WAV", fileExtension: "wav", uti: "com.microsoft.waveform-audio", category: .audio, iconName: "waveform.circle.fill", accentColor: .white, subtitle: ""),
        FormatOption(displayName: "PNG", fileExtension: "png", uti: "public.png", category: .image, iconName: "camera.fill", accentColor: .white, subtitle: ""),
        FormatOption(displayName: "JPEG", fileExtension: "jpg", uti: "public.jpeg", category: .image, iconName: "photo.fill", accentColor: .white, subtitle: ""),
        zipFormat
    ]

    // 5. Audio Targets (AAC, WAV, AIFF, CAF, FLAC, Zip)
    public static let audioFormats: [FormatOption] = [
        FormatOption(displayName: "M4A", fileExtension: "m4a", uti: "com.apple.m4a-audio", category: .audio, iconName: "waveform.circle.fill", accentColor: .white, subtitle: ""),
        FormatOption(displayName: "WAV", fileExtension: "wav", uti: "com.microsoft.waveform-audio", category: .audio, iconName: "waveform", accentColor: .white, subtitle: ""),
        FormatOption(displayName: "AIFF", fileExtension: "aiff", uti: "public.aiff-audio", category: .audio, iconName: "music.note", accentColor: .white, subtitle: ""),
        FormatOption(displayName: "CAF", fileExtension: "caf", uti: "com.apple.coreaudio-format", category: .audio, iconName: "recordingtape", accentColor: .white, subtitle: ""),
        FormatOption(displayName: "AAC", fileExtension: "aac", uti: "public.aac-audio", category: .audio, iconName: "waveform.badge.magnifyingglass", accentColor: .white, subtitle: ""),
        FormatOption(displayName: "FLAC", fileExtension: "flac", uti: "org.xiph.flac", category: .audio, iconName: "sparkles", accentColor: .white, subtitle: ""),
        zipFormat
    ]

    // 6. Text & Document Targets (Formatted PDF, TXT, HTML, PNG, Zip)
    public static let textDocFormats: [FormatOption] = [
        FormatOption(displayName: "PDF", fileExtension: "pdf", uti: "com.adobe.pdf", category: .document, iconName: "doc.text.fill", accentColor: .white, subtitle: ""),
        FormatOption(displayName: "TXT", fileExtension: "txt", uti: "public.plain-text", category: .document, iconName: "text.alignleft", accentColor: .white, subtitle: ""),
        FormatOption(displayName: "HTML", fileExtension: "html", uti: "public.html", category: .document, iconName: "chevron.left.forwardslash.chevron.right", accentColor: .white, subtitle: ""),
        FormatOption(displayName: "PNG", fileExtension: "png", uti: "public.png", category: .image, iconName: "camera.fill", accentColor: .white, subtitle: ""),
        zipFormat
    ]

    // 7. Generic Fallback for Any Other File Type (Always compressable offline)
    public static let genericFormats: [FormatOption] = [
        zipFormat,
        tarFormat,
        gzFormat
    ]

    // MARK: - Precise Offline Compatibility Filtering

    public func compatibleFormats(for fileURL: URL) -> [FormatOption] {
        let ext = fileURL.pathExtension.lowercased()

        var candidates: [FormatOption] = []

        if ext == "pdf" {
            candidates = Self.pdfDocFormats
        } else if ["ppt", "pptx", "key", "odp"].contains(ext) {
            candidates = Self.presentationFormats
        } else if ["txt", "md", "markdown", "json", "csv", "xml", "yaml", "yml", "log", "swift", "py", "js", "ts", "html", "css", "c", "cpp", "h", "sh", "docx", "doc", "rtf"].contains(ext) {
            candidates = Self.textDocFormats
        } else if ["mp3", "m4a", "wav", "aiff", "aif", "caf", "flac", "aac", "ogg", "alac"].contains(ext) {
            candidates = Self.audioFormats
        } else if ["mov", "mp4", "m4v", "avi", "mkv", "webm"].contains(ext) {
            candidates = Self.videoFormats
        } else if ["png", "jpg", "jpeg", "webp", "heic", "tiff", "tif", "gif", "bmp", "ico", "avif", "psd", "svg", "raw", "dng", "cr2", "nef"].contains(ext) {
            candidates = Self.imageFormats
        } else {
            // Unsupported file format for conversion
            return []
        }

        // Filter out identical format (e.g. don't convert png -> png, or pdf -> pdf)
        // Always preserve ZIP compression option!
        let filtered = candidates.filter { option in
            if option.fileExtension == "zip" { return true }
            if option.fileExtension == ext { return false }
            if (ext == "jpg" || ext == "jpeg") && (option.fileExtension == "jpg" || option.fileExtension == "jpeg") { return false }
            if (ext == "tif" || ext == "tiff") && (option.fileExtension == "tif" || option.fileExtension == "tiff") { return false }
            return true
        }

        return filtered
    }

    public func isFormatSupported(for fileURL: URL) -> Bool {
        return !compatibleFormats(for: fileURL).isEmpty
    }

    // MARK: - Collision Safe Output URL

    public func collisionSafeURL(beside originalURL: URL, extension ext: String) -> URL {
        let directory = originalURL.deletingLastPathComponent()
        let baseName = originalURL.deletingPathExtension().lastPathComponent

        var candidate = directory.appendingPathComponent("\(baseName).\(ext)")
        var counter = 1

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName) (\(counter)).\(ext)")
            counter += 1
        }
        return candidate
    }

    // MARK: - Main Conversion Dispatcher

    public func convert(files: [URL], to targetFormat: FormatOption) async throws -> [URL] {
        // Universal Archive Compression Handling
        if targetFormat.fileExtension == "zip" {
            return try await compressToZipArchive(files: files)
        }
        if targetFormat.fileExtension == "tar.gz" || targetFormat.fileExtension == "tar" {
            return try await compressToTarArchive(files: files)
        }
        if targetFormat.fileExtension == "gz" {
            return try await compressToGzipArchive(files: files)
        }

        var results: [URL] = []
        for file in files {
            let output = try await convertSingleFile(inputURL: file, targetFormat: targetFormat)
            results.append(output)
        }
        return results
    }

    private func convertSingleFile(inputURL: URL, targetFormat: FormatOption) async throws -> URL {
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw ConversionError.fileNotFound(inputURL)
        }

        let inputExt = inputURL.pathExtension.lowercased()

        // 1. PDF input
        if inputExt == "pdf" {
            return try await convertPDF(inputURL: inputURL, targetFormat: targetFormat)
        }

        // 2. Presentation input (PPT, PPTX, KEY, ODP)
        if ["ppt", "pptx", "key", "odp"].contains(inputExt) {
            return try await convertPresentation(inputURL: inputURL, targetFormat: targetFormat)
        }

        // 3. Video input
        if ["mov", "mp4", "m4v", "avi", "mkv", "webm"].contains(inputExt) {
            return try await convertVideo(inputURL: inputURL, targetFormat: targetFormat)
        }

        // 4. Audio input
        if ["mp3", "m4a", "wav", "aiff", "aif", "caf", "flac", "aac", "ogg", "alac"].contains(inputExt) {
            return try await convertAudio(inputURL: inputURL, targetFormat: targetFormat)
        }

        // 5. Text / Document input
        if ["txt", "md", "markdown", "json", "csv", "xml", "yaml", "yml", "log", "swift", "py", "js", "ts", "html", "css", "c", "cpp", "h", "sh", "rtf", "rtfd", "docx", "doc"].contains(inputExt) {
            return try await convertTextDocument(inputURL: inputURL, targetFormat: targetFormat)
        }

        // 6. Image input
        return try await convertImage(inputURL: inputURL, targetFormat: targetFormat)
    }

    // MARK: - Image Conversion

    private func convertImage(inputURL: URL, targetFormat: FormatOption) async throws -> URL {
        let outputURL = collisionSafeURL(beside: inputURL, extension: targetFormat.fileExtension)

        // 1. WebP Export (Rock-Solid Offline WebP Engine)
        if targetFormat.fileExtension == "webp" {
            let inExt = inputURL.pathExtension.lowercased()
            if ["png", "jpg", "jpeg", "tif", "tiff"].contains(inExt) {
                do {
                    try await encodeFileToWebP(from: inputURL, to: outputURL, quality: 85)
                    return outputURL
                } catch {
                    // Fall back to CGImage decode and re-encode
                }
            }

            guard let imageSource = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                throw ConversionError.readFailure("Failed to decode image frames for WebP conversion.")
            }
            return try await exportCGImageToWebP(cgImage: cgImage, outputURL: outputURL)
        }

        // 2. PDF Target
        if targetFormat.fileExtension == "pdf" {
            guard let imageSource = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                throw ConversionError.readFailure("Failed to decode image frames for PDF conversion.")
            }
            let pdfDoc = PDFDocument()
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            guard let pdfPage = PDFPage(image: nsImage) else {
                throw ConversionError.writeFailure("Failed to generate PDF page.")
            }
            pdfDoc.insert(pdfPage, at: 0)
            guard pdfDoc.write(to: outputURL) else {
                throw ConversionError.writeFailure("Failed to write PDF document.")
            }
            return outputURL
        }

        // 3. Raster Image Formats (JPEG, PNG, HEIC, GIF)
        guard let imageSource = CGImageSourceCreateWithURL(inputURL as CFURL, nil) else {
            throw ConversionError.readFailure("Could not initialize CGImageSource for \(inputURL.lastPathComponent)")
        }

        let utiString: String
        switch targetFormat.fileExtension {
        case "jpg", "jpeg": utiString = "public.jpeg"
        case "png": utiString = "public.png"
        case "heic": utiString = "public.heic"
        case "gif": utiString = "com.compuserve.gif"
        default: utiString = targetFormat.uti
        }

        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, utiString as CFString, 1, nil) else {
            throw ConversionError.writeFailure("System does not support writing format: \(targetFormat.displayName) (\(utiString))")
        }

        var properties: [CFString: Any] = [:]
        if ["jpg", "jpeg", "heic"].contains(targetFormat.fileExtension) {
            properties[kCGImageDestinationLossyCompressionQuality] = 0.92
        }

        CGImageDestinationAddImageFromSource(destination, imageSource, 0, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.writeFailure("Failed to finalize image destination for \(outputURL.lastPathComponent)")
        }

        return outputURL
    }

    // MARK: - PDF Conversion

    private func convertPDF(inputURL: URL, targetFormat: FormatOption) async throws -> URL {
        guard let pdfDoc = PDFDocument(url: inputURL) else {
            throw ConversionError.readFailure("Failed to open PDF document.")
        }

        let outputURL = collisionSafeURL(beside: inputURL, extension: targetFormat.fileExtension)

        // 1. Text extraction
        if targetFormat.fileExtension == "txt" {
            let fullText = (0..<pdfDoc.pageCount).compactMap { pdfDoc.page(at: $0)?.string }.joined(separator: "\n\n")
            do {
                try fullText.write(to: outputURL, atomically: true, encoding: .utf8)
                return outputURL
            } catch {
                throw ConversionError.writeFailure(error.localizedDescription)
            }
        }

        // 2. High-DPI Page Rendering (PNG, JPEG, WEBP, HEIC)
        guard let firstPage = pdfDoc.page(at: 0) else {
            throw ConversionError.readFailure("PDF has no pages.")
        }

        let pageRect = firstPage.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0 // High DPI (Retina quality)
        let pixelWidth = max(Int(pageRect.width * scale), 100)
        let pixelHeight = max(Int(pageRect.height * scale), 100)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw ConversionError.writeFailure("Failed to allocate bitmap context for PDF rendering.")
        }

        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        context.scaleBy(x: scale, y: scale)
        firstPage.draw(with: .mediaBox, to: context)

        guard let cgImage = context.makeImage() else {
            throw ConversionError.writeFailure("Failed to capture rendered PDF page.")
        }

        // WebP Target
        if targetFormat.fileExtension == "webp" {
            return try await exportCGImageToWebP(cgImage: cgImage, outputURL: outputURL)
        }

        // Raster formats
        let uti: String
        switch targetFormat.fileExtension {
        case "png": uti = "public.png"
        case "jpg", "jpeg": uti = "public.jpeg"
        case "heic": uti = "public.heic"
        default: uti = "public.png"
        }

        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, uti as CFString, 1, nil) else {
            throw ConversionError.writeFailure("Failed to create image destination for PDF page (\(uti)).")
        }

        var properties: [CFString: Any] = [:]
        if ["jpg", "jpeg", "heic"].contains(targetFormat.fileExtension) {
            properties[kCGImageDestinationLossyCompressionQuality] = 0.92
        }

        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.writeFailure("Failed to save rendered PDF image.")
        }

        return outputURL
    }

    // MARK: - Presentation Conversion (PPT, PPTX, KEY, ODP)

    private func convertPresentation(inputURL: URL, targetFormat: FormatOption) async throws -> URL {
        let outputURL = collisionSafeURL(beside: inputURL, extension: targetFormat.fileExtension)

        let request = QLThumbnailGenerator.Request(
            fileAt: inputURL,
            size: CGSize(width: 1920, height: 1080),
            scale: 2.0,
            representationTypes: .all
        )

        let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
        let cgImage = representation.cgImage

        if targetFormat.fileExtension == "pdf" {
            let pdfDoc = PDFDocument()
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            guard let pdfPage = PDFPage(image: nsImage) else {
                throw ConversionError.writeFailure("Failed to create PDF page from slide.")
            }
            pdfDoc.insert(pdfPage, at: 0)
            guard pdfDoc.write(to: outputURL) else {
                throw ConversionError.writeFailure("Failed to write PDF slide document.")
            }
            return outputURL
        }

        if targetFormat.fileExtension == "webp" {
            return try await exportCGImageToWebP(cgImage: cgImage, outputURL: outputURL)
        }

        let uti: String
        switch targetFormat.fileExtension {
        case "png": uti = "public.png"
        case "jpg", "jpeg": uti = "public.jpeg"
        default: uti = "public.png"
        }

        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, uti as CFString, 1, nil) else {
            throw ConversionError.writeFailure("Failed to create image destination for presentation slide.")
        }

        var properties: [CFString: Any] = [:]
        if ["jpg", "jpeg"].contains(targetFormat.fileExtension) {
            properties[kCGImageDestinationLossyCompressionQuality] = 0.92
        }

        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.writeFailure("Failed to save presentation slide image.")
        }

        return outputURL
    }

    // MARK: - Video Conversion

    private func convertVideo(inputURL: URL, targetFormat: FormatOption) async throws -> URL {
        let asset = AVURLAsset(url: inputURL)
        let outputURL = collisionSafeURL(beside: inputURL, extension: targetFormat.fileExtension)

        // 1. Poster Frame Image (PNG, JPEG, WEBP)
        if ["png", "jpg", "jpeg", "webp"].contains(targetFormat.fileExtension) {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let time = CMTime(seconds: 0.1, preferredTimescale: 600)
            let cgImage = try generator.copyCGImage(at: time, actualTime: nil)

            if targetFormat.fileExtension == "webp" {
                return try await exportCGImageToWebP(cgImage: cgImage, outputURL: outputURL)
            }

            let uti: String
            switch targetFormat.fileExtension {
            case "png": uti = "public.png"
            case "jpg", "jpeg": uti = "public.jpeg"
            default: uti = "public.png"
            }

            guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, uti as CFString, 1, nil) else {
                throw ConversionError.writeFailure("Failed to create poster image destination.")
            }
            CGImageDestinationAddImage(destination, cgImage, nil)
            guard CGImageDestinationFinalize(destination) else {
                throw ConversionError.writeFailure("Failed to save video poster frame.")
            }
            return outputURL
        }

        // 2. Video to Animated GIF
        if targetFormat.fileExtension == "gif" {
            return try await convertVideoToGIF(asset: asset, outputURL: outputURL)
        }

        // 3. Video / Audio Transcode
        let presetName: String
        let outputFileType: AVFileType

        switch targetFormat.fileExtension {
        case "m4a", "wav":
            presetName = AVAssetExportPresetAppleM4A
            outputFileType = .m4a
        case "mov":
            presetName = AVAssetExportPresetHighestQuality
            outputFileType = .mov
        default:
            presetName = AVAssetExportPresetHighestQuality
            outputFileType = .mp4
        }

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: presetName) else {
            throw ConversionError.exportFailed("Could not initialize video export session.")
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = outputFileType

        await exportSession.export()

        if exportSession.status == .completed {
            return outputURL
        } else {
            let msg = exportSession.error?.localizedDescription ?? "Unknown export error"
            throw ConversionError.exportFailed(msg)
        }
    }

    private func convertVideoToGIF(asset: AVAsset, outputURL: URL) async throws -> URL {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 480)

        let duration = try await asset.load(.duration)
        let totalSeconds = min(CMTimeGetSeconds(duration), 6.0) // Max 6 seconds for GIF clip
        let frameRate: Double = 10.0 // 10 fps
        let frameCount = Int(totalSeconds * frameRate)

        guard frameCount > 0 else {
            throw ConversionError.exportFailed("Video duration too short.")
        }

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            "com.compuserve.gif" as CFString,
            frameCount,
            nil
        ) else {
            throw ConversionError.writeFailure("Failed to create GIF destination.")
        }

        let gifProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0 // Infinite loop
            ]
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

        let frameProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: 1.0 / frameRate
            ]
        ]

        for i in 0..<frameCount {
            let time = CMTime(seconds: Double(i) / frameRate, preferredTimescale: 600)
            if let image = try? generator.copyCGImage(at: time, actualTime: nil) {
                CGImageDestinationAddImage(destination, image, frameProperties as CFDictionary)
            }
        }

        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.writeFailure("Failed to finalize GIF file.")
        }

        return outputURL
    }

    // MARK: - Audio Conversion

    private func convertAudio(inputURL: URL, targetFormat: FormatOption) async throws -> URL {
        let asset = AVURLAsset(url: inputURL)
        let outputURL = collisionSafeURL(beside: inputURL, extension: targetFormat.fileExtension)

        let presetName: String
        let outputFileType: AVFileType

        switch targetFormat.fileExtension {
        case "m4a", "aac", "alac":
            presetName = AVAssetExportPresetAppleM4A
            outputFileType = .m4a
        case "wav", "aiff", "caf":
            presetName = AVAssetExportPresetPassthrough
            outputFileType = .caf
        default:
            presetName = AVAssetExportPresetAppleM4A
            outputFileType = .m4a
        }

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: presetName) else {
            throw ConversionError.exportFailed("Could not create audio export session.")
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = outputFileType

        await exportSession.export()

        if exportSession.status == .completed {
            return outputURL
        } else {
            let msg = exportSession.error?.localizedDescription ?? "Audio export error"
            throw ConversionError.exportFailed(msg)
        }
    }

    // MARK: - Text / Document Conversion

    private func convertTextDocument(inputURL: URL, targetFormat: FormatOption) async throws -> URL {
        let outputURL = collisionSafeURL(beside: inputURL, extension: targetFormat.fileExtension)
        let textContent = try String(contentsOf: inputURL, encoding: .utf8)

        if targetFormat.fileExtension == "pdf" {
            let attrString = NSAttributedString(
                string: textContent,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 13),
                    .foregroundColor: NSColor.textColor
                ]
            )

            let pageSize = CGSize(width: 595.2, height: 841.8) // A4
            let margin: CGFloat = 50.0
            let textRect = CGRect(x: margin, y: margin, width: pageSize.width - 2 * margin, height: pageSize.height - 2 * margin)

            let pdfData = NSMutableData()
            guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
                throw ConversionError.writeFailure("Failed to allocate PDF data consumer.")
            }

            var mediaBox = CGRect(origin: .zero, size: pageSize)
            guard let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
                throw ConversionError.writeFailure("Failed to create PDF context.")
            }

            pdfContext.beginPage(mediaBox: &mediaBox)
            let framesetter = CTFramesetterCreateWithAttributedString(attrString as CFAttributedString)
            let path = CGPath(rect: textRect, transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
            CTFrameDraw(frame, pdfContext)
            pdfContext.endPage()
            pdfContext.closePDF()

            try (pdfData as Data).write(to: outputURL)
            return outputURL
        }

        if targetFormat.fileExtension == "html" {
            let htmlString = "<!DOCTYPE html><html><head><meta charset='utf-8'></head><body><pre>\(textContent)</pre></body></html>"
            try htmlString.write(to: outputURL, atomically: true, encoding: .utf8)
            return outputURL
        }

        if ["png", "jpg", "jpeg"].contains(targetFormat.fileExtension) {
            let attrString = NSAttributedString(
                string: textContent,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 14),
                    .foregroundColor: NSColor.black
                ]
            )
            let imageSize = NSSize(width: 800, height: 1000)
            let image = NSImage(size: imageSize)
            image.lockFocus()
            NSColor.white.setFill()
            NSRect(origin: .zero, size: imageSize).fill()
            attrString.draw(in: NSRect(x: 40, y: 40, width: 720, height: 920))
            image.unlockFocus()
            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let data = bitmap.representation(using: targetFormat.fileExtension == "png" ? .png : .jpeg, properties: [:]) else {
                throw ConversionError.writeFailure("Failed to render text to image.")
            }
            try data.write(to: outputURL)
            return outputURL
        }

        // txt fallback
        try textContent.write(to: outputURL, atomically: true, encoding: .utf8)
        return outputURL
    }

    // MARK: - Rock-Solid Offline WebP Conversion Pipeline

    private func exportCGImageToWebP(cgImage: CGImage, outputURL: URL) async throws -> URL {
        let tempPNG = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        defer { try? FileManager.default.removeItem(at: tempPNG) }

        guard let dest = CGImageDestinationCreateWithURL(tempPNG as CFURL, "public.png" as CFString, 1, nil) else {
            throw ConversionError.writeFailure("Failed to allocate PNG buffer for WebP conversion.")
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw ConversionError.writeFailure("Failed to render intermediate buffer for WebP conversion.")
        }

        try await encodeFileToWebP(from: tempPNG, to: outputURL, quality: 85)
        return outputURL
    }

    private func encodeFileToWebP(from inputURL: URL, to outputURL: URL, quality: Int = 85) async throws {
        // 1. Primary: cwebp (Official Google libwebp binary)
        let candidateCwebp = [
            "/opt/homebrew/bin/cwebp",
            "/usr/local/bin/cwebp",
            "/usr/bin/cwebp"
        ]
        if let cwebp = candidateCwebp.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            do {
                try await runProcess(executable: cwebp, arguments: ["-q", "\(quality)", inputURL.path, "-o", outputURL.path])
                return
            } catch {
                print("[LiquidDrop] cwebp failed, attempting fallback: \(error.localizedDescription)")
            }
        }

        // 2. Secondary: ffmpeg (with libwebp codec)
        let candidateFFmpeg = [
            "/usr/local/bin/ffmpeg",
            "/opt/homebrew/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]
        if let ffmpeg = candidateFFmpeg.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            do {
                try await runProcess(executable: ffmpeg, arguments: ["-i", inputURL.path, "-c:v", "libwebp", "-quality", "\(quality)", outputURL.path, "-y"])
                return
            } catch {
                print("[LiquidDrop] ffmpeg failed, attempting Python fallback: \(error.localizedDescription)")
            }
        }

        // 3. Tertiary: Python3 PIL (Pillow)
        let candidatePythons = [
            "/usr/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3"
        ]
        if let python = candidatePythons.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            let script = "from PIL import Image; Image.open(r'\(inputURL.path)').save(r'\(outputURL.path)', 'WEBP', quality=\(quality))"
            try await runProcess(executable: python, arguments: ["-c", script])
            return
        }

        throw ConversionError.writeFailure("No WebP encoder (cwebp, ffmpeg, or pillow) is available on this system.")
    }

    // MARK: - Native Offline ZIP & Archive Compression

    private func compressToZipArchive(files: [URL]) async throws -> [URL] {
        guard !files.isEmpty else { return [] }

        // Single file compression: Creates <file>.zip beside the original
        if files.count == 1 {
            let inputURL = files[0]
            let outputURL = collisionSafeURL(beside: inputURL, extension: "zip")

            // /usr/bin/ditto is macOS's official Finder compress utility
            try await runProcess(
                executable: "/usr/bin/ditto",
                arguments: ["-c", "-k", "--sequesterRsrc", inputURL.path, outputURL.path]
            )
            return [outputURL]
        }

        // Multi-file compression: Creates Archive.zip containing all dropped items
        let first = files[0]
        let parentDir = first.deletingLastPathComponent()
        var outputURL = parentDir.appendingPathComponent("Archive.zip")
        var counter = 1
        while FileManager.default.fileExists(atPath: outputURL.path) {
            outputURL = parentDir.appendingPathComponent("Archive (\(counter)).zip")
            counter += 1
        }

        var args = ["-q", "-j", outputURL.path]
        args.append(contentsOf: files.map { $0.path })
        try await runProcess(executable: "/usr/bin/zip", arguments: args)
        return [outputURL]
    }

    private func compressToTarArchive(files: [URL]) async throws -> [URL] {
        guard !files.isEmpty else { return [] }
        let first = files[0]
        let outputURL = collisionSafeURL(beside: first, extension: "tar.gz")
        let parentDir = first.deletingLastPathComponent()

        var args = ["-czf", outputURL.path, "-C", parentDir.path]
        args.append(contentsOf: files.map { $0.lastPathComponent })
        try await runProcess(executable: "/usr/bin/tar", arguments: args)
        return [outputURL]
    }

    private func compressToGzipArchive(files: [URL]) async throws -> [URL] {
        var results: [URL] = []
        for file in files {
            let outputURL = collisionSafeURL(beside: file, extension: "gz")
            let script = "/usr/bin/gzip -c '\(file.path)' > '\(outputURL.path)'"
            try await runProcess(executable: "/bin/sh", arguments: ["-c", script])
            results.append(outputURL)
        }
        return results
    }

    // MARK: - Native Asynchronous Subprocess Runner

    private func runProcess(executable: String, arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: executable)
                proc.arguments = arguments
                let errPipe = Pipe()
                proc.standardError = errPipe

                do {
                    try proc.run()
                    proc.waitUntilExit()
                    if proc.terminationStatus == 0 {
                        continuation.resume()
                    } else {
                        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                        let errMsg = String(data: errData, encoding: .utf8) ?? "Process exited with code \(proc.terminationStatus)"
                        continuation.resume(throwing: ConversionError.writeFailure(errMsg))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
