//
//  ViewController.swift
//  AudioSwitcher
//
//  Created by Don Browning on 4/20/21.
//

import Cocoa
import SimplyCoreAudio

class ViewController: NSViewController {

// MARK: - private members
    
    //private var _sca: SimplyCoreAudio?
    //private var _currentDevices =  [AudioDevice]()
    private var _selectedDevice: MyAudioDevice?
    private var _audioState: AudioState?
    private var _currentDeviceName: String?
    
    private var _manualChange = false
    private var _preventChange = true
    
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var currentDeviceLabel: NSTextField!
    @IBOutlet weak var stickyCheckbox: NSButton!
    @IBOutlet weak var changeCountLabel: NSTextField!
    
    @IBOutlet weak var enableButton: NSButton!
    @IBOutlet weak var lockDeviceCheckbox: NSButton!
    

// MARK: - overrides
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
        
        resetPlist(doNotOverwrite: true)
        
// TODO: - Sticky Flag
        
        // Need to persist the sticky flag to plist, and recall from there when view loads
        // right now it defaults to true, so it's always set
        // this is because the UI used to always be loaded before it was a menubar app
        // now that the view can be unloaded but it still catch the switch event it looks at the default which is in the storyboard

        _audioState = AudioState.LoadAudioEnvironment()
        guard let device = _audioState?.ActiveOutputDevice else {return}
        
        currentDeviceLabel.stringValue = device.name
        
        
        _currentDeviceName = device.name
        print("Current device name: \(_currentDeviceName)")
        
        var observer = NotificationCenter.default.addObserver(forName: .defaultOutputDeviceChanged,
                                                               object: nil,
                                                                queue: .main) { (notification) in
            
            
            print("A change happened")
            
            if !self._manualChange {
                print("Do auto change shit")
                if self._preventChange {
                   // flip back to the previous default
                    self._audioState?.RevertToSonos()
                }
                
            }
            
            // the list refresh doesn't seem to pick up new devices...
            // but does work when a change occurs in the Sound Settings
            self._audioState?.reload()
            self.tableView.reloadData()
            
            self._manualChange = false
            
            self.incrementCounter()
            let counterVal = self.loadCounter()
            self.changeCountLabel.stringValue = String(counterVal)
        }

        // load counter
        let counterTotal = loadCounter()
        changeCountLabel.stringValue = String(counterTotal)
        
        
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        view.window?.styleMask.remove(.resizable)
        view.window?.styleMask.remove(.miniaturizable)
        //view.window?.center()
        
        tableView.reloadData()
        
        NSApplication.shared.activate(ignoringOtherApps: true)
        
    }
    
    override func viewWillDisappear() {
       
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.showMenuItem?.isEnabled = true
        
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selItem = tableView.selectedRow
        
        let selectedDevice = _audioState?.Devices[selItem]
    
        // hold on to selected device in case they hit the enabled button
        _selectedDevice = selectedDevice
        
        // enable the "enable" button now
        self.enableButton.isEnabled = true
        
        print("Setting: \(selectedDevice!)")
    }


// MARK: - IBActions
    
    @IBAction func testChangeVolume(_ sender: Any) {
        
        // MARK: - TODO Add the volume slider ability
        
        // holy shit, figured it out, but now i need to replace the button with a slider
        // and a call to GetVolumeLevel to set the slider
        // the values are 0..1
        
        _audioState?.ChangeDeviceVolue(selectedDevice: _selectedDevice!, volume: 0.4)
       
        print("Done!")
        
    }
    
    
    @IBAction func revertButton(_ sender: NSButton) {
        _manualChange = true
        
        guard let selectedDevice = _selectedDevice else {return }
        _audioState?.MakeActiveOutputDevice(device: selectedDevice)
        
        tableView.reloadData()
        
        currentDeviceLabel.stringValue = selectedDevice.name
        
        print("Setting \(selectedDevice.name) as default output device")
    }
    
    @IBAction func refreshDeviceList(_ sender: NSButton) {
        _audioState?.reload()
        
        tableView.reloadData()
    }
    
    @IBAction func stickyCheckbox(_ sender: NSButton) {
        _preventChange = (stickyCheckbox.state == .on)
        
        print("Prevent?: \(_preventChange)")
    }
    
    func getCurrentDeviceName() -> String {
        guard let device = _currentDeviceName else {
            return "unable to find device name"
        }
        
        return device
    }
    
    func getStickyStatus() -> Bool {
        let s = _preventChange
        print("StickyStatus: ", s)
        return s
    }
    
    func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
