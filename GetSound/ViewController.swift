//
//  ViewController.swift
//  GetSound
//
//  Created by Yusaku Eigen on 2016/07/23.
//  Copyright © 2016年 栄元優作. All rights reserved.
//

import UIKit
import AudioToolbox

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


class ViewController: UIViewController {
    
    var timer: NSTimer!
    var queue: AudioQueueRef!
    var flag = 0
    
    var users:[String] = ["test"]
    
    
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
        print("".stringByAppendingFormat("%.2f", levelMeter.mPeakPower))
        
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
    
}

