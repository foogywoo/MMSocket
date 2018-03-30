//
//  MMSocketBase.swift
//  MMSocket
//
//  Created by Mathieu Guindon on 2018-03-05.
//  Copyright © 2018 Mathieu Guindon. All rights reserved.
//

import Foundation


public class MMPacketBase {
  
  public struct Header : Codable {
    let validationMarker = "@MM@"
    var messageType: Int = 0
    var payloadSize: Int = 0
    var encodedPayloadSize: String {
      get {
         return String(format: "%16d", self.payloadSize)
      }
      set {
        guard let size = Int(newValue.trimmingCharacters(in: .whitespaces)) else
        {
          print("Error decoding encodedPayloadSize")
          self.payloadSize = 0
          return
        }
        self.payloadSize = size
      }
    }
    
    public init(messageType: Int, payloadSize: Int) {
      self.messageType = messageType
      self.payloadSize = payloadSize
    }
    
    enum CodingKeys: String, CodingKey {
      case validationMarker
      case messageType
      case encodedPayloadSize
    }
    
    public init(from decoder: Decoder) throws {
      let values = try decoder.container(keyedBy: CodingKeys.self)
      messageType = try values.decode(Int.self, forKey: .messageType)
      encodedPayloadSize = try values.decode(String.self, forKey: .encodedPayloadSize)
    }
    
    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(validationMarker, forKey: .validationMarker)
      try container.encode(messageType, forKey: .messageType)
      try container.encode(encodedPayloadSize, forKey: .encodedPayloadSize)
    }
  
  }
  
  public var header: Header
  
  static var headerSize: Int {
    get {
      //compute header size
      let header = Header(messageType: 0, payloadSize: 0)
      let encoder = JSONEncoder()
      let headerData = try! encoder.encode(header)
      return headerData.count
    }
  }
  
  
  public init(_ msgType: Int) {
    self.header = Header(messageType: msgType, payloadSize: 0)
  }
  
  public init( withData: Data) throws {
    let jsonDecoder = JSONDecoder()
    let decodedHeader = try jsonDecoder.decode(Header.self, from: withData)
    self.header = decodedHeader
  }
  
}
