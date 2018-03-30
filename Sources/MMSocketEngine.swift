//
//  MMSocketEngine.swift
//  MMSocket
//
//  Created by Mathieu Guindon on 2018-03-05.
//  Copyright © 2018 Mathieu Guindon. All rights reserved.
//

import Foundation

public class MMSocketEngine {
  
  var handlersDictionary: [Int : [(Data) -> Void]]

  public init() {
    self.handlersDictionary = [Int : [(Data) -> Void]]()
  }
  
  //temp
  public func simulateReceivePacket(packetType: Int, data: Data) {
    //let handler = self.handlers[0]
    //handler(data)
  }
  
  public func onReceive(socketClient: MMSocketClient) {
    // reading packet header
    let headerSize = MMPacketBase.headerSize
    
    do {
      let headerData = try socketClient.readData(size: headerSize)
      
      //create packet from header data
      print("header => " + String(data: headerData, encoding: .utf8)!)
      guard let packet = try? MMPacketBase(withData: headerData) else {
        print("Fail to decode header")
        return
      }
      
      //read packet payload
      guard let payloadData = try? socketClient.readData(size: packet.header.payloadSize) else {
        print("Fail to read payload data")
        return
      }
      
      print("payload => " + String(data: payloadData, encoding: .utf8)!)
      
      guard let handlers = self.handlersDictionary[packet.header.messageType] else {
        print("No handler defined for packet of type \(packet.header.messageType)")
        return
      }
      
      guard !handlers.isEmpty else {
        print("No handler defined for packet of type \(packet.header.messageType)")
        return
      }
      
      //call each handlers with the payload as Data
      for handler in handlers {
        handler(payloadData)
      }

    } catch let error as MMSocketError where error.code == MMSocketError.Code.SocketClosed {
      print("Socket closed: \(error)")
      return
    } catch {
      print("Fail to read header data")
      return
    }
  }
  
  public func on(_ packetType: Int, handler: @escaping (Data) -> Void) {
    var handlers = self.handlersDictionary[packetType]
    
    if handlers == nil {
      handlers = [(Data) -> Void]()
      self.handlersDictionary[packetType] = handlers
    }
    
     self.handlersDictionary[packetType]!.append(handler)
  }
}
