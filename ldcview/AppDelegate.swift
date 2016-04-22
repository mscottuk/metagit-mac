//
//  AppDelegate.swift
//  ldcview
//
//  Created by Mark Scott on 16/06/2015.
//  Copyright (c) 2015 Mark Scott. All rights reserved.
//

import Cocoa

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
        let interface = NSXPCInterface(withProtocol: LDCViewInterface.self)
        newConnection.exportedInterface = interface
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    func getJSON(pathReq:NSURL, result: (NSDictionary?) -> ()) {
        var myResult: NSDictionary? = nil
        
        if self.path == nil
        {
            result(nil)
        }
        
//        var myPath = getURLFromSecureBookmark(bookmark!)

        self.path!.startAccessingSecurityScopedResource()
        
        if access(pathReq.fileSystemRepresentation, R_OK) == 0
        {
            let file_data:NSData? = NSData(contentsOfFile: pathReq.path!)
            var err:NSError?
            do
            {
                if let json = try NSJSONSerialization.JSONObjectWithData(file_data!, options: []) as? NSDictionary
                {
                    myResult = json
                }
            }
            catch let error as NSError{
                err = error
            }
        }
        
        self.path!.stopAccessingSecurityScopedResource()
        
        result(myResult)
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
        self.currentFolderMenuItem.title = "Monitoring " + ldcviewdelegate.path!.path!
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
        statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(-1)
        statusItem!.menu = statusMenu
        statusItem!.title = "M"
        statusItem!.highlightMode = true
    }

}

