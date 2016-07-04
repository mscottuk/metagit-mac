//
//  HelperXPCInterface.swift
//  metagit
//
//  Created by Mark on 27/06/2016.
//  Copyright © 2016 Mark. All rights reserved.
//

import Foundation

@objc protocol LoginItemXPCInterface {
    func registerEndpoint(endpoint:NSXPCListenerEndpoint)
    func returnEndpoint(result: (NSXPCListenerEndpoint?) -> ())
}