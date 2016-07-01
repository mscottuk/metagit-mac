//
//  LDCViewInterface.swift
//  ldcview
//
//  Created by Mark on 15/06/2016.
//  Copyright © 2016 Mark Scott. All rights reserved.
//

import Foundation

@objc protocol LDCViewInterface {
    func getJSON(pathReq: NSURL, result: ([MetadataEntry]?) -> () )
    func getPath(result: (NSURL?) -> ())
    func metadataExists(pathReq: NSURL, result: (Bool) -> () )
    func helloWorld(result: (NSString) -> ())
}
