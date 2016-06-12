//
// Copyright 2016 iAchieved.it LLC
//
// MIT License (https://opensource.org/licenses/MIT)
//

import Glibc

// NOTE:  If your CPU temperature is provided in a different location
//        change it here:
let CpuTemperatureFile = "/sys/class/hwmon/hwmon0/temp1_input"

struct CPU {
  var temperature:Double? {
    get {
      let BUFSIZE = 16
      let pp      = popen("cat " + CpuTemperatureFile, "r")
      var buf     = [CChar](repeating:0, count:BUFSIZE)
      guard fgets(&buf, Int32(BUFSIZE), pp) != nil else {
	pclose(pp)
        return nil
      }
      pclose(pp)
      
      let s = String(String(cString:buf).characters.dropLast())
      if let t = Double(s) {
        return t/1000
      } else {
        return nil
      }
    }
  }
}
