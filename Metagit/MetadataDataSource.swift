//
//  MetadataDataSource.swift
//  Metagit
//
//  Created by Mark on 30/06/2016.
//  Copyright © 2016 Mark. All rights reserved.
//

import Foundation
import Cocoa

class MetadataDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    
    var data: [MetadataEntry]?
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        if data != nil
        {
            return data!.count
        }
        else
        {
            NSLog("dataDict nil %@", data==nil ? " true" : "false")
            return 0
        }
    }
    
    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        
        guard data != nil else
        {
            NSLog("dataDict %@ nil", data==nil ? " true" : "false")
            return "N/A"
        }
        
        switch (tableColumn!.identifier)
        {
        case "key":
            return data![row].key
        case "value":
            return data![row].value
        case "versions":
            return data![row].versions
        default:
            return "N/A"
        }
    }
    
}

