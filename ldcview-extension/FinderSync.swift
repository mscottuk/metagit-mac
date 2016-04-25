//
//  FinderSync.swift
//  ldcview-extension
//
//  Created by Mark Scott on 16/06/2015.
//  Copyright (c) 2015 Mark Scott. All rights reserved.
//

import Cocoa
import FinderSync

class MetadataDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {

    var dataDict: NSDictionary?

    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        if dataDict != nil
        {
            return dataDict!.count
        }
        else
        {
            NSLog("dataDict %@ nil", dataDict==nil ? " true" : "false")
            return 0
        }
    }

    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        
        if dataDict != nil
        {
            let key = dataDict?.allKeys[row] as! String
            let value:AnyObject? = dataDict?.valueForKey(key)
            
            if tableColumn?.identifier == "key"
            {
                return key
            }
            else
            {
                return value
            }
        }
        else
        {
            NSLog("dataDict %@ nil", dataDict==nil ? " true" : "false")
            return "N/A"
        }
    }
    
}

class FinderSync: FIFinderSync {
    
    @IBOutlet weak var window: NSWindow!
    
    @IBOutlet weak var myTableView : NSTableView!
    
    var windowController: NSWindowController?
    
    var metadataDataSource: MetadataDataSource?

    let imageNameMetadataExists = "m1.eps"

    var myFolderURL: NSURL?
    
    override init() {
        super.init()
        
        NSLog("ldcview-debug: START")
        NSLog("FinderSync() launched from %@", NSBundle.mainBundle().bundlePath)

        let interface = NSXPCInterface(withProtocol: LDCViewInterface.self)
        let conn = NSXPCConnection(machServiceName: "29547XHFYR.uk.ac.soton.ses.ldcview.ldcviewlistener", options: NSXPCConnectionOptions(rawValue: 0))
        conn.remoteObjectInterface = interface
        conn.resume()
        let remote = conn.remoteObjectProxy as! LDCViewInterface
        
        remote.getPath()
        {
            (configuredPath: NSURL?) -> () in
            NSLog("ldcview-debug: hello 1")
            dispatch_sync(dispatch_get_main_queue())
            {
                NSLog("ldcview-debug: hello")
                self.myFolderURL = configuredPath
                // Set up the directory we are syncing.
                if self.myFolderURL != nil
                {
                    NSLog("ldcview-debug:" + self.myFolderURL!.path!)
                    FIFinderSyncController.defaultController().directoryURLs = [self.myFolderURL!]
                }
                else
                {
                    NSLog("ldcview-debug: No URL")
                }
            }
        }

        // Set up images for badge identifiers.
        FIFinderSyncController.defaultController().setBadgeImage(NSImage(named: imageNameMetadataExists)!, label: "Metadata exists" , forBadgeIdentifier: "MetadataExists")
        
        self.windowController = NSWindowController(windowNibName: "MetadataWindow", owner: self)
                
        NSLog("Main thread=%@", NSThread.isMainThread() ? "true":"false")

        
        NSLog("init() done")
    
    }

    // MARK: - Primary Finder Sync protocol methods

//    override func beginObservingDirectoryAtURL(url: NSURL) {
//        // The user is now seeing the container's contents.
//        // If they see it in more than one view at a time, we're only told once.
//        NSLog("beginObservingDirectoryAtURL: %@", url.filePathURL!)
//        
//        if let metadata_file = getMetadataFilePath(url)
//        {
//            self.showData(metadata_file)
//        }
//    }
//
//
//    override func endObservingDirectoryAtURL(url: NSURL) {
//        // The user is no longer seeing the container's contents.
//        NSLog("endObservingDirectoryAtURL: %@", url.filePathURL!)
//    }

