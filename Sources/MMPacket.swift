//
//  MMPacket.swift
//  MMSocket
//
//  Created by Mathieu Guindon on 2018-03-04.
//  Copyright © 2018 Mathieu Guindon. All rights reserved.
//

import Foundation

public class MMPacket<T: Codable> : MMPacketBase {
  
  var payload: T
  
  public init(_ msgType: Int, withPayload: T) {
    self.payload = withPayload
    super.init(msgType)
  }
  
//  public init(withData: Data) {
//      
//  }
  
  public func asData() -> Data
  {
    var data = Data(capacity: 256)
    let encoder = JSONEncoder()
    
    //payload
    let payloadData = try! encoder.encode(self.payload)

    //header
    self.header.payloadSize = payloadData.count
    let headerData = try! encoder.encode(self.header)      
    
    data.append(headerData)
    data.append(payloadData)
    
    return data
  }
  
}
