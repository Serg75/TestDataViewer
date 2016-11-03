//
//  DataController.swift
//  testDataViewer
//
//  Created by Sergey Slobodenyuk on 01/11/16.
//  Copyright © 2016 Elements Interactive. All rights reserved.
//

import Foundation
import MobileCoreServices
import UIKit


public let connectionStatusNotification = Notification.Name("connectionStatus")
public let connectionIsAvailable = "isAvailable"
public let connectionMustBe = "mustBe"

public let tableDataReadyNotification = Notification.Name("tableDataReady")


class DataController {
    
    enum UpdateStatus {
        case notUpdated, processing, finished
    }
    private static var _updateStatus = UpdateStatus.notUpdated
    
    
    private static let config = URLSessionConfiguration.default
    private static var session = URLSession(configuration: config)
    
    private static let sharedInstance = DataController()
    
    private static let cachePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    
    private static var connectionRequested = false
    
    private var reach: Reachability?
    
    
    static func configure() {
        sharedInstance.setupReachability()
        
        // check the table for a new version every 60 seconds
        Timer.scheduledTimer(timeInterval: 60,
                             target: self,
                             selector: #selector(self.updateTable),
                             userInfo: nil,
                             repeats: true)
    }
    
    
    // MARK: - Reachability
    
    private func setupReachability() {
        // Allocate a reachability object
        self.reach = Reachability.forInternetConnection()
        
        // Tell the reachability that we DON'T want to be reachable on 3G/EDGE/CDMA
        self.reach!.reachableOnWWAN = false
        
        // Here we set up a NSNotification observer. The Reachability that caused the notification
        // is passed in the object parameter
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(DataController.reachabilityChanged(_:)),
                                               name: NSNotification.Name.reachabilityChanged,
                                               object: nil)
        
