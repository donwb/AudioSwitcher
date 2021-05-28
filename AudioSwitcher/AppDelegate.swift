//
//  AppDelegate.swift
//  AudioSwitcher
//
//  Created by Don Browning on 4/20/21.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    
    private var statusItem: NSStatusItem?
    var statusView: StatusView?
    var _mainWindowView: ViewController?
    
    var _lastDevice: String?
    var _deviceIsSticky: Bool?
    
    
    // referencing this tutorial for pushing app to menubar
    // https://www.appcoda.com/macos-status-bar-apps/
    // https://betterprogramming.pub/swift-3-creating-a-custom-view-from-a-xib-ecdfe5b3a960
    
    @IBOutlet weak var menu: NSMenu?
    @IBOutlet weak var firstMenuItem: NSMenuItem?
    @IBOutlet weak var showMenuItem: NSMenuItem?
    
    
    
    @IBAction func showPreferences(_ sender: Any) {
        showMainWindow()
        _lastDevice = _mainWindowView?.getCurrentDeviceName()
        _deviceIsSticky = _mainWindowView?.getStickyStatus()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        showMainWindow()
        
        _lastDevice = _mainWindowView?.getCurrentDeviceName()
        _deviceIsSticky = _mainWindowView?.getStickyStatus()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        //statusItem?.button?.title = "Audio Switcher"
        let itemImage = NSImage(named: "plugmenuicon")
        itemImage?.isTemplate = true
        statusItem?.button?.image = itemImage
        
        
        if let menu = menu {
            statusItem?.menu = menu
            menu.autoenablesItems = false
            
            menu.delegate = self
        }
        
        if let item = firstMenuItem {
            statusView = StatusView(frame: NSRect(x:0.0, y: 0.0, width: 250.0, height: 45.0))
            
            item.view = statusView
            
        }
    }
    
    func showMainWindow() {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let mWV = storyboard.instantiateController(withIdentifier: .init(stringLiteral: "preferencesID")) as? ViewController else
            { return }
        _mainWindowView = mWV
        
        
        let window = NSWindow(contentViewController: mWV)
        window.makeKeyAndOrderFront(nil)
        
        showMenuItem?.isEnabled = false
    }

}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        if let lastDevice = _lastDevice {
            statusView?.setLabel(labelName: lastDevice)
            if let sticky = _deviceIsSticky {
                statusView?.setSticky(isStickyOn: sticky)
            }
        } else {
            statusView?.setLabel(labelName: "Cannot get current device name")
        }
    }
    
    func menuDidClose(_ menu: NSMenu) {
        statusView?.setLabel(labelName: "clear")
    }
}
