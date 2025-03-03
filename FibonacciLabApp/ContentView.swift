import SwiftUI
import Charts
import BigInt


@main
struct FibonacciLabApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}


/// A single measurement: which algorithm, for what input n, and how long it took in seconds.
struct DataPoint: Identifiable {
    let id = UUID()
    let input: Int
    let time: Double
    let algorithm: String
}

/// The six algorithms from your lab, each returning a BigInt result except Binet (Double).
enum FibAlgorithm: String, CaseIterable, Identifiable {
    case recursive = "Recursive"
    case binet = "Binet"                // Will remain inaccurate for large n
    case iterative = "Iterative"
    case matrix = "Matrix"
    case fastDoubling = "Fast Doubling"
    case expBySquaring = "Exp. by Squaring"
    
    var id: String { rawValue }
    
    /// Safe input ranges to avoid super-long waits or Binet inaccuracy
    func inputList() -> [Int] {
        switch self {
        case .recursive:
            // Naive recursion is O(2^n). Keep it <= ~30ish
            return [5, 7, 10, 12, 15, 20, 25, 30]
        case .binet:
            // Binet is only valid up to ~70. Past that, it’s wrong.
            return [5, 7, 10, 12, 15, 20, 25, 30, 40, 50, 60, 70]
        case .iterative, .matrix, .fastDoubling, .expBySquaring:
            // These can handle bigger n easily, though naive matrix exponent. can be slow if n is large.
            // Adjust as you like. E.g. from your lab doc:
            return [501, 631, 794, 1000, 1259, 1585, 1995, 2512, 3162, 3981, 5012, 6310, 7943, 10000]
        }
    }
    
    /// Compute fib(n). Binet returns a Double; all others return BigInt.
    /// We'll convert the result to a String just to confirm correctness if needed.
    func computeFib(n: Int) -> String {
        switch self {
        case .recursive:
            return String(fibRecursiveBigInt(n))
        case .binet:
            // Binet is Double-based, inaccurate if n>70
            let val = fibBinetDouble(n)
            return String(val) // might show e.g. 3.484...e+14
        case .iterative:
            return String(fibIterativeBigInt(n))
        case .matrix:
            return String(fibMatrixBigInt(n))
        case .fastDoubling:
            return String(fibFastDoublingBigInt(n))
        case .expBySquaring:
            return String(fibExpBySquaringBigInt(n))
        }
    }
    
    /// Wrapper to measure time, ignoring or not printing the actual big result
    func measureFibTime(n: Int) -> Double {
        measureTime {
            _ = computeFib(n: n)
        }
    }
}

// --------------------------------------------------------------------------------------
// MARK: - Naive Recursive (BigInt)
// --------------------------------------------------------------------------------------

/// A direct translation of naive recursion in Swift, returning BigInt for exact results.
func fibRecursiveBigInt(_ n: Int) -> BigInt {
    if n <= 1 { return BigInt(n) }
    return fibRecursiveBigInt(n - 1) + fibRecursiveBigInt(n - 2)
}

// --------------------------------------------------------------------------------------
// MARK: - Binet in Double
// --------------------------------------------------------------------------------------

/// Binet formula. Only accurate up to ~70.
func fibBinetDouble(_ n: Int) -> Double {
    // If we exceed 70, just return .nan or skip the call
    if n > 70 {
        return Double.nan
    }
    // For small n:
    if n <= 1 { return Double(n) }
    let sqrt5 = sqrt(5.0)
    let phi   = (1 + sqrt5) / 2
    let psi   = (1 - sqrt5) / 2
    return (pow(phi, Double(n)) - pow(psi, Double(n))) / sqrt5
}

// --------------------------------------------------------------------------------------
// MARK: - Iterative (BigInt)
// --------------------------------------------------------------------------------------

func fibIterativeBigInt(_ n: Int) -> BigInt {
    if n <= 1 { return BigInt(n) }
    var a = BigInt(0), b = BigInt(1)
    for _ in 2...n {
        let sum = a + b
        a = b
        b = sum
    }
    return b
}

