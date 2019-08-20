//
//  Alert.swift
//  OmniKit
//
//  Created by Pete Schwamb on 10/24/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public enum AlertTrigger {
    case unitsRemaining(Double)
    case timeUntilAlert(TimeInterval)
}

public enum BeepRepeat: UInt8 {
    case once = 0
    case every1MinuteFor3MinutesAndRepeatEvery60Minutes = 1
    case every1MinuteFor15Minutes = 2
    case every1MinuteFor3MinutesAndRepeatEvery15Minutes = 3
    case every3MinutesFor60minutesStartingAt2Minutes = 4
    case every60Minutes = 5
    case every15Minutes = 6
    case every15MinutesFor60minutesStartingAt14Minutes = 7
    case every5Minutes = 8
}


public struct AlertConfiguration {

    let slot: AlertSlot
    let trigger: AlertTrigger
    let active: Bool
    let duration: TimeInterval
    let beepRepeat: BeepRepeat
    let beepType: BeepType
    let autoOffModifier: Bool

    static let length = 6

    public init(alertType: AlertSlot, active: Bool = true, autoOffModifier: Bool = false, duration: TimeInterval, trigger: AlertTrigger, beepRepeat: BeepRepeat, beepType: BeepType) {
        self.slot = alertType
        self.active = active
        self.autoOffModifier = autoOffModifier
        self.duration = duration
        self.trigger = trigger
        self.beepRepeat = beepRepeat
        self.beepType = beepType
    }
}

public enum PodAlert: CustomStringConvertible, RawRepresentable, Equatable {
    public typealias RawValue = [String: Any]

    // 2 hours long, time for user to start pairing process
    case waitingForPairingReminder

    // 1 hour long, time for user to finish priming, cannula insertion
    case finishSetupReminder

    // User configurable with PDM (1-24 hours before 72 hour expiration) "Change Pod Soon"
    case expirationAlert(TimeInterval)

    // 72 hour alarm
    case expirationAdvisoryAlarm(alarmTime: TimeInterval, duration: TimeInterval)

    // 79 hour alarm (1 hour before shutdown)
    case shutdownImminentAlarm(TimeInterval)

    // reservoir below configured value alarm
    case lowReservoirAlarm(Double)

    // auto-off timer; requires user input every x minutes
    case autoOffAlarm(active: Bool, countdownDuration: TimeInterval)

    public var description: String {
        switch self {
        case .waitingForPairingReminder:
            return LocalizedString("Waiting for pairing reminder", comment: "Description waiting for pairing reminder")
        case .finishSetupReminder:
            return LocalizedString("Finish setup ", comment: "Description for finish setup")
        case .expirationAlert:
            return LocalizedString("Expiration alert", comment: "Description for expiration alert")
        case .expirationAdvisoryAlarm:
            return LocalizedString("Pod expiration advisory alarm", comment: "Description for expiration advisory alarm")
        case .shutdownImminentAlarm:
            return LocalizedString("Shutdown imminent alarm", comment: "Description for shutdown imminent alarm")
        case .lowReservoirAlarm:
            return LocalizedString("Low reservoir advisory alarm", comment: "Description for low reservoir alarm")
        case .autoOffAlarm:
            return LocalizedString("Auto-off alarm", comment: "Description for auto-off alarm")
        }
    }

    public var configuration: AlertConfiguration {
        switch self {
        case .waitingForPairingReminder:
            return AlertConfiguration(alertType: .slot7, duration: .minutes(110), trigger: .timeUntilAlert(.minutes(10)), beepRepeat: .every5Minutes, beepType: .bipBeepBipBeepBipBeepBipBeep)
        case .finishSetupReminder:
            return AlertConfiguration(alertType: .slot7, duration: .minutes(55), trigger: .timeUntilAlert(.minutes(5)), beepRepeat: .every5Minutes, beepType: .bipBeepBipBeepBipBeepBipBeep)
        case .expirationAlert(let alertTime):
            if alertTime == 0 {
                // deactivate slot3 alert if alertTime is 0
                return AlertConfiguration(alertType: .slot3, active: false, duration: 0, trigger: .timeUntilAlert(alertTime), beepRepeat: .every1MinuteFor3MinutesAndRepeatEvery15Minutes, beepType: .bipBeepBipBeepBipBeepBipBeep)
            } else {
                return AlertConfiguration(alertType: .slot3, duration: 0, trigger: .timeUntilAlert(alertTime), beepRepeat: .every1MinuteFor3MinutesAndRepeatEvery15Minutes, beepType: .bipBeepBipBeepBipBeepBipBeep)
            }
        case .expirationAdvisoryAlarm(let alarmTime, let duration):
            return AlertConfiguration(alertType: .slot7, duration: duration, trigger: .timeUntilAlert(alarmTime), beepRepeat: .every60Minutes, beepType: .bipBeepBipBeepBipBeepBipBeep)

        case .shutdownImminentAlarm(let alarmTime):
            return AlertConfiguration(alertType: .slot2, duration: 0, trigger: .timeUntilAlert(alarmTime), beepRepeat: .every15Minutes, beepType: .bipBeepBipBeepBipBeepBipBeep)
        case .lowReservoirAlarm(let units):
            if units == 0 {
                // deactivate slot4 alert if units is 0
                return AlertConfiguration(alertType: .slot4, active: false, duration: 0, trigger: .unitsRemaining(units), beepRepeat: .every1MinuteFor3MinutesAndRepeatEvery60Minutes, beepType: .bipBeepBipBeepBipBeepBipBeep)
            } else {
                return AlertConfiguration(alertType: .slot4, duration: 0, trigger: .unitsRemaining(units), beepRepeat: .every1MinuteFor3MinutesAndRepeatEvery60Minutes, beepType: .bipBeepBipBeepBipBeepBipBeep)
            }
        case .autoOffAlarm(let active, let countdownDuration):
            return AlertConfiguration(alertType: .slot0, active: active, autoOffModifier: true, duration: .minutes(15), trigger: .timeUntilAlert(countdownDuration), beepRepeat: .every1MinuteFor15Minutes, beepType: .bipBeepBipBeepBipBeepBipBeep)
        }
    }


