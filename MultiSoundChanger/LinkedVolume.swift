import Foundation

/// A common delta preserves the offset between devices, including at either boundary.
enum LinkedVolume {
    static func delta(levels: [Double], requested: Double) -> Double {
        guard !levels.isEmpty, requested.isFinite,
              levels.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { return 0 }
        if requested > 0 { return min(requested, 1 - levels.max()!) }
        return max(requested, -levels.min()!)
    }
}
