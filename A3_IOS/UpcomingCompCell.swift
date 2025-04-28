//  UpcomingCompCell.swift
//  A3_IOS
//
//  Created by Aryan Samal on 4/8/25.
//

import Foundation
import UIKit

class UpcomingCompCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var compName: UILabel!
    @IBOutlet weak var location: UILabel!
    @IBOutlet weak var date: UILabel!
    @IBOutlet weak var editButton: UIButton!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
    }
    
    @IBAction func editButtonTapped(_ sender: Any) {
        
    }
    
}
