//
//  TeamsViewController.swift
//  A3_IOS
//
//  Created by Eshitha B on 3/10/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

struct TeamSummary {
    let id: String
    let name: String
    let university: String
    let teamLogoURL: String
}

class TeamsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    @IBOutlet weak var profileButton: UIBarButtonItem!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var teamSearchBar: UISearchBar!
    @IBOutlet weak var addTeamButton: UIBarButtonItem! //only visible if user is admin
    
    let db = Firestore.firestore()
    var teams: [TeamSummary] = []
    var filteredTeams: [TeamSummary] = []
    var isSearching = false
    var isAdmin: Bool = false
    var id: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        addTeamButton.isEnabled = false
        addTeamButton.tintColor = .clear  // Makes it invisible

        if let currentUser = Auth.auth().currentUser {
            let userId = currentUser.uid
            id = userId
            updateProfileButtonImage(userId: userId)
            db.collection("users").document(userId).getDocument { (document, error) in
                if let document = document, document.exists {
                    self.isAdmin = document.data()?["admin"] as? Bool ?? false
                    DispatchQueue.main.async {
                        if self.isAdmin {
                            self.addTeamButton.isEnabled = true
                            self.addTeamButton.tintColor = nil // Resets to default color
                        }
                    }
                } else {
                    print("User document not found or error: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
        
        tableView.delegate = self
        tableView.dataSource = self
        teamSearchBar.delegate = self

        fetchTeamsFromFirestore()
    }
    
    func updateProfileButtonImage(userId: String) {
        let buttonSize: CGFloat = 36

        let imageButton = UIButton(type: .custom)
        imageButton.layer.cornerRadius = buttonSize / 2
        imageButton.clipsToBounds = true
        imageButton.contentMode = .scaleAspectFill
        imageButton.setImage(UIImage(systemName: "person.circle"), for: .normal)

        imageButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
          imageButton.widthAnchor.constraint(equalToConstant: buttonSize),
          imageButton.heightAnchor.constraint(equalToConstant: buttonSize)
        ])

        Firestore.firestore()
          .collection("users")
          .document(userId)
          .getDocument { snapshot, error in
            if let error = error {
              print("Error fetching user data: \(error)")
              return
            }
            guard
              let data = snapshot?.data(),
              let urlString = data["profileImage"] as? String,
              let url = URL(string: urlString)
            else {
              print("Invalid or missing image URL")
              return
            }

            URLSession.shared.dataTask(with: url) { data, _, error in
              guard let data = data, let image = UIImage(data: data) else {
                print("Failed to load image data:", error?.localizedDescription ?? "")
                return
              }
              DispatchQueue.main.async {
                imageButton.setImage(image, for: .normal)
              }
            }.resume()
          }

        imageButton.addTarget(self, action: #selector(profileButtonTapped), for: .touchUpInside)

        profileButton.customView = imageButton
    }

    @objc func profileButtonTapped() {
        performSegue(withIdentifier: "TeamsProfileVCSegue", sender: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchTeamsFromFirestore()  // Fetch teams again when the view appears (after adding a new team)
        updateProfileButtonImage(userId: id!)
    }
    
    func fetchTeamsFromFirestore() {
        db.collection("teams").getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching teams: \(error)")
                return
            }
            
            self.teams = snapshot?.documents.compactMap { doc in
                let data = doc.data()
                return TeamSummary(
                    id: doc.documentID,
                    name: data["name"] as? String ?? "",
                    university: data["university"] as? String ?? "",
                    teamLogoURL: data["teamLogoURL"] as? String ?? ""
                )
            } ?? []
            
            //sort teams alphabetically by team name
            self.teams.sort { $0.name.lowercased() < $1.name.lowercased() }
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    //TableView Methods
    // Set the height of the cells (make them bigger)
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 85
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? filteredTeams.count : teams.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let team = isSearching ? filteredTeams[indexPath.row] : teams[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "CustomTeamSummaryCell", for: indexPath) as! CustomTeamSummaryCell
        cell.configure(with: team)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedTeam = isSearching ? filteredTeams[indexPath.row] : teams[indexPath.row]
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let teamInfoVC = storyboard.instantiateViewController(withIdentifier: "teamInfoViewController") as? TeamInfoViewController {
            teamInfoVC.teamId = selectedTeam.id
            self.navigationController?.pushViewController(teamInfoVC, animated: true)
        }
    }
    
    // Swipe actions for Delete and Edit for teams (only enabled if user is admin)
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard isAdmin else { return nil }

        let team = teams[indexPath.row]

        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { (_, _, completionHandler) in
            self.deleteTeam(teamId: team.id, indexPath: indexPath)
            completionHandler(true)
        }

        let editAction = UIContextualAction(style: .normal, title: "Edit") { (_, _, completionHandler) in
            self.editTeam(team: team)
            completionHandler(true)
        }

        return UISwipeActionsConfiguration(actions: [deleteAction, editAction])
    }

    // delete team from databasse
    func deleteTeam(teamId: String, indexPath: IndexPath) {
        db.collection("teams").document(teamId).delete { error in
            if let error = error {
                print("Error deleting team: \(error)")
            } else {
                print("Team deleted successfully.")
                self.teams.remove(at: indexPath.row)
                DispatchQueue.main.async {
                    self.tableView.deleteRows(at: [indexPath], with: .automatic)
                }
            }
        }
    }
    
    // edit team takes you to a new View Controller
    func editTeam(team: TeamSummary) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let createTeamVC = storyboard.instantiateViewController(withIdentifier: "CreateTeamViewController") as? CreateTeamViewController {
            createTeamVC.teamId = team.id  // Pass the team ID to CreateTeamVC
            self.navigationController?.pushViewController(createTeamVC, animated: true)
        }
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let lowercasedSearchText = searchText.lowercased()

        if searchText.isEmpty {
            isSearching = false
            filteredTeams = []
        } else {
            isSearching = true
            filteredTeams = teams.filter { team in
                return team.name.lowercased().contains(lowercasedSearchText) ||
                       team.university.lowercased().contains(lowercasedSearchText)
            }
        }

        tableView.reloadData()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        isSearching = false
        searchBar.text = ""
        searchBar.resignFirstResponder()
        tableView.reloadData()
    }
    
    // Code to dismiss the keyboard:
    // Called when 'return' key pressed
    // (does not dismiss due to using a search bar)
    // TODO: for final phase
    private func searchBarSearchButtonClicked(_ searchBar: UISearchBar) -> Bool {
            searchBar.resignFirstResponder()
            return true
        }
    
    // Called when the user clicks on the view outside of the UITextField
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            self.view.endEditing(true)
        }
}
