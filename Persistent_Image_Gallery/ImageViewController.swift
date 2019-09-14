//
//  ImageViewController.swift
//  Image_Gallery
//
//  Created by Artem Musel on 9/10/19.
//  Copyright © 2019 Artem Musel. All rights reserved.
//

import UIKit

class ImageViewController: UIViewController, UIScrollViewDelegate {
    
    var imageURL: URL?
    @IBOutlet weak var activitySpinner: UIActivityIndicatorView!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let url = imageURL {
            let request = URLRequest(url: url)
            if let data = URLCache.shared.cachedResponse(for: request)?.data, let image = UIImage(data: data) {
                imageView.image = image
                imageView.sizeToFit()
                
                // The size of the image
                let imageSize = imageView?.image?.size ?? CGSize.zero
                
                // Size of the display
                let displaySize = scrollView.bounds.size
                
                // Scrollview content-size must fit the image
                scrollView.contentSize = imageSize
                
                // A scale that will fit the whole image on screen
                let zoomScaleThatFitsWholeImage = min(displaySize.width/imageSize.width,
                                                      displaySize.height/imageSize.height)
                scrollView.minimumZoomScale = zoomScaleThatFitsWholeImage
                scrollView.maximumZoomScale = 2
                scrollView.zoomScale = zoomScaleThatFitsWholeImage
                
                
                let size = imageView.frame.size
                scrollView.contentSize = size
                scrollViewWidth.constant = size.width
                scrollViewHeight.constant = size.height
            }
        }
    }
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var scrollViewWidth: NSLayoutConstraint!
    @IBOutlet weak var scrollViewHeight: NSLayoutConstraint!
    
    @IBOutlet weak var scrollView: UIScrollView! {
        didSet {
            scrollView.addSubview(imageView)
            scrollView.delegate = self
        }
    }
    
    // MARK: UIScrollViewDelegate
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        scrollViewWidth.constant = scrollView.contentSize.width
        scrollViewHeight.constant = scrollView.contentSize.height
    }
}
