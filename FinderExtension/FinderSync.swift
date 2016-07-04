//
//  FinderSync.swift
//  FinderExtension
//
//  Created by Mark on 27/06/2016.
//  Copyright © 2016 Mark. All rights reserved.
//

import Cocoa
import FinderSync

class FinderSync: FIFinderSync {

//    var myFolderURL: NSURL? = NSURL(fileURLWithPath: "/Users/mark/Desktop")

    var appConnection: NSXPCConnection?
    var appInterface: NSXPCInterface?
    var remoteEndpoint: NSXPCListenerEndpoint?
    var appProxy: MetagitXPCInterface?
    var monitoredPath: NSURL?
    let metagitImage = "MetadataExists.eps"
    
    override init() {
        super.init()

        NSLog("FinderSync() launched from %@", NSBundle.mainBundle().bundlePath)

        // Set up the directory we are syncing.
//        FIFinderSyncController.defaultController().directoryURLs = [self.myFolderURL!]
        
        // Set up images for our badge identifiers. For demonstration purposes, this uses off-the-shelf images.
        FIFinderSyncController.defaultController().setBadgeImage(NSImage(named: metagitImage)!, label: "Metadata exists" , forBadgeIdentifier: "MetadataExists")
        
        self.lookupMonitoredPath()
    }

    // MARK: - Primary Finder Sync protocol methods

//    override func beginObservingDirectoryAtURL(url: NSURL) {
//        // The user is now seeing the container's contents.
//        // If they see it in more than one view at a time, we're only told once.
//        NSLog("beginObservingDirectoryAtURL: %@", url.filePathURL!)
//    }
//
//
//    override func endObservingDirectoryAtURL(url: NSURL) {
//        // The user is no longer seeing the container's contents.
//        NSLog("endObservingDirectoryAtURL: %@", url.filePathURL!)
//    }

    override func requestBadgeIdentifierForURL(url: NSURL) {
        NSLog("requestBadgeIdentifierForURL: %@", url.filePathURL!)

        // Lookup if metadata exists
        self.lookupMetadataForURL(url)
    }

    // MARK: - Menu and toolbar item support

    override var toolbarItemName: String {
        return "FinderExtension"
    }

    override var toolbarItemToolTip: String {
        return "FinderExtension: Click the toolbar item for a menu."
    }

    override var toolbarItemImage: NSImage {
        return NSImage(named: metagitImage)!
    }

    override func menuForMenuKind(menuKind: FIMenuKind) -> NSMenu? {

        // Produce a menu for the extension.
        let menu = NSMenu(title:"")

        switch (menuKind) {

        case FIMenuKind.ContextualMenuForItems:
            let items = FIFinderSyncController.defaultController().selectedItemURLs()
            if (items != nil && items!.count > 0) {
                let _ = menu.addItemWithTitle("Show Associated Metadata", action: #selector(FinderSync.showAssociatedMetadata(_:)), keyEquivalent: "")
            }
            else {
                let _ = menu.addItemWithTitle("Only item one can be selected", action: nil, keyEquivalent: "");
            }

        case FIMenuKind.ToolbarItemMenu:
            // Lookup the main app's monitored path in case things changed
            self.lookupMonitoredPath()
            
            let menutitle = (self.monitoredPath == nil) ? "Path not set" : "Monitoring " + self.monitoredPath!.path!
            let menuitem = menu.addItemWithTitle(menutitle, action: nil, keyEquivalent: "")
            menuitem?.enabled = false
            let _ = menu.addItemWithTitle("Change current folder", action: #selector(FinderSync.requestForNewPath(_:)), keyEquivalent: "")

        default:
            return super.menuForMenuKind(menuKind)

        }

        return menu
}

    @IBAction func showAssociatedMetadata(sender: AnyObject?) {
        if self.appProxy == nil { self.attemptMainAppConnection(); }
        guard self.appProxy != nil else { NSLog("Couldn't make connection to helper"); return; }
        if let items = FIFinderSyncController.defaultController().selectedItemURLs()
        where items.count == 1 {
            self.appProxy!.showMetadata(items[0])
        }
    }

    @IBAction func requestForNewPath(sender: AnyObject?) {
        if self.appProxy == nil { self.attemptMainAppConnection(); }
        guard self.appProxy != nil else { NSLog("Couldn't make connection to helper"); return; }
        self.appProxy!.requestForNewPath(saveMonitoredPath)
    }

    func saveMonitoredPath(monitoredPath: NSURL?) {
        dispatch_sync(dispatch_get_main_queue()) {
            self.monitoredPath = monitoredPath
            if monitoredPath != nil {
                FIFinderSyncController.defaultController().directoryURLs = [monitoredPath!]
            }
        }
    }

    func lookupMonitoredPath() {
        if self.appProxy == nil { self.attemptMainAppConnection(); }
        guard self.appProxy != nil else { NSLog("Couldn't make connection to helper"); return; }
        self.appProxy!.getPath(self.saveMonitoredPath)
    }

    func lookupMetadataForURL(url:NSURL) {
        if self.appProxy == nil { self.attemptMainAppConnection(); }
        guard self.appProxy != nil else { NSLog("Couldn't make connection to helper"); return; }
        self.appProxy!.metadataExists(url) {
            (exists:Bool) -> () in
            dispatch_sync(dispatch_get_main_queue()) {
                FIFinderSyncController.defaultController().setBadgeIdentifier(exists ? "MetadataExists" : "", forURL: url)
            }
        }

    }
    
    func attemptMainAppConnection() {
        let connection = NSXPCConnection(machServiceName: "29547XHFYR.uk.ac.soton.Metagit.LoginItem", options: NSXPCConnectionOptions())
        let interface = NSXPCInterface(withProtocol: LoginItemXPCInterface.self)
        connection.remoteObjectInterface = interface
        connection.resume()
        let proxy = connection.remoteObjectProxy as! LoginItemXPCInterface
        proxy.returnEndpoint()
            {
                (returnedEndpoint:NSXPCListenerEndpoint?) -> Void in
                dispatch_sync(dispatch_get_main_queue())
                {
                    if returnedEndpoint != nil
                    {
                        NSLog("Endpoint received")
                        self.remoteEndpoint = returnedEndpoint
                        self.appConnection = NSXPCConnection(listenerEndpoint: self.remoteEndpoint!)
                        self.appInterface = NSXPCInterface(withProtocol: MetagitXPCInterface.self)
                        self.appConnection!.remoteObjectInterface = self.appInterface!
                        self.appConnection!.resume()
                        self.appProxy = self.appConnection!.remoteObjectProxy as? MetagitXPCInterface
                    }
                    else
                    {
                        NSLog("Could not contact main app")
                    }
                }
        }
    }
    
}

