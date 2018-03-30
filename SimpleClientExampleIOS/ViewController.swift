//
//  ViewController.swift
//  SimpleClientExampleIOS
//
//  Created by Mathieu Guindon on 2018-03-27.
//  Copyright © 2018 Mathieu Guindon. All rights reserved.
//

import UIKit
import MMSocket

class ViewController: UIViewController {
  
  var socketClient = MMSocketClient()
  var socketEngine = MMSocketEngine()

  override func viewDidLoad() {
    super.viewDidLoad()
    
    let bonjourConfig = MMBonjourConfig(domain: "local.", type: "_mmtest._tcp.", name: "mmtest")
    do {
      try self.socketClient.connectTo(withBonjourConfig: bonjourConfig, closeHandler: self.closeHandler) {
        
        print("connected to appleTV!")
        
        //send some data
        let payload = ExamplePayload(withString: "a simple string payload")
        let packet = MMPacket<ExamplePayload>(PacketType.ExamplePacket.rawValue, withPayload: payload)
        let packedData = packet.asData()
        print(String(data: packedData, encoding: .utf8)!)
        
        try? self.socketClient.sendData(packedData)
        do {
          try self.socketClient.startReceiving() { receiving_client in
            self.socketEngine.onReceive(socketClient: receiving_client)
          }
        } catch let error as MMSocketError {
          print("fail to start receiving: \(error)")
        } catch {
          print("fail to start receiving: unhandled error")
        }
      }
    } catch let error as MMSocketError {
      print("could not connect: \(error)")
    } catch {
      print("could not connect: unhandled error")
    }
  }

  func closeHandler() {
    print("socked closed, will try to reconnect")
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }


}

