//
//  RankingCell.swift
//  A3_IOS
//
//  Created by Akhilesh Bitla on 3/12/25.
//

import Foundation
import UIKit

class RankingCell: UITableViewCell {
    
    @IBOutlet weak var teamRankLabel: UILabel!
    @IBOutlet weak var teamImageView: UIImageView!
    @IBOutlet weak var teamNameLabel: UILabel!
    @IBOutlet weak var teamEloLabel: UILabel!
    
    override func layoutSubviews() {
        super.layoutSubviews()
        teamImageView.layer.cornerRadius = teamImageView.frame.width / 2
        teamImageView.clipsToBounds = true
        teamImageView.contentMode = .scaleAspectFill
    }

    
    override func prepareForReuse() {
        super.prepareForReuse()
        teamImageView.image = nil
    }
    
    
}
