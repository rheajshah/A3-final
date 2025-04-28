//
//  ScoreEntryCell.swift
//  A3_IOS
//
//  Created by Rhea Shah on 4/27/25.
//

import UIKit

protocol ScoreEntryCellDelegate: AnyObject {
    func scoresDidUpdate(for teamID: String, scores: [Int])
}

class ScoreEntryCell: UITableViewCell {
    
    @IBOutlet weak var teamNameLabel: UILabel!
    
    @IBOutlet weak var judge1Label: UILabel!
    @IBOutlet weak var judge2Label: UILabel!
    @IBOutlet weak var judge3Label: UILabel!
    @IBOutlet weak var judge4Label: UILabel!
    
    @IBOutlet weak var judge1Field: UITextField!
    @IBOutlet weak var judge2Field: UITextField!
    @IBOutlet weak var judge3Field: UITextField!
    @IBOutlet weak var judge4Field: UITextField!
    
    weak var delegate: ScoreEntryCellDelegate?
    private var teamID: String?
    
    func configure(with team: LineupTeam, judgeNames: [String], existingScores: [Int]) {
        teamNameLabel.text = team.name
        teamID = team.id
        
        if judgeNames.count >= 4 {
            judge1Label.text = "\(judgeNames[0])'s score:"
            judge2Label.text = "\(judgeNames[1])'s score:"
            judge3Label.text = "\(judgeNames[2])'s score:"
            judge4Label.text = "\(judgeNames[3])'s score:"
        }
        
        let fields = [judge1Field, judge2Field, judge3Field, judge4Field]
        
        for (index, field) in fields.enumerated() {
            field?.keyboardType = .decimalPad
            field?.addTarget(self, action: #selector(scoreChanged(_:)), for: .editingChanged)
            
            // Pre-populate if existing score available
            if existingScores.indices.contains(index) {
                field?.text = "\(existingScores[index])"
            } else {
                field?.text = "" // otherwise blank
            }
        }
    }
    
    @objc func scoreChanged(_ sender: UITextField) {
        guard let id = teamID else { return }
        let scores = [judge1Field, judge2Field, judge3Field, judge4Field].compactMap { Int($0.text ?? "") }
        delegate?.scoresDidUpdate(for: id, scores: scores)
    }
}
