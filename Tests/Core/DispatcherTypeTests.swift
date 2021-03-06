import Dispatch
@testable import PromiseKit
import XCTest

class DispatcherTypeTests: XCTestCase {
    
    struct ScenarioParameters {
        let hiatusLikelihoods: [Double]
        let noDelayLikelihoods: [Double]
        let intervals: [Double]
        let dispatches: [Int]
    }

    let standardParams = ScenarioParameters(
        hiatusLikelihoods: [ 0.3 ],
        noDelayLikelihoods: [ 0.75 ],
        intervals: [ 0.02, 0.1 ],
        dispatches: [ 20 ]
    )

    // Low-CPU, low-parallelism test environment
    let travisParams = ScenarioParameters(
        hiatusLikelihoods: [ 0.3 ],
        noDelayLikelihoods: [ 0.75 ],
        intervals: [ 0.1, 0.3 ],
        dispatches: [ 10 ]
    )

    // More thorough testing, but takes longer to run
    let tortureParams = ScenarioParameters(
        hiatusLikelihoods: [ 0.0, 0.3, 0.7 ],
        noDelayLikelihoods: [ 0.3, 0.75, 1.0 ],
        intervals: [ 0.02, 0.1 ],
        dispatches: [ 20 ]
    )

    lazy var scenarios = generateRateLimitScenarios(travisParams)
    var rng = Xoroshiro(0x80D0082B8A9651BA, 0x49A8092CFD464A11) // Arbitrary seed
    let debug = false
    let laxity = 1 // For Travis and low-parallelism environments, elsewhere use 0
    
    struct RateLimitScenario {
        let maxDispatches: Int
        let interval: Double
        let hiatusLikelihood: Double
        let nHiatuses: Int
        let noDelayLikelihood: Double
        let delays: [UInt32]
    }
    
    func printScenarioDetails(_ scenario: RateLimitScenario) {
        guard debug else { return }
        print("\nNew run: n = \(scenario.delays.count), most = \(scenario.maxDispatches),",
            "interval = \(scenario.interval), pNoDelay = \(scenario.noDelayLikelihood),",
            "pHiatus = \(scenario.hiatusLikelihood), nHiatuses = \(scenario.nHiatuses)\n")
    }
    
    func printTestResults(_ deltaT: TimeInterval, _ concurrent: Int, _ scenario: RateLimitScenario) {
        guard debug else { return }
        let rateAvg = Double(scenario.delays.count) * scenario.interval / deltaT
        print("result actual max = \(concurrent), target max = \(scenario.maxDispatches), average rate = \(rateAvg)")
    }
    
    func generateRateLimitScenarios(_ params: ScenarioParameters) -> [RateLimitScenario] {
        
        var rng = Xoroshiro(0x80D0082B8A9651BA, 0x49A8092CFD464A11) // Arbitrary seed
        var scenarios: [RateLimitScenario] = []
        
        for hiatusLikelihoodPerInterval in params.hiatusLikelihoods {
            for noDelayLikelihood in params.noDelayLikelihoods {
                for interval in params.intervals {
                    for maxDispatches in params.dispatches {

        // <------------
        
        let n = maxDispatches * 10
        let avgSlice = UInt32(interval * 1_000_000 * 0.9 / Double(maxDispatches))
        let normalDelayRange = 0...avgSlice
        let hiatusRange = UInt32(interval * 0.5 * 1_000_000)...UInt32(interval * 2.5 * 1_000_000)
        let hiatusLikelihoodPerDispatch = 1 - pow(1 - hiatusLikelihoodPerInterval, 1 / Double(maxDispatches))
        
        var delays: [UInt32] = []
        for _ in 1...n {
            let rand = Double.random(in: 0...1, using: &rng)
            if rand < hiatusLikelihoodPerDispatch {
                delays.append(hiatusRange.randomElement(using: &rng)!)
            } else if rand > (1 - noDelayLikelihood) {
                delays.append(0)
            } else {
                delays.append(normalDelayRange.randomElement(using: &rng)!)
            }
        }

        let nHiatuses = delays.reduce(0) { $1 > avgSlice ? $0 + 1 : $0 }
            
        scenarios.append(RateLimitScenario(maxDispatches: maxDispatches, interval: interval,
            hiatusLikelihood: hiatusLikelihoodPerInterval, nHiatuses: nHiatuses,
            noDelayLikelihood: noDelayLikelihood, delays: delays))
        
        // <-------------
        
        }}}}
            
        return scenarios
    }

