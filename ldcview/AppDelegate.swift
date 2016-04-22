//
//  AppDelegate.swift
//  ldcview
//
//  Created by Mark Scott on 16/06/2015.
//  Copyright (c) 2015 Mark Scott. All rights reserved.
//

import Cocoa
import ObjectiveGit

class LDCViewDelegate: NSObject, NSXPCListenerDelegate, LDCViewInterface
{
//    var bookmark: NSData?
    var path: NSURL?
    
    override convenience init()
    {
        if let defaultURL = LDCViewDelegate.getBookmarkedURL()
        {
            defaultURL.startAccessingSecurityScopedResource()
            self.init(newpath: defaultURL)
            defaultURL.stopAccessingSecurityScopedResource()
        }
        else
        {
            self.init(newpath: nil)
        }
    }
    
    init(newpath: NSURL?)
    {
        super.init()
        
        if newpath != nil
        {
            setNewPath(newpath!)
        }
    }
    
    func listener(listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        
        //        let interface = NSXPCInterface(withProtocol:(`protocol`: DataProtocol.self))
        dispatch_async(dispatch_get_main_queue())
        {
            NSLog("should accept??")
        }
        let interface = NSXPCInterface(withProtocol: LDCViewInterface.self)
        newConnection.exportedInterface = interface
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    func getJSON(pathReq:NSURL, result: (NSDictionary?) -> ()) {
        var myResult = Dictionary<String,AnyObject>()
        
        if self.path == nil
        {
            result(nil)
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
            
            if let git_repo_path = discover_repository(pathReq)
            {
                var filepath = pathReq.path!
                filepath.removeRange(pathReq.path!.rangeOfString(git_repo_path.URLByDeletingLastPathComponent!.path!)!)
                filepath.removeAtIndex(filepath.startIndex)
                NSLog("Going to try and get metadata for ", filepath)
                let gitrepo = try! GTRepository(URL: git_repo_path)
                let data_rev = "metadata"
                let data_commit_id = (filepath=="datafile.txt") ? "b70362ba68e2b91808da90ea00c6e1f0bbd772d9" : "8a5977b1cdf8e1ddae208f7916648e687f177450"
                
                
                let metadata_node_path = get_metadata_node_path(NSURL.fileURLWithPath(filepath))
                NSLog("metadata_node_path=" + metadata_node_path.relativeString!)
                let metadata_node = try! gitrepo.lookUpObjectByRevParse(data_rev + ":" + metadata_node_path.relativeString!) as! GTTree
                for tree in metadata_node.entries! {
                    
                    let metadata_key = tree.name
                    let metadata_path = get_metadata_blob_path(NSURL.fileURLWithPath(filepath), streamname: metadata_key, datacommitid: data_commit_id)
                    let rev_parse_path = String(format: "%@:%@", data_rev, metadata_path.relativeString!)
                    NSLog("rev_parse_path=" + rev_parse_path)
                    if let git_object = try? gitrepo.lookUpObjectByRevParse(rev_parse_path) as? GTBlob
                    {
                        myResult[metadata_key] = String(data:git_object!.data()!, encoding: NSUTF8StringEncoding)
                    }

                }
                
//                myResult!["author"] = String(data: (try! gitrepo.lookUpObjectByRevParse("metadata:datafile.txt/92df1d6a-b6da-5ddb-9055-44349d03203e/author/b70362ba68e2b91808da90ea00c6e1f0bbd772d9") as! GTBlob).data()!, encoding: NSUTF8StringEncoding)
            }
        }
        
        self.path!.stopAccessingSecurityScopedResource()
        
        result(myResult)
    }
    
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
        NSLog("discover, base_path:" + base_path.absoluteString)
        
        // Get a file manager for checking files exist
        let manager = NSFileManager.defaultManager()
        var url_is_dir:ObjCBool = false
        var git_is_dir: ObjCBool = false
        if manager.fileExistsAtPath(base_path.path!, isDirectory: &url_is_dir)
            && url_is_dir
            && manager.fileExistsAtPath(base_path.URLByAppendingPathComponent(".git").path!, isDirectory: &git_is_dir)
            && git_is_dir {
            // We found .git
            let return_path = base_path.URLByAppendingPathComponent(".git")
            NSLog("discover, return: " + return_path.absoluteString)
            return return_path
        }
        else
        {
            let next_path:NSURL = base_path.URLByDeletingLastPathComponent!
            if next_path == base_path || next_path.absoluteString.isEmpty
            {
                return nil
            }
            else
            {
                return self.discover_repository(next_path)
            }
        }
    }
    
