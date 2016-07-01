//
//  LDCViewDelegate.swift
//  ldcview
//
//  Created by Mark on 25/05/2016.
//  Copyright © 2016 Mark Scott. All rights reserved.
//

import Foundation
import ObjectiveGit

class LDCViewDelegate: NSObject, NSXPCListenerDelegate, LDCViewInterface
{
    //    var bookmark: NSData?
    var path: NSURL?
    
    override convenience init()
    {
        if let defaultURL = LDCViewDelegate.getBookmarkedURL()
        {
            NSLog("ldcview-delegate: Bookmarked path defined")
            defaultURL.startAccessingSecurityScopedResource()
            self.init(newpath: defaultURL)
            defaultURL.stopAccessingSecurityScopedResource()
            NSLog("init done, newpath %@", self.path!)
        }
        else
        {
            NSLog("ldcview-delegate: Bookmarked path defined")
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

    func helloWorld(result: (NSString) -> ()) {
        dispatch_sync(dispatch_get_main_queue())
        {
            result("Hello world")
        }
    }
    
    func metadataExists(pathReq:NSURL, result: (Bool) -> ()) {
        if self.path == nil
        {
            result(false)
        }
        NSLog("metadataExists: %@", pathReq.path!)
        
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
    
    func getJSON(pathReq:NSURL, result: [MetadataEntry]? -> ()) {
        var myResult = [MetadataEntry]()
        
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
        
        result(myResult)
    }
    
    
    //    func find_first_data_commit_with_metadata_for_blob(dataobject: GTBlob, currentcommit: GTCommit, path:NSURL, repo:GTRepository) -> GTCommit
    //    {
    //        do
    //        {
    //            var metadatanodepath = get_metadata_node_path(path)
    //            var metadatanode = try! repo.lookUpObjectByRevParse("metadata:"+metadatanodepath.relativeString!)
    //            for stream in metadatanode.entries!
    //            {
    //
    //            }
    ////            var metadatablobpath = get_metadata_blob_path(path, streamname: String, datacommitid: <#T##String#>)
    ////            var metadatablob = repo.lookUpObjectByRevParse("metadata:"+path)
    //        }
    //        catch
    //        {
    //
    //        }
    //    }
    
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
            new_base_path = NSURL(string: base_path.path!)!
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
        if let defaults = NSUserDefaults(suiteName: "29547XHFYR.uk.ac.soton.ldcview")
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
        let defaults = NSUserDefaults(suiteName: "29547XHFYR.uk.ac.soton.ldcview")
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
