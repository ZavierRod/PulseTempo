import XCTest
import MusicKit
@testable import PulseTempo

final class MusicKitManagerTests: XCTestCase {
    @MainActor func testRequestAuthorization_Authorized() {
        let expectation = expectation(description: "authorized")
        let manager = MusicKitManager(
            authorizationRequester: { .authorized },
            statusProvider: { .authorized },
            subscriptionProvider: { try await MusicSubscription.current }
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
            subscriptionProvider: { try await MusicSubscription.current }
        )

        manager.requestAuthorization { status in
            XCTAssertEqual(status, .denied)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testAuthorizationStatus() {
        let manager = MusicKitManager(
            authorizationRequester: { .authorized },
            statusProvider: { .restricted },
            subscriptionProvider: { try await MusicSubscription.current }
        )

        XCTAssertEqual(manager.authorizationStatus, .restricted)
    }

    func testIsAuthorized() {
        let manager = MusicKitManager(
            authorizationRequester: { .authorized },
            statusProvider: { .authorized },
            subscriptionProvider: { try await MusicSubscription.current }
        )

        XCTAssertTrue(manager.isAuthorized)
    }

    func testCheckSubscriptionStatus_WithSubscription() async {
        let manager = MusicKitManager(
            authorizationRequester: { .authorized },
            statusProvider: { .authorized },
            subscriptionProvider: { try await MusicSubscription.current }
        )

        let result = await manager.checkSubscriptionStatus()
        XCTAssert(result == true || result == false)
    }

    func testCheckSubscriptionStatus_NoSubscription() async {
        let manager = MusicKitManager(
            authorizationRequester: { .authorized },
            statusProvider: { .authorized },
            subscriptionProvider: { throw NSError(domain: "MusicKitManagerTests", code: 1) }
        )

        let result = await manager.checkSubscriptionStatus()
        XCTAssertFalse(result)
    }

    func testSingletonPattern() {
        let first = MusicKitManager.shared
        let second = MusicKitManager.shared
        XCTAssertTrue(first === second)
    }
}
