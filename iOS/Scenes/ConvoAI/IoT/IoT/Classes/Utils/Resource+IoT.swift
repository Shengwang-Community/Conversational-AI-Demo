//
//  Resource+VoiceAgent.swift
//  DigitalHuman
//
//  Created by qinhui on 2025/1/16.
//

import Foundation
import Common

extension ResourceManager {
    static func localizedString(_ key: String) -> String {
        return localizedString(key, bundleName: IoTEntrance.kSceneName)
    }
    
    enum L10n {
        public enum Error {
            public static let networkError = ResourceManager.localizedString("error.network")
            public static let roomError = ResourceManager.localizedString("error.room.error")
            public static let joinError = ResourceManager.localizedString("error.join.error")
            public static let resouceLimit = ResourceManager.localizedString("error.join.error.resource.limit")
            public static let networkDisconnected = ResourceManager.localizedString("error.network.disconnect")
            public static let microphonePermissionTitle = ResourceManager.localizedString("error.microphone.permission.alert.title")
            public static let microphonePermissionDescription = ResourceManager.localizedString("error.microphone.permission.alert.description")
            public static let permissionCancel = ResourceManager.localizedString("error.permission.alert.cancel")
            public static let permissionConfirm = ResourceManager.localizedString("error.permission.alert.confirm")
        }
        
        public enum Iot {
            public static let title = ResourceManager.localizedString("iot.info.title")
            public static let device = ResourceManager.localizedString("iot.info.device")
            public static let submit = ResourceManager.localizedString("iot.common.submit")
            public static let cancel = ResourceManager.localizedString("iot.common.cancel")
            public static let confim = ResourceManager.localizedString("iot.common.alert.confim")
            // Permissions
            public static let permissionTitle = ResourceManager.localizedString("iot.permission.title")
            public static let permissionDescription = ResourceManager.localizedString("iot.permission.description")
            public static let permissionGoButton = ResourceManager.localizedString("iot.permission.go_button")
            
            // Device Adding Process
            public static let deviceAddTitle = ResourceManager.localizedString("iot.device.add.title")
            public static let deviceAddProgress = ResourceManager.localizedString("iot.device.add.progress")
            public static let deviceSendingData = ResourceManager.localizedString("iot.device.add.progress")

            public static let deviceAddSuccessTitle = ResourceManager.localizedString("iot.device.add.success.title")
            public static let deviceAddSuccessDescription = ResourceManager.localizedString("iot.device.add.success.description")
            
            // Device Scanning
            public static let deviceScanningTitle = ResourceManager.localizedString("iot.device.scanning.title")
            public static let deviceScanningDescription = ResourceManager.localizedString("iot.device.scanning.description")
            
            // Empty Device Page
            public static let deviceEmptyWelcome = ResourceManager.localizedString("iot.device.empty.welcome")
            public static let deviceEmptyDescription = ResourceManager.localizedString("iot.device.empty.description")
            public static let deviceEmptyAddButton = ResourceManager.localizedString("iot.device.empty.add_button")
            
            // Device Setup
            public static let deviceSetupInstructionTitle = ResourceManager.localizedString("iot.device.setup.instruction.title")
            public static let deviceSetupInstruction = ResourceManager.localizedString("iot.device.setup.instruction")
            public static let deviceSetupInstructionSub = ResourceManager.localizedString("iot.device.setup.instruction.sub")
            public static let deviceSetupPermissionDescription = ResourceManager.localizedString("iot.device.setup.permission_description")
            public static let deviceSetupComplete = ResourceManager.localizedString("iot.device.setup.complete")
            
            // Device Setup Steps
            public static let deviceStep1Title = ResourceManager.localizedString("iot.device.step1.title")
            public static let deviceStep1Description = ResourceManager.localizedString("iot.device.step1.description")
            public static let deviceStep2Title = ResourceManager.localizedString("iot.device.step2.title")
            public static let deviceStep2Description = ResourceManager.localizedString("iot.device.step2.description")
            public static let deviceStep3Title = ResourceManager.localizedString("iot.device.step3.title")
            public static let deviceStep3Description = ResourceManager.localizedString("iot.device.step3.description")
            
            // Others
            public static let deviceDefaultPreset = ResourceManager.localizedString("iot.device.default_preset")
            
            // Permission Items
            public static let permissionItemLocation = ResourceManager.localizedString("iot.permission.item.location")
            public static let permissionItemBluetooth = ResourceManager.localizedString("iot.permission.item.bluetooth")
            public static let permissionItemWifi = ResourceManager.localizedString("iot.permission.item.wifi")
            public static let permissionBluetoothEnable = ResourceManager.localizedString("iot.permission.bluetooth.enable")
            public static let permissionBluetoothUnauthorized = ResourceManager.localizedString("iot.permission.bluetooth.unauthorized")
            public static let permissionLocationUnauthorized = ResourceManager.localizedString("iot.permission.location.unauthorized")
            public static let buttonNext = ResourceManager.localizedString("iot.permission.button.next")
            
            // Device Search Failed
            public static let deviceSearchFailedTitle = ResourceManager.localizedString("iot.device.search.failed.title")
            public static let deviceSearchFailedDescription = ResourceManager.localizedString("iot.device.search.failed.description")
            public static let deviceSearchFailedRetry = ResourceManager.localizedString("iot.device.search.failed.retry")
            public static let deviceSearchFailedTip = ResourceManager.localizedString("iot.device.search.failed.tip")
            public static let deviceSearchFailedSwipeTip = ResourceManager.localizedString("iot.device.search.failed.swipe.tip")