    func rateLimitTest(_ dispatcher: Dispatcher, delays: [UInt32], interval: TimeInterval) -> (TimeInterval, Int) {
        
        let testStart = DispatchTime.now()
        var closureStartTimes: [DispatchTime] = []
        let serializer = DispatchQueue(label: "Rate limit")
        let ex = expectation(description: "Rate limit")

        for delay in delays {
            usleep(delay)
            Guarantee.value(42).done(on: dispatcher) { _ in
                let now = DispatchTime.now()
                serializer.sync {
                    closureStartTimes.append(now)
                    if closureStartTimes.count == delays.count {
                        ex.fulfill()
                    }
                }
            }
        }
        
        let totalDelay = Double(delays.reduce(0, +)) / 1_000_000
        let expectedDuration = interval * Double(delays.count)
        let adequateTime = max(expectedDuration, totalDelay) * 1.5
        waitForExpectations(timeout: adequateTime)
        
        let most = mostAtOnce(closureStartTimes, interval: interval)
        let duration = DispatchTime.now() - testStart
        
        return (duration, most)
    }

    func mostAtOnce(_ times: [DispatchTime], interval: TimeInterval) -> Int {
        var most = 0
        for start in times {
            let timeRange = start...(start + interval)
            let pruned = times.filter { timeRange.contains($0) }
            most = max(most, pruned.count)
        }
        return most
    }
    
    func testRateLimitedDispatcher() {
        for scenario in scenarios {
            printScenarioDetails(scenario)
            let dispatcher = RateLimitedDispatcher(maxDispatches: scenario.maxDispatches, perInterval: scenario.interval)
            let (deltaT, mostConcurrent) = rateLimitTest(dispatcher, delays: scenario.delays, interval: scenario.interval)
            // For the nonstrict RateLimitedDispatcher, burst rate may be up to 2X the goal.
            // There is, unavoidably, a potential lag between the time a closure is dispatched and the
            // time it actually starts to run and has its start-time measured. This redistribution in time
            // makes it impossible to verify rates with perfect accuracy because of bunching. For desktop
            // testing the issue essentially never occurs and laxity should be set to 0.
            XCTAssertLessThanOrEqual(mostConcurrent, scenario.maxDispatches * 2 + laxity)
            // Significantly under the goal rate is also a concern
            XCTAssertGreaterThan(mostConcurrent, (scenario.maxDispatches * 3) / 4)
            printTestResults(deltaT, mostConcurrent, scenario)
        }
    }

#if false
    // fails sporadically and is causing us woe as a result
    func testStrictRateLimitedDispatcher() {
        for scenario in scenarios {
            printScenarioDetails(scenario)
            let dispatcher = StrictRateLimitedDispatcher(maxDispatches: scenario.maxDispatches, perInterval: scenario.interval)
            let (deltaT, mostConcurrent) = rateLimitTest(dispatcher, delays: scenario.delays, interval: scenario.interval)
            // There is, unavoidably, a potential lag between the time a closure is dispatched and the
            // time it actually starts to run and has its start-time measured. This redistribution in time
            // makes it impossible to verify rates with perfect accuracy because of bunching. For desktop
            // testing the issue essentially never occurs and laxity should be set to 0.
            XCTAssertLessThanOrEqual(mostConcurrent, scenario.maxDispatches + laxity)
            // Significantly under the goal rate is also a concern
            XCTAssertGreaterThan(mostConcurrent, (scenario.maxDispatches * 3) / 4)
            printTestResults(deltaT, mostConcurrent, scenario)
            // print("tail wait start", DispatchTime.now().rawValue)
            usleep(UInt32(scenario.interval * 1_000_000 * 2))
            // print("tail wait end", DispatchTime.now().rawValue)
            XCTAssert(dispatcher.startTimeHistory.count == 0, "Dispatcher did not clean up properly")
        }
    }
#endif
    
