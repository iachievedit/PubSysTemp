//
// Copyright 2016 iAchieved.it LLC
//
// MIT License (https://opensource.org/licenses/MIT)
//

import swiftlog
import Glibc
import Foundation

var secure:Bool = false
var verifyBundle:String?
if Process.arguments.count == 3 {
  if Process.arguments[1] == "secure" {
    verifyBundle = Process.arguments[2]
    secure       = true
  }
}

slogLevel = .Verbose // Change to .Verbose to get real chatty

slogToFile(atPath:"/tmp/pubSysTemp.log")

let BUFSIZE = 128
var buffer  = [CChar](repeating:0, count:BUFSIZE)
guard gethostname(&buffer, BUFSIZE) == 0 else {
  SLogError("Unable to obtain hostname")
  exit(-1)
}

let client = Client(clientId:String(cString:buffer))
//client.host = "mqtt.no-ip.info"
client.host = "192.168.1.131"
client.keepAlive = 10

if secure {
  client.secureMQTT = secure
  client.port       = 8883
}

let nc = NotificationCenter.defaultCenter()
var reportTemperature:Timer?

_ = nc.addObserverForName(DisconnectedNotification.name, object:nil, queue:nil){_ in
  SLogInfo("Connecting to broker")

  reportTemperature?.invalidate()
  if !client.connect() {
    SLogError("Unable to connect to broker.hivemq.com, retrying in 30 seconds")
    let retryInterval     = 30
    let retryTimer        = Timer.scheduledTimer(withTimeInterval:TimeInterval(retryInterval),
                                                   repeats:false){ _ in
      nc.postNotification(DisconnectedNotification)
    }
    RunLoop.current().add(retryTimer, forMode:RunLoopMode.defaultRunLoopMode)
  }
}

_ = nc.addObserverForName(ConnectedNotification.name, object:nil, queue:nil) {_ in

  let reportInterval    = 20
  reportTemperature = Timer.scheduledTimer(withTimeInterval:TimeInterval(reportInterval),
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
                                                                           
  RunLoop.current().add(reportTemperature!, forMode:RunLoopMode.defaultRunLoopMode)

}

nc.postNotification(DisconnectedNotification) // Kick the connection

let heartbeat = Timer.scheduledTimer(withTimeInterval:TimeInterval(30), repeats:true){_ in return}
RunLoop.current().add(heartbeat, forMode:RunLoopMode.defaultRunLoopMode)
RunLoop.current().run()

