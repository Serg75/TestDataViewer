//
//  DetailViewController.swift
//  testDataViewer
//
//  Created by Sergey Slobodenyuk on 01/11/16.
//  Copyright © 2016 Elements Interactive. All rights reserved.
//

import UIKit
import Kingfisher

class DetailViewController: UIViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detailDescriptionLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var noImageView: UIImageView!
    
    
    func configureView() {
        // Update the user interface for the detail item.
        if let detail = self.detailItem {
            
            // title
            if let title = self.titleLabel {
                title.text = detail.title
                title.isHidden = false
            }
            
            // description
            if let label = self.detailDescriptionLabel {
                label.setAttributedTextWithoutFont(text: detail.description)
                label.isHidden = false
            }
            
            // image
            if let label = self.noImageView {
                label.isHidden = true
            }
            if let url = detail.imageURL, let imageView = self.imageView {
                
                imageView.kf.indicatorType = .activity
                imageView.kf.setImage(with: url,
                                      options: [.transition(.fade(0.2))],
                                      completionHandler: { (image: Image?, error: NSError?, cacheType: CacheType, url: URL?) in
                                        
                                        if error != nil {
                                            self.noImageView.isHidden = false
                                        }
                })
            } else {
                if let label = self.noImageView {
                    label.isHidden = false
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.configureView()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    var detailItem: RowData? {
        didSet {
            // Update the view.
            self.configureView()
        }
    }
    
    
}

