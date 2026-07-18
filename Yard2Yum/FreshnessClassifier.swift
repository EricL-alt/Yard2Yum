// FreshnessClassifier.swift
// Yard2Yum — on-device produce quality check for farm listings.
//
// Runs the fresh_rotten_fruit_classifier.tflite model (TensorFlowLiteSwift,
// via CocoaPods — see FRESHNESS_CLASSIFIER_SETUP.md) on a produce photo and
// produces a Fresh Confidence Score in [0, 1], bucketed into four categories.
//
// The TensorFlowLite import is compile-time optional so the project still
// builds before `pod install` has been run or on machines without the pod;
// in that case classification returns nil and the UI degrades gracefully.

import SwiftUI
import UIKit
#if canImport(TensorFlowLite)
import TensorFlowLite
#endif

// MARK: - Fresh Confidence Score Categories
//
// Thresholds were calibrated on the validation set for a ~25% distribution
// per band (Red 90 / Orange 90 / Yellow 89 / Green 90 images).
enum FreshnessCategory: String, CaseIterable, Identifiable {
    case red, orange, yellow, green
    var id: String { rawValue }

    init(score: Double) {
        switch score {
        case ..<0.0131: self = .red
        case ..<0.3116: self = .orange
        case ..<0.8753: self = .yellow
        default:        self = .green
        }
    }

    var title: String {
        switch self {
        case .red:    return "High Risk"
        case .orange: return "Low Risk"
        case .yellow: return "Probably Fine"
        case .green:  return "Totally Fresh"
        }
    }

    var colorName: String {
        switch self {
        case .red:    return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green:  return "Green"
        }
    }

    var rangeText: String {
        switch self {
        case .red:    return "0.00 – 0.0131"
        case .orange: return "0.0131 – 0.3116"
        case .yellow: return "0.3116 – 0.8753"
        case .green:  return "0.8753 – 1.00"
        }
    }

    var color: Color {
        switch self {
        case .red:    return Color(red: 0.95, green: 0.35, blue: 0.30)
        case .orange: return Color(red: 0.95, green: 0.58, blue: 0.35)
        case .yellow: return Color(red: 0.94, green: 0.85, blue: 0.54)
        case .green:  return Color.y2yAccent
        }
    }
}

// MARK: - Classifier

final class FreshnessClassifier {

    /// Shared instance; nil when the TFLite pod or the bundled model is unavailable.
    static let shared = FreshnessClassifier()

    static let modelName = "fresh_rotten_fruit_classifier"

    /// Runs classification off the main thread.
    /// Returns the Fresh Confidence Score in [0, 1], or nil if the model
    /// (or the TensorFlowLite pod) is unavailable or inference fails.
    static func classifyInBackground(image: UIImage) async -> Double? {
        await Task.detached(priority: .userInitiated) {
            shared?.freshConfidenceScore(for: image)
        }.value
    }

#if canImport(TensorFlowLite)
    private let interpreter: Interpreter

    init?() {
        guard let modelPath = Bundle.main.path(forResource: Self.modelName, ofType: "tflite") else {
            print("FreshnessClassifier: \(Self.modelName).tflite not found in bundle.")
            return nil
        }
        do {
            interpreter = try Interpreter(modelPath: modelPath)
            try interpreter.allocateTensors()
        } catch {
            print("FreshnessClassifier: failed to create interpreter: \(error.localizedDescription)")
            return nil
        }
    }

    func freshConfidenceScore(for image: UIImage) -> Double? {
        do {
            let inputShape = try interpreter.input(at: 0).shape.dimensions
            // Expected shape: [1, height, width, 3]
            let height = inputShape.count > 2 ? inputShape[1] : 128
            let width  = inputShape.count > 2 ? inputShape[2] : 128

            guard let inputData = Self.rgbFloatData(from: image, width: width, height: height) else {
                print("FreshnessClassifier: failed to preprocess image.")
                return nil
            }

            try interpreter.copy(inputData, toInputAt: 0)
            try interpreter.invoke()

            let outputTensor = try interpreter.output(at: 0)
            let probabilities = outputTensor.data.toArray(type: Float32.self)
            guard !probabilities.isEmpty else { return nil }

            // Class order matches training labels ["fresh", "rotten"]: with two
            // outputs index 0 is the "fresh" probability; a single sigmoid
            // output is already the fresh confidence.
            let score = Double(probabilities[0])
            return min(max(score, 0.0), 1.0)
        } catch {
            print("FreshnessClassifier: inference failed: \(error.localizedDescription)")
            return nil
        }
    }
#else
    // TensorFlowLite pod not installed — classifier unavailable.
    init?() { return nil }
    func freshConfidenceScore(for image: UIImage) -> Double? { nil }
#endif

    /// Draws the image into a width×height RGBA context (resizing it in the
    /// process), then packs normalized [0, 1] Float32 RGB values in row-major
    /// order — matching the model's training preprocessing.
    static func rgbFloatData(from image: UIImage, width: Int, height: Int) -> Data? {
        guard let cgImage = image.cgImage, width > 0, height > 0 else { return nil }
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var rawBytes = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &rawBytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var floats = [Float32]()
        floats.reserveCapacity(width * height * 3)
        for row in 0..<height {
            for col in 0..<width {
                let offset = row * bytesPerRow + col * bytesPerPixel
                floats.append(Float32(rawBytes[offset])     / 255.0)
                floats.append(Float32(rawBytes[offset + 1]) / 255.0)
                floats.append(Float32(rawBytes[offset + 2]) / 255.0)
            }
        }
        return floats.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}

extension Data {
    func toArray<T>(type: T.Type) -> [T] {
        withUnsafeBytes { ptr in
            Array(UnsafeBufferPointer(
                start: ptr.baseAddress!.assumingMemoryBound(to: T.self),
                count: count / MemoryLayout<T>.stride
            ))
        }
    }
}

// MARK: - Freshness Badge (shared UI)

struct FreshnessBadge: View {
    let score: Double
    var compact: Bool = false

    private var category: FreshnessCategory { FreshnessCategory(score: score) }

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(category.color).frame(width: 8, height: 8)
            Text(compact ? category.title : "\(category.colorName) · \(category.title)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(category.color)
            Text(String(format: "%.2f", score))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(Color.y2ySubtext)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(category.color.opacity(0.12))
        .clipShape(Capsule())
    }
}
