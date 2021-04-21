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
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var currentDeviceLabel: NSTextField!
    
    @IBOutlet weak var lockDeviceCheckbox: NSButton!
    

    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self

        _audioState = AudioState.LoadAudioEnvironment()
        
        var observer = NotificationCenter.default.addObserver(forName: .defaultOutputDeviceChanged,
                                                               object: nil,
                                                                queue: .main) { (notification) in
            
            
            print("A change happened")
            
            if !self._manualChange {
                print("Do auto change shit")
                // including refresh the list
            }
            
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
        print("Setting: \(selectedDevice)")
    }


    
    @IBAction func revertButton(_ sender: NSButton) {
        _manualChange = true
        
        guard let selectedDevice = _selectedDevice else {return }
        _audioState?.MakeActiveOutputDevice(device: selectedDevice)
        
        tableView.reloadData()
        
        print("Setting \(selectedDevice.name) as default output device")
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
            cellView.textField?.textColor = (enabled ? .green : .red)
            
            return cellView
            
        } else {
            let cellID = NSUserInterfaceItemIdentifier(rawValue: "deviceCell")
            guard let cellView = tableView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView else {return nil}
            
            cellView.textField?.stringValue = device.name ?? "unk"
            cellView.textField?.textColor = (enabled ? .green : .red)
            
            return cellView
        }
    }
   
}

