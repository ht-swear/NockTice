//
//  ViewController.swift
//  GetSound
//
//  Created by Yusaku Eigen on 2016/07/23.
//  Copyright © 2016年 栄元優作. All rights reserved.
//

import UIKit
import AudioToolbox
import CoreBluetooth

private func AudioQueueInputCallback(
    inUserData: UnsafeMutablePointer<Void>,
    inAQ: AudioQueueRef,
    inBuffer: AudioQueueBufferRef,
    inStartTime: UnsafePointer<AudioTimeStamp>,
    inNumberPacketDescriptions: UInt32,
    inPacketDescs: UnsafePointer<AudioStreamPacketDescription>)
{
    // Do nothing, because not recoding.
}


class ViewController: UIViewController, CBPeripheralManagerDelegate {
    
    var timer: NSTimer!
    var queue: AudioQueueRef!
    var flag = 0
    var users:[String] = []
    var dataFormat = AudioStreamBasicDescription(mSampleRate: 44100.0,
                                                 mFormatID: kAudioFormatLinearPCM,
                                                 mFormatFlags: AudioFormatFlags(kLinearPCMFormatFlagIsBigEndian |
                                                    kLinearPCMFormatFlagIsSignedInteger |
                                                    kLinearPCMFormatFlagIsPacked),
                                                 mBytesPerPacket: 2,
                                                 mFramesPerPacket: 1,
                                                 mBytesPerFrame: 2,
                                                 mChannelsPerFrame: 1,
                                                 mBitsPerChannel: 16,
                                                 mReserved: 0)
    
    // BLE
    
    var peripheralManager: CBPeripheralManager!
    var serviceUUID: CBUUID!
    var characteristic: CBMutableCharacteristic!
    var userData:NSString!
    var data:NSData!
    var clocktimer: NSTimer = NSTimer()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    @IBAction func startGetSound(sender: AnyObject) {
        var audioQueue: AudioQueueRef = nil
        var error = noErr
        error = AudioQueueNewInput(
            &dataFormat,
            AudioQueueInputCallback,
            UnsafeMutablePointer(unsafeAddressOf(self)),
            .None,
            .None,
            0,
            &audioQueue)
        if error == noErr {
            self.queue = audioQueue
        }
        AudioQueueStart(self.queue, nil)
        
         self.peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: nil)
        
        // Enable level meter
        var enabledLevelMeter: UInt32 = 1
        AudioQueueSetProperty(self.queue, kAudioQueueProperty_EnableLevelMetering, &enabledLevelMeter, UInt32(sizeof(UInt32)))
        
