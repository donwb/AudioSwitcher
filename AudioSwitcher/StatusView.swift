//
//  StatusView.swift
//  AudioSwitcher
//
//  Created by Don Browning on 5/6/21.
//

import Cocoa

class StatusView: NSView, LoadableView {

   
    @IBOutlet var contentView: NSView!
    @IBOutlet weak var statusTextLabel: NSTextField!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        _ = load(fromNIBNamed: "StatusView")
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func setLabel(labelName: String) {
        self.statusTextLabel.stringValue = labelName
    }
    
}
