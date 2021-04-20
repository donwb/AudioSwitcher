//
//  ViewController.swift
//  AudioSwitcher
//
//  Created by Don Browning on 4/20/21.
//

import Cocoa
import SimplyCoreAudio

class ViewController: NSViewController {

    
    private var _sca: SimplyCoreAudio?
    private var _currentDevices =  [AudioDevice]()
    private var _selectedDevice: AudioDevice?
    
    @IBOutlet weak var tableView: NSTableView!
    
    

    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
        
        // Do any additional setup after loading the view.
        _sca = SimplyCoreAudio()
        loadDevices()
        
        
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
        let selectedDevice = _currentDevices[selItem]
        
        _selectedDevice = selectedDevice
        
        print("Setting: \(selectedDevice)")
    }


    
    @IBAction func revertButton(_ sender: NSButton) {
        
        guard let selDevice = _selectedDevice else { return }
        
        let outputDevices = _sca?.allOutputDevices
        
        for device in outputDevices! {
            if device.name == selDevice.name {
                device.isDefaultOutputDevice = true
            }
        }
        loadDevices()
        
        
        tableView.reloadData()
        
        print("Set \(selDevice.name) as default output device")
        
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
        return _currentDevices.count
    }
}

extension ViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let device = _currentDevices[row]
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
        
//        return nil
    }
    
    private func loadDevices() {
        _currentDevices.removeAll()
        
        let outputDevices = _sca?.allOutputDevices
        for d in outputDevices! {
            let ad = AudioDevice(name: d.name, id: d.id, enabled: d.isDefaultOutputDevice)
            _currentDevices.append(ad)
        }
        
    }
}

struct AudioDevice: Codable {
    init(name: String, id: UInt32, enabled: Bool){
        self.name = name
        self.id = id
        self.enabled = enabled
    }
    let name: String
    let id: UInt32
    let enabled: Bool
}