        self.reach!.startNotifier()
    }
    
    @objc func reachabilityChanged(_ notification: NSNotification) {
        let status = self.reach!.isReachableViaWiFi() || self.reach!.isReachableViaWWAN()
        if status {
            print("Service avalaible!!!")
            DataController.updateTable()
        } else {
            print("No service avalaible!!!")
        }
        
        // here I send simplified notification for view controllers
        NotificationCenter.default.post(name: connectionStatusNotification,
                                        object: nil,
                                        userInfo: [connectionIsAvailable : status])
    }
    
    // MARK: - Table Data
    
    // data from csv file
    private static var tableData = [RowData]()
    
    static var tableDataRowCount: Int {
        return tableData.count
    }
    
    static func tableDataForRow(_ row: Int) -> RowData? {
        if row <= tableData.count {
            return tableData[row]
        }
        return nil
    }
    
    private static let TABLE_FILE_KEY = "0Aqg9JQbnOwBwdEZFN2JKeldGZGFzUWVrNDBsczZxLUE"
    private static let TABLE_CSV_FILE = "https://docs.google.com/spreadsheet/ccc?key=0Aqg9JQbnOwBwdEZFN2JKeldGZGFzUWVrNDBsczZxLUE&single=true&gid=0&output=csv"

    private static let FILES_GET_PATTERN = "https://www.googleapis.com/drive/v2/files/%@?alt=%@&key=%@"
    private static let GOOGLE_API_KEY = "AIzaSyAmDkeTSTRzxr4hWmomg3ezPKlNPHxtqnY"
    
    private static let csvVersionKey = "csvVersion"
    private static let csvLocalFile = "table.csv"
    
    
    @objc static func updateTable() {
        
        guard _updateStatus != .processing else { return }
        
        if (sharedInstance.reach!.currentReachabilityStatus() == .NotReachable) {
            
            // show "Offline" indicator on startup
            NotificationCenter.default.post(name: connectionStatusNotification,
                                            object: nil,
                                            userInfo: [connectionIsAvailable : false])
            
            if FileManager.default.fileExists(atPath: cachePath.appendingPathComponent(csvLocalFile).path) {
                
                readCachedTable()
                
            } else if !connectionRequested {
                
                // prevent show request multiple times
                connectionRequested = true
                
                NotificationCenter.default.post(name: connectionStatusNotification,
                                                object: nil,
                                                userInfo: [connectionMustBe : true])
            }
            return;
        }
        
        guard let url = URL(string: String(format:FILES_GET_PATTERN, TABLE_FILE_KEY, "json", GOOGLE_API_KEY)) else { return }
        
        _updateStatus = .processing
        
        let request = URLRequest(url: url, cachePolicy: NSURLRequest.CachePolicy.useProtocolCachePolicy, timeoutInterval: 60)
        
        let task = session.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            
            if error == nil && data != nil {
                
                if let metadata = getMetadata(data!), let val = metadata["shared"] as? NSNumber, val.boolValue {
                    
                    let storage = UserDefaults.standard
                    let currentVersion = storage.string(forKey: csvVersionKey)
                    let newVersion = metadata["version"] as! String
                    
                    if currentVersion != newVersion {
                        
                        if let url = URL(string: TABLE_CSV_FILE) {
                            fetchTable(url: url, completionHandler: { (data: Data) in
                                do {
                                    let cachedCSV = cachePath.appendingPathComponent(csvLocalFile)
                                    try data.write(to: cachedCSV, options: Data.WritingOptions.atomicWrite)
                                    UserDefaults.standard.set(newVersion, forKey:csvVersionKey)

                                    self.updateDidFinishWithNewVersion(true)
                                } catch  {
                                    print(error)
                                    self.updateDidFinishWithNewVersion(false)
                                }
                            })
                        } else {
                            print("wrong csv url!")
                            self.updateDidFinishWithNewVersion(false)
                        }
                    } else {
                        if tableData.count == 0 {
                            readCachedTable()
                        }
                        self.updateDidFinishWithNewVersion(false)
                    }
                } else {
                    self.updateDidFinishWithNewVersion(false)
                }
            } else {
                if error != nil {
                    print(error!)
                }
                self.updateDidFinishWithNewVersion(false)
            }
        }
        task.resume()
    }
    
    private class func readCachedTable() {
        fetchTable(url: cachePath.appendingPathComponent(csvLocalFile), completionHandler: { (data: Data) in
        })
    }
    
    private static func getMetadata(_ data: Data) -> [String: Any]? {
        do {
            let metadata = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)
            return metadata as? [String: Any]
        } catch let error as NSError {
            print("google grive file metadata error: \(error)")
            return nil
        }
    }
    
    private static func updateDidFinishWithNewVersion(_ newVersion: Bool) {
        _updateStatus = .finished
        if newVersion {
            NotificationCenter.default.post(Notification(name: tableDataReadyNotification))
        }
    }
    
    static func fetchTable(url: URL, completionHandler: @escaping (_ data: Data) -> Void) {
        
        let task = session.dataTask(with: url) { (data: Data?, responce: URLResponse?, error: Error?) in
            if error == nil {
                if data != nil, let csvData = String.init(data: data!, encoding: String.Encoding.utf8) {
                    
                    // test info
                    print("================== vvv ==================")
                    print(csvData)
                    print("================== ^^^ ==================")
                    
                    let rows = self.getRows(csvData).dropFirst()    // remove headers
                    var newData = [RowData]()
                    for row in rows {
                        var fields = self.getFieldsForRow(row)
                        if fields.count == 2 {
                            fields.append("")
                        }
                        if fields.count == 3 {
                            
                            // test info
                            print("\(fields[0])|\(fields[1])|\(fields[2])")
                            
                            newData.append(RowData.init(title: fields[0],
                                                        description: fields[1].attributedFromHTML(),
                                                        imageURL: URL(string: fields[2])))
                        } else {
                            print("error in row:")
                            print(row)
                        }
                    }
                    
                    tableData = newData
                    
                    completionHandler(data!)
                    
                    NotificationCenter.default.post(Notification(name: tableDataReadyNotification))
                }
            } else {
                print(error!)
            }
        }
        task.resume()
    }
    
    // Handle new lines and quotes:
    
    private class func getRows(_ stringData: String) -> [String] {
        var cleanData = stringData
        cleanData = cleanData.replacingOccurrences(of: "\r", with: "\n")
        cleanData = cleanData.replacingOccurrences(of: "\n\n", with: "\n")
        cleanData = cleanData.replacingOccurrences(of: "\"\"", with: "\"")
        return components(of: cleanData, separatedBy: "\n")
    }
    
    private class func getFieldsForRow(_ row: String) -> [String] {
        return components(of: row, separatedBy: ",").map { self.cleanString($0) }
    }
    
    private class func components(of originalString:String, separatedBy separator: Character) -> [String] {
        var quotesCount = 0
        var output = [String]()
        var field = ""
        
        for char in originalString.characters {
            switch char {
            case "\"":
                quotesCount += 1
                field.append(char)
            case separator:
                if quotesCount % 2 == 0 {
                    output.append(field)
                    field = ""
                } else {
                    field.append(char)
                }
            default:
                field.append(char)
            }
        }
        output.append(field)
        return output
    }
    
    private class func cleanString(_ inputString: String) -> String {
        let outputString = inputString.trimmingCharacters(in: CharacterSet.whitespaces)
        var characters = outputString.characters
        if characters.first == "\"" && characters.last == "\"" {
            characters = characters.dropFirst().dropLast()
            return String.init(characters)
        }
        return outputString
    }
    
    
    // MARK: - Extra
    
    class func isImageURL(_ url: URL) -> Bool {
        return mimeType(fileExtension: url.pathExtension).hasPrefix("image/")
    }
    
    class private func mimeType(fileExtension: String) -> String {
        if !fileExtension.isEmpty {
            let UTIRef = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension as CFString, nil)
            let UTI = UTIRef?.takeUnretainedValue()
            UTIRef?.release()
            
            let MIMETypeRef = UTTypeCopyPreferredTagWithClass(UTI!, kUTTagClassMIMEType)
            if MIMETypeRef != nil
            {
                let MIMEType = MIMETypeRef?.takeUnretainedValue()
                MIMETypeRef?.release()
                return MIMEType as! String
            }
        }
        return ""
    }
}
