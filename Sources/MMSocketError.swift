//
//  SocketError.swift
//  Flow
//
//  Created by Mathieu Guindon on 2018-02-28.
//  Copyright © 2018 Mathieu Guindon. All rights reserved.
//

import Foundation

public struct MMSocketError: Swift.Error, CustomStringConvertible {
  
  public enum Code {
    case FailToCreate
    case FailToBind
    case FailToConnect
    case FailToListen
    case FailToAcccept
    case FailToSend
    case SocketClosed
    case FailToRead
    case FailToClose
    case SocketNotConnected
  }

  public private(set) var code: Code
  public private(set) var posixReason: String
  public private(set) var additionalInfo: String = ""
  
  public var description: String {
    
    return "Error: \(self.code): \(self.posixReason) \(additionalInfo)"
  }
  
  init(_ code: Code, info: String = "") {
    
    self.code = code
    self.additionalInfo = info
    self.posixReason = String(validatingUTF8: strerror(errno)) ?? "Error: \(errno)"
  }
}

