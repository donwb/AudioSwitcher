//
//  ViewController.swift
//  AudioSwitcher
//
//  Created by Don Browning on 4/20/21.
//

import Cocoa
import SimplyCoreAudio

class ViewController: NSViewController {

    
    //private var _sca: SimplyCoreAudio?
    //private var _currentDevices =  [AudioDevice]()
    private var _selectedDevice: AudioDevice?
    private var _audioState: AudioState?
    
    private var _manualChange = false
    private var _preventChange = true
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var currentDeviceLabel: NSTextField!
    @IBOutlet weak var stickyCheckbox: NSButton!
    
    @IBOutlet weak var lockDeviceCheckbox: NSButton!
    

    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self

        _audioState = AudioState.LoadAudioEnvironment()
        guard let device = _audioState?.ActiveOutputDevice else {return}
        
        currentDeviceLabel.stringValue = device.name
        
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
            
        }

        
        
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        tableView.reloadData()
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
        print("Setting: \(selectedDevice!)")
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
    
    func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

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

