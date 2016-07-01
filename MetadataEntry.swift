//
//  MetadataEntry.swift
//  ldcview
//
//  Created by Mark on 26/04/2016.
//  Copyright © 2016 Mark Scott. All rights reserved.
//

import Foundation

@objc(MetadataEntry) class MetadataEntry:NSObject, NSCoding, NSSecureCoding {
    var key: String?
    var value: String?
    var versions: Int?
    
    static func supportsSecureCoding() -> Bool {
        return true
    }
    override init() {
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
//        aDecoder.decodeObjectOfClass(UInt, forKey: "key")
        key = aDecoder.decodeObjectForKey("key") as? String
        value = aDecoder.decodeObjectForKey("value") as? String
        versions = aDecoder.decodeObjectForKey("versions") as? Int
        super.init()
    }
    
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(key, forKey: "key")
        aCoder.encodeObject(value, forKey: "value")
        aCoder.encodeObject(versions, forKey: "versions")
    }
}