// --------------------------------------------------------------------------------------
// MARK: - Matrix (BigInt)
// --------------------------------------------------------------------------------------

/// A naive matrix exponentiation that returns fib(n) as a BigInt, exactly.
func fibMatrixBigInt(_ n: Int) -> BigInt {
    if n <= 1 { return BigInt(n) }
    // 2x2 matrix in BigInt
    func multiply(_ m1: [[BigInt]], _ m2: [[BigInt]]) -> [[BigInt]] {
        return [
            [m1[0][0]*m2[0][0] + m1[0][1]*m2[1][0],
             m1[0][0]*m2[0][1] + m1[0][1]*m2[1][1]],
            [m1[1][0]*m2[0][0] + m1[1][1]*m2[1][0],
             m1[1][0]*m2[0][1] + m1[1][1]*m2[1][1]]
        ]
    }
    
    func matrixPower(_ base: [[BigInt]], _ p: Int) -> [[BigInt]] {
        var result: [[BigInt]] = [[1,0],[0,1]] // identity
        var current = base
        var e = p
        while e > 0 {
            if e & 1 == 1 {
                result = multiply(result, current)
            }
            current = multiply(current, current)
            e >>= 1
        }
        return result
    }
    
    let base: [[BigInt]] = [[1,1],[1,0]]
    let powered = matrixPower(base, n-1)
    return powered[0][0] // F(n)
}

// --------------------------------------------------------------------------------------
// MARK: - Fast Doubling (BigInt)
// --------------------------------------------------------------------------------------

func fibFastDoublingBigInt(_ n: Int) -> BigInt {
    /// Returns (F(k), F(k+1)) as BigInt
    func fastDouble(_ k: Int) -> (BigInt, BigInt) {
        if k == 0 {
            return (BigInt(0), BigInt(1))
        }
        let (f_k, f_kPlus1) = fastDouble(k/2)
        let c = f_k * ((2 * f_kPlus1) - f_k)
        let d = f_k * f_k + f_kPlus1 * f_kPlus1
        if k & 1 == 0 {
            return (c, d)
        } else {
            return (d, c + d)
        }
    }
    return fastDouble(n).0
}

// --------------------------------------------------------------------------------------
// MARK: - Exponentiation by Squaring (BigInt)
// --------------------------------------------------------------------------------------

func fibExpBySquaringBigInt(_ n: Int) -> BigInt {
    if n == 0 { return BigInt(0) }
    func helper(_ k: Int) -> (BigInt, BigInt) {
        if k == 0 { return (BigInt(0), BigInt(1)) } // (F(0), F(1))
        let (a, b) = helper(k/2)
        let c = a * ((2 * b) - a)
        let d = a*a + b*b
        if k & 1 == 0 {
            return (c, d)
        } else {
            return (d, c + d)
        }
    }
    return helper(n).0
}

// --------------------------------------------------------------------------------------
// MARK: - measureTime
// --------------------------------------------------------------------------------------

/// Measures how long a block takes in seconds.
func measureTime(_ block: () -> Void) -> Double {
    let start = CFAbsoluteTimeGetCurrent()
    block()
    return CFAbsoluteTimeGetCurrent() - start
}

// --------------------------------------------------------------------------------------
// MARK: - ZoomableChart
// --------------------------------------------------------------------------------------

/// A simple chart of execution times vs. n, with pinch-to-zoom.
struct ZoomableChart: View {
    let dataPoints: [DataPoint]
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        Chart {
            ForEach(dataPoints) { dp in
                LineMark(
                    x: .value("n", dp.input),
                    y: .value("Time (s)", dp.time)
                )
                .foregroundStyle(by: .value("Algorithm", dp.algorithm))
            }
        }
        .chartLegend(.visible)
        .frame(height: 300)
        .scaleEffect(scale)
        .gesture(
            MagnificationGesture()
                .onChanged { val in scale = lastScale * val }
                .onEnded { _ in lastScale = scale }
        )
        .animation(.easeInOut, value: scale)
    }
}

