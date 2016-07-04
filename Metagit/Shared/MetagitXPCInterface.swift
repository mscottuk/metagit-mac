//
//  MetagitXPCInterface.swift
//  metagit
//
//  Created by Mark on 27/06/2016.
//  Copyright © 2016 Mark. All rights reserved.
//

import Foundation

@objc protocol MetagitXPCInterface {
//    func getJSON(pathReq: NSURL, result: ([MetadataEntry]?) -> () )
//    func getPath(result: (NSURL?) -> ())
//    func metadataExists(pathReq: NSURL, result: (Bool) -> () )
//    func helloWorld(result: (NSString) -> ())
    func metadataExists(pathReq: NSURL, result: (Bool) -> ())
    func showMetadata(pathReq: NSURL)
    func getPath(result: (NSURL?) -> ())
    func requestForNewPath(result: (NSURL?) -> ())
}