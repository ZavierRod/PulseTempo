//
//  MusicKitManager.swift
//  PulseTempo
//
//  Created by Zavier Rodrigues on 11/5/25.
//

import Foundation
import MusicKit
import StoreKit
import UIKit

/// Manages MusicKit authorization and configuration
/// 
/// This singleton class handles all interactions with Apple Music authorization.
/// It provides methods to request access, check authorization status, and
/// determine if the user has an active Apple Music subscription.
///
/// Usage:
/// ```swift
/// MusicKitManager.shared.requestAuthorization { status in
///     if status == .authorized {
///         // User granted access to Apple Music
///     }
/// }
/// ```
final class MusicKitManager {
    
    // MARK: - Singleton
    
    /// Shared instance of MusicKitManager
    /// Using a singleton ensures we have a single source of truth for authorization state
    static let shared = MusicKitManager()
    
    // MARK: - Initialization
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    // MARK: - Authorization
    
    /// Request authorization to access Apple Music
    ///
    /// This method presents the system authorization dialog to the user.
    /// The user can grant or deny access to their Apple Music library and playback control.
    ///
    /// - Parameter completion: Called with the authorization status after user responds
    /// - Note: This must be called from the main thread as it presents UI
    @MainActor
    func requestAuthorization(completion: @escaping (MusicAuthorization.Status) -> Void) {
        // Request authorization asynchronously
        Task {
            let status = await MusicAuthorization.request()
            completion(status)
        }
    }
    
    /// Get the current authorization status without requesting
    ///
    /// Use this to check if you already have authorization before making MusicKit calls.
    /// This does NOT trigger the authorization dialog.
    ///
    /// - Returns: Current authorization status
    var authorizationStatus: MusicAuthorization.Status {
        return MusicAuthorization.currentStatus
    }
    
    /// Check if the user is authorized to access Apple Music
    ///
    /// Convenience property that returns true only if status is .authorized
    ///
    /// - Returns: True if authorized, false otherwise
    var isAuthorized: Bool {
        return authorizationStatus == .authorized
    }
    
    // MARK: - Subscription Status
    
    /// Check if the user has an active Apple Music subscription
    ///
    /// This is important because some MusicKit features require an active subscription.
    /// For example, full track playback requires a subscription, while 30-second previews don't.
    ///
    /// - Returns: True if user has active subscription, false otherwise
    /// - Note: This requires authorization to be granted first
    @MainActor
    func checkSubscriptionStatus() async -> Bool {
        // First check if we're authorized
        guard isAuthorized else {
            return false
        }
        
        // Check subscription status
        do {
            let subscription = try await MusicSubscription.current
            
            // Check if user can play catalog content (requires subscription)
            return subscription.canPlayCatalogContent
        } catch {
            print("Error checking subscription status: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Subscription Options
    
    /// Present the Apple Music subscription UI to the user.
    ///
    /// On iOS 18 and later, this method logs a message recommending the SwiftUI modifier.
    /// On earlier iOS versions, it presents the SKCloudServiceSetupViewController.
    ///
    /// For iOS 18+, prefer using the SwiftUI modifier:
    /// `musicSubscriptionOffer(isPresented:options:onLoadCompletion:)` from MusicKit.
    ///
    /// - Parameter presenter: Optional view controller to present from. If nil, finds top-most controller.
    @MainActor
    func presentSubscriptionOffer(from presenter: UIViewController? = nil) {
        // Check iOS version at runtime
        if #available(iOS 18.0, *) {
            // On iOS 18+, SKCloudServiceSetupViewController is deprecated
            // Log guidance to use SwiftUI modifier instead
            print("⚠️ On iOS 18+, use the SwiftUI musicSubscriptionOffer(isPresented:options:onLoadCompletion:) modifier.")
            print("Example usage:")
            print(".musicSubscriptionOffer(isPresented: $isPresentingOffer,")
            print("                        options: MusicSubscriptionOfferOptions(action: .subscribe)) { loaded, error in")
            print("    // Handle load completion")
            print("}")
        } else {
            // On iOS < 18, use SKCloudServiceSetupViewController
            let setupVC = SKCloudServiceSetupViewController()
            let options: [SKCloudServiceSetupOptionsKey: Any] = [
                .action: SKCloudServiceSetupAction.subscribe
            ]

            setupVC.load(options: options) { [weak self] loaded, error in
                if let error = error {
                    print("Error loading Apple Music subscription UI: \(error.localizedDescription)")
                    return
                }
                guard loaded else {
                    print("Failed to load Apple Music subscription UI.")
                    return
                }

                guard let presenter = presenter ?? self?.topMostPresenter() else {
                    print("Unable to find a presenter to show the Apple Music subscription UI.")
                    return
                }
                presenter.present(setupVC, animated: true)
            }
        }
    }
    
    /// Finds the top-most view controller suitable for presentation in the active scene.
    @MainActor
    private func topMostPresenter() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        return topViewController(from: root)
    }
    
    /// Recursively finds the most visible view controller starting from a root.
    private func topViewController(from root: UIViewController) -> UIViewController {
        if let nav = root as? UINavigationController, let visible = nav.visibleViewController {
            return topViewController(from: visible)
        }
        if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(from: selected)
        }
        if let presented = root.presentedViewController {
            return topViewController(from: presented)
        }
        return root
    }
}

// MARK: - MusicKit Errors

/// Custom errors for MusicKit operations
enum MusicKitError: LocalizedError {
    /// User denied authorization to access Apple Music
    case authorizationDenied
    
    /// User doesn't have an active Apple Music subscription
    case noSubscription
    
    /// The requested music item was not found
    case itemNotFound
    
    /// Playback failed for an unknown reason
    case playbackFailed
    
    /// The user's music library is empty or unavailable
    case libraryUnavailable
    
    /// A custom error with a specific message
    case custom(String)
    
    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Access to Apple Music was denied. Please grant permission in Settings."
        case .noSubscription:
            return "An active Apple Music subscription is required for this feature."
        case .itemNotFound:
            return "The requested music item could not be found."
        case .playbackFailed:
            return "Music playback failed. Please try again."
        case .libraryUnavailable:
            return "Your music library is unavailable. Please check your connection."
        case .custom(let message):
            return message
        }
    }
}

