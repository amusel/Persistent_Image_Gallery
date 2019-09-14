//
//  ImageCollectionViewController.swift
//  Image_Gallery
//
//  Created by Artem Musel on 9/6/19.
//  Copyright © 2019 Artem Musel. All rights reserved.
//

import UIKit

class ImageCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout,
    UICollectionViewDropDelegate, UICollectionViewDragDelegate, UIDropInteractionDelegate
{
    var document: GalleryDocument?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView!.dropDelegate = self
        collectionView!.dragDelegate = self
        //make enabled for iPhone
        collectionView.dragInteractionEnabled = true
        
        createTrashButton()
        
        URLCache.shared = URLCache(
            memoryCapacity: 1000*1024*1024,
            diskCapacity: 1000*1024*1024,
            diskPath: nil
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        //standard item width = 2 in row
        itemWidth = (collectionView.frame.size.width / 2) - itemSpacing
        
        document?.open { success in
            if success {
                self.title = self.document?.localizedName
                self.gallery = self.document?.gallery
                self.collectionView.reloadData()
            }
        }
    }
    
    private func save() {
        document?.gallery = gallery
        if document?.gallery != nil {
            document?.updateChangeCount(.done)
        }
    }
    
    @IBAction func close(_ sender: UIBarButtonItem) {
        let cell = collectionView.visibleCells.first(where: { cell in
            if let imageCell = cell as? ImageCollectionViewCell {
                return imageCell.imageView.image != nil
            }
            
            return false
        })
        
        if let imageCell = cell as? ImageCollectionViewCell {
            document?.thumbnail = imageCell.imageView.image
        }
        
        dismiss(animated: true, completion: { self.document?.close() })
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ImageView",
            let imageViewController = segue.destination as? ImageViewController,
            let imageCell = sender as? UICollectionViewCell,
            let indexPath = collectionView.indexPath(for: imageCell) {
                imageViewController.imageURL = gallery.images[indexPath.item].url
            }
    }
    
    //perform seque only if image is valid and loaded
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "ImageView", 
            let imageCell = sender as? ImageCollectionViewCell,
            imageCell.imageView.image == nil
        {
            return false
        }
        
        return true
    }
    
    
    // MARK: UICollectionViewDataSource
    var gallery: Gallery! {
        didSet {
            save()
        }
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if gallery == nil {
            return 0
        }
        
        return gallery.images.count
    }

    override func collectionView(_ collectionView: UICollectionView,
                                 cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath)
        
        let galleryItem = gallery.images[indexPath.item]
        
        guard let imageCell = cell as? ImageCollectionViewCell else {
            return cell
        }
        
        let cache = URLCache.shared
        
        let request = URLRequest(url: galleryItem.url)
        
        //use cache
        if let data = cache.cachedResponse(for: request)?.data, let image = UIImage(data: data) {
            imageCell.imageView.image = image
        }
        //or download
        else {
            imageCell.imageView.image = nil
            imageCell.label.text = ""
            imageCell.activitySpinner.startAnimating()
            
            DispatchQueue.global(qos: .userInitiated).async {
                URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
                    if let data = data, let response = response,
                        ((response as? HTTPURLResponse)?.statusCode ?? 500) < 300,
                        let image = UIImage(data: data)
                    {
                        DispatchQueue.main.async {
                            let cachedData = CachedURLResponse(response: response, data: data)
                            cache.storeCachedResponse(cachedData, for: request)
                            if imageCell.imageView.image == nil {
                                imageCell.activitySpinner.stopAnimating()
                                imageCell.imageView.image = image
                            }
                        }
                    }
                    //in case something went wrong
                    else {
                        DispatchQueue.main.async {
                            imageCell.activitySpinner.stopAnimating()
                            imageCell.label.text = "Not valid image🥺"
                        }
                    }
                }).resume()
            }
        }
        
        return cell
    }
    
    
    // MARK: UICollectionViewDelegateFlowLayout
    let itemSpacing: CGFloat = 5
    var itemWidth: CGFloat = 0 {
        didSet {
            let minimumWidth = (collectionView.frame.size.width / 3) - itemSpacing*2
            let maximunWidth = collectionView.frame.size.width - 5
            if itemWidth > maximunWidth {
                itemWidth = maximunWidth
            }
            else if itemWidth < minimumWidth {
                itemWidth = minimumWidth
            }
            
            if oldValue != itemWidth {
                flowLayout?.invalidateLayout()
            }
        }
    }
    
    var flowLayout: UICollectionViewFlowLayout? {
        return collectionView?.collectionViewLayout as? UICollectionViewFlowLayout
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let galleryImage = gallery.images[indexPath.item]
        let itemHeight = itemWidth / CGFloat(galleryImage.aspect)
        
        return CGSize(width: itemWidth, height: itemHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return itemSpacing
    }
    
    @IBAction func zoom(_ sender: UIPinchGestureRecognizer) {
        if sender.state == .began || sender.state == .changed {
            itemWidth *= sender.scale
            sender.scale = 1
        }
    }
    
    
    // MARK: UICollectionViewDragDelegate
    func collectionView(_ collectionView: UICollectionView,
                        itemsForBeginning session: UIDragSession,
                        at indexPath: IndexPath) -> [UIDragItem] {
        session.localContext = collectionView
        return dragItem(at: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        itemsForAddingTo session: UIDragSession,
                        at indexPath: IndexPath, point: CGPoint) -> [UIDragItem] {
        return dragItem(at: indexPath)
    }
    
    private func dragItem(at indexPath: IndexPath) -> [UIDragItem] {
        if let url = gallery.images[indexPath.item].url as NSURL? {
            let dragItem = UIDragItem(itemProvider: NSItemProvider(object: url))
            dragItem.localObject = gallery.images[indexPath.item]
            return [dragItem]
        }
        
        return []
    }
    
    
    // MARK: UICollectionViewDropDelegate
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        if collectionView.hasActiveDrag {
            //local objects are nsurl
            return session.canLoadObjects(ofClass: NSURL.self)
        } else {
            return session.canLoadObjects(ofClass: URL.self) && session.canLoadObjects(ofClass: UIImage.self)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        dropSessionDidUpdate session: UIDropSession,
                        withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal
    {
        if gallery == nil {
            //if no gallery is sellected
            return UICollectionViewDropProposal(operation: .forbidden)
        }
        
        //if it's local movement, there is no need in copy
        let isSelf = (session.localDragSession?.localContext as? UICollectionView) == collectionView
        return UICollectionViewDropProposal(operation: isSelf ? .move : .copy, intent: .insertAtDestinationIndexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        performDropWith coordinator: UICollectionViewDropCoordinator) {
        let destinationIndexPath = coordinator.destinationIndexPath ?? IndexPath(row: 0, section: 0)
        
        for item in coordinator.items {
            if let sourceIndexPath = item.sourceIndexPath {
                collectionView.performBatchUpdates({
                    let removed = gallery.images.remove(at: sourceIndexPath.item)
                    gallery.images.insert(removed, at: destinationIndexPath.item)
                    collectionView.deleteItems(at: [sourceIndexPath])
                    collectionView.insertItems(at: [destinationIndexPath])
                })
                coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)
            }
            else {
                let placeholderContext = coordinator.drop(
                    item.dragItem,
                    to: UICollectionViewDropPlaceholder(insertionIndexPath: destinationIndexPath, reuseIdentifier: "PlaceholderCell"))

                var galleryItem = Gallery.GalleryItem()
                
                item.dragItem.itemProvider.loadObject(ofClass: UIImage.self) { (provider, error) in
                    if let image = provider as? UIImage {
                        galleryItem.aspect = image.aspectRatio
                    }
                }
                
                _ = item.dragItem.itemProvider.loadObject(ofClass: URL.self) { (provider, error) in
                    if let url = provider?.imageURL {
                        galleryItem.url = url
                        
                        DispatchQueue.main.async {
                            placeholderContext.commitInsertion { indexPath in
                                self.gallery.images.insert(galleryItem, at: indexPath.item)
                            }
                        }
                    }
                    else {
                        placeholderContext.deletePlaceholder()
                    }
                }
            }
        }
    }
    
    
    // MARK: UIDropInteractionDelegate
    //creates BarButtonItem for trash bin, because
    //standard button can not have interactions
    private func createTrashButton() {
        let trashButton = UIButton()
        trashButton.setImage(UIImage(named: "icon_trash"), for: .normal)
        
        let dropInteraction = UIDropInteraction(delegate: self)
        trashButton.addInteraction(dropInteraction)
        
        let barItem = UIBarButtonItem(customView: trashButton)
        
        navigationItem.rightBarButtonItem = barItem
        
        barItem.customView!.widthAnchor.constraint(equalToConstant: 25).isActive = true
        barItem.customView!.heightAnchor.constraint(equalToConstant: 25).isActive = true
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: NSURL.self)
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return UIDropProposal(operation: .move)
    }

    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        if (session.localDragSession?.localContext as? UICollectionView) != collectionView {
            return
        }

        for item in session.items {
            if let galleryItem = item.localObject as? Gallery.GalleryItem,
                let index = gallery.images.firstIndex(of: galleryItem) {
                gallery.images.remove(at: index)
                collectionView.reloadData()
            }
        }
    }
}
