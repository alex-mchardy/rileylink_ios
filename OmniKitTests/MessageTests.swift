//
//  MessageTests.swift
//  OmniKitTests
//
//  Created by Pete Schwamb on 10/14/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import OmniKit

class MessageTests: XCTestCase {
    
    func testMessageData() {
        // 2016-06-26T20:33:28.412197 ID1:1f01482a PTYPE:PDM SEQ:13 ID2:1f01482a B9:10 BLEN:3 BODY:0e0100802c CRC:88
        
        let msg = Message(address: 0x1f01482a, messageBlocks: [GetStatusCommand()], sequenceNum: 4)
        
        XCTAssertEqual("1f01482a10030e0100802c", msg.encoded().hexadecimalString)
    }
    
    func testMessageDecoding() {
        do {
            let msg = try Message(encodedData: Data(hexadecimalString: "1f00ee84300a1d18003f1800004297ff8128")!)
            
            XCTAssertEqual(0x1f00ee84, msg.address)
            XCTAssertEqual(12, msg.sequenceNum)
            
            let messageBlocks = msg.messageBlocks
            
            XCTAssertEqual(1, messageBlocks.count)
            
            let statusResponse = messageBlocks[0] as! StatusResponse
            
            XCTAssertEqual(nil, statusResponse.reservoirLevel)
            XCTAssertEqual(TimeInterval(minutes: 4261), statusResponse.timeActive)

            XCTAssertEqual(.normal, statusResponse.deliveryStatus)
            XCTAssertEqual(.aboveFiftyUnits, statusResponse.podProgressStatus)
            XCTAssertEqual(6.3, statusResponse.insulin, accuracy: 0.01)
            XCTAssertEqual(0, statusResponse.insulinNotDelivered)
            XCTAssertEqual(3, statusResponse.podMessageCounter)
            XCTAssert(statusResponse.alerts.isEmpty)

            XCTAssertEqual("1f00ee84300a1d18003f1800004297ff8128", msg.encoded().hexadecimalString)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testAssemblingMultiPacketMessage() {
        do {
            let packet1 = try Packet(encodedData: Data(hexadecimalString: "ffffffffe4ffffffff041d011b13881008340a5002070002070002030000a62b0004479420")!)
            XCTAssertEqual(packet1.data.hexadecimalString, "ffffffff041d011b13881008340a5002070002070002030000a62b00044794")
            XCTAssertEqual(packet1.packetType, .pod)

            XCTAssertThrowsError(try Message(encodedData: packet1.data)) { error in
                XCTAssertEqual(String(describing: error), "notEnoughData")
            }
            
            let packet2 = try Packet(encodedData: Data(hexadecimalString: "ffffffff861f00ee878352ff")!)
            XCTAssertEqual(packet2.address, 0xffffffff)
            XCTAssertEqual(packet2.data.hexadecimalString, "1f00ee878352")
            XCTAssertEqual(packet2.packetType, .con)
            
            let messageBody = packet1.data + packet2.data
            XCTAssertEqual(messageBody.hexadecimalString, "ffffffff041d011b13881008340a5002070002070002030000a62b000447941f00ee878352")

            let message = try Message(encodedData: messageBody)
            XCTAssertEqual(message.messageBlocks.count, 1)

        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testParsingVersionResponse() {
        do {
            let config = try VersionResponse(encodedData: Data(hexadecimalString: "011502070002070002020000a64000097c279c1f08ced2")!)
            XCTAssertEqual(23, config.data.count)
            XCTAssertEqual(0x1f08ced2, config.address)
            XCTAssertEqual(42560, config.lot)
            XCTAssertEqual(621607, config.tid)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testParsingLongVersionResponse() {
        do {
            let message = try Message(encodedData: Data(hexadecimalString: "ffffffff041d011b13881008340a5002070002070002030000a62b000447941f00ee878352")!)
            let config = message.messageBlocks[0] as! VersionResponse
            XCTAssertEqual(29, config.data.count)
            XCTAssertEqual(0x1f00ee87, config.address)
            XCTAssertEqual(42539, config.lot)
            XCTAssertEqual(280468, config.tid)
            XCTAssertEqual("2.7.0", String(describing: config.piVersion))
            XCTAssertEqual("2.7.0", String(describing: config.pmVersion))
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }

    func testParsingConfigWithPairingExpired() {
        do {
            let message = try Message(encodedData: Data(hexadecimalString: "ffffffff04170115020700020700020e0000a5ad00053030971f08686301fd")!)
            let config = message.messageBlocks[0] as! VersionResponse
            XCTAssertEqual(.pairingExpired, config.setupState)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }

    func testAssignAddressCommand() {
        do {
            // Encode
            let encoded = AssignAddressCommand(address: 0x1f01482a)
            XCTAssertEqual("07041f01482a", encoded.data.hexadecimalString)

            // Decode
            let decoded = try AssignAddressCommand(encodedData: Data(hexadecimalString: "07041f01482a")!)
            XCTAssertEqual(0x1f01482a, decoded.address)
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testSetupPodCommand() {
        do {
            var components = DateComponents()
            components.day = 12
            components.month = 6
            components.year = 2016
            components.hour = 13
            components.minute = 47

            // Decode
            let decoded = try ConfigurePodCommand(encodedData: Data(hexadecimalString: "03131f0218c31404060c100d2f0000a4be0004e4a1")!)
            XCTAssertEqual(0x1f0218c3, decoded.address)
            XCTAssertEqual(components, decoded.dateComponents)
            XCTAssertEqual(0x0000a4be, decoded.lot)
            XCTAssertEqual(0x0004e4a1, decoded.tid)

            // Encode
            let encoded = ConfigurePodCommand(address: 0x1f0218c3, dateComponents: components, lot: 0x0000a4be, tid: 0x0004e4a1)
            XCTAssertEqual("03131f0218c31404060c100d2f0000a4be0004e4a1", encoded.data.hexadecimalString)            

        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testInsertCannula() {
//        2018-04-03T19:23:14.3d ID1:1f00ee85 PTYPE:PDM SEQ:17 ID2:1f00ee85 B9:38 BLEN:31 BODY:1a0e7e30bf16020065010050000a000a170d000064000186a0 CRC:33
//        2018-04-03T19:23:14.3d ID1:1f00ee85 PTYPE:ACK SEQ:18 ID2:1f00ee85 CRC:89
//        2018-04-03T19:23:14.3d ID1:1f00ee85 PTYPE:CON SEQ:19 CON:000000000000808c CRC:6f
//        2018-04-03T19:23:14.3d ID1:1f00ee85 PTYPE:POD SEQ:20 ID2:1f00ee85 B9:3c BLEN:10 BODY:1d570016f00a00000bff8099 CRC:86
//        2018-04-03T19:23:14.3d ID1:1f00ee85 PTYPE:ACK SEQ:21 ID2:1f00ee85 CRC:a0

        do {
            // Decode
            let cmd = try SetInsulinScheduleCommand(encodedData: Data(hexadecimalString: "1a0ebed2e16b02010a0101a000340034")!)
            XCTAssertEqual(0xbed2e16b, cmd.nonce)
            
            if case SetInsulinScheduleCommand.DeliverySchedule.bolus(let units, let timeBetweenPulses) = cmd.deliverySchedule {
                XCTAssertEqual(2.6, units)
                XCTAssertEqual(.seconds(1), timeBetweenPulses)
            } else {
                XCTFail("Expected ScheduleEntry.bolus type")
            }
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testStatusResponseAlarmsParsing() {
        // 1d 28 0082 00 0044 46eb ff
        
        do {
            // Decode
            let status = try StatusResponse(encodedData: Data(hexadecimalString: "1d28008200004446ebff")!)
            XCTAssert(status.alerts.contains(.slot3))
            XCTAssert(status.alerts.contains(.slot7))
        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
    
    func testConfigureAlertsCommand() {
        // 79a4 10df 0502
        // Pod expires 1 minute short of 3 days
        let podSoftExpirationTime = TimeInterval(hours:72) - TimeInterval(minutes:1)
        let alertConfig1 = AlertConfiguration(alertType: .slot7, active: true, autoOffModifier: false, duration: .hours(7), trigger: .timeUntilAlert(podSoftExpirationTime), beepRepeat: .every60Minutes, beepType: .bipBeepBipBeepBipBeepBipBeep)
        XCTAssertEqual("79a410df0502", alertConfig1.data.hexadecimalString)

        // 2800 1283 0602
        let podHardExpirationTime = TimeInterval(hours:79) - TimeInterval(minutes:1)
        let alertConfig2 = AlertConfiguration(alertType: .slot2, active: true, autoOffModifier: false, duration: .minutes(0), trigger: .timeUntilAlert(podHardExpirationTime), beepRepeat: .every15Minutes, beepType: .bipBeepBipBeepBipBeepBipBeep)
        XCTAssertEqual("280012830602", alertConfig2.data.hexadecimalString)

        // 020f 0000 0202
        let alertConfig3 = AlertConfiguration(alertType: .slot0, active: false, autoOffModifier: true, duration: .minutes(15), trigger: .timeUntilAlert(0), beepRepeat: .every1MinuteFor15Minutes, beepType: .bipBeepBipBeepBipBeepBipBeep)
        XCTAssertEqual("020f00000202", alertConfig3.data.hexadecimalString)
        
        let configureAlerts = ConfigureAlertsCommand(nonce: 0xfeb6268b, configurations:[alertConfig1, alertConfig2, alertConfig3])
        XCTAssertEqual("1916feb6268b79a410df0502280012830602020f00000202", configureAlerts.data.hexadecimalString)
        
        do {
            let decoded = try ConfigureAlertsCommand(encodedData: Data(hexadecimalString: "1916feb6268b79a410df0502280012830602020f00000202")!)
            XCTAssertEqual(3, decoded.configurations.count)
            
            let config1 = decoded.configurations[0]
            XCTAssertEqual(.slot7, config1.slot)
            XCTAssertEqual(true, config1.active)
            XCTAssertEqual(false, config1.autoOffModifier)
            XCTAssertEqual(.hours(7), config1.duration)
            if case AlertTrigger.timeUntilAlert(let duration) = config1.trigger {
                XCTAssertEqual(podSoftExpirationTime, duration)
            }
            XCTAssertEqual(.every60Minutes, config1.beepRepeat)
            XCTAssertEqual(.bipBeepBipBeepBipBeepBipBeep, config1.beepType)
            
            let cfg = try AlertConfiguration(encodedData: Data(hexadecimalString: "4c0000640102")!)
            XCTAssertEqual(.slot4, cfg.slot)
            XCTAssertEqual(true, cfg.active)
            XCTAssertEqual(false, cfg.autoOffModifier)
            XCTAssertEqual(0, cfg.duration)
            if case AlertTrigger.unitsRemaining(let volume) = cfg.trigger {
                XCTAssertEqual(10, volume)
            }
            XCTAssertEqual(.every1MinuteFor3MinutesAndRepeatEvery60Minutes, cfg.beepRepeat)
            XCTAssertEqual(.bipBeepBipBeepBipBeepBipBeep, cfg.beepType)


        } catch (let error) {
            XCTFail("message decoding threw error: \(error)")
        }
    }
}
