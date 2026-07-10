//
//  AppLock.swift
//  PreferenceFlow
//

import SwiftUI
import LocalAuthentication

/// Drives the optional app lock: locked state, Face ID / Touch ID / passcode
/// authentication, and a one-shot auto-prompt per lock so a cancelled Face ID
/// doesn't loop forever. The lock uses `.deviceOwnerAuthentication`, which
/// falls back to the device passcode automatically when biometrics fail or
/// aren't enrolled.
@MainActor
@Observable
final class AppLockManager {
    private(set) var isLocked = false
    private(set) var isAuthenticating = false
    private(set) var lastErrorMessage: String?
    private var hasAutoPrompted = false

    /// Locks the app and resets the auto-prompt so the next activation
    /// triggers one authentication attempt.
    func lock() {
        isLocked = true
        hasAutoPrompted = false
        lastErrorMessage = nil
    }

    /// Prompts authentication automatically at most once per lock. Manual
    /// retries go through `authenticate()` via the unlock button.
    func autoAuthenticateIfNeeded() async {
        guard isLocked, !hasAutoPrompted, !isAuthenticating else { return }
        hasAutoPrompted = true
        await authenticate()
    }

    /// Runs Face ID / Touch ID with device-passcode fallback and unlocks on success.
    func authenticate() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        let context = LAContext()
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock your consultant preference profiles."
            )
            if success {
                lastErrorMessage = nil
                withAnimation(.easeOut(duration: 0.25)) { isLocked = false }
            }
        } catch let error as LAError where error.code == .userCancel || error.code == .appCancel || error.code == .systemCancel {
            // User dismissed the prompt — stay locked quietly, no error banner.
        } catch {
            lastErrorMessage = "Couldn't verify — try again or use your device passcode."
        }
    }

    /// Whether the device can authenticate at all (biometrics or passcode set).
    static var canUseDeviceAuthentication: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// The friendly name + SF Symbol for the device's biometry, used in
    /// Settings copy and on the lock screen ("Face ID", "Touch ID", "Passcode").
    static var biometryLabel: (name: String, icon: String) {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return ("Passcode", "lock.fill")
        }
        switch context.biometryType {
        case .faceID: return ("Face ID", "faceid")
        case .touchID: return ("Touch ID", "touchid")
        case .opticID: return ("Optic ID", "opticid")
        default: return ("Passcode", "lock.fill")
        }
    }

    /// A standalone identity check used outside the lock screen (e.g. to
    /// confirm before turning the app lock off). Returns true on success.
    static func verifyIdentity(reason: String) async -> Bool {
        let context = LAContext()
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}

/// Full-screen cover shown while the app is locked. Mirrors the app's teal
/// identity, auto-prompts once, and offers a manual retry button.
struct AppLockScreen: View {
    let manager: AppLockManager

    private var biometry: (name: String, icon: String) { AppLockManager.biometryLabel }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                ZStack {
                    Circle().fill(Theme.heroGradient).frame(width: 96, height: 96)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(spacing: 8) {
                    Text("ORPrep Locked")
                        .font(.title2.weight(.bold))
                    Text("Your consultant profiles stay private on this device.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                if let message = manager.lastErrorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                Spacer()
                Button {
                    Task { await manager.authenticate() }
                } label: {
                    Label("Unlock with \(biometry.name)", systemImage: biometry.icon)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.accent, in: .capsule)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(manager.isAuthenticating)
                .padding(.horizontal, 40)
                .padding(.bottom, 48)
            }
            .frame(maxWidth: 480)
        }
        .task {
            await manager.autoAuthenticateIfNeeded()
        }
    }
}
