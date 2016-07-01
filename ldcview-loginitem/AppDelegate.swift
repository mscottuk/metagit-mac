//
//  AppDelegate.swift
//  ldcview-loginitem
//
//  Created by Mark on 15/06/2016.
//  Copyright © 2016 Mark Scott. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        
//        let xpclistener = NSXPCListener(machServiceName: "29547XHFYR.uk.ac.soton.ses.xpctest.xpcservice")
        NSLog("Starting xpc listener...")
        let xpclistener = NSXPCListener.serviceListener()
        
        let xpcdelegate = LDCDelegate()
        xpclistener.delegate = xpcdelegate
        
        NSLog("Resuming xpc listener")
        
        xpclistener.resume()
        
        NSLog("We shouldn't get here")
        
        exit(1)
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }


}

class LDCDelegate: NSObject, NSXPCListenerDelegate, LDCServiceInterface
{
    
    var endpoint : NSXPCListenerEndpoint?
    
    func listener(listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        NSLog("Trying to accept connection")
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
