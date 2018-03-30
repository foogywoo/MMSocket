//
//  ViewController.swift
//  SimpleServerExampleTVOS
//
//  Created by Mathieu Guindon on 2018-03-27.
//  Copyright © 2018 Mathieu Guindon. All rights reserved.
//

import UIKit
import MMSocket

class ViewController: UIViewController {

  var socketServer = MMSocketServer()
  var socketEngine = MMSocketEngine()

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    
    self.socketEngine.on(PacketType.ExamplePacket.rawValue) { payloadData in
      let jsonDecoder = JSONDecoder()
      
      guard let decodedPayload = try? jsonDecoder.decode(ExamplePayload.self, from: payloadData) else {
        print("fail to decode JSON")
        return
      }
      
      print(decodedPayload)

      DispatchQueue.main.async {
//        self.authCodeLabel.text = "\(decodedPayload.authCode)"
//        self.requestForAccessToken(authorizationCode:decodedPayload.authCode)
      }
    }
  }
  
  deinit {
    socketServer.stop()
  }
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let bonjourConfig = MMBonjourConfig(domain: "local.", type: "_mmtest._tcp.", name: "mmtest")
    do {
      try socketServer.startListening(onPort: 0, publishingOnBonjour: bonjourConfig) { client in
        print("client connected.")
        do {
          try client.startReceiving() { receiving_client in
            self.socketEngine.onReceive(socketClient: receiving_client)
          }
        } catch let error as MMSocketError {
          print("fail to start receiving: \(error)")
        } catch {
          print("fail to start receiving: unhandled error")
        }
      }
    } catch let error as MMSocketError {
      print("fail to start listening: \(error)")
    } catch {
      print("fail to start receiving: unhandled error")
    }
    
    print("Listening on port \(socketServer.port)")

  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }


}

