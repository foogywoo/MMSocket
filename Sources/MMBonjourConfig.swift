
//
//  MMBonjourConfig.swift
//  MMSocket
//
//  Created by Mathieu Guindon on 2018-03-13.
//  Copyright © 2018 Mathieu Guindon. All rights reserved.
//

import Foundation

public struct MMBonjourConfig {
  public private(set) var domain: String = ""
  public private(set) var type: String = ""
  public private(set) var name: String = ""

  public init(domain: String, type: String, name: String) {
    self.domain = domain
    self.type = type
    self.name = name
  }
}
