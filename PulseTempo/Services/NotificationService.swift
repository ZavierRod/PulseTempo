//
//  NotificationService.swift
//  PulseTempo
//
//  Created on 1/20/26.
//
//  Manages local notifications for workout sync between Watch and iPhone.
//

import Foundation
import UserNotifications
import Combine

/// Manages local notifications for bidirectional workout sync
class NotificationService: NSObject, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = NotificationService()
    
    // MARK: - Constants
    
    static let workoutRequestCategory = "WORKOUT_REQUEST"
    static let startWorkoutAction = "START_WORKOUT"
    static let dismissAction = "DISMISS"
    
    // MARK: - Published Properties
    
    /// Whether notification permission is granted
    @Published var isAuthorized: Bool = false
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
    }
    
    // MARK: - Setup
    
    /// Request notification permission and register categories
    func requestPermission(completion: ((Bool) -> Void)? = nil) {
        let center = UNUserNotificationCenter.current()
        
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                
                if granted {
                    self?.registerNotificationCategories()
                    print("✅ [iOS] Notification permission granted")
                } else {
                    print("❌ [iOS] Notification permission denied: \(error?.localizedDescription ?? "Unknown")")
                }
                
                completion?(granted)
            }
        }
    }
    
    /// Register notification categories with actions
    private func registerNotificationCategories() {
        let startAction = UNNotificationAction(
            identifier: Self.startWorkoutAction,
            title: "Start Workout",
            options: [.foreground]
        )
        
        let dismissAction = UNNotificationAction(
            identifier: Self.dismissAction,
            title: "Not Now",
            options: []
        )
        
        let workoutCategory = UNNotificationCategory(
            identifier: Self.workoutRequestCategory,
            actions: [startAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([workoutCategory])
        print("📋 [iOS] Registered notification categories")
    }
    
    // MARK: - Post Notifications
    
    /// Post a local notification when watch requests workout start
    func postWorkoutRequestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "PulseTempo"
        content.body = "Your Apple Watch wants to start a workout. Tap to begin!"
        content.sound = .default
        content.categoryIdentifier = Self.workoutRequestCategory
        
        // Add custom data
        content.userInfo = [
            "type": "workoutRequest",
            "source": "watch"
        ]
        
        // Trigger immediately
        let request = UNNotificationRequest(
            identifier: "workout-request-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ [iOS] Failed to post notification: \(error.localizedDescription)")
            } else {
                print("🔔 [iOS] Posted workout request notification")
            }
        }
    }
    
    /// Clear any pending workout request notifications
    func clearWorkoutRequestNotifications() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: ["workout-request"]
        )
        // Also remove any with the timestamp pattern
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let workoutNotificationIds = notifications
                .filter { $0.request.identifier.hasPrefix("workout-request-") }
                .map { $0.request.identifier }
            
            UNUserNotificationCenter.current().removeDeliveredNotifications(
                withIdentifiers: workoutNotificationIds
            )
        }
        print("🧹 [iOS] Cleared workout request notifications")
    }
}