// MARK: - plist functions
    
    func loadCounter() -> Int {
        let res = getPlist()
        let plistDict = res.plistDict
        
        guard let currentTotal = plistDict["total"] as? Int else {
            return -1
        }
        return currentTotal
        
    }
    
    func getPlist() -> (plistDestPath: String, plistDict: NSMutableDictionary) {
        let docsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        let destPath = docsPath.appendingPathComponent("Stats.plist")
    
        let plistDict: NSMutableDictionary = NSMutableDictionary(contentsOfFile: destPath)!
        
        return (destPath, plistDict)
    }
    
    func incrementCounter() {
        let res = getPlist()
        let destPath = res.plistDestPath
        let plistDict = res.plistDict
        
        
        guard var currentTotal = plistDict["total"] as? Int else {
            print("Couldn't get the total from the plist... stopping!")
            return
        }
        
        currentTotal += 1
        plistDict["total"] = currentTotal
        plistDict["lastChange"] = Date()
        
        plistDict.write(toFile: destPath, atomically: true)
    }
    
    func resetPlist(doNotOverwrite: Bool) {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let firstDocPath = paths[0]
        
        guard  let settingsFile = Bundle.main.url(forResource: "Stats", withExtension: ".plist")
        else {
            print("Can't find source file")
            return
        }
        let fileManager = FileManager.default
        do {
            let docsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
            let destPath = docsPath.appendingPathComponent("Stats.plist")
            let destPathURL = URL(fileURLWithPath: destPath)
            
            
            if fileManager.fileExists(atPath: destPath) {
                if doNotOverwrite {
                    print("File  exists... Not forcing, leaving alone")
                    return
                } else {
                    print("File exists, overwriting...")
                    try fileManager.removeItem(atPath: destPath)
                    try fileManager.copyItem(at: settingsFile, to: destPathURL)
                }
            } else {
                print("File doesn't exist, copying new")
                try fileManager.copyItem(at: settingsFile, to: destPathURL)
            }
            
        } catch let error as NSError {
            print("An error occured while trying to copy plist file: ", error)
        }
        
        print(firstDocPath)
    }
   
}

// MARK: - tableview extensions

extension ViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        guard let count = _audioState?.Devices.count else { return 0}
        return count
    }
}

extension ViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        //let device = _currentDevices[row]
        guard let device = _audioState?.Devices[row] else { return nil }
        
        let enabled = device.enabled
        
        if tableColumn?.identifier == NSUserInterfaceItemIdentifier(rawValue: "idColumn") {
            //device.id
            let cellID = NSUserInterfaceItemIdentifier(rawValue: "idCell")
            guard let cellView = tableView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView else {return nil}
            
            cellView.textField?.integerValue = Int(device.id) ?? 0
            cellView.textField?.textColor = (enabled ? .systemGreen : .red)
            cellView.textField?.font = (enabled ? NSFont.boldSystemFont(ofSize: 12.0) : nil)
            
            return cellView
            
        } else {
            let cellID = NSUserInterfaceItemIdentifier(rawValue: "deviceCell")
            guard let cellView = tableView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView else {return nil}
            
            cellView.textField?.stringValue = device.name ?? "unk"
            cellView.textField?.textColor = (enabled ? .systemGreen : .red)
            cellView.textField?.font = (enabled ? NSFont.boldSystemFont(ofSize: 12.0) : nil)
            //cellView.textField?.font = NSFont(name: "Helvetica", size: 12.0)
            
            return cellView
        }
    }
   
}

