# MMSocket

MMSocket framework provides a simple way of creating swift client and server sockets on both iOS and tvOS.

I created this simple framework for a project in which I needed to exchange some data between a tvOS app and a iOS companion app.

## Features
* iOS and tvOS support
* Pure swift
* Zero configuration support using Bonjour
* Fully asynchronous operations using GCD
* Simple protocol implementation to send various data packets  encoded in JSON
* No external dependencies

## Installation
### Cartage
To integrate MMSocket into your Xcode project using Carthage, specify it in your Cartfile:

`github "MMSocket/MMSocket"`

Run /carthage update/ to build the framework and drag the built MMSocket.framework into your Xcode project.

# Code examples
## Client socket example
```swift
class ExamplePayload : Codable {
var aString : String = ""
public init(withString aString: String) {
self.aString = aString
}
}

//look for a bonjour service named mmtest
let bonjourConfig = MMBonjourConfig(domain: "local.", type: "_mmtest._tcp.", name: "mmtest")

//connect to this bonjour service
try? self.socketClient.connectTo(withBonjourConfig: bonjourConfig, closeHandler: self.closeHandler) {

//prepare a packet of type 0x01 with ExamplePayload     
let payload = ExamplePayload(withString: "a simple string payload")
let packet = MMPacket<ExamplePayload>(0x01, withPayload: payload)
let packedData = packet.asData()

//send the packet
try? self.socketClient.sendData(packedData)
}

```

## Server socket example
```swift

class ExamplePayload : Codable {
var aString : String = ""
public init(withString aString: String) {
self.aString = aString
}
}

//Advertise ourself as a bonjour service named mmtest
let bonjourConfig = MMBonjourConfig(domain: "local.", type: "_mmtest._tcp.", name: "mmtest")

//Start listening using this bonjour config.
//Passing 0 for the port means it will be automatically assigned
try? socketServer.startListening(onPort: 0, publishingOnBonjour: bonjourConfig) { client in

//Start receiving. This will trigger when data is received on this socket
//we forward this to the Socket Engine which will make sense of the packets.
//You can decide to handle data by yourself, SocketEngine usage is not mandatory.
try? client.startReceiving() { receiving_client in
self.socketEngine.onReceive(socketClient: receiving_client)
}
}

//Subscribe for packet of type 0x01
//when received, the packet string will be decoded and printed
self.socketEngine.on(0x01) { payloadData in
let jsonDecoder = JSONDecoder()
guard let decPayload = try? jsonDecoder.decode(ExamplePayload.self, from: payloadData) else {
print("fail to decode payload")
return
}
print(decPayload)
}

//DISCLAIMER: Error handling have been intentionaly excluded in this sample code for reading simplicity. Have a look at the full SimpleServerExampleTVOS for proper error handling. 
```

## Sample projects
### SimpleServerExampleTVOS
A basic server running on tvOS

### SimplerClientExampleIOS
A basic client running pn iOS. It will try to connect to a bonjour client of type /mmtest/ (the one defined in SimpleServerExampleTVOS) and then send a simple string.

---
