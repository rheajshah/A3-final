//
//  ScoresEntryViewController.swift
//  A3_IOS
//
//  Created by Rhea Shah on 4/27/25.
//

import UIKit
import FirebaseFirestore

class ScoresEntryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    
    var competitionID: String!
    var teams: [LineupTeam] = [] // Passed from previous VC
    var judgeNames: [String] = [] // NEW: real judge names passed in
    var scores: [String: [Int]] = [:] // teamID -> list of 4 judge scores
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return teams.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120 // or 130 if you want even more breathing room
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let team = teams[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ScoreEntryCell", for: indexPath) as? ScoreEntryCell else {
            return UITableViewCell()
        }
        cell.configure(with: team, judgeNames: judgeNames)
        cell.delegate = self
        return cell
    }
    
    @IBAction func saveScoresTapped(_ sender: UIButton) {
        let db = Firestore.firestore()
        var avgScores: [(teamID: String, avg: Double)] = []
        
        for (teamID, judgeScores) in scores {
            guard judgeScores.count == 4 else {
                print("Skipping \(teamID) — not all judge scores entered.")
                continue
            }
            
            let avg = Double(judgeScores.reduce(0, +)) / Double(judgeScores.count)
            avgScores.append((teamID, avg))
            
            db.collection("comps").document(competitionID).collection("scores").document(teamID).setData([
                "judge1Score": judgeScores[0],
                "judge2Score": judgeScores[1],
                "judge3Score": judgeScores[2],
                "judge4Score": judgeScores[3],
                "averageScore": avg
            ]) { error in
                if let error = error {
                    print("Error saving scores for \(teamID): \(error)")
                } else {
                    print("Saved scores for \(teamID)")
                }
            }
        }
        
        // Now save placings
        let sorted = avgScores.sorted { $0.avg > $1.avg }
        let placingIDs = sorted.map { $0.teamID }
        
        db.collection("comps").document(competitionID).updateData([
            "placings": placingIDs
        ]) { error in
            if let error = error {
                print("Error updating placings: \(error)")
            } else {
                print("Placings updated successfully.")
            }
        }
    }
}

extension ScoresEntryViewController: ScoreEntryCellDelegate {
    func scoresDidUpdate(for teamID: String, scores: [Int]) {
        self.scores[teamID] = scores
    }
}
