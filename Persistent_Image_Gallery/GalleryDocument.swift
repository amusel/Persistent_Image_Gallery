//
//  Document.swift
//  Persistent_Image_Gallery
//
//  Created by Artem Musel on 9/12/19.
//  Copyright © 2019 Artem Musel. All rights reserved.
//

import UIKit

class GalleryDocument: UIDocument {
    var gallery = Gallery()
    
    override func contents(forType typeName: String) throws -> Any {
        return gallery.json ?? Data()
    }
    
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        if let json = contents as? Data, let gallery = Gallery(json: json) {
            self.gallery = gallery
        }
    }
    var thumbnail: UIImage!
    
    override func fileAttributesToWrite(to url: URL, for saveOperation: UIDocument.SaveOperation) throws -> [AnyHashable : Any] {
        var attributes = try super.fileAttributesToWrite(to: url, for: saveOperation)
        
        if let thumbnail = self.thumbnail {
            attributes[URLResourceKey.thumbnailDictionaryKey] = [URLThumbnailDictionaryItem.NSThumbnail1024x1024SizeKey:thumbnail]
        }
        
        return attributes
    }
}