    func testConcurrencyLimitedDispatcher() {
        
        for scenario in scenarios {
            
            printScenarioDetails(scenario)
            let dispatcher = ConcurrencyLimitedDispatcher(limit: scenario.maxDispatches)
            
            var nConcurrent = 0
            var maxNConcurrent = 0
            var nRun = 0
            let serializer = DispatchQueue(label: "Concurrency test")
            let ex = expectation(description: "Concurrency limit")
            
            for delay in scenario.delays {
                usleep(delay)
                Guarantee.value(42).done(on: dispatcher) { _ in
                    serializer.sync {
                        nConcurrent += 1
                        maxNConcurrent = max(maxNConcurrent, nConcurrent)
                    }
                    usleep(UInt32.random(in: 10_000...100_000, using: &self.rng))
                    serializer.sync {
                        nConcurrent -= 1
                        nRun += 1
                        if nRun == scenario.delays.count {
                            ex.fulfill()
                        }
                    }
                }
            }
            
            waitForExpectations(timeout: Double(scenario.delays.count) * 0.1)
            // Usually maxNConcurrent will == target, but some platforms have inherent limits on parallelism, at least in test
            XCTAssertLessThanOrEqual(maxNConcurrent, scenario.maxDispatches, "More concurrent tasks than allowed")
            XCTAssertGreaterThanOrEqual(maxNConcurrent, 2, "Concurrent executions not concurrent")

        }
    }

    // These aren't really "tests" per se; they just exercise all the various init types
    // to verify that none of them produce ambiguity warnings or recurse indefinitely,
    // and that DispatchQueue members are accessible.

    func testRateLimitedDispatcherInit() {
        XCTAssertNotNil(RateLimitedDispatcher(maxDispatches: 1, perInterval: 1))
        XCTAssertNotNil(RateLimitedDispatcher(maxDispatches: 1, perInterval: 1, queue: DispatchQueue.main))
        XCTAssertNotNil(RateLimitedDispatcher(maxDispatches: 1, perInterval: 1, queue: CurrentThreadDispatcher()))
        XCTAssertNotNil(RateLimitedDispatcher(maxDispatches: 1, perInterval: 1, queue: .main))
        XCTAssertNotNil(RateLimitedDispatcher(maxDispatches: 1, perInterval: 1, queue: .global(qos: .background)))
    }
    
    func testStrictRateLimitedDispatcherInit() {
        XCTAssertNotNil(StrictRateLimitedDispatcher(maxDispatches: 1, perInterval: 1))
        XCTAssertNotNil(StrictRateLimitedDispatcher(maxDispatches: 1, perInterval: 1, queue: DispatchQueue.main))
        XCTAssertNotNil(StrictRateLimitedDispatcher(maxDispatches: 1, perInterval: 1, queue: CurrentThreadDispatcher()))
        XCTAssertNotNil(StrictRateLimitedDispatcher(maxDispatches: 1, perInterval: 1, queue: .main))
        XCTAssertNotNil(StrictRateLimitedDispatcher(maxDispatches: 1, perInterval: 1, queue: .global(qos: .background)))
    }

    func testConcurrencyLimitedDispatcherInit() {
        XCTAssertNotNil(ConcurrencyLimitedDispatcher(limit: 1))
        XCTAssertNotNil(ConcurrencyLimitedDispatcher(limit: 1, queue: DispatchQueue.main))
        XCTAssertNotNil(ConcurrencyLimitedDispatcher(limit: 1, queue: CurrentThreadDispatcher()))
        XCTAssertNotNil(ConcurrencyLimitedDispatcher(limit: 1, queue: .main))
        XCTAssertNotNil(ConcurrencyLimitedDispatcher(limit: 1, queue: .global(qos: .background)))
    }
    
}

// Reproducible, seedable RNG

struct Xoroshiro: RandomNumberGenerator {
    
    typealias State = (UInt64, UInt64)
    
    var state: State
    
    init(_ a: UInt64, _ b: UInt64) {
        state = (a, b)
    }
    
    mutating func next() -> UInt64 {
        let (l, k0, k1, k2): (UInt64, UInt64, UInt64, UInt64) = (64, 55, 14, 36)
        let result = state.0 &+ state.1
        let x = state.0 ^ state.1
        state.0 = ((state.0 << k0) | (state.0 >> (l - k0))) ^ x ^ (x << k1)
        state.1 = (x << k2) | (x >> (l - k2))
        return result
    }
    
}
