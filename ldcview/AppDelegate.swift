//
//  AppDelegate.swift
//  ldcview
//
//  Created by Mark Scott on 16/06/2015.
//  Copyright (c) 2015 Mark Scott. All rights reserved.
//

import Cocoa
import ServiceManagement

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var currentFolderMenuItem: NSMenuItem!
    @IBOutlet weak var changeCurrentFolderMenuItem: NSMenuItem!
    
    // Save these variables to prevent garbage collection
    let anonlistener = NSXPCListener.anonymousListener()
    let mainappdelegate = LDCViewDelegate()
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        
        // Check the folder we have access to
        
        // Gain access to the folder
        if mainappdelegate.path == nil
        {
            promptForPath(NSURL(fileURLWithPath: NSHomeDirectory()))
        }
        
        let success = SMLoginItemSetEnabled("29547XHFYR.uk.ac.soton.ldcview.helper", true)
        NSLog("SMLoginItemSetEnabled" + (success ? " succeeded" : " failed"))
        
        // Set up our listener
        anonlistener.delegate = self.mainappdelegate
        anonlistener.resume()
        NSLog("Our listener set up")

        // Register the end point with shared XPC service
        let connection = NSXPCConnection(machServiceName: "29547XHFYR.uk.ac.soton.ldcview.helper", options: NSXPCConnectionOptions())
        let interface = NSXPCInterface(withProtocol: LDCServiceInterface.self)
        connection.remoteObjectInterface = interface
        connection.resume()
        if let proxy = connection.remoteObjectProxyWithErrorHandler({ (err: NSError) in
            dispatch_sync(dispatch_get_main_queue()){
            NSLog(err.localizedDescription)
            }
        }) as? LDCServiceInterface
        {
            proxy.registerEndpoint(anonlistener.endpoint)
            NSLog("Connection made")
//            connection.invalidate()
        }
        else{
            NSLog("No connection")
        }
        
        
        
        self.window.orderOut(self)
        self.changeCurrentFolderMenuItem.target = self
        self.changeCurrentFolderMenuItem.action = #selector(AppDelegate.showWindow(_:))
        self.setCurrentFolderMenuItem()
    }
    
    func showWindow(sender: AnyObject)
    {
        promptForPath(NSURL(fileURLWithPath: NSHomeDirectory()))
    }
    
    func setCurrentFolderMenuItem()
    {
        var menuTitle:String
        if let monitoredPath = mainappdelegate.path {
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
                    self.mainappdelegate.setNewPath(picked_url)
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

