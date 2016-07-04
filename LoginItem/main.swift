//
//  main.swift
//  metagit
//
//  Created by Mark on 28/06/2016.
//  Copyright © 2016 Mark. All rights reserved.
//

import Foundation

let bundleID = NSBundle.mainBundle().bundleIdentifier!
let xpclistener = NSXPCListener(machServiceName: bundleID)
let xpcdelegate = HelperXPCDelegate()

xpclistener.delegate = xpcdelegate
NSLog("Starting xpc listener with bundle ID %@", bundleID)
xpclistener.resume()
NSRunLoop.currentRunLoop().run()

// We shouldn't get here
NSLog("We shouldn't get here")

exit(1)
