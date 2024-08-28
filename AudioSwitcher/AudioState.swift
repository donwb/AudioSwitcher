//
//  AudioState.swift
//  AudioSwitcher
//
//  Created by Don Browning on 4/21/21.
//

import Foundation
import SimplyCoreAudio
import CloudKit


class AudioState {
    // MARK: - private members
    
    private var _sca: SimplyCoreAudio?
    private var _devices = [MyAudioDevice]()
    
    // MARK: - Initializers
    init() {
        _devices = []
        _sca = SimplyCoreAudio()
    }
    
    // MARK: - Statics
    static func LoadAudioEnvironment() -> AudioState{
        let audioState = AudioState()
        let devices = audioState.loadDevices()
        audioState._devices = devices
        
        return audioState
        
    }
    
    // MARK: - Private functions
    private func loadDevices() -> [MyAudioDevice] {
        //_devices.removeAll()
        var myDevices = [MyAudioDevice]()
        let outputDevices = _sca?.allOutputDevices
        for d in outputDevices! {
            let ad = MyAudioDevice(name: d.name, id: d.id, enabled: d.isDefaultOutputDevice)
            myDevices.append(ad)
        }
        
        let sortedDevices = myDevices.sorted{ $0.id < $1.id }
        let sortByEnabled = sortedDevices.sorted{ $0.enabled != $1.enabled }
        
        return sortByEnabled
    }
    
    // MARK: - Public functions
    func reload() {
        let devices = loadDevices()
        self._devices = devices
        
    }
    
    func MakeActiveOutputDevice(device: MyAudioDevice) {
        guard let scaDevices = _sca?.allOutputDevices else {
            fatalError("Can't obtain the list of audio devices from CoreAudio")
            
        }
        
        for d in scaDevices {
            if d.name == device.name {
                d.isDefaultOutputDevice = true
            }
        }
        
        reload()
        
    }
    
    func ChangeDeviceVolue(selectedDevice: MyAudioDevice, volume: Double){
        guard let scaDevices = _sca?.allOutputDevices else {
            fatalError("Can't obtain the list of audio devices from CoreAudio")
            
        }

        let floatVolume = Float(volume)
        
        if let theDevice = findDevice(selectedDevice: selectedDevice) {
            print("setting volume for \(theDevice.name)")
            theDevice.setVolume(floatVolume, channel: 0, scope: .output)
        }
    }
    
    func GetVolumeLevel(selectedDevice: MyAudioDevice) -> Double? {
        guard let scaDevices = _sca?.allOutputDevices else {
            fatalError("Can't obtain the list of audio devices from CoreAudio")
            
        }
        
        if let theDevice = findDevice(selectedDevice: selectedDevice) {
            let vi = theDevice.volumeInfo(channel: 0, scope: .output)
            print(vi)
            
            guard let vi = vi else {
                // fatalError("The volume info returned nil")
                print("The volume info returned nil")
                return nil
            }
            
            guard let theVolume = vi.volume else {
                //fatalError("unable to get the volume from volume info")
                print("unable to get the volume info from VolumeInfo")
                return nil
            }
            
            let viDouble = Double(theVolume)
            
            return viDouble
        }
        
        return nil
        
    }
    
    func IsDeviceMuted(selectedDevice: MyAudioDevice) -> Bool {
        let theDevice = findDevice(selectedDevice: selectedDevice)
        
        let isMuted = theDevice!.isMuted(channel: 0, scope: .output)
        print("Is it muted: \(isMuted)")
        
        return isMuted ?? false
        
    }
    
    func findDevice(selectedDevice: MyAudioDevice) -> AudioDevice? {
        guard let scaDevices = _sca?.allOutputDevices else {
            fatalError("Can't obtain the list of audio devices from CoreAudio")
            
        }
        
        var foundDevice: AudioDevice?
        foundDevice = nil
        
        for device in scaDevices {
            if device.name == selectedDevice.name {
                foundDevice = device
                break
            }
        }
        
        return foundDevice
    }
    
    func RevertToSonos() {
        let d = MyAudioDevice(name: "HIFI DSD", id: 77, enabled: false)
        MakeActiveOutputDevice(device: d)
        
    }
    
    var Devices: [MyAudioDevice] {
        get {
            return _devices
        }
    }
    
    var ActiveOutputDevice: MyAudioDevice? {
        get{
            var active: MyAudioDevice?
            // gotta be a better way no doubt
            for d in _devices{
                if d.enabled == true {
                    active = d
                }
            }
            return active
        }
    }
    
    
}

// MARK: - Structs
struct MyAudioDevice: Codable {
    init(name: String, id: UInt32, enabled: Bool){
        self.name = name
        self.id = id
        self.enabled = enabled
    }
    let name: String
    let id: UInt32
    let enabled: Bool
}