    // MARK: - RawRepresentable
    public init?(rawValue: RawValue) {

        guard let name = rawValue["name"] as? String else {
            return nil
        }

        switch name {
        case "waitingForPairingReminder":
            self = .waitingForPairingReminder
        case "finishSetupReminder":
            self = .finishSetupReminder
        case "expirationAlert":
            guard let alertTime = rawValue["alertTime"] as? Double else {
                return nil
            }
            self = .expirationAlert(TimeInterval(alertTime))
        case "expirationAdvisoryAlarm":
            guard let alarmTime = rawValue["alarmTime"] as? Double,
                let duration = rawValue["duration"] as? Double else
            {
                return nil
            }
            self = .expirationAdvisoryAlarm(alarmTime: TimeInterval(alarmTime), duration: TimeInterval(duration))
        case "shutdownImminentAlarm":
            guard let alarmTime = rawValue["alarmTime"] as? Double else {
                return nil
            }
            self = .shutdownImminentAlarm(alarmTime)
        case "lowReservoirAlarm":
            guard let units = rawValue["units"] as? Double else {
                return nil
            }
            self = .lowReservoirAlarm(units)
        case "autoOffAlarm":
            guard let active = rawValue["active"] as? Bool,
                let countdownDuration = rawValue["countdownDuration"] as? Double else
            {
                return nil
            }
            self = .autoOffAlarm(active: active, countdownDuration: TimeInterval(countdownDuration))
        default:
            return nil
        }
    }

    public var rawValue: RawValue {

        let name: String = {
            switch self {
            case .waitingForPairingReminder:
                return "waitingForPairingReminder"
            case .finishSetupReminder:
                return "finishSetupReminder"
            case .expirationAlert:
                return "expirationAlert"
            case .expirationAdvisoryAlarm:
                return "expirationAdvisoryAlarm"
            case .shutdownImminentAlarm:
                return "shutdownImminentAlarm"
            case .lowReservoirAlarm:
                return "lowReservoirAlarm"
            case .autoOffAlarm:
                return "autoOffAlarm"
            }
        }()


        var rawValue: RawValue = [
            "name": name,
        ]

        switch self {
        case .expirationAlert(let alertTime):
            rawValue["alertTime"] = alertTime
        case .expirationAdvisoryAlarm(let alarmTime, let duration):
            rawValue["alarmTime"] = alarmTime
            rawValue["duration"] = duration
        case .shutdownImminentAlarm(let alarmTime):
            rawValue["alarmTime"] = alarmTime
        case .lowReservoirAlarm(let units):
            rawValue["units"] = units
        case .autoOffAlarm(let active, let countdownDuration):
            rawValue["active"] = active
            rawValue["countdownDuration"] = countdownDuration
        default:
            break
        }

        return rawValue
    }
}

public enum AlertSlot: UInt8 {
    case slot0 = 0x00
    case slot1 = 0x01
    case slot2 = 0x02
    case slot3 = 0x03
    case slot4 = 0x04
    case slot5 = 0x05
    case slot6 = 0x06
    case slot7 = 0x07

    public var bitMaskValue: UInt8 {
        return 1<<rawValue
    }

    public typealias AllCases = [AlertSlot]
    
    static var allCases: AllCases {
        return (0..<8).map { AlertSlot(rawValue: $0)! }
    }
}

public struct AlertSet: RawRepresentable, Collection, CustomStringConvertible, Equatable {
    
    public typealias RawValue = UInt8
    public typealias Index = Int
    
    public let startIndex: Int
    public let endIndex: Int
    
    private let elements: [AlertSlot]
    
    public static let none = AlertSet(rawValue: 0)
    
    public var rawValue: UInt8 {
        return elements.reduce(0) { $0 | $1.bitMaskValue }
    }
    
    public init(slots: [AlertSlot]) {
        self.elements = slots
        self.startIndex = 0
        self.endIndex = self.elements.count
    }

    public init(rawValue: UInt8) {
        self.init(slots: AlertSlot.allCases.filter { rawValue & $0.bitMaskValue != 0 })
    }

    public subscript(index: Index) -> AlertSlot {
        return elements[index]
    }
    
    public func index(after i: Int) -> Int {
        return i+1
    }
    
    public var description: String {
        if elements.count == 0 {
            return LocalizedString("No alerts", comment: "Pod alert state when no alerts are active")
        } else {
            let alarmDescriptions = elements.map { String(describing: $0) }
            return alarmDescriptions.joined(separator: ", ")
        }
    }
}
