//
//  MMSocket.swift
//  Flow
//
//  Created by Mathieu Guindon on 2018-02-26.
//  Copyright © 2018 Mathieu Guindon. All rights reserved.
//

import Foundation

public class MMSocketServer {
  
  var sock_fd: Int32 = -1
  var listenSource:  DispatchSourceRead? = nil
  var socketClient: MMSocketClient? = nil
  var netService: NetService?
  
  public var port: UInt16 = 0
  
  public init() {
  }
  
  deinit {
    self.stop()
  }
  
  //will start listening on specified port
  //this will be published on bonjour if a proper config is passed. If empty config is passed no publishing will occur
  public func startListening(onPort: UInt16, publishingOnBonjour bonjourConfig: MMBonjourConfig,
                             withClientHandler clientHandler: @escaping (MMSocketClient) -> ()) throws {
    
    self.sock_fd = socket(AF_INET, SOCK_STREAM, 0)
    
    if self.sock_fd == -1 {
      throw MMSocketError(MMSocketError.Code.FailToCreate)
    }
    
    var sock_opt_on = Int32(1)
    setsockopt(self.sock_fd, SOL_SOCKET, SO_REUSEADDR, &sock_opt_on, socklen_t(MemoryLayout.size(ofValue: sock_opt_on)))
    _ = fcntl(self.sock_fd, F_SETFL, O_NONBLOCK)
    
    var server_addr = sockaddr_in()
    var server_addr_size = socklen_t(MemoryLayout.size(ofValue: server_addr))
    server_addr.sin_len = UInt8(server_addr_size)
    server_addr.sin_addr.s_addr = INADDR_ANY;
    server_addr.sin_family = sa_family_t(AF_INET) // chooses IPv4
    server_addr.sin_port = onPort
    
    let bind_server = withUnsafePointer(to: &server_addr) {
      bind(self.sock_fd, UnsafeRawPointer($0).assumingMemoryBound(to: sockaddr.self), server_addr_size)
    }
    
    if bind_server == -1 {
      close(self.sock_fd)
      throw MMSocketError(MMSocketError.Code.FailToBind)
    }
    
    withUnsafeMutablePointer(to: &server_addr) {
      ptr in _ = ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { ptrSockAddr in
        getsockname(sock_fd, UnsafeMutablePointer(ptrSockAddr), &server_addr_size)
      }
      
      self.port = UInt16(bigEndian:server_addr.sin_port)
    }
    
    if listen(self.sock_fd, 1) == -1 {
      self.stop()
      throw MMSocketError(MMSocketError.Code.FailToListen)
    }

    //publish this on bonjour if a config has been passed
    if !bonjourConfig.domain.isEmpty && !bonjourConfig.name.isEmpty && !bonjourConfig.type.isEmpty {
      self.netService = NetService(domain: bonjourConfig.domain,
                                   type: bonjourConfig.type,
                                   name: bonjourConfig.name,
                                   port: Int32(self.port))
      self.netService!.publish(options: [])
    }
    
    listenSource = DispatchSource.makeReadSource(fileDescriptor: sock_fd)//queue: DispatchQueue.global())
        
    listenSource!.setEventHandler {
      var client_addr = sockaddr_storage()
      var client_addr_len = socklen_t(MemoryLayout.size(ofValue: client_addr))
      
      //block on accept
      let client_fd = withUnsafeMutablePointer(to: &client_addr) {
        accept(self.sock_fd, UnsafeMutableRawPointer($0).assumingMemoryBound(to: sockaddr.self), &client_addr_len)
      }
      
      if client_fd != -1 {
        //always allow only 1 client at a time. The previous one will be disconnected
        try? self.socketClient?.close()
        self.socketClient = nil
        
        self.socketClient = MMSocketClient.init(withSocketHandle: client_fd)
        clientHandler(self.socketClient!)
      }          
    }
    
    listenSource?.resume()
  }
  
  public func stop() {
    if (self.sock_fd != -1) {
      close(self.sock_fd)
    }
    
    if listenSource != nil {
      listenSource?.cancel()
    }
  }
  
}
