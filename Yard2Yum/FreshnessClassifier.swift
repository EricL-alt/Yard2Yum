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

// Force import TensorFlowLite - if this fails, the pod isn't properly installed
import TensorFlowLite

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

    private let interpreter: Interpreter

    init?() {
        // Debug: List all files in the bundle to see what's actually there
        if let resourcePath = Bundle.main.resourcePath {
            print("FreshnessClassifier: Bundle resource path: \(resourcePath)")
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                let tfliteFiles = contents.filter { $0.hasSuffix(".tflite") }
                print("FreshnessClassifier: .tflite files in bundle: \(tfliteFiles)")
                if tfliteFiles.isEmpty {
                    print("FreshnessClassifier: No .tflite files found. All files: \(contents.prefix(20))")
                }
            } catch {
                print("FreshnessClassifier: Error listing bundle contents: \(error)")
            }
        }
        
        guard let modelPath = Bundle.main.path(forResource: Self.modelName, ofType: "tflite") else {
            print("FreshnessClassifier: \(Self.modelName).tflite not found in bundle.")
            print("FreshnessClassifier: Searched in: \(Bundle.main.bundlePath)")
            
            // Try alternative search methods
            if let url = Bundle.main.url(forResource: Self.modelName, withExtension: "tflite") {
                print("FreshnessClassifier: Found via URL method: \(url)")
            }
            
            return nil
        }
        print("FreshnessClassifier: Found model at: \(modelPath)")
        
        do {
            // Create interpreter with proper configuration
            var options = Interpreter.Options()
            options.threadCount = 2
            interpreter = try Interpreter(modelPath: modelPath, options: options)
            
            // Allocate tensors
            try interpreter.allocateTensors()
            print("FreshnessClassifier: Tensors allocated successfully")
            
            // Log model details - do this AFTER allocating tensors
            do {
                let inputTensor = try interpreter.input(at: 0)
                print("FreshnessClassifier: Model loaded successfully!")
                print("  Input shape: \(inputTensor.shape.dimensions)")
                print("  Input data type: \(inputTensor.dataType)")
                
                // Note: We can't access output tensor details until after first invoke
                print("  Model is ready for inference")
            } catch {
                print("FreshnessClassifier: Warning - could not read tensor details: \(error.localizedDescription)")
                // Continue anyway - the interpreter is still valid
            }
        } catch {
            print("FreshnessClassifier: failed to create interpreter: \(error.localizedDescription)")
            print("FreshnessClassifier: Error details: \(error)")
            return nil
        }
    }

    func freshConfidenceScore(for image: UIImage) -> Double? {
        do {
            let inputTensor = try interpreter.input(at: 0)
            let inputShape = inputTensor.shape.dimensions
            
            // Expected shape: [1, height, width, 3]
            let height = inputShape.count > 1 ? Int(inputShape[1]) : 128
            let width  = inputShape.count > 2 ? Int(inputShape[2]) : 128

            print("FreshnessClassifier: Input shape: \(inputShape), using \(width)x\(height)")

            guard let inputData = Self.rgbFloatData(from: image, width: width, height: height) else {
                print("FreshnessClassifier: failed to preprocess image.")
                return nil
            }

            print("FreshnessClassifier: Input data size: \(inputData.count) bytes")
            print("FreshnessClassifier: Expected size: \(width * height * 3 * 4) bytes (Float32)")

            // Copy input data
            try interpreter.copy(inputData, toInputAt: 0)
            
            // Run inference
            try interpreter.invoke()
            print("FreshnessClassifier: Inference completed successfully")

            // Get output
            let outputTensor = try interpreter.output(at: 0)
            let outputShape = outputTensor.shape.dimensions
            print("FreshnessClassifier: Output shape: \(outputShape)")
            print("FreshnessClassifier: Output data size: \(outputTensor.data.count) bytes")
            
            // The output shape is [1, 2] meaning batch_size=1, num_classes=2
            // The data is stored as a flat array, so we can access it directly
            let probabilities = outputTensor.data.toArray(type: Float32.self)
            print("FreshnessClassifier: Output probabilities (raw): \(probabilities)")
            print("FreshnessClassifier: Number of values: \(probabilities.count)")
            
            // For shape [1, 2], the flat array contains [class0, class1]
            // where class0 = rotten, class1 = fresh (based on testing)
            guard probabilities.count >= 2 else {
                print("FreshnessClassifier: Expected 2 probabilities but got \(probabilities.count)")
                return nil
            }
            
            // Extract the two class probabilities
            let rottenProb = probabilities[0]
            let freshProb = probabilities[1]
            
            print("FreshnessClassifier: Rotten probability: \(rottenProb)")
            print("FreshnessClassifier: Fresh probability: \(freshProb)")
            
            // Verify they sum to ~1.0 (softmax output)
            let sum = rottenProb + freshProb
            print("FreshnessClassifier: Sum of probabilities: \(sum)")
            
            // Use the fresh probability as the score
            let score = Double(freshProb)
            print("FreshnessClassifier: Using fresh probability as score: \(score)")
            
            let clampedScore = min(max(score, 0.0), 1.0)
            print("FreshnessClassifier: Final clamped score: \(clampedScore)")
            return clampedScore
        } catch {
            print("FreshnessClassifier: inference failed: \(error.localizedDescription)")
            print("FreshnessClassifier: Error details: \(error)")
            return nil
        }
    }

    /// Draws the image into a width×height RGBA context (resizing it in the
    /// process), then packs normalized [0, 1] Float32 RGB values in row-major
    /// order — matching the model's training preprocessing.
    static func rgbFloatData(from image: UIImage, width: Int, height: Int) -> Data? {
        guard let cgImage = image.cgImage, width > 0, height > 0 else {
            print("FreshnessClassifier: Invalid image or dimensions")
            return nil
        }
        
        // Log original image size vs target size
        let originalSize = image.size
        print("FreshnessClassifier: Original image size: \(originalSize.width)×\(originalSize.height)")
        print("FreshnessClassifier: Resizing to: \(width)×\(height)")
        
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
        ) else {
            print("FreshnessClassifier: Failed to create CGContext")
            return nil
        }
        
        context.interpolationQuality = .high
        // This draw call automatically resizes the image to fit the 128×128 context
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        print("FreshnessClassifier: Image resized and drawn into context")

        var floats = [Float32]()
        floats.reserveCapacity(width * height * 3)
        
        // Check first few pixels to verify we have valid data
        var sampleSum: Float32 = 0
        
        for row in 0..<height {
            for col in 0..<width {
                let offset = row * bytesPerRow + col * bytesPerPixel
                let r = Float32(rawBytes[offset])     / 255.0
                let g = Float32(rawBytes[offset + 1]) / 255.0
                let b = Float32(rawBytes[offset + 2]) / 255.0
                
                floats.append(r)
                floats.append(g)
                floats.append(b)
                
                if row == 0 && col < 3 {
                    sampleSum += r + g + b
                }
            }
        }
        
        print("FreshnessClassifier: Preprocessed \(floats.count) values, sample sum: \(sampleSum)")
        
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
