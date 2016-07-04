//
//  HelperXPCDelegate.swift
//  metagit
//
//  Created by Mark on 28/06/2016.
//  Copyright © 2016 Mark. All rights reserved.
//

import Foundation

class HelperXPCDelegate: NSObject, NSXPCListenerDelegate, LoginItemXPCInterface
{
    
    var endpoint : NSXPCListenerEndpoint?
    
    func listener(listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        let interface = NSXPCInterface(withProtocol: LoginItemXPCInterface.self)
        newConnection.exportedInterface = interface
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }
    
    func registerEndpoint(endpoint: NSXPCListenerEndpoint) {
        NSLog("Received endpoint")
        self.endpoint = endpoint
    }
    
    func returnEndpoint(result: (NSXPCListenerEndpoint?) -> ()) {
        NSLog("Returning endpoint")
        result(endpoint)
    }
}
