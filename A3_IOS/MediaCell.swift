//
//  MediaCell.swift
//  A3_IOS
//
//  Created by Akhilesh Bitla on 4/7/25.
//

import Foundation
import UIKit

class MediaCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    override func awakeFromNib() {
            super.awakeFromNib()
            imageView.contentMode = .scaleAspectFill // or .scaleAspectFit depending on your goal
            imageView.clipsToBounds = true
        }

        func configure(with urlString: String) {
            guard let url = URL(string: urlString) else { return }

            URLSession.shared.dataTask(with: url) { data, _, error in
                guard let data = data, error == nil,
                      let image = UIImage(data: data) else { return }

                DispatchQueue.main.async {
                    self.imageView.image = image
                }
            }.resume()
        }
}
