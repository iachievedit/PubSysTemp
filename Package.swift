import PackageDescription

let package = Package(
  name: "PubSysTemp",
  dependencies:[
  //  .Package(url:"https://github.com/iachievedit/MQTT", majorVersion:0, minor:1)
    .Package(url:"../MQTT", majorVersion:0, minor:1)
  ]
)
