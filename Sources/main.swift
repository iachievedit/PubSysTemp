//
// Copyright 2016 iAchieved.it LLC
//
// MIT License (https://opensource.org/licenses/MIT)
//

import swiftlog
import Glibc
import Foundation

slogLevel = .Info // Change to .Verbose to get real chatty

slogToFile(atPath:"/tmp/pubSysTemp.log")

let BUFSIZE = 128
var buffer  = [CChar](repeating:0, count:BUFSIZE)
guard gethostname(&buffer, BUFSIZE) == 0 else {
  SLogError("Unable to obtain hostname")
  exit(-1)
}

let client = Client(clientId:String(cString:buffer))
client.host = "broker.hivemq.com"
client.keepAlive = 10

let nc = NSNotificationCenter.defaultCenter()
var reportTemperature:NSTimer?

_ = nc.addObserverForName("DisconnectedNotification", object:nil, queue:nil){_ in
  SLogInfo("Connecting to broker")

  reportTemperature?.invalidate()
  if !client.connect() {
    SLogError("Unable to connect to broker.hivemq.com, retrying in 30 seconds")
    let retryInterval     = 30
    let retryTimer        = NSTimer.scheduledTimer(NSTimeInterval(retryInterval),
                                                   repeats:false){ _ in
      nc.postNotificationName("DisconnectedNotification", object:nil)
    }
    NSRunLoop.currentRunLoop().addTimer(retryTimer, forMode:NSDefaultRunLoopMode)
  }
}

_ = nc.addObserverForName("ConnectedNotification", object:nil, queue:nil) {_ in

  let reportInterval    = 10
  reportTemperature = NSTimer.scheduledTimer(NSTimeInterval(reportInterval),
                                                 repeats:true){_ in

    if client.connState == .CONNECTED {
      if let cpuTemperature = CPU().temperature {
        _ = client.publish(topic:"/\(client.clientId)/cpu/temperature/value",
                           withString:String(cpuTemperature))
        SLogInfo("Published temperature to \(cpuTemperature)")
      } else {
        SLogError("Unable to obtain CPU temperature")
      }
    } else {
      SLogError("MQTT client is not connected")
    }
  }
                                                                           
  NSRunLoop.currentRunLoop().addTimer(reportTemperature!, forMode:NSDefaultRunLoopMode)

}

nc.postNotificationName("DisconnectedNotification", object:nil) // Kick the connection

let heartbeat = NSTimer.scheduledTimer(NSTimeInterval(30), repeats:true){_ in return}
NSRunLoop.currentRunLoop().addTimer(heartbeat, forMode:NSDefaultRunLoopMode)
NSRunLoop.currentRunLoop().run()

