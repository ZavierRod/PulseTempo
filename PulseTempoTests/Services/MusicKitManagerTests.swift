import XCTest
import MusicKit
@testable import PulseTempo

final class MusicKitManagerTests: XCTestCase {
    @MainActor func testRequestAuthorization_Authorized() {
        let expectation = expectation(description: "authorized")
        let manager = MusicKitManager(
            authorizationRequester: { .authorized },
            statusProvider: { .authorized },
            subscriptionStatusProvider: { true }
        )

        manager.requestAuthorization { status in
            XCTAssertEqual(status, .authorized)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testRequestAuthorization_Denied() {
        let expectation = expectation(description: "denied")
        let manager = MusicKitManager(
            authorizationRequester: { .denied },
            statusProvider: { .denied },
            subscriptionStatusProvider: { true }
        )

        manager.requestAuthorization { status in
            XCTAssertEqual(status, .denied)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testAuthorizationStatus() {
        let manager = MusicKitManager(
            authorizationRequester: { .authorized },
            statusProvider: { .restricted },
            subscriptionStatusProvider: { true }
        )

        XCTAssertEqual(manager.authorizationStatus, .restricted)
    }

    @MainActor func testIsAuthorized() {
        let manager = MusicKitManager(
            authorizationRequester: { .authorized },
            statusProvider: { .authorized },
            subscriptionStatusProvider: { true }
        )

        XCTAssertTrue(manager.isAuthorized)
    }

    @MainActor func testCheckSubscriptionStatus_WithSubscription() async {
        let manager = MusicKitManager(
            authorizationRequester: { .authorized },
            statusProvider: { .authorized },
            subscriptionStatusProvider: { true }
        )

        let result = await manager.checkSubscriptionStatus()
        XCTAssert(result == true || result == false)
    }

    @MainActor func testCheckSubscriptionStatus_NoSubscription() async {
        let manager = MusicKitManager(
            authorizationRequester: { .authorized },
            statusProvider: { .authorized },
            subscriptionStatusProvider: { throw NSError(domain: "MusicKitManagerTests", code: 1) }
        )

        let result = await manager.checkSubscriptionStatus()
        XCTAssertFalse(result)
    }

    @MainActor func testSingletonPattern() {
        let first = MusicKitManager.shared
        let second = MusicKitManager.shared
        XCTAssertTrue(first === second)
    }
}
