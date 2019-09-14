//
//  GalleriesModel.swift
//  Image_Gallery
//
//  Created by Artem Musel on 9/6/19.
//  Copyright © 2019 Artem Musel. All rights reserved.
//

import Foundation

struct Gallery: Equatable, Codable {
    let identifier: String
    var title: String
    var images: [GalleryItem] = []
    
    //image with url
    struct GalleryItem: Equatable, Codable {
        var url: URL!
        var aspect: Double = 1
    }
    
    init(title: String = "") {
        self.title = title
        identifier = UUID().uuidString
    }
    
    static func == (lhs: Gallery, rhs: Gallery) -> Bool {
        return lhs.identifier == rhs.identifier
    }
    
    //MARK: JSON
    var json: Data? {
        return try? JSONEncoder().encode(self)
    }
    
    init?(json: Data) {
        if let newValue = try? JSONDecoder().decode(Gallery.self, from: json) {
            self = newValue
        }
        else {
            return nil
        }
    }
}

