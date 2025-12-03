//
//  rezzlerApp.swift
//  rezzler
//
//  Created by Arnaud Crowther on 12/3/25.
//

import SwiftUI
import AppKit
import CoreGraphics

@main
struct rezzlerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    
    // Target resolutions
    private let resolution1 = (width: 1470, height: 956)
    private let resolution2 = (width: 1710, height: 1112)
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        updateIcon()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            NSApp.terminate(nil)
        } else {
            toggleResolution()
        }
    }
    
    private func toggleResolution() {
        guard let currentMode = CGDisplayCopyDisplayMode(CGMainDisplayID()) else { return }
        
        let currentWidth = currentMode.width
        let currentHeight = currentMode.height
        
        let targetWidth: Int
        let targetHeight: Int
        
        // Determine which resolution to switch to
        if currentWidth == resolution2.width && currentHeight == resolution2.height {
            // Currently at higher res, switch to lower
            targetWidth = resolution1.width
            targetHeight = resolution1.height
        } else {
            // Currently at lower res (or any other), switch to higher
            targetWidth = resolution2.width
            targetHeight = resolution2.height
        }
        
        setResolution(width: targetWidth, height: targetHeight)
        updateIcon()
    }
    
    private func setResolution(width: Int, height: Int) {
        let displayID = CGMainDisplayID()
        
        // Save mouse position as relative coordinates (0.0 to 1.0)
        let mousePos = NSEvent.mouseLocation
        let screenFrame = NSScreen.main?.frame ?? .zero
        let relativeX = mousePos.x / screenFrame.width
        let relativeY = mousePos.y / screenFrame.height
        
        // Pre-calculate target position in new resolution
        let newWidth = CGFloat(width)
        let newHeight = CGFloat(height)
        let targetX = relativeX * newWidth
        let targetY = (1.0 - relativeY) * newHeight
        let targetPoint = CGPoint(x: targetX, y: targetY)
        
        // Get all modes including HiDPI
        let options = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
        guard let modes = CGDisplayCopyAllDisplayModes(displayID, options) as? [CGDisplayMode] else {
            print("Failed to get display modes")
            return
        }
        
        // Find matching HiDPI mode first, then fall back to regular mode
        let matchingMode = modes.first { mode in
            mode.width == width && mode.height == height && mode.pixelWidth > mode.width
        } ?? modes.first { mode in
            mode.width == width && mode.height == height
        }
        
        guard let targetMode = matchingMode else {
            print("Resolution \(width)x\(height) not available")
            showAlert(message: "Resolution \(width)x\(height) is not available on this display.\n\nCheck Xcode console for available modes.")
            return
        }
        
        // Hide cursor and disconnect mouse tracking during transition
        NSCursor.hide()
        CGAssociateMouseAndMouseCursorPosition(0)
        
        let config = UnsafeMutablePointer<CGDisplayConfigRef?>.allocate(capacity: 1)
        defer { config.deallocate() }
        
        var error = CGBeginDisplayConfiguration(config)
        guard error == .success else {
            print("Failed to begin display configuration: \(error)")
            CGAssociateMouseAndMouseCursorPosition(1)
            NSCursor.unhide()
            return
        }
        
        error = CGConfigureDisplayWithDisplayMode(config.pointee, displayID, targetMode, nil)
        guard error == .success else {
            print("Failed to configure display mode: \(error)")
            CGCancelDisplayConfiguration(config.pointee)
            CGAssociateMouseAndMouseCursorPosition(1)
            NSCursor.unhide()
            return
        }
        
        error = CGCompleteDisplayConfiguration(config.pointee, .permanently)
        if error != .success {
            print("Failed to complete display configuration: \(error)")
        }
        
        // Warp immediately, then again after display settles
        CGWarpMouseCursorPosition(targetPoint)
        
        // Small delay to let display fully reconfigure, then finalize cursor position
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            CGWarpMouseCursorPosition(targetPoint)
            CGAssociateMouseAndMouseCursorPosition(1)
            NSCursor.unhide()
        }
    }
    
    private func updateIcon() {
        guard let button = statusItem.button else { return }
        guard let currentMode = CGDisplayCopyDisplayMode(CGMainDisplayID()) else { return }
        
        let currentWidth = currentMode.width
        let currentHeight = currentMode.height
        
        // Show plus (zoom in) when at higher res, minus (zoom out) when at lower res
        if currentWidth == resolution2.width && currentHeight == resolution2.height {
            button.image = NSImage(systemSymbolName: "plus.magnifyingglass", accessibilityDescription: "Zoom In")
        } else {
            button.image = NSImage(systemSymbolName: "minus.magnifyingglass", accessibilityDescription: "Zoom Out")
        }
    }
    
    private func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Resolution Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