    override func requestBadgeIdentifierForURL(url: NSURL) {
        NSLog("requestBadgeIdentifierForURL: %@", url.path!)
        let interface = NSXPCInterface(withProtocol: LDCViewInterface.self)
        let conn = NSXPCConnection(machServiceName: "29547XHFYR.uk.ac.soton.ses.ldcview.ldcviewlistener", options: NSXPCConnectionOptions())
        conn.remoteObjectInterface = interface
        conn.resume()
        let remote = conn.remoteObjectProxy as! LDCViewInterface
        remote.metadataExists(url)
        {
            (exists:Bool) -> () in
            dispatch_sync(dispatch_get_main_queue())
            {
                if(exists)
                {
                    NSLog("requestBadgeIdentifierForURL: metadata found at %@", url.absoluteString)
                    FIFinderSyncController.defaultController().setBadgeIdentifier("MetadataExists", forURL: url)
                }
            }
        }

        
//        if let metadata_file = self.getMetadataFilePath(url)
//        {
//            NSLog("Received %@", metadata_file)
//            // Get a file manager for checking files exist
//            let manager = NSFileManager.defaultManager()
//
//            if manager.fileExistsAtPath(metadata_file.path!)
//            {
//                NSLog("requestBadgeIdentifierForURL: metadata found at %@", metadata_file.absoluteString)
//                FIFinderSyncController.defaultController().setBadgeIdentifier("MetadataExists", forURL: url)
//            }
//        }
    }

    // MARK: - Menu and toolbar item support

    override var toolbarItemName: String {
        return "ldcview-extension"
    }

    override var toolbarItemToolTip: String {
        return "ldcview-extension: Click the toolbar item for a menu."
    }

    override var toolbarItemImage: NSImage {
        return NSImage(named: imageNameMetadataExists)!
    }
    
    var menuitems:[NSURL]?
    var menutarget:NSURL?

