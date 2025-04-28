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
        
        fetchExistingScores()
         
         // Add tap to dismiss keyboard
         let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
         tapGesture.cancelsTouchesInView = false
         view.addGestureRecognizer(tapGesture)
     }
     
     @objc func dismissKeyboard() {
         view.endEditing(true)
     }
     
     func fetchExistingScores() {
         let db = Firestore.firestore()
         
         db.collection("comps").document(competitionID).collection("scores").getDocuments { snapshot, error in
             if let error = error {
                 print("Error fetching existing scores: \(error)")
                 return
             }
             
             guard let documents = snapshot?.documents else { return }
             
             for doc in documents {
                 let data = doc.data()
                 let teamID = doc.documentID
                 let judge1 = data["judge1Score"] as? Int ?? 0
                 let judge2 = data["judge2Score"] as? Int ?? 0
                 let judge3 = data["judge3Score"] as? Int ?? 0
                 let judge4 = data["judge4Score"] as? Int ?? 0
                 
                 self.scores[teamID] = [judge1, judge2, judge3, judge4]
             }
             
             DispatchQueue.main.async {
                 self.tableView.reloadData()
             }
         }
     }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return teams.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 130
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false // Disable row selection highlighting
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let team = teams[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ScoreEntryCell", for: indexPath) as? ScoreEntryCell else {
            return UITableViewCell()
        }
        
        let existingScores = scores[team.id] ?? [] // Get any already-entered scores
        
        cell.configure(with: team, judgeNames: judgeNames, existingScores: existingScores)
        cell.delegate = self
        return cell
    }
    
    @IBAction func saveScoresTapped(_ sender: UIButton) {
        let db = Firestore.firestore()
        var avgScores: [(teamID: String, avg: Double)] = []
        
        // Dictionary to store updated ELO scores for teams
        var updatedELOScores: [String: Double] = [:]
        
        // Loop through scores and calculate the average for each team
        for (teamID, judgeScores) in scores {
            guard judgeScores.count == 4 else {
                print("Skipping \(teamID) — not all judge scores entered.")
                continue
            }
            
            let avg = Double(judgeScores.reduce(0, +)) / Double(judgeScores.count)
            avgScores.append((teamID, avg))
            
            // Save the updated scores to Firestore
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
            
            // Store the updated average score for ELO calculation later
            updatedELOScores[teamID] = avg
        }
        
        // Now save placings based on updated average scores
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
        
        // Check if this competition is being edited or is the first time it's being added
        db.collection("comps").document(competitionID).getDocument { (document, error) in
            if let error = error {
                print("Error fetching competition data for edit check: \(error)")
                return
            }
            
            if let document = document, document.exists {
                let placingsArray = document.data()?["placings"] as? [String] ?? []
                
                // If placings are populated, this competition has already been evaluated
                let isEditing = placingsArray.contains { teamID in
                    // Check if the current team is already placed in this competition
                    return updatedELOScores.keys.contains(teamID)
                }
                
                // Recalculate ELO if it's an edit (i.e., placings are populated)
                if isEditing {
                    // Recalculate ELO for the affected team based on all comps scores
                    for (teamID, newAvg) in updatedELOScores {
                        // Fetch all competitions this team has participated in
                        db.collection("teams").document(teamID).getDocument { (teamDoc, error) in
                            if let error = error {
                                print("Error fetching team data for ELO update: \(error)")
                                return
                            }
                            
                            if let teamDoc = teamDoc, teamDoc.exists {
                                let compsArray = teamDoc.data()?["comps"] as? [String] ?? []
                                
                                // Initialize a variable to calculate the total score
                                var totalScore: Double = 0
                                var totalCompetitions = compsArray.count
                                print("TeamID: \(teamID) | Total Comps: \(totalCompetitions)")

                                // Loop through all comps to calculate the total score for this team
                                for compID in compsArray {
                                    db.collection("comps").document(compID).collection("scores").document(teamID).getDocument { (compDoc, error) in
                                        if let error = error {
                                            print("Error fetching comp data for recalculation: \(error)")
                                            return
                                        }
                                        
                                        if let compDoc = compDoc, compDoc.exists {
                                            let avgScore = compDoc.data()?["averageScore"] as? Double ?? 0.0
                                            totalScore += avgScore
                                        }
                                        // Once all comps are fetched, recalculate ELO
                                        if totalCompetitions == compsArray.count {
                                            let newELO = totalScore / Double(totalCompetitions)
                                            db.collection("teams").document(teamID).updateData([
                                                "eloScore": newELO
                                            ]) { error in
                                                if let error = error {
                                                    print("Error updating ELO score for \(teamID): \(error)")
                                                } else {
                                                    print("Updated ELO score for \(teamID) to \(newELO)")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // If this is a new competition, we just update the ELO based on newAvg (as done earlier)
                    for (teamID, newAvg) in updatedELOScores {
                        db.collection("teams").document(teamID).getDocument { (teamDoc, error) in
                            if let error = error {
                                print("Error fetching team data for ELO update: \(error)")
                                return
                            }
                            
                            if let teamDoc = teamDoc, teamDoc.exists {
                                var currentELO = teamDoc.data()?["eloScore"] as? Double ?? 0.0
                                let compsArray = teamDoc.data()?["comps"] as? [String] ?? []
                                
                                let currentCompetitionsCount = compsArray.count
                                
                                // Calculate the new ELO score
                                let newELO = (currentELO * Double(currentCompetitionsCount) + newAvg) / Double(currentCompetitionsCount + 1)
                                
                                // Update the team's ELO score
                                db.collection("teams").document(teamID).updateData([
                                    "eloScore": newELO
                                ]) { error in
                                    if let error = error {
                                        print("Error updating ELO score for \(teamID): \(error)")
                                    } else {
                                        print("Updated ELO score for \(teamID) to \(newELO)")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

extension ScoresEntryViewController: ScoreEntryCellDelegate {
    func scoresDidUpdate(for teamID: String, scores: [Int]) {
        self.scores[teamID] = scores
    }
}