            // Error Alert
            public static let errorAlertTitle = ResourceManager.localizedString("iot.error.alert.title")
            public static let errorAlertSubtitle = ResourceManager.localizedString("iot.error.alert.subtitle")
            public static let errorCheckWifi = ResourceManager.localizedString("iot.error.check.wifi")
            public static let errorCheckPairingMode = ResourceManager.localizedString("iot.error.check.pairing")
            public static let errorCheckRouter = ResourceManager.localizedString("iot.error.check.router")
            
            // Device Settings
            public static let deviceSettingsTitle = ResourceManager.localizedString("iot.device.settings.title")
            public static let deviceSettingsPreset = ResourceManager.localizedString("iot.device.settings.preset")
            public static let deviceSettingsLanguage = ResourceManager.localizedString("iot.device.settings.language")
            public static let deviceSettingsLanguageTitle = ResourceManager.localizedString("iot.device.settings.language.title")
            
            public static let deviceSettingsAdvanced = ResourceManager.localizedString("iot.device.settings.advanced")
            public static let deviceSettingsInterrupt = ResourceManager.localizedString("iot.device.settings.interrupt")
            public static let deviceSettingsInterruptMatchWord = ResourceManager.localizedString("iot.device.settings.interrupt.match")

            public static let deviceSettingsReconnect = ResourceManager.localizedString("iot.device.settings.reconnect")
            public static let deviceSettingsDelete = ResourceManager.localizedString("iot.device.settings.delete")
            public static let deviceSettingsDeleteTitle = ResourceManager.localizedString("iot.device.settings.delete.title")
            public static let deviceSettingsDeleteDescription = ResourceManager.localizedString("iot.device.settings.delete.description")
            public static let deviceSettingsDeleteConfirm = ResourceManager.localizedString("iot.device.settings.delete.confirm")
            public static let deviceSettingsSaveTitle = ResourceManager.localizedString("iot.device.settings.save.title")
            public static let deviceSettingsSaveDescription = ResourceManager.localizedString("iot.device.settings.save.description")
            public static let deviceSettingsSaveConfirm = ResourceManager.localizedString("iot.device.settings.save.confirm")
            public static let deviceSettingsSaveDiscard = ResourceManager.localizedString("iot.device.settings.save.discard")
            public static let deviceRename = ResourceManager.localizedString("iot.device.rename.title")
            public static let deviceRenameSucceed = ResourceManager.localizedString("iot.device.rename.success")
            public static let deviceRenamePlaceholder = ResourceManager.localizedString("iot.device.rename.placeholder")
            public static let deviceRenameTips = ResourceManager.localizedString("iot.device.rename.tips")
            
            // WiFi Settings
            public static let wifiSettingsTitle = ResourceManager.localizedString("iot.wifi.settings.title")
            public static let wifiSettingsSubtitle = ResourceManager.localizedString("iot.wifi.settings.subtitle")
            public static let wifiSettingsTip = ResourceManager.localizedString("iot.wifi.settings.tip")
            public static let wifiSettingsError = ResourceManager.localizedString("iot.wifi.settings.error")
            public static let wifiSettingsPasswordPlaceholder = ResourceManager.localizedString("iot.wifi.settings.password.placeholder")
            public static let wifiSettingsSwitch = ResourceManager.localizedString("iot.wifi.settings.switch")
            public static let wifiSettingsNext = ResourceManager.localizedString("iot.wifi.settings.next")
            
            // Hotspot Settings
            public static let hotspotOpenTitle = ResourceManager.localizedString("iot.hotspot.open.title")
            public static let hotspotSettingsButton = ResourceManager.localizedString("iot.hotspot.settings.button")
            public static let hotspotCheckPrefix = ResourceManager.localizedString("iot.hotspot.check.prefix")
            public static let hotspotCompatibilityMode = ResourceManager.localizedString("iot.hotspot.compatibility.mode")
            public static let hotspotInputTitle = ResourceManager.localizedString("iot.hotspot.input.title")
            public static let hotspotDeviceNamePlaceholder = ResourceManager.localizedString("iot.hotspot.device.name.placeholder")
            public static let hotspotPasswordPlaceholder = ResourceManager.localizedString("iot.hotspot.password.placeholder")
            public static let hotspotNext = ResourceManager.localizedString("iot.hotspot.next")
            public static let hotspotTabWifi = ResourceManager.localizedString("iot.hotspot.tab.wifi")
            public static let hotspotTabMobile = ResourceManager.localizedString("iot.hotspot.tab.mobile")

            // Device Search
            public static let deviceSearchTitle = ResourceManager.localizedString("iot.device.search.title")
            
            // Device Search Status
            public static let deviceSearchStatusReady = ResourceManager.localizedString("iot.device.search.status.ready")
            public static let deviceSearchStatusConnected = ResourceManager.localizedString("iot.device.search.status.connected")
            public static let deviceSearchStatusConfiguring = ResourceManager.localizedString("iot.device.search.status.configuring")
            public static let deviceSearchStatusCompleted = ResourceManager.localizedString("iot.device.search.status.completed")
        }
    }
}



