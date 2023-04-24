//
// SensorScanningViewModel.swift
// MovesenseShowcase
//
// Copyright © 2023 Canned Bit Ltd. All rights reserved.
// Copyright (c) 2018 Suunto. All rights reserved.
//

import Foundation
import MovesenseApi
import MovesenseVirtualApi

enum MovesenseObserverEventSensorScanning: ObserverEvent {

    case deviceDiscovered(_ device: DeviceViewModel)
    case deviceStateChanged(_ device: DeviceViewModel)
    case onError(_ error: Error)
}

class SensorScanningViewModel: Observable {

    private var devices: [MovesenseDevice] {
        return Movesense.api.getDevices()
    }

    // Observable
    internal var observations: [Observation] = [Observation]()
    private(set) var observationQueue: DispatchQueue = DispatchQueue.global()

    // Self
    init() {
        Movesense.api.initializeVirtualApi()
        Movesense.api.addObserver(self)
    }

    func connectDevice(_ serial: String) {
        guard let device = (devices.first { $0.serialNumber == serial }) else { return }
        Movesense.api.connectDevice(device)
    }

    func disconnectDevice(_ serial: String) {
        guard let device = (devices.first { $0.serialNumber == serial }) else { return }
        Movesense.api.disconnectDevice(device)
    }

    func getConnectedDevices() -> [DeviceViewModel] {
        return devices.filter { $0.isConnected }.map { DeviceViewModel($0) }
    }

    func getActiveDevices() -> [DeviceViewModel] {
        return devices.filter { $0.deviceState != .disconnected }.map { DeviceViewModel($0) }
    }

    func getInactiveDevicesFiltered(_ searchText: String?) -> [DeviceViewModel] {
        guard let searchText = searchText?.lowercased(),
              searchText.isEmpty == false else {
            return devices.filter { $0.deviceState == .disconnected }.map { DeviceViewModel($0) }
        }

        return devices.filter { device in
            device.deviceState == .disconnected &&
            (device.localName.lowercased().contains(searchText) ||
             device.serialNumber.contains(searchText))
        }.map { DeviceViewModel($0) }
    }

    func startDevicesScan() {
        Movesense.api.startScan()
    }

    func stopDevicesScan() {
        Movesense.api.stopScan()
    }

    func resetDevices() {
        Movesense.api.resetScan()
    }

    func createVirtualDevice() {
        Movesense.api.createVirtualDevice()
    }
}

extension SensorScanningViewModel: Observer {

    func handleEvent(_ event: ObserverEvent) {
        guard let event = event as? MovesenseObserverEventApi else { return }

        switch event {
        case .apiDeviceDiscovered(let device): deviceDiscovered(device)
        case .apiDeviceConnecting(let device): deviceConnecting(device)
        case .apiDeviceConnected(let device): deviceConnected(device)
        case .apiDeviceDisconnected(let device): deviceDisconnected(device)
        case .apiDeviceOperationInitiated: return
        case .apiError(let error): onApiError(error)
        }
    }

    func deviceConnecting(_ device: MovesenseDevice) {
        let connectingDevice = DeviceViewModel(device, newState: .connecting)
        notifyObservers(MovesenseObserverEventSensorScanning.deviceStateChanged(connectingDevice))
    }

    func deviceConnected(_ device: MovesenseDevice) {
        let connectedDevice = DeviceViewModel(device, newState: .connected)
        notifyObservers(MovesenseObserverEventSensorScanning.deviceStateChanged(connectedDevice))
    }

    func deviceDisconnected(_ device: MovesenseDevice) {
        let disconnectedDevice = DeviceViewModel(device, newState: .disconnected)
        notifyObservers(MovesenseObserverEventSensorScanning.deviceStateChanged(disconnectedDevice))
    }

    func onDeviceError(_ error: Error, device: MovesenseDevice) {
        let errorDevice = DeviceViewModel(device, newState: .disconnected)
        notifyObservers(MovesenseObserverEventSensorScanning.onError(error))
        notifyObservers(MovesenseObserverEventSensorScanning.deviceStateChanged(errorDevice))
    }

    func deviceDiscovered(_ device: MovesenseDevice) {
        notifyObservers(MovesenseObserverEventSensorScanning.deviceDiscovered(DeviceViewModel(device)))
    }

    func onApiError(_ error: Error) {
        notifyObservers(MovesenseObserverEventSensorScanning.onError(error))
    }
}