        self.timer = NSTimer.scheduledTimerWithTimeInterval(0.65,
                                                            target: self,
                                                            selector: #selector(ViewController.detectVolume(_:)),
                                                            userInfo: nil,
                                                            repeats: true)
        self.timer?.fire()
    }
    
    
    
    func stopUpdatingVolume(){
        
        // Finish observation
        self.timer.invalidate()
        self.timer = nil
        AudioQueueFlush(self.queue)
        AudioQueueStop(self.queue, false)
        AudioQueueDispose(self.queue, true)
    }
    
    
    func detectVolume(timer: NSTimer){
        
        // Get level
        var levelMeter = AudioQueueLevelMeterState()
        var propertySize = UInt32(sizeof(AudioQueueLevelMeterState))
        
        AudioQueueGetProperty(
            self.queue,
            kAudioQueueProperty_CurrentLevelMeterDB,
            &levelMeter,
            &propertySize)
        
        // Show the audio channel's peak and average RMS power.
//        print("".stringByAppendingFormat("%.2f", levelMeter.mPeakPower))
        
        if flag == 1 && levelMeter.mPeakPower >= -1.0 {
            flag = 0
            postUser()
        }else if flag == 0 && levelMeter.mPeakPower >= -1.0 {
            flag += 1
        }else{
            flag = 0
        }
        
    }
    
    func postUser() {
        let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        let url = NSURL(string: "https://life-cloud.ht.sfc.keio.ac.jp/~eigen/key/slack_api.php")!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        request.HTTPBody = "User=\(users)".dataUsingEncoding(NSUTF8StringEncoding)
        
        let task = session.dataTaskWithRequest(request, completionHandler:{
            (data, response, error) in
            if error == nil{
                let httpResponse = response as? NSHTTPURLResponse
                if (httpResponse?.statusCode == 200) {
                    print("通信成功しているよ")
                    let result = NSString(data: data!, encoding: NSUTF8StringEncoding)
                    print(result!)
                    
                }
            }
        })
        task.resume()
        
    }
    // ペリフェラルマネージャの状態が変化すると呼ばれる
    func peripheralManagerDidUpdateState(peripheral: CBPeripheralManager) {
        
        print("state: \(peripheral.state)")
        
        switch peripheral.state {
            
        case CBPeripheralManagerState.PoweredOn:
            // サービスを作成
            self.serviceUUID = CBUUID(string: "0000")
            let service = CBMutableService(type: serviceUUID, primary: true)
            
            // キャラクタリスティックを作成
            let characteristicUUID = CBUUID(string: "0001")
            
            let properties = CBCharacteristicProperties.Write
            
            let permissions = CBAttributePermissions.Writeable
            
            self.characteristic = CBMutableCharacteristic(
                type: characteristicUUID,
                properties: properties,
                value: nil,
                permissions: permissions)
            
            // キャラクタリスティックをサービスにセット
            service.characteristics = [self.characteristic]
            
            // サービスを Peripheral Manager にセット
            self.peripheralManager.addService(service)
            break
            
        default:
            break
        }
    }
    
    
    // サービス追加処理が完了すると呼ばれる
    func peripheralManager(peripheral: CBPeripheralManager, didAddService service: CBService, error: NSError?) {
        
        if (error != nil) {
            print("サービス追加失敗！ error: \(error)")
            return
        }
        
        print("サービス追加成功！")
        // アドバタイズメントデータを作成する
        let advertisementData: Dictionary = [
            CBAdvertisementDataLocalNameKey: "Test Device",
            CBAdvertisementDataServiceUUIDsKey: [self.serviceUUID]
        ]
        // アドバタイズ開始
        self.peripheralManager.startAdvertising(advertisementData)
    }
    
    // アドバタイズ開始処理が完了すると呼ばれる
    func peripheralManagerDidStartAdvertising(peripheral: CBPeripheralManager, error: NSError?) {
        
        if (error != nil) {
            print("アドバタイズ開始失敗！ error: \(error)")
            return
        }
        
        print("アドバタイズ開始成功！")
    }
    
    
    func peripheralManager(peripheral: CBPeripheralManager, didReceiveWriteRequests requests: [CBATTRequest]) {
        print("\(requests.count) 件のWriteリクエスト受信！")
        for request in requests {
            
            if request.characteristic.UUID.isEqual(characteristic.UUID) {
                
                //                 print("Requested value:\(request.value) service uuid:\(request.characteristic.service.UUID) characteristic uuid:\(request.characteristic.UUID)")
                
                // CBCharacteristicのvalueに、CBATTRequestのvalueをセット
                characteristic.value = request.value
                self.userData = NSString(data: characteristic.value!, encoding: NSUTF8StringEncoding)!
                users.append(self.userData as String)
                self.clocktimer.invalidate()
                //timer
                self.clocktimer = NSTimer.scheduledTimerWithTimeInterval(40.0, target: self, selector: #selector(ViewController.lognow(_:)), userInfo: nil, repeats: true)
                
                print(self.userData)
            }
        }
        
        // リクエストに応答
        peripheralManager.respondToRequest(requests[0], withResult: .Success)
    }
    func lognow(clocktimer:NSTimer){
        print("not connected")
        self.users = []
    }
}

