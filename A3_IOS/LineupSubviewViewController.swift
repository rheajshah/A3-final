//
//  LineupSubviewViewController.swift
//  A3_IOS
//
//  Created by Rhea Shah on 4/4/25.
//

import UIKit
import FirebaseFirestore

class LineupSubviewViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var selectCompetingTeamsButton: UIButton!
    @IBOutlet weak var lineupTitleLabel: UILabel!
    
    var isAdmin: Bool!
    var competitionID: String!
    var attendingTeams: [LineupTeam] = []
    var placingsExist: Bool = false
    var placings: [String] = []
    let db = Firestore.firestore()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        // Show button only if user is admin
        selectCompetingTeamsButton.isHidden = !(isAdmin ?? false)
        
        // Fetch the list of teams attending the competition or placings
        fetchCompetitionInfo()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchCompetitionInfo()  // Fetch teams again when the view appears (after adding a new team)
    }

    func fetchCompetitionInfo() {
        let compRef = db.collection("comps").document(competitionID)
        
        compRef.getDocument { snapshot, error in
            if let error = error {
                print("Error fetching competition data: \(error)")
                return
            }

            guard let data = snapshot?.data() else { return }

            let competingTeamIDs = data["competingTeams"] as? [String] ?? []
            let placingsTeamIDs = data["placings"] as? [String] ?? []

            if !competingTeamIDs.isEmpty {
                if !placingsTeamIDs.isEmpty && competingTeamIDs.count == placingsTeamIDs.count {
                    // Placings exist and complete
                    self.placingsExist = true
                    self.fetchTeamDetailsInOrder(teamIDs: placingsTeamIDs)
                } else {
                    // No full placings yet
                    self.placingsExist = false
                    self.fetchTeamDetails(teamIDs: competingTeamIDs)
                }

                DispatchQueue.main.async {
                    self.lineupTitleLabel.text = self.placingsExist ? "Placings" : "Lineup"
                }
            }
        }
    }

    
//    // Fetch the teams attending the competition based on the competitionID
//    func fetchAttendingTeams() {
//        let compRef = db.collection("comps").document(competitionID)
//        
//        compRef.getDocument { snapshot, error in
//            if let error = error {
//                print("Error fetching competition data: \(error)")
//                return
//            }
//
//            if let data = snapshot?.data(), let teamIDs = data["competingTeams"] as? [String] {
//                // Now fetch the details of each team using their teamIDs
//                self.fetchTeamDetails(teamIDs: teamIDs)
//            }
//        }
//    }

    // Normal fetch
    func fetchTeamDetails(teamIDs: [String]) {
        db.collection("teams").whereField(FieldPath.documentID(), in: teamIDs).getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching team details: \(error)")
                return
            }

            self.attendingTeams = snapshot?.documents.compactMap { doc in
                let data = doc.data()
                let teamName = data["name"] as? String ?? "Unknown"
                let logoURL = data["teamLogoURL"] as? String ?? ""
                let eloScore = data["eloScore"] as? Double ?? 0
                return LineupTeam(id: doc.documentID, name: teamName, logoURL: logoURL, elo: eloScore)
            } ?? []

            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }

    // Fetch with specific order (for placings)
    func fetchTeamDetailsInOrder(teamIDs: [String]) {
        db.collection("teams").whereField(FieldPath.documentID(), in: teamIDs).getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching team details: \(error)")
                return
            }

            guard let docs = snapshot?.documents else { return }
            var teamsDict: [String: LineupTeam] = [:]

            let dispatchGroup = DispatchGroup() // Used to handle async calls

            for doc in docs {
                let data = doc.data()
                let teamName = data["name"] as? String ?? "Unknown"
                let logoURL = data["teamLogoURL"] as? String ?? ""
                
                // Start the async fetch for each team's average score
                dispatchGroup.enter()
                
                // Fetch the average score from the competition's scores collection
                let compRef = self.db.collection("comps").document(self.competitionID).collection("scores").document(doc.documentID)
                compRef.getDocument { document, error in
                    if let error = error {
                        print("Error fetching score data for team \(doc.documentID): \(error)")
                        dispatchGroup.leave() // Leave the group if error
                        return
                    }
                    
                    guard let scoreData = document?.data() else {
                        dispatchGroup.leave() // Leave the group if no data
                        return
                    }

                    // Extract the average score from the scores document
                    let averageScore = scoreData["averageScore"] as? Double ?? 0.0
                    
                    // Create the LineupTeam object with the fetched average score
                    let team = LineupTeam(id: doc.documentID, name: teamName, logoURL: logoURL, elo: averageScore)
                    teamsDict[doc.documentID] = team
                    
                    dispatchGroup.leave() // Leave the group after processing the team
                }
            }

            // Once all async fetches are completed, update the attendingTeams
            dispatchGroup.notify(queue: .main) {
                self.attendingTeams = teamIDs.compactMap { teamsDict[$0] }
                self.tableView.reloadData()
            }
        }
    }


    // Table View Data Source Methods
    // Set the height of the cells (make them bigger)
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return attendingTeams.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "LineupTeamCell", for: indexPath) as? LineupTeamCell else {
            return UITableViewCell()
        }

        let team = attendingTeams[indexPath.row]
        let position = indexPath.row + 1 // 1-based ranking

        cell.configure(with: team, position: position, isPlacingsMode: placingsExist)
       
        return cell
    }
    
    // Handle tap on a team from the list in LineupSubviewViewController
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedTeam = attendingTeams[indexPath.row]
        
        // Perform the segue to the team details view
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let teamInfoVC = storyboard.instantiateViewController(withIdentifier: "teamInfoViewController") as? TeamInfoViewController {
            teamInfoVC.teamId = selectedTeam.id  //pass the team ID to TeamInfoViewController
            self.navigationController?.pushViewController(teamInfoVC, animated: true)
        }
    }

    // Prepare for segue to SelectTeamsViewController
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showSelectTeamsView" {
            // Get the destination view controller (SelectTeamsViewController)
            if let selectTeamsVC = segue.destination as? SelectTeamsViewController {
                // Pass the competitionID to the SelectTeamsViewController
                selectTeamsVC.competitionID = self.competitionID
            }
        }
    }		
}

class LineupTeam {
    var id: String
    var name: String
    var logoURL: String
    var elo: Double

    init(id: String, name: String, logoURL: String, elo: Double) {
        self.id = id
        self.name = name
        self.logoURL = logoURL
        self.elo = elo
    }
}