    func getPath(result: (NSURL?) -> ()) {
        result(self.path)
    }
    
    func setNewPath(newPath: NSURL) -> Bool
    {
        if access(newPath.fileSystemRepresentation, R_OK) == 0
        {
           let bookmarkData = LDCViewDelegate.generateSecureBookmark(newPath)
            self.path = LDCViewDelegate.getURLFromSecureBookmark(bookmarkData)
            LDCViewDelegate.saveBookmark(bookmarkData)
            return true
        }
        else
        {
            self.path = nil
            return false
        }
    }
    
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
        var bookmarkError:ErrorType?
        var secure_url: NSURL?
        do {
            secure_url = try NSURL(byResolvingBookmarkData: bookmarkData, options: NSURLBookmarkResolutionOptions.WithSecurityScope, relativeToURL: nil, bookmarkDataIsStale: &isStale)
        }
        catch {// let error as NSError {
            bookmarkError = error
            secure_url = nil
        }
        
        return secure_url!
    }
    
    static func generateSecureBookmark(newPath: NSURL) -> NSData
    {
        var bookmarkError: ErrorType?//NSError?
        var bookmarkData: NSData?
        do {
            bookmarkData = try newPath.bookmarkDataWithOptions([NSURLBookmarkCreationOptions.WithSecurityScope, NSURLBookmarkCreationOptions.SecurityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: nil, relativeToURL: nil)
        } catch {//let error as NSError {
            bookmarkError = error
            bookmarkData = nil
        }
        
        return bookmarkData!
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var currentFolderMenuItem: NSMenuItem!
    @IBOutlet weak var changeCurrentFolderMenuItem: NSMenuItem!

    let ldcviewlistener = NSXPCListener(machServiceName: "29547XHFYR.uk.ac.soton.ses.ldcview.ldcviewlistener")

    var ldcviewdelegate = LDCViewDelegate()
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        
        // Check the folder we have access to
        
        // Gain access to the folder
        if ldcviewdelegate.path == nil
        {
            promptForPath(NSURL(fileURLWithPath: NSHomeDirectory()))
        }

        ldcviewlistener.delegate = ldcviewdelegate
        ldcviewlistener.resume()
        
        NSLog("listener resumed")
        
        self.window.orderOut(self)
        self.changeCurrentFolderMenuItem.target = self
        self.changeCurrentFolderMenuItem.action = Selector("showWindow:")
        self.setCurrentFolderMenuItem()
    }
    
    func showWindow(sender: AnyObject)
    {
        promptForPath(NSURL(fileURLWithPath: NSHomeDirectory()))
    }
    
    func setCurrentFolderMenuItem()
    {
        var menuTitle:String
        if let monitoredPath = ldcviewdelegate.path {
             menuTitle = "Monitoring " + monitoredPath.path!
        }
        else{
             menuTitle = "Path not set"
        }
        self.currentFolderMenuItem.title = menuTitle
}

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }

    func promptForPath(path:NSURL)
    {
        let openPanel = NSOpenPanel()
        openPanel.level = 8
        openPanel.directoryURL = path
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.canCreateDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.title = "Select metadata folder to grant permission to metadata"
        openPanel.beginWithCompletionHandler()
            {
                (panel_result:Int) -> Void in
                if let picked_url = openPanel.URLs[0] as? NSURL
                    where panel_result == NSFileHandlingPanelOKButton
                {
                    self.ldcviewdelegate.setNewPath(picked_url)
                    self.setCurrentFolderMenuItem()
                }
        }
    }
    var statusItem: NSStatusItem? = nil
    @IBOutlet weak var statusMenu: NSMenu!

    override func awakeFromNib() {
        super.awakeFromNib()
        statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSVariableStatusItemLength)
        statusItem!.menu = statusMenu
        statusItem!.button!.title = "M"
        statusItem!.highlightMode = true
    }

}

