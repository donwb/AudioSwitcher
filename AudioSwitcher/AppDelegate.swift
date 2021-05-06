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
    
    // referencing this tutorial for pushing app to menubar
    // https://www.appcoda.com/macos-status-bar-apps/
    @IBOutlet weak var menu: NSMenu?
    @IBOutlet weak var firstMenuItem: NSMenuItem?
    
    @IBAction func showPreferences(_ sender: Any) {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let vc = storyboard.instantiateController(withIdentifier: .init(stringLiteral: "preferencesID")) as? ViewController else
            { return }
        
        let window = NSWindow(contentViewController: vc)
        window.makeKeyAndOrderFront(nil)
        
        
        
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        //statusItem?.button?.title = "Audio Switcher"
        let itemImage = NSImage(named: "plug")
        itemImage?.isTemplate = true
        statusItem?.button?.image = itemImage
        
        
        if let menu = menu {
            statusItem?.menu = menu
        }
    }

}

