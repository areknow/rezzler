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
        
        let config = UnsafeMutablePointer<CGDisplayConfigRef?>.allocate(capacity: 1)
        defer { config.deallocate() }
        
        var error = CGBeginDisplayConfiguration(config)
        guard error == .success else {
            print("Failed to begin display configuration: \(error)")
            return
        }
        
        error = CGConfigureDisplayWithDisplayMode(config.pointee, displayID, targetMode, nil)
        guard error == .success else {
            print("Failed to configure display mode: \(error)")
            CGCancelDisplayConfiguration(config.pointee)
            return
        }
        
        error = CGCompleteDisplayConfiguration(config.pointee, .permanently)
        if error != .success {
            print("Failed to complete display configuration: \(error)")
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
