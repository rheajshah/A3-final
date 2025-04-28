//
//  CustomTeamSummaryCell.swift
//  A3_IOS
//
//  Created by Rhea Shah on 4/6/25.
//

import UIKit

class CustomTeamSummaryCell: UITableViewCell {
    
    @IBOutlet weak var teamLogoImageView: UIImageView!
    @IBOutlet weak var teamName: UILabel!
    @IBOutlet weak var location: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Initialization code
        teamLogoImageView.layer.cornerRadius = teamLogoImageView.frame.size.width / 2
        teamLogoImageView.clipsToBounds = true
    }
    
    func configure(with team: TeamSummary) {
        teamName.text = team.name
        location.text = team.university
        
        if let logoURL = URL(string: team.teamLogoURL) {
            loadImage(from: logoURL, into: teamLogoImageView)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        teamLogoImageView.image = nil
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


