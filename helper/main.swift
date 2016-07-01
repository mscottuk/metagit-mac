//
//  main.swift
//  ldcview
//
//  Created by Mark on 22/06/2016.
//  Copyright © 2016 Mark Scott. All rights reserved.
//

import Foundation


class LDCDelegate: NSObject, NSXPCListenerDelegate, LDCServiceInterface
{
    
    var endpoint : NSXPCListenerEndpoint?
    
    func listener(listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        let interface = NSXPCInterface(withProtocol: LDCServiceInterface.self)
        newConnection.exportedInterface = interface
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }
    
    func registerEndpoint(endpoint: NSXPCListenerEndpoint) {
        NSLog("ldcview-service: Received endpoint")
        self.endpoint = endpoint
    }
    
    func returnEndpoint(result: (NSXPCListenerEndpoint?) -> ()) {
        NSLog("ldcview-service: Returning endpoint")
        result(endpoint)
    }
}

let bundleID = NSBundle.mainBundle().bundleIdentifier!
let xpclistener = NSXPCListener(machServiceName: bundleID)
let xpcdelegate = LDCDelegate()

xpclistener.delegate = xpcdelegate
NSLog("Starting xpc listener with bundle ID %@", bundleID)
xpclistener.resume()
NSRunLoop.currentRunLoop().run()

// We shouldn't get here
NSLog("We shouldn't get here")

exit(1)
