//
//  LIFXGroup.swift
//  Remote Control for LIFX
//
//  Created by David Wu on 1/3/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Cocoa

let notificationGroupColorChanged = NSNotification.Name(rawValue: "net.gofake1.groupColorChangedKey")
let notificationGroupNameChanged  = NSNotification.Name(rawValue: "net.gofake1.groupNameChangedKey")
let notificationGroupPowerChanged = NSNotification.Name(rawValue: "net.gofake1.groupPowerChangedKey")

class LIFXGroup: NSObject, HudRepresentable, StatusMenuItemRepresentable {

    struct NumberedNameSequence {
        var count: Int = 1

        mutating func next() -> String {
            defer { count += 1 }
            return "Group \(count)"
        }
    }

    override var description: String {
        return "group: { name: \(name), device_addresses: \(promisedDeviceAddresses) }"
    }

    override var hashValue: Int {
        return id.hashValue
    }

    private static var names = NumberedNameSequence()
    @objc dynamic var devices = [LIFXDevice]()
    var color = LIFXLight.Color(nsColor: NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)) {
        didSet {
            NotificationCenter.default.post(name: notificationGroupColorChanged, object: self)
        }
    }
    var hudController = HudController()
    var hudTitle: String {
        return name
    }
    /// Visibility in status menu
    @objc dynamic var isVisible = true
    var statusMenuItem = NSMenuItem()
    @objc dynamic var name: String {
        didSet {
            NotificationCenter.default.post(name: notificationGroupNameChanged, object: self)
        }
    }
    var power = LIFXDevice.PowerState.enabled {
        didSet {
            NotificationCenter.default.post(name: notificationGroupPowerChanged, object: self)
        }
    }
    let id: String
    private var promisedDeviceAddresses = [Address]()

    override init() {
        id = String(Date().timeIntervalSince1970)
        name = LIFXGroup.names.next()
        super.init()
        makeControllers()
    }

    init(csvLine: CSV.Line, version: Int) {
        id = csvLine.values[1]
        name = csvLine.values[2]
        super.init()
        switch version {
        case 1:
            guard csvLine.values.count >= 3 else { return }
            csvLine.values[3...].forEach {
                if let address = Address($0) {
                    promisedDeviceAddresses.append(address)
                }
            }
        case 2: fallthrough
        case 3:
            isVisible = csvLine.values[3] == "visible"
            guard csvLine.values.count >= 4 else { return }
            csvLine.values[4...].forEach {
                if let address = Address($0) {
                    promisedDeviceAddresses.append(address)
                }
            }
        default:
            break
        }
        makeControllers()
    }

    static func ==(lhs: LIFXGroup, rhs: LIFXGroup) -> Bool {
        return lhs.id == rhs.id
    }

    func makeControllers() {
        hudController.representable = self
        let hudViewController = GroupHudViewController()
        hudViewController.group = self
        hudController.contentViewController = hudViewController

        let menuItemViewController = GroupMenuItemViewController()
        menuItemViewController.group = self
        statusMenuItem.representedObject = menuItemViewController
        statusMenuItem.view = menuItemViewController.view
    }

    /// Finish initialization from saved state after LIFX objects created
    func restore(from model: LIFXModel) {
        for address in promisedDeviceAddresses {
            if let device = model.device(for: address) {
                devices.append(device)
            }
        }
    }

    func device(at index: Int) -> LIFXDevice {
        return devices[index]
    }

    func add(device: LIFXDevice) {
        devices.append(device)
    }

    func remove(device: LIFXDevice) {
        if let index = devices.index(of: device) {
            devices.remove(at: index)
        }
    }

    func setPower(_ power: LIFXDevice.PowerState) {
        self.power = power
        devices.forEach { $0.setPower(power) }
    }

    func setColor(_ color: LIFXLight.Color) {
        self.color = color
        devices.forEach { ($0 as? LIFXLight)?.setColor(color) }
    }

    func willBeRemoved() {
        hudController.close()
        statusMenuItem.menu?.removeItem(statusMenuItem)
        devices.removeAll()
    }
}

extension LIFXGroup: CSVEncodable {
    var csvLine: CSV.Line? {
        var line = CSV.Line("group", id, name, isVisible ? "visible" : "hidden")
        for device in devices {
            line.append(String(device.address))
        }
        return line
    }
}
