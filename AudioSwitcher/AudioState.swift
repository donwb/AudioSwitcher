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
    private var _devices = [AudioDevice]()
    
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
    private func loadDevices() -> [AudioDevice] {
        //_devices.removeAll()
        var myDevices = [AudioDevice]()
        let outputDevices = _sca?.allOutputDevices
        for d in outputDevices! {
            let ad = AudioDevice(name: d.name, id: d.id, enabled: d.isDefaultOutputDevice)
            myDevices.append(ad)
        }
        
        return myDevices
    }
    
    // MARK: - Public functions
    func reload() {
        let devices = loadDevices()
        self._devices = devices
        
    }
    
    func MakeActiveOutputDevice(device: AudioDevice) {
        guard let scaDevices = _sca?.allOutputDevices else {return}
        
        for d in scaDevices {
            if d.name == device.name {
                d.isDefaultOutputDevice = true
            }
        }
        
        reload()
        
    }
    
    var Devices: [AudioDevice] {
        get {
            return _devices
        }
    }
    
    var ActiveOutputDevice: AudioDevice? {
        get{
            var active: AudioDevice?
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