    override func menuForMenuKind(menuKind: FIMenuKind) -> NSMenu {
        // Produce a menu for the extension.
        let menu = NSMenu(title: "")

        let menuitem = menu.addItemWithTitle("Show Associated Metadata", action: #selector(FinderSync.showAssociatedMetadata(_:)), keyEquivalent: "")

//            let data:Dictionary<String,AnyObject> = ["target":target, "items": items]
//            item.representedObject = data
//            menuitems = items
//            menutarget = target

//        if
//            let target = FIFinderSyncController.defaultController().targetedURL(),
//            let items = FIFinderSyncController.defaultController().selectedItemURLs()
//        {
//            NSLog("menuForMenuKind: menu item: %@, target = %@, items = ", menuitem!.title, target.filePathURL!)
//            for obj: AnyObject in items
//            {
//                let obj_url = obj as! NSURL
//                NSLog("menuForMenuKind: %@",obj_url.path!)
//            }
//        }

        return menu
    }

    @IBAction func showAssociatedMetadata(sender: AnyObject?) {
        if
            let menuitem = sender as? NSMenuItem,
            let target = FIFinderSyncController.defaultController().targetedURL(),
            let items = FIFinderSyncController.defaultController().selectedItemURLs()
        {
//        NSLog("showAssociatedMetadata: 2," + String("%@", item.representedObject == nil))
//        let representedObject = item.representedObject as! Dictionary<String,AnyObject>
//        NSLog("showAssociatedMetadata: 3")
//        let target = representedObject["target"] as! NSURL
//        NSLog("showAssociatedMetadata: 4")
//        let items = representedObject["items"] as! [NSURL]
//        let items=menuitems!
//        let target=menutarget!
//                NSLog("showAssociatedMetadata: 5")
        NSLog("sampleAction: menu item: %@, target = %@, items = ", menuitem.title, target.filePathURL!)
        for obj: AnyObject in items
        {
            let obj_url = obj as! NSURL
            if let metadata_file = getMetadataFilePath(obj_url)
            {
                NSLog("Trying to display data for: %@",obj_url.path!)
                self.showData(obj_url)//metadata_file
            }
            else
            {
                NSLog("Could not get metadata for: %@", obj_url.path!)
            }
        }
        }
    }

    func showData(metadata_file:NSURL)
    {
        let interface = NSXPCInterface(withProtocol: LDCViewInterface.self)
        let conn = NSXPCConnection(machServiceName: "29547XHFYR.uk.ac.soton.ses.ldcview.ldcviewlistener", options: NSXPCConnectionOptions())
        conn.remoteObjectInterface = interface
        conn.resume()
        let remote = conn.remoteObjectProxy as! LDCViewInterface
        remote.getJSON(metadata_file)
        {
            (json:NSDictionary?) -> () in
                dispatch_sync(dispatch_get_main_queue())
                {
                    NSLog("Setting data source")
                    NSLog("json %@ nil", json==nil ? " true" : "false")
                    self.windowController!.showWindow(self)
                    self.metadataDataSource = self.myTableView.dataSource() as? MetadataDataSource
                    self.metadataDataSource!.dataDict = json
                    self.myTableView.reloadData()
                    NSLog("Data source set")
                }
        }
    }

    func getMetadataFilePath(request_url: NSURL) -> NSURL?
    {
        let manager = NSFileManager.defaultManager()
        
        // Check path exists and determine if it is a directory
        var url_is_dir: ObjCBool = false
        if !manager.fileExistsAtPath(request_url.path!, isDirectory:&url_is_dir)
        {
            NSLog("requestBadgeIdentifierForURL: %@ does not exist", request_url.path!)
            return nil
        }
        
        // Work out the parent directory of the metadata folder
        var metadata_dir_parent: NSURL = request_url
        
        if !url_is_dir
        {
            // Delete the file name only if it is a file
            metadata_dir_parent = metadata_dir_parent.URLByDeletingLastPathComponent!
        }
        
        // Work out where the metadata folder is. Generate the metadata folder path from the parent.
        let metadata_dir_name = ".git"
        var metadata_dir_path: NSURL = metadata_dir_parent.URLByAppendingPathComponent(metadata_dir_name)
        var metadata_dir_exists:Bool = false
        
        // Walk up the tree until we find a metadata folder
        // Stop when we have found the metadata or we go outside the monitored folder
        while (!metadata_dir_exists) && ((metadata_dir_parent.path!).characters.count >= (self.myFolderURL!.path!).characters.count)
        {
            // Stop if we find that one of our parents is a metadata folder
            if(metadata_dir_parent.lastPathComponent == metadata_dir_name)
            {
                //NSLog("requestBadgeIdentifierForURL: ignoring _metadata")
                return nil
            }
            
            var metadata_path_exists:Bool = false
            var metadata_path_is_dir:ObjCBool = false
            metadata_path_exists = manager.fileExistsAtPath(metadata_dir_path.path!, isDirectory:&metadata_path_is_dir)
            metadata_dir_exists = metadata_path_exists && metadata_path_is_dir
            
            if !metadata_dir_exists
            {
                metadata_dir_parent = metadata_dir_parent.URLByDeletingLastPathComponent!
                metadata_dir_path = metadata_dir_parent.URLByAppendingPathComponent(metadata_dir_name)
            }
        }
        
        if !metadata_dir_exists
        {
            NSLog("requestBadgeIdentifierForURL: metadata dir does not exist: %@", request_url.path!)
            return nil
        }
        else
        {
            NSLog("So far I have %@", metadata_dir_path.filePathURL!)
            return metadata_dir_path
        }
        
        // Generate a relative path for the requested URL so we can find it in the metadata folder
        
        // This will give us dir2/file1.txt from /home/dir1/dir2/file1.txt
        // where metadata_dir_path is /home/dir1/_metadata
        // and metadata_base_path is /home/dir1
        
        var relative_path_start:String.Index = request_url.path!.startIndex.advancedBy((metadata_dir_parent.path!).characters.count)
        if(request_url.path! != metadata_dir_parent.path!)
        {
            // Skip the leading '/' (if we are at the top of the tree then we don't get one)
            relative_path_start = relative_path_start.advancedBy(1)
        }
        
        let url_relative_to_metadata_base = NSURL(string: request_url.path!.substringFromIndex(relative_path_start), relativeToURL:metadata_dir_parent)!
        
        // Look in the metadata folder for a metadata file
        var url_metadata_file:NSURL
        if url_is_dir
        {
            url_metadata_file = metadata_dir_path.URLByAppendingPathComponent(url_relative_to_metadata_base.relativeString!).URLByAppendingPathComponent("_folder_metadata.json").URLByStandardizingPath!
        }
        else
        {
            url_metadata_file = metadata_dir_path.URLByAppendingPathComponent(url_relative_to_metadata_base.relativeString!).URLByAppendingPathExtension("json").URLByStandardizingPath!
        }
        
        return url_metadata_file
    }
}

