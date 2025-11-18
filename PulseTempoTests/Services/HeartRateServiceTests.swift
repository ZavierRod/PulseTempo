import XCTest
import Combine
import HealthKit
@testable import PulseTempo

final class HeartRateServiceTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []
    private var service: HeartRateService!

    override func setUp() {
        super.setUp()
        // Use shared HealthKitManager to avoid memory issues
        service = HeartRateService(healthKitManager: .shared)
    }

    override func tearDown() {
        // Stop monitoring to clean up timers and avoid deallocation issues
        service?.stopMonitoring()
        cancellables = []
        service = nil
        super.tearDown()
    }

    func testStartMonitoring_Success() {
        let expectation = expectation(description: "start monitoring")

        service.startMonitoring(useDemoMode: true) { result in
            if case .failure(let error) = result {
                XCTFail("Unexpected failure: \(error)")
            }
            XCTAssertTrue(self.service.isMonitoring)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testStartMonitoring_WithDemoMode() {
        let expectation = expectation(description: "demo mode")

        service.startMonitoring(useDemoMode: true) { result in
            XCTAssertTrue(result.isSuccess)
            XCTAssertTrue(self.service.isDemoMode)
            XCTAssertEqual(self.service.currentHeartRate, 100)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testStopMonitoring() {
        service.startMonitoring(useDemoMode: true) { _ in }
        service.stopMonitoring()

        XCTAssertFalse(service.isMonitoring)
        XCTAssertEqual(service.currentHeartRate, 0)
        XCTAssertFalse(service.isDemoMode)
    }

    func testDemoModeHeartRatePattern() {
        service.startMonitoring(useDemoMode: true) { _ in }

        service.updateDemoHeartRate(elapsedOverride: 30)
        XCTAssertEqual(service.currentDemoPhase, .warmUp)

        service.updateDemoHeartRate(elapsedOverride: 400)
        XCTAssertEqual(service.currentDemoPhase, .steady)

        service.updateDemoHeartRate(elapsedOverride: 650)
        XCTAssertEqual(service.currentDemoPhase, .intense)

        service.updateDemoHeartRate(elapsedOverride: 1200)
        XCTAssertEqual(service.currentDemoPhase, .coolDown)
    }

    func testHeartRatePublisher() {
        let expectation = expectation(description: "heart rate publish")
        var received: [Int] = []

        service.currentHeartRatePublisher
            .sink { value in
                received.append(value)
                if received.count == 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        service.currentHeartRate = 90
        service.currentHeartRate = 110

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(received.suffix(2), [90, 110])
    }

    func testErrorPublisher() {
        enum SampleError: Error { case sample }
        let expectation = expectation(description: "error publish")
        var received: [Error?] = []

        service.errorPublisher
            .sink { error in
                received.append(error)
                if received.compactMap({ $0 }).count == 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        service.error = SampleError.sample

        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(received.contains { $0 is SampleError })
    }

    func testSetDemoHeartRate() {
        service.startMonitoring(useDemoMode: true) { _ in }
        service.setDemoHeartRate(190)
        XCTAssertEqual(service.currentHeartRate, 190)

        service.setDemoHeartRate(20)
        XCTAssertEqual(service.currentHeartRate, 60)
    }
}

private extension Result where Success == Void {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

// NOTE: We cannot create mock HealthKitManager by subclassing due to memory management issues
// Tests use the real shared HealthKitManager singleton with demo mode for HeartRateService
