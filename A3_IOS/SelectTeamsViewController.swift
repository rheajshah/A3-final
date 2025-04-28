//
//  SelectTeamsViewController.swift
//  A3_IOS
//
//  Created by Eshitha B on 4/4/25.
//

import UIKit
import FirebaseFirestore

protocol SelectTeamsDelegate: AnyObject {
    func didUpdateCompetingTeams()
}

class SelectTeamsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    

    @IBOutlet weak var tableView: UITableView!
    weak var delegate: SelectTeamsDelegate?

    
    var teams: [OptionItem] = []
   let db = Firestore.firestore()
   
   var selectedTeams: [String] = []    // Only stores selected team IDs
   var competitionID: String!          // Passed in from CompDescriptionViewController
   
   override func viewDidLoad() {
       super.viewDidLoad()
       
       tableView.delegate = self
       tableView.dataSource = self
       
       fetchCompDetailsAndTeams()
   }
   
   // Fetch selected teams + then fetch all teams
   func fetchCompDetailsAndTeams() {
       let compRef = db.collection("comps").document(competitionID)
       
       compRef.getDocument { snapshot, error in
           if let error = error {
               print("Error fetching competition data: \(error)")
               return
           }
           
           let data = snapshot?.data()
           self.selectedTeams = data?["competingTeams"] as? [String] ?? []  // default to empty
           
           self.fetchAllTeams()
       }
   }
   
   // Fetch all teams from Firestore, use selectedTeams to check checkboxes
   func fetchAllTeams() {
       db.collection("teams").getDocuments { (snapshot, error) in
           if let error = error {
               print("Error fetching teams: \(error)")
               return
           }
           
           self.teams = snapshot?.documents.compactMap { doc in
               let data = doc.data()
               let teamName = data["name"] as? String ?? ""
               let teamID = doc.documentID
               let isSelected = self.selectedTeams.contains(teamID)
               return OptionItem(id: teamID, title: teamName, isSelected: isSelected)
           } ?? []
           
           DispatchQueue.main.async {
               self.tableView.reloadData()
           }
       }
   }
   
   // MARK: - Table View Methods
   
   func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
       return teams.count
   }
   
   func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
       guard let cell = tableView.dequeueReusableCell(withIdentifier: "CheckboxCell", for: indexPath) as? CheckboxTableViewCell else {
           return UITableViewCell()
       }
       
       let team = teams[indexPath.row]
       cell.titleLabel.text = team.title
       
       let imageName = team.isSelected ? "checkmark.square.fill" : "square"
       cell.checkboxButton.setImage(UIImage(systemName: imageName), for: .normal)
       
       cell.checkboxButton.tag = indexPath.row
       cell.checkboxButton.addTarget(self, action: #selector(checkboxTapped(_:)), for: .touchUpInside)
       
       return cell
   }
    
    @objc func checkboxTapped(_ sender: UIButton) {
        let index = sender.tag
        let teamID = teams[index].id
        
        teams[index].isSelected.toggle()
        
        if teams[index].isSelected {
            if !selectedTeams.contains(teamID) {
                selectedTeams.append(teamID)
                updateTeamDocument(teamID: teamID, add: true)
            }
        } else {
            selectedTeams.removeAll { $0 == teamID }
            updateTeamDocument(teamID: teamID, add: false)
        }
        
        tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
        saveSelectedTeamsToCompetition(compID: competitionID)
        
    }
    
    // MARK: - Firestore Update Methods
    
    func saveSelectedTeamsToCompetition(compID: String) {
        let compRef = db.collection("comps").document(compID)
        
        compRef.updateData([
            "competingTeams": selectedTeams
        ]) { error in
            if let error = error {
                print("Error updating competition with selected teams: \(error)")
            } else {
                print("Competition updated with selected teams!")
            }
        }
        
        
    }
    
    func updateTeamDocument(teamID: String, add: Bool) {
        let teamRef = db.collection("teams").document(teamID)
        
        if add {
            teamRef.updateData([
                "comps": FieldValue.arrayUnion([competitionID])
            ]) { error in
                if let error = error {
                    print("Error adding comp to team \(teamID): \(error)")
                } else {
                    print("Comp \(self.competitionID!) added to team \(teamID)'s comps array")
                }
            }
        } else {
            teamRef.updateData([
                "comps": FieldValue.arrayRemove([competitionID])
            ]) { error in
                if let error = error {
                    print("Error removing comp from team \(teamID): \(error)")
                } else {
                    print("Comp \(self.competitionID!) removed from team \(teamID)'s comps array")
                }
            }
        }
    }
}

    // MARK: - Custom Cell


class CheckboxTableViewCell: UITableViewCell {
    @IBOutlet weak var checkboxButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
}

struct OptionItem {
    let id: String  // Team ID
    let title: String
    var isSelected: Bool
}
