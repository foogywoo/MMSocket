//
//  MMSocketClient.swift
//  MMSocket
//
//  Created by Mathieu Guindon on 2018-03-01.
//  Copyright © 2018 Mathieu Guindon. All rights reserved.
//

import Foundation

public class MMSocketClient: NSObject {
  
  var sock_fd: Int32 = -1
  var readSource: DispatchSourceRead? = nil
  var connectSource: DispatchSourceWrite? = nil
  var sendQueue = [Data]()
  var closeHandler : (() -> ())?

  //bonjour related
  var browser: NetServiceBrowser!
  var services: NSMutableArray = []
  var onConnectHandler: (() -> ())?

  
  public convenience init(withSocketHandle: Int32) {
    self.init()
    
    //no sigpipe on disconnection, otherwise process will stop
    var sock_opt_on = Int32(1)
    setsockopt(self.sock_fd, SOL_SOCKET, SO_NOSIGPIPE, &sock_opt_on, socklen_t(MemoryLayout.size(ofValue: sock_opt_on)))

    if withSocketHandle == -1 {
      print("SocketClient init called with an invalid socket")
    } else {
      self.sock_fd = withSocketHandle
    }
  }
  
  public override init() {
    self.sendQueue.reserveCapacity(10)
  }
  
  public func startReceiving(_ receiveHandler: @escaping (MMSocketClient) -> ()) throws {
    guard self.sock_fd != -1 else {
      throw MMSocketError(MMSocketError.Code.SocketNotConnected)
    }

    print("start receiving...")
    self.readSource = DispatchSource.makeReadSource(fileDescriptor: self.sock_fd)//queue: DispatchQueue.global())
    
    self.readSource!.setEventHandler {
      receiveHandler(self)
    }
    
    self.readSource?.resume()
  }
  
  public func connectTo(_ address: String, onPort: Int, closeHandler: @escaping () -> (), onConnect: @escaping () -> ()) throws {
    print("conneting...")
    self.sock_fd = socket(AF_INET, SOCK_STREAM, 0)
    
    if self.sock_fd == -1 {
      throw MMSocketError(MMSocketError.Code.FailToCreate)
    }

    self.closeHandler = closeHandler
    
    let flags = fcntl(self.sock_fd, F_GETFL, 0)
    let fcntlStatus = fcntl(self.sock_fd, F_SETFL, flags | O_NONBLOCK)

    //no sigpipe on disconnection, otherwise process will stop
    var sock_opt_on = Int32(1)
    setsockopt(self.sock_fd, SOL_SOCKET, SO_NOSIGPIPE, &sock_opt_on, socklen_t(MemoryLayout.size(ofValue: sock_opt_on)))
    
    if fcntlStatus == -1 {
      try self.close()
      print("error \(errno)")
      throw MMSocketError(MMSocketError.Code.FailToCreate)
    }
    
    var client_addr = sockaddr_in()
    let client_addr_size = socklen_t(MemoryLayout.size(ofValue: client_addr))
    client_addr.sin_len = UInt8(client_addr_size)
    inet_pton(AF_INET, address, &(client_addr.sin_addr));
    client_addr.sin_family = sa_family_t(AF_INET) // chooses IPv4
    client_addr.sin_port = in_port_t((CUnsignedShort(onPort).bigEndian))
    
    connectSource = DispatchSource.makeWriteSource(fileDescriptor: sock_fd)
    
    connectSource!.setEventHandler {
      
        _ = withUnsafePointer(to: &client_addr) {
        Darwin.connect(self.sock_fd, UnsafeRawPointer($0).assumingMemoryBound(to: sockaddr.self), client_addr_size)
        }

      let err = errno;
      if (err == ECONNREFUSED) {
        print("error \(errno)")
        //TODO: call onError
        self.connectSource?.cancel()
      }
      else if (err == EISCONN) {
        onConnect()
        self.connectSource?.cancel()
      }
    }
    
    try withUnsafePointer(to: &client_addr) {
      Darwin.connect(self.sock_fd, UnsafeRawPointer($0).assumingMemoryBound(to: sockaddr.self), client_addr_size)
      if errno != EINPROGRESS {
        try self.close()
        print("error \(errno)")
        throw MMSocketError(MMSocketError.Code.FailToConnect)
      }
    }
    
    connectSource?.resume()
  }
  
  public func sendData(_ data: Data) throws {
    guard self.sock_fd != -1 else {
      throw MMSocketError(MMSocketError.Code.SocketNotConnected)
    }

    print("sending data \(data.count) bytes")
    self.sendQueue.append(data)
    try self.sendQueuedData()
  }
  
