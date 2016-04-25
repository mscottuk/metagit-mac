//
//  xpcinterfaces.swift
//  ldcview
//
//  Created by Mark Scott on 18/06/2015.
//  Copyright (c) 2015 Mark Scott. All rights reserved.
//

import Foundation
@objc protocol LDCViewInterface {
    func getJSON(pathReq: NSURL, result: (NSDictionary?) -> () )
    func getPath(result: (NSURL?) -> ())
    func metadataExists(pathReq: NSURL, result: (Bool) -> () )
}