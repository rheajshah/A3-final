//
//  LineupTeamCell.swift
//  A3_IOS
//
//  Created by Rhea Shah on 4/7/25.
//

import UIKit

class LineupTeamCell: UITableViewCell {
    
    @IBOutlet weak var numberLabel: UILabel!
    @IBOutlet weak var teamLogoImageView: UIImageView!
    @IBOutlet weak var teamName: UILabel!
    @IBOutlet weak var eloLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Initialization code
        teamLogoImageView.layer.cornerRadius = teamLogoImageView.frame.size.width / 2
        teamLogoImageView.clipsToBounds = true
    }
    
    func configure(with team: LineupTeam, position: Int?, isPlacingsMode: Bool) {
        if isPlacingsMode {
            numberLabel.isHidden = false
            numberLabel.text = "\(position ?? 0)" // 1, 2, 3, etc.
        } else {
            numberLabel.isHidden = true
        }
    }

    func loadImage(from url: URL, into imageView: UIImageView?) {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data {
                DispatchQueue.main.async {
                    imageView?.image = UIImage(data: data)
                }
            }
        }.resume()
    }
}



