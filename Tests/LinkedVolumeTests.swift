import Foundation

@main
struct LinkedVolumeTests {
    static func check(_ levels: [Double], _ requested: Double, _ expected: [Double]) {
        let delta = LinkedVolume.delta(levels: levels, requested: requested)
        let actual = levels.map { $0 + delta }
        precondition(zip(actual, expected).allSatisfy { abs($0 - $1) < 0.000001 }, "\(actual) != \(expected)")
    }
    static func main() {
        check([0.5, 0.3], 0.05, [0.55, 0.35])
        check([0.98, 0.78], 0.05, [1, 0.8])
        check([1, 0.8], 0.05, [1, 0.8])
        check([1, 0.8], -0.05, [0.95, 0.75])
        check([0.22, 0.02], -0.05, [0.2, 0])
        check([0.2, 0], -0.05, [0.2, 0])
        check([0.49], 0.05, [0.54])
        check([0.7, 0.3], 0.05, [0.75, 0.35]) // manual balance change
        precondition(LinkedVolume.delta(levels: [], requested: 0.05) == 0)
        precondition(LinkedVolume.delta(levels: [.nan], requested: 0.05) == 0)
        var levels = [0.5, 0.3]
        for _ in 0..<30 { let d = LinkedVolume.delta(levels: levels, requested: 0.05); levels = levels.map { $0 + d } }
        precondition(abs(levels[0] - 1) < 0.000001 && abs(levels[1] - 0.8) < 0.000001)
        for _ in 0..<30 { let d = LinkedVolume.delta(levels: levels, requested: -0.05); levels = levels.map { $0 + d } }
        precondition(abs(levels[0] - 0.2) < 0.000001 && abs(levels[1]) < 0.000001)
        print("Linked volume tests passed (12 scenarios).")
    }
}
