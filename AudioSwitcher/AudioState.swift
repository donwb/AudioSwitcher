//
//  AudioState.swift
//  AudioSwitcher
//
//  Created by Don Browning on 4/21/21.
//

import Foundation
import SimplyCoreAudio


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
        guard let scaDevices = _sca?.allOutputDevices else {return}
        
        for d in scaDevices {
            if d.name == device.name {
                d.isDefaultOutputDevice = true
            }
        }
        
        reload()
        
    }
    
    func ChangeDeviceVolue(selectedDevice: MyAudioDevice, volume: Float){
        guard let scaDevices = _sca?.allOutputDevices else { return }

        if let theDevice = findDevice(selectedDevice: selectedDevice) {
            print("setting volume for \(theDevice.name)")
            theDevice.setVolume(volume, channel: 0, scope: .output)
        }
        
        
//
//        for device in scaDevices {
//            if device.name == selectedDevice.name {
//                print("setting volume for \(device.name)")
//
//                //device.setVolume(75, channel: 1 , scope: .output)
//                //let retVal = device.setMute(true, channel: 2, scope: .output)
//                //print("Return: \(retVal)")
//
//                let isMuted = device.isMuted(channel: 51, scope: .output)
//                print("Is it muted: \(isMuted)")
//
//                print("\n")
//                let vi = device.volumeInfo(channel: 0, scope: .output)
//                print(vi)
//                device.setVolume(0.8, channel: 0, scope: .output)
//
//
//
//            }
//        }
    }
    
    func GetVolumeLevel(selectedDevice: MyAudioDevice) -> Double? {
        guard let scaDevices = _sca?.allOutputDevices else { return nil }
        
        if let theDevice = findDevice(selectedDevice: selectedDevice) {
            let vi = theDevice.volumeInfo(channel: 0, scope: .output)
            print(vi)
            
            guard let vi = vi else {
                fatalError("The volume info returned nil")
            }
            guard let theVolume = vi.volume else {
                fatalError("unable to get the volume from volume info")
            }
            
            let viDouble = Double(theVolume)
            
            return viDouble
        }
        
        return nil
        
    }
    
    func findDevice(selectedDevice: MyAudioDevice) -> AudioDevice? {
        guard let scaDevices = _sca?.allOutputDevices else { return nil }
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
