//
//  PacketExample.swift
//  MMSocket
//
//  Created by Mathieu Guindon on 2018-03-27.
//  Copyright © 2018 Mathieu Guindon. All rights reserved.
//

import Foundation

enum PacketType : Int {
  case ExamplePacket = 1
}


class ExamplePayload : Codable {
  var aString : String = ""
  public init(withString aString: String) {
    self.aString = aString
  }
}