// --------------------------------------------------------------------------------------
// MARK: - SummaryView
// --------------------------------------------------------------------------------------

/// Summarizes for each algorithm: average time, max time, range of n, and each data point.
struct SummaryView: View {
    let dataPoints: [DataPoint]
    
    private var grouped: [String: [DataPoint]] {
        Dictionary(grouping: dataPoints, by: \.algorithm)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(grouped.keys.sorted(), id: \.self) { algo in
                if let points = grouped[algo], !points.isEmpty {
                    let times = points.map { $0.time }
                    let avgTime = times.reduce(0, +) / Double(times.count)
                    let maxTime = times.max() ?? 0
                    let ns = points.map { $0.input }
                    let minN = ns.min() ?? 0
                    let maxN = ns.max() ?? 0
                    
                    Text("\(algo) Algorithm:")
                        .font(.headline)
                    Text("• Average time: \(String(format: "%.6f", avgTime)) s")
                    Text("• Maximum time: \(String(format: "%.6f", maxTime)) s")
                    Text("• Tested n from \(minN) to \(maxN)")
                    
                    ForEach(points.sorted(by: { $0.input < $1.input })) { p in
                        Text("   n = \(p.input) | \(String(format: "%.6e", p.time)) s")
                            .font(.footnote)
                    }
                    Divider()
                }
            }
        }
        .padding(.horizontal)
    }
}

// --------------------------------------------------------------------------------------
// MARK: - ContentView (Main Interface)
// --------------------------------------------------------------------------------------

struct ContentView: View {
    @State private var selected = Dictionary(uniqueKeysWithValues: FibAlgorithm.allCases.map { ($0, false) })
    @State private var dataPoints: [DataPoint] = []
    @State private var isComparing = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 1) Toggles
                    VStack(alignment: .leading) {
                        Text("Select Algorithms:")
                            .font(.headline)
                        ForEach(FibAlgorithm.allCases) { algo in
                            Toggle(algo.rawValue, isOn: Binding(
                                get: { selected[algo] ?? false },
                                set: { selected[algo] = $0 }
                            ))
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                        }
                    }
                    .padding(.horizontal)
                    
                    // 2) Chart
                    ZoomableChart(dataPoints: dataPoints)
                        .padding()
                    
                    // 3) Compare
                    Button(action: compareSelectedAlgorithms) {
                        Text(isComparing ? "Comparing..." : "Compare")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(isComparing || selectedAlgorithms().isEmpty)
                    .padding(.horizontal)
                    
                    // 4) Summary
                    if !dataPoints.isEmpty {
                        SummaryView(dataPoints: dataPoints)
                    }
                    
                    Spacer()
                }
                .navigationTitle("Compare Fibonacci Algos")
            }
        }
    }
    
    private func selectedAlgorithms() -> [FibAlgorithm] {
        selected.compactMap { $1 ? $0 : nil }
    }
    
    /// Times each selected algorithm on its inputList, measuring BigInt-based results (or Binet double).
    func compareSelectedAlgorithms() {
        isComparing = true
        dataPoints.removeAll()
        
        DispatchQueue.global(qos: .userInitiated).async {
            var allPoints = [DataPoint]()
            
            for algo in selectedAlgorithms() {
                let inputs = algo.inputList()
                for n in inputs {
                    let t = algo.measureFibTime(n: n)
                    // If you want to see the actual fib value, do:
                    // let fibValue = algo.computeFib(n: n)
                    // print("\(algo.rawValue) F(\(n)) = \(fibValue)")
                    
                    let dp = DataPoint(input: n, time: t, algorithm: algo.rawValue)
                    allPoints.append(dp)
                }
            }
            let sorted = allPoints.sorted { $0.input < $1.input }
            DispatchQueue.main.async {
                self.dataPoints = sorted
                self.isComparing = false
            }
        }
    }
}
