//
//  MasterViewController.swift
//  testDataViewer
//
//  Created by Sergey Slobodenyuk on 01/11/16.
//  Copyright © 2016 Elements Interactive. All rights reserved.
//

import UIKit
import Kingfisher

class MasterViewController: UITableViewController {
    
    @IBOutlet weak var offlineIndicator: UIView!
    
    
    var detailViewController: DetailViewController? = nil
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        if let split = self.splitViewController {
            if UIDevice.current.userInterfaceIdiom == .pad {
                split.preferredDisplayMode = .allVisible
            }
            let controllers = split.viewControllers
            self.detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
        }
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(connectionStatus(_:)),
                                               name: connectionStatusNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateTable(_:)),
                                               name: tableDataReadyNotification,
                                               object: nil)
        
        DataController.updateTable()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.clearsSelectionOnViewWillAppear = self.splitViewController!.isCollapsed
        super.viewWillAppear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func connectionStatus(_ notification: NSNotification) {
        if let status = notification.userInfo?[connectionIsAvailable] as? Bool {
            offlineIndicator.isHidden = status
        }
        if (notification.userInfo?[connectionMustBe] as? Bool) != nil {
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                let alert = UIAlertController(title: "No Internet Connection", message: "You must be connected to the internet for the first time", preferredStyle: UIAlertControllerStyle.alert)
                
                let defaultAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil)
                alert.addAction(defaultAction)

                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    
    func updateTable(_ notification: NSNotification) {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    
    // MARK: - Segues
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            if let indexPath = self.tableView.indexPathForSelectedRow {
                if let row = DataController.tableDataForRow(indexPath.row) {
                    let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
                    controller.detailItem = row
                    controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem
                    controller.navigationItem.leftItemsSupplementBackButton = true
                }
            }
        }
    }
    
    // MARK: - Table View
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 75
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return DataController.tableDataRowCount
    }
    
    var imageCache = [String: UIImage]()
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! CustomTableViewCell
        
        if let rowData = DataController.tableDataForRow(indexPath.row) {
            cell.titleLabel!.text = rowData.title.replacingOccurrences(of: "\n", with: ", ")
            cell.descriptionLabel.setAttributedTextWithoutFont(text: rowData.description)
            cell.thumbnail.image = nil
            
            if let imgURL = rowData.imageURL, DataController.isImageURL(imgURL) {
                
                // resizing images here cause Kingfisher uses different cache images for large and small ones
                //let processor = ResizingImageProcessor(targetSize: cell.thumbnail.frame.size)
                
                cell.thumbnail.kf.setImage(with: imgURL,
                                           options: [.transition(.fade(0.2))],
                                           completionHandler: { (image: Image?, error: NSError?, cacheType: CacheType, url: URL?) in
                                            
                                            if error != nil {
                                                cell.thumbnail.image = #imageLiteral(resourceName: "No_Image_Available")
                                            }
                })
            } else {
                cell.thumbnail.image = #imageLiteral(resourceName: "No_Image_Available")
            }
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return false
    }
    
}