  private func sendQueuedData() throws {
    guard !self.sendQueue.isEmpty else {
        return
    }
    while !self.sendQueue.isEmpty {
      let data = self.sendQueue.removeFirst()
      
      let dispatchData = data.withUnsafeBytes { DispatchData(bytes: UnsafeRawBufferPointer(start: $0, count: data.count)) }

      DispatchIO.write(toFileDescriptor: self.sock_fd, data: dispatchData, runningHandlerOn: DispatchQueue.global()) { asyncData, error in
        if error != 0 {
          print("sendData error \(error)")
        }
      }
    }
  }
  
  public func readData( size: Int) throws -> Data {
    guard self.sock_fd != -1 else {
      throw MMSocketError(MMSocketError.Code.SocketNotConnected)
    }
    
    var totalReadCount = 0
    var buf = [UInt8](repeating: 0, count: size)
    var data = Data(capacity: size)
    
    while totalReadCount < size {
      let readCount = read(self.sock_fd, &buf, size - totalReadCount)
      
      switch readCount {
      case 0:
        //nothing left to read, meaning closed
        try self.close()
        throw MMSocketError(MMSocketError.Code.SocketClosed)
      case let st where st < 0:
        throw MMSocketError(MMSocketError.Code.FailToRead)
      default:
        totalReadCount+=readCount
        data.append(buf, count:readCount)
      }
    }
    
    return data
  }
  
  public func close() throws {
    guard self.sock_fd != -1 else {
      throw MMSocketError(MMSocketError.Code.SocketNotConnected)
    }

    print("closing socket")
    //stop the 2 sources
    if self.readSource != nil {
      self.readSource?.cancel()
    }

    if self.connectSource != nil {
      self.connectSource?.cancel()
    }

    if Darwin.close(self.sock_fd) == -1 {
      throw MMSocketError(MMSocketError.Code.FailToClose)
    }
    
    self.sendQueue.removeAll()
    
    self.sock_fd = -1
    
    self.closeHandler?()
  }
  
  deinit {
    if sock_fd != -1 {
      try? self.close()
    }
  }
}

//bonjour extension
extension MMSocketClient: NetServiceBrowserDelegate, NetServiceDelegate {
  
  public func connectTo(withBonjourConfig bonjourConfig: MMBonjourConfig, closeHandler: @escaping () -> (), onConnect: @escaping () -> ()) throws {
    
    //look for _flow host with bonjour
    self.browser = NetServiceBrowser()
    self.browser.delegate = self;
    self.browser.searchForServices(ofType: bonjourConfig.type, inDomain: bonjourConfig.domain)
    self.onConnectHandler = onConnect
    self.closeHandler = closeHandler
  }
  
  public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
    
    print("adding a service")
    if service.port == -1 {
      print("service \(service.name) of type \(service.type)" + " not yet resolved")
      self.services.add(service)
      service.delegate = self
      service.resolve(withTimeout:1000)
    }
  }
  
  public func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
    
    print("netServiceBrowserWillSearch")
  }
  
  
  public func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
    
    print("netServiceBrowserDidStopSearch")
  }
  
  
  //NetServiceDelegate protocol
  public func netServiceDidResolveAddress(_ sender: NetService) {
    
    print("resolved service \(sender.name) of type \(sender.type)," +
      "port \(sender.port), addresses \(sender.addresses as Any)")
    
    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
    guard let data = sender.addresses?.first else { return }
    data.withUnsafeBytes { (pointer:UnsafePointer<sockaddr>) -> Void in
      guard getnameinfo(pointer, socklen_t(data.count), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 else {
        return
      }
    }
    let ipAddress = String(cString:hostname)
    print(ipAddress)
    
    do {
      
      try self.connectTo(ipAddress, onPort: sender.port, closeHandler: (self.closeHandler)!, onConnect: (self.onConnectHandler)!)
      
    } catch let error as MMSocketError {
      print("Fail to create socket: : \(error)")
    } catch {
      print("fail to start receiving: unhandled error")
    }      
  }
  
  public func netServiceWillPublish(_ sender: NetService) {
    
    print("netServiceWillPublish")
  }
  
  
  public func netServiceDidPublish(_ sender: NetService) {
    
    print("netServiceDidPublish")
  }
  
  public func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
    
    print("didNotPublish")
  }
  
  
  public func netServiceWillResolve(_ sender: NetService) {
    
    print("netServiceWillResolve")
  }
  
  public func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
    
    print("didNotResolve")
  }
  
  
  public func netServiceDidStop(_ sender: NetService) {
    
    print("netServiceDidStop")
  }

  

}



