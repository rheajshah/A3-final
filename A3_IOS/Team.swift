//
//  Team.swift
//  A3_IOS
//
//  Created by Akhilesh Bitla on 4/6/25.
//

import Foundation
import UIKit

class Team {
    var name: String
    var university: String
    var city: String
    var state: String
    var teamPicture: UIImage?
    var teamLogo: UIImage?

    init(name: String, university: String, city: String, state: String, teamPicture: UIImage? = nil, teamLogo: UIImage? = nil) {
        self.name = name
        self.university = university
        self.city = city
        self.state = state
        self.teamPicture = teamPicture
        self.teamLogo = teamLogo
    }
}
