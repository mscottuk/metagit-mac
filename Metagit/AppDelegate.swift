//
//  AppDelegate.swift
//  metagit
//
//  Created by Mark on 27/06/2016.
//  Copyright © 2016 Mark. All rights reserved.
//

import Cocoa
import ObjectiveGit
import ServiceManagement

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSXPCListenerDelegate, MetagitXPCInterface
 {

    @IBOutlet weak var metadataWindow: NSWindow!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var currentFolderMenuItem: NSMenuItem!
    @IBOutlet weak var changeCurrentFolderMenuItem: NSMenuItem!
    
    var myFolderURL: NSURL?
    var path: NSURL?

    let anonlistener = NSXPCListener.anonymousListener()
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSVariableStatusItemLength)
    var metadataDataSource: MetadataDataSource?
    
    
    // MARK: - NSApplicationDelegate methods

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application

        // Set up the status menu
        self.statusItem.menu = self.statusMenu
//        self.statusItem.button!.title = "M"
        let stringAttributes = [ NSFontAttributeName: NSFont(name: "Trebuchet MS Bold Italic", size: 14.0)! ]
        let buttonTitleString = NSMutableAttributedString(string: "M", attributes: stringAttributes )
        self.statusItem.button!.attributedTitle = buttonTitleString
        self.statusItem.highlightMode = true
        self.changeCurrentFolderMenuItem.target = self
        self.changeCurrentFolderMenuItem.action = #selector(AppDelegate.showWindow(_:))

        // Retrieve path
        if let defaultURL = AppDelegate.getBookmarkedURL()
        {
            defaultURL.startAccessingSecurityScopedResource()
            setNewPath(defaultURL)
            defaultURL.stopAccessingSecurityScopedResource()
        }

        // Gain access to the folder
        if self.path == nil
        {
            self.promptForPath()
        }

        // Start Login Item
        let success = SMLoginItemSetEnabled("29547XHFYR.uk.ac.soton.Metagit.LoginItem", true)

        // Set up an anonymous listener and register it with Login Item's XPC service
        self.anonlistener.delegate = self
        self.anonlistener.resume()
        
        // Register the anoymous listener with shared XPC service
        let connection = NSXPCConnection(machServiceName: "29547XHFYR.uk.ac.soton.Metagit.LoginItem", options: NSXPCConnectionOptions())
        let interface = NSXPCInterface(withProtocol: LoginItemXPCInterface.self)
        connection.remoteObjectInterface = interface
        connection.resume()
        if let proxy = connection.remoteObjectProxyWithErrorHandler({ (err: NSError) in
            dispatch_sync(dispatch_get_main_queue()) {
                NSLog("Error:" + err.domain + String(err.code) + err.localizedDescription)
                var ui = err.userInfo as NSDictionary
                var enm = ui.objectEnumerator()
                while let value = enm.nextObject() {
                    NSLog("Error dict:" + String(value))
                }
            }
        }) as? LoginItemXPCInterface
        {
            proxy.registerEndpoint(anonlistener.endpoint)
            NSLog("Connection made")
        }
        else{
            NSLog("No connection")
        }
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
        self.anonlistener.invalidate()
    }

    
    // MARK: - Application's methods
    
    func showWindow(sender: AnyObject) {
        // Menu action to prompt for new path
        self.promptForPath()
    }
    
    func promptForPath()
    {
        var startPath: NSURL?
        if (self.path == nil) {
            startPath = NSURL(fileURLWithPath: NSHomeDirectoryForUser(NSUserName())!)
        }
        else {
            startPath = self.path
        }
        promptForPath(startPath!)

    }

    func promptForPath(startPath:NSURL)
    {
        let openPanel = NSOpenPanel()
        openPanel.level = 8
        openPanel.directoryURL = startPath
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.canCreateDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.title = "Select metadata folder to grant permission to metadata"
        let panel_result = openPanel.runModal()
        
        // Only make the change if person clicked OK
        if panel_result == NSFileHandlingPanelOKButton
        && openPanel.URLs.count > 0
        {
            let picked_url = openPanel.URLs[0]
            self.setNewPath(picked_url)
            
        }
    }

    func setCurrentFolderMenuItem()
    {
        var menuTitle:String
        if let monitoredPath = self.path {
            menuTitle = "Monitoring " + monitoredPath.path!
        }
        else{
            menuTitle = "Path not set"
        }
        self.currentFolderMenuItem.title = menuTitle
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
            // Delete the file name
            metadata_dir_parent = metadata_dir_parent.URLByDeletingLastPathComponent!
        }
        
        // Work out where the metadata folder is. Generate the metadata folder path from the parent.
        var metadata_dir_path: NSURL = metadata_dir_parent.URLByAppendingPathComponent("_metadata")
        var metadata_dir_exists:Bool = false
        
        // Walk up the tree until we find a metadata folder
        // Stop when we have found the metadata or we go outside the monitored folder
        while (!metadata_dir_exists) && ((metadata_dir_parent.path!).characters.count >= (self.myFolderURL!.path!).characters.count)
        {
            // Stop if we find that one of our parents is a metadata folder
            if(metadata_dir_parent.lastPathComponent == "_metadata")
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
                metadata_dir_path = metadata_dir_parent.URLByAppendingPathComponent("_metadata")
            }
        }
        
        if !metadata_dir_exists
        {
            NSLog("requestBadgeIdentifierForURL: metadata_dir does not exist")
            return nil
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

    
    func setNewPath(newPath: NSURL) -> Bool
    {
        if access(newPath.fileSystemRepresentation, R_OK) == 0
        {
            let bookmarkData = AppDelegate.generateSecureBookmark(newPath)
            self.path = AppDelegate.getURLFromSecureBookmark(bookmarkData)
            AppDelegate.saveBookmark(bookmarkData)
            self.setCurrentFolderMenuItem()
            return true
        }
        else
        {
            self.path = nil
            return false
        }
    }
    
    func getJSON(pathReq:NSURL) -> [MetadataEntry]? {
        var myResult = [MetadataEntry]()
        
        if self.path == nil
        {
            return (nil)
        }
        
        //        var myPath = getURLFromSecureBookmark(bookmark!)
        
        self.path!.startAccessingSecurityScopedResource()
        
        if access(pathReq.fileSystemRepresentation, R_OK) == 0
        {
            //            let file_data:NSData? = NSData(contentsOfFile: pathReq.path!)
            //            var err:NSError?
            //            do
            //            {
            //                if let json = try NSJSONSerialization.JSONObjectWithData(file_data!, options: []) as? NSDictionary
            //                {
            //                    try myResult = json as? Dictionary<String,AnyObject>
            //                }
            //            }
            //            catch {
            //            }
            
            NSLog("Calling discover_repository from getJSON")
            if let git_repo_path = discover_repository(pathReq)
            {
                var filepath = pathReq.path!
                filepath.removeRange(pathReq.path!.rangeOfString(git_repo_path.URLByDeletingLastPathComponent!.path!)!)
                filepath.removeAtIndex(filepath.startIndex)
                NSLog("Going to try and get metadata for ", filepath)
                let gitrepo = try! GTRepository(URL: NSURL(fileURLWithPath: git_repo_path.path!))
                let data_rev = "metadata"
                //                let data_commit_id = (filepath=="datafile.txt") ? "b70362ba68e2b91808da90ea00c6e1f0bbd772d9" : "8a5977b1cdf8e1ddae208f7916648e687f177450"
                
                // Find data object in Git
                //                let dataobject = try! gitrepo.lookUpObjectByRevParse("HEAD:%@" + filepath)
                
                let metadata_node_path = get_metadata_node_path(NSURL.fileURLWithPath(filepath))
                NSLog("metadata_node_path=" + metadata_node_path.relativeString!)
                if let metadata_node = try? gitrepo.lookUpObjectByRevParse(data_rev + ":" + metadata_node_path.relativeString!) as? GTTree
                {
                    
                    // Walk up tree until reach a merge or the first commit looking for metadata nodes
                    // Get a commit from the HEAD (metadata_node)
                    for stream in metadata_node!.entries!
                    {
                        if let metadata_versions = try? gitrepo.lookUpObjectByRevParse("metadata:" + get_metadata_stream_path(NSURL.fileURLWithPath(filepath), streamname: stream.name).relativeString!)
                        {
                            
                            var current_data_commit = try! gitrepo.lookUpObjectByRevParse("HEAD") as! GTCommit
                            while current_data_commit.parents.count <= 1
                            {
                                let metadata_key = stream.name
                                let metadata_path = get_metadata_blob_path(NSURL.fileURLWithPath(filepath), streamname: metadata_key, datacommitid: current_data_commit.OID!.SHA)
                                let rev_parse_path = String(format: "%@:%@", data_rev, metadata_path.relativeString!)
                                //                            NSLog("rev_parse_path=" + rev_parse_path)
                                if let git_object = try? gitrepo.lookUpObjectByRevParse(rev_parse_path) as? GTBlob
                                {
                                    let newEntry = MetadataEntry()
                                    newEntry.key = metadata_key
                                    newEntry.value = String(data:git_object!.data()!, encoding: NSUTF8StringEncoding)
                                    newEntry.versions = metadata_versions.entries!.count
                                    myResult.append(newEntry)
                                    break
                                }
                                if current_data_commit.parents.count == 0
                                {
                                    break // No more parents so break out of loop
                                }
                                else
                                {
                                    current_data_commit = current_data_commit.parents[0] // Go to next parent
                                }
                            }
                            if current_data_commit.parents.count > 1
                            {
                                NSLog("Merge detected")
                            }
                        }
                    }
                }
            }
        }
        
        self.path!.stopAccessingSecurityScopedResource()
        
        return (myResult)
    }
    

    // MARK: - Metadata methods
    
    func get_metadata_node_path(path:NSURL)->NSURL
    {
        let metadata_name = NSUUID(UUIDString: "92df1d6a-b6da-5ddb-9055-44349d03203e")
        let metadatanodepath = path.URLByAppendingPathComponent(metadata_name!.UUIDString.lowercaseString)
        return metadatanodepath
    }
    func get_metadata_stream_path(path:NSURL,streamname:String)->NSURL
    {
        let metadata_node_path = get_metadata_node_path(path)
        let metadata_stream_path = metadata_node_path.URLByAppendingPathComponent(streamname)
        return metadata_stream_path
    }
    
    func get_metadata_blob_path(path:NSURL,streamname:String,datacommitid:String)->NSURL
    {
        let metadata_stream_path = get_metadata_stream_path(path, streamname:streamname)
        let metadata_blob_path = metadata_stream_path.URLByAppendingPathComponent(datacommitid)
        return metadata_blob_path
    }
    
    func discover_repository(base_path: NSURL) -> NSURL? {
        //        var next_path:NSURL = base_path
        NSLog("discover, base_path:" + base_path.path!)
        
        var new_base_path: NSURL
        
        // We have to convert the base path into a proper path (not a file reference like file:///.file/id=6571767.1881190/)
        if base_path.isFileReferenceURL()
        {
//            new_base_path = NSURL(string: base_path.path!)!
            new_base_path = base_path.filePathURL!
        }
        else
        {
            new_base_path = base_path
        }
        
        // Get a file manager for checking files exist
        let manager = NSFileManager.defaultManager()
        var url_is_dir:ObjCBool = false
        var git_is_dir: ObjCBool = false
        if manager.fileExistsAtPath(new_base_path.path!, isDirectory: &url_is_dir)
            && url_is_dir
            && manager.fileExistsAtPath(new_base_path.URLByAppendingPathComponent(".git").path!, isDirectory: &git_is_dir)
            && git_is_dir {
            // We found .git
            let return_path = new_base_path.URLByAppendingPathComponent(".git")
            NSLog("discover, return: " + return_path.absoluteString)
            return return_path
        }
        else
        {
            if new_base_path.path! == "/"
            {
                return nil
            }
            else
            {
                let next_path:NSURL = new_base_path.URLByDeletingLastPathComponent!
                if next_path.path! == new_base_path.path! || next_path.path!.isEmpty
                {
                    return nil
                }
                else
                {
                    NSLog("Nested called to discover_repository")
                    return self.discover_repository(next_path)
                }
            }
        }
    }


    // MARK: - Secure bookmark creation, storage and retrieval

    static func getBookmarkedURL() -> NSURL?
    {
        // Load the folder from defaults (security-scoped bookmark)
        if let defaults = NSUserDefaults(suiteName: "29547XHFYR.uk.ac.soton.ses.ldcview")
        {
            if let bookmarkData = defaults.objectForKey("bookmark") as? NSData
            {
                return getURLFromSecureBookmark(bookmarkData)
            }
        }
        
        return nil
    }
    
    static func saveBookmark(bookmarkData: NSData)
    {
        // Load the folder from defaults (security-scoped bookmark)
        let defaults = NSUserDefaults(suiteName: "29547XHFYR.uk.ac.soton.ses.ldcview")
        defaults!.setObject(bookmarkData, forKey: "bookmark")
        defaults!.synchronize()
    }
    
    static func getURLFromSecureBookmark(bookmarkData: NSData) -> NSURL
    {
        var isStale: ObjCBool = true
        var bookmarkError:NSError?
        var secure_url: NSURL?
        do {
            secure_url = try NSURL(byResolvingBookmarkData: bookmarkData, options: NSURLBookmarkResolutionOptions.WithSecurityScope, relativeToURL: nil, bookmarkDataIsStale: &isStale)
        } catch let error as NSError {
            bookmarkError = error
            secure_url = nil
        }
        
        return secure_url!
    }
    
    static func generateSecureBookmark(newPath: NSURL) -> NSData
    {
        var bookmarkError: NSError?
        var bookmarkData: NSData?
        do {
            bookmarkData = try newPath.bookmarkDataWithOptions([NSURLBookmarkCreationOptions.WithSecurityScope, NSURLBookmarkCreationOptions.SecurityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: nil, relativeToURL: nil)
        } catch let error as NSError {
            bookmarkError = error
            bookmarkData = nil
        }
        
        return bookmarkData!
    }

    
    // MARK: - NSXPCListenerDelegate methods
    
    func listener(listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        let interface = NSXPCInterface(withProtocol: MetagitXPCInterface.self)
        newConnection.exportedInterface = interface
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }
    
    
    // MARK: - MetagitXPCInterface methods
    
    func metadataExists(pathReq:NSURL, result: (Bool) -> ()) {
        NSLog("metadataExists: %@", pathReq.path!)
        if self.path == nil
        {
            NSLog("Path is nil, returning false")
            result(false)
            return
        }
        //        result(true)
        //        return
        
        //        exit(1)
        self.path!.startAccessingSecurityScopedResource()
        defer{ self.path!.stopAccessingSecurityScopedResource() }
        guard access(pathReq.fileSystemRepresentation, R_OK) == 0 else { result(false); return; }
        
        NSLog("Calling discover_repository from metadataExists")
        
        if let git_repo_path = discover_repository(pathReq)
        {
            var relativepathreq = pathReq.path!
            // Use the parent of the .git directory to find the relative path
            relativepathreq.removeRange(pathReq.path!.rangeOfString(git_repo_path.URLByDeletingLastPathComponent!.path!)!)
            
            // Remove starting slash
            if relativepathreq.hasPrefix("/")
            {
                relativepathreq.removeAtIndex(relativepathreq.startIndex)
            }
            
            // Check for metadata node for path (don't care what streams)
            let gitrepo = try! GTRepository(URL: NSURL(fileURLWithPath: git_repo_path.path!))
            let metadata_node_path = get_metadata_node_path(NSURL.fileURLWithPath(relativepathreq))
            if let _ = try? gitrepo.lookUpObjectByRevParse("metadata:" + (metadata_node_path.relativeString ?? "")) as? GTTree
            {
                result(true)
                return
            }
        }
        result(false)
    }
    
    func showMetadata(pathReq:NSURL){
        NSLog("metadataExists: %@", pathReq.path!)
        if self.path == nil
        {
            NSLog("Path is nil, aborting")
            return
        }
        
        self.path!.startAccessingSecurityScopedResource()
        defer{ self.path!.stopAccessingSecurityScopedResource() }
        guard access(pathReq.fileSystemRepresentation, R_OK) == 0 else { return; }
        
        if let metadata = self.getJSON(pathReq)
        {
            dispatch_sync(dispatch_get_main_queue()){
                //                self.windowController!.showWindow(self)
                self.metadataWindow.makeKeyAndOrderFront(self)
                self.metadataDataSource = self.tableView.dataSource() as? MetadataDataSource
                self.metadataDataSource!.data = metadata
                self.tableView.reloadData()
            }
        }
    }
    
    func getPath(result: (NSURL?) -> ()) {
        result(self.path)
    }
    
    func requestForNewPath(result: (NSURL?) -> ()) {
        dispatch_sync(dispatch_get_main_queue()) {
            self.promptForPath()
            result(self.path)
        }
    }

}
