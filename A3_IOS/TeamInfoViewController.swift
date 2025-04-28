//
//  TeamInfoViewController.swift
//  A3_IOS
//
//  Created by Akhilesh Bitla on 3/12/25.
//

import UIKit
import FirebaseFirestore
import FirebaseStorage

class TeamInfoViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var teamPicture: UIImageView!
    @IBOutlet weak var teamName: UILabel!
    @IBOutlet weak var university: UILabel!
    @IBOutlet weak var location: UILabel!
    @IBOutlet weak var instaIcon: UIImageView!
    @IBOutlet weak var eloRank: UILabel!
    @IBOutlet weak var eloScore: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var compPlacingsTableView: UITableView!
    
    
    //a variable to hold the team ID passed from TeamsViewController
    var teamId: String?
    var comps: [CompCollectionViewCell] = []
    var instagramHandle: String?
    var competitionDetails: [(name: String, placing: String, logoURL: String)] = []
    var compsVisitedIds: [String] = []
    
    private let db = Firestore.firestore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.dataSource = self
        collectionView.delegate = self
        
        compPlacingsTableView.dataSource = self
        compPlacingsTableView.delegate = self
                
        // Check if the teamId is available, then fetch the team details
//        if let teamId = teamId {
//            fetchTeamDetails(teamId: teamId)
//        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(openInstagram))
        instaIcon.isUserInteractionEnabled = true
        instaIcon.addGestureRecognizer(tapGesture)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        competitionDetails.removeAll()

        if let teamId = teamId {
            fetchTeamDetails(teamId: teamId)
        }
    }
    
    private func fetchCompetitionDetails(for compIds: [String]) {
        let group = DispatchGroup()
        competitionDetails.removeAll()
        print(compIds)
        for compId in compIds {
            group.enter()
            Firestore.firestore().collection("comps").document(compId)
              .getDocument { snapshot, _ in
                defer { group.leave() }
                guard let d = snapshot?.data() else { return }

                let name     = d["name"]    as? String ?? "Unknown Competition"
                let placings = d["placings"] as? [String]  ?? []
                let idx      = self.teamId.flatMap { placings.firstIndex(of: $0) }
                let placeStr = idx.map { String($0 + 1) } ?? "–"
                let logoURL  = d["logoURL"] as? String    ?? ""

                self.competitionDetails.append(
                  (name: name, placing: placeStr, logoURL: logoURL)
                )
            }
        }
        group.notify(queue: .main) {
            self.compPlacingsTableView.reloadData()
        }
    }
    
    func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        return competitionDetails.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CompTableCell", for: indexPath)
        let detail = competitionDetails[indexPath.row]
        
        // Texts
        cell.textLabel?.text       = detail.name
        cell.detailTextLabel?.text = detail.placing
        
        // Reset image view to prevent any resizing when reused
        cell.imageView?.image = UIImage(systemName: "photo") // placeholder
        
        if let url = URL(string: detail.logoURL) {
            loadImage(from: url, into: cell.imageView)
        }
        
        // Ensure the image view stays circular
        if let iv = cell.imageView {
            iv.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                iv.widthAnchor.constraint(equalToConstant: 40),
                iv.heightAnchor.constraint(equalToConstant: 40)
            ])
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            iv.layer.cornerRadius = 20 // half of 40
        }
        
        // Disable selection highlight, so it doesn't affect the size
        cell.selectionStyle = .none
        cell.isUserInteractionEnabled = false
        return cell
    }

    // Optional: Handle cell selection explicitly (this will avoid resizing)
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Deselect row without animation to avoid resizing
        tableView.deselectRow(at: indexPath, animated: false)
        // Optionally, handle the selection logic (e.g., push a new view controller, etc.)
    }







    func fetchTeamDetails(teamId: String) {
        db.collection("teams").document(teamId).getDocument { (document, error) in
            if let error = error {
                print("Error fetching team details: \(error)")
                return
            }
            
            if let document = document, document.exists {
                let data = document.data()
                
                //extract the additional information from Firestore
                let name = data?["name"] as? String ?? "Unknown"
                let university = data?["university"] as? String ?? "Unknown"
                //construct location from city and state fields
                let city = data?["city"] as? String ?? ""
                let state = data?["state"] as? String ?? ""
                let location = (city.isEmpty || state.isEmpty) ? "Location not available" : "\(city), \(state)"
                
                self.instagramHandle = data?["instagram"] as? String
                
                let teamPictureURL = data?["teamPictureURL"] as? String ?? ""
                let eloRank = data?["eloRank"] as? Int ?? -1
                let eloScore = data?["eloScore"] as? Double ?? 0.0
                let compIds = data?["comps"] as? [String] ?? []
                
                // Update the UI with the fetched data
                DispatchQueue.main.async {
                    self.teamName.text = name
                    self.university.text = university
                    self.location.text = location
                    self.eloRank.text = "# \(eloRank)"
                    self.eloScore.text = String(format: "%.2f", eloScore)  //format eloScore as a string with two decimal places
                    
                    
                    // Set the team picture (if available)
                    if let pictureURL = URL(string: teamPictureURL) {
                        self.loadImage(from: pictureURL, into: self.teamPicture)
                    }
                    
                    // Fetch competitions
                    self.fetchCompetitions(for: compIds)
                    self.fetchCompetitionDetails(for: compIds)
                }
            }
        }
    }
    
    @objc func openInstagram() {
        guard let handle = instagramHandle, !handle.isEmpty else {
            print("No Instagram handle available")
            return
        }
        
        let urlString = "https://instagram.com/\(handle)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    func fetchCompetitions(for compIds: [String]) {
        guard !compIds.isEmpty else {
            self.comps = []
            self.collectionView.reloadData()
            return
        }

        let group = DispatchGroup()
        var tempComps: [CompCollectionViewCell] = []

        for compId in compIds {
            group.enter()
            db.collection("comps").document(compId).getDocument { (doc, err) in
                if let err = err {
                    print("Error fetching comp \(compId): \(err)")
                    group.leave()
                    return
                }

                if let compData = doc?.data() {
                    let id = compData["id"] as? String ?? compId
                    let name = compData["name"] as? String ?? "N/A"
                    let date = compData["date"] as? String ?? ""
                    let logoURL = compData["logoURL"] as? String ?? ""

                    let newComp = CompCollectionViewCell(id: id, dateOrRank: date, name: name, imageURL: logoURL)
                    tempComps.append(newComp)
                }

                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.comps = tempComps.sorted { $0.dateOrRank < $1.dateOrRank }
            self.collectionView.reloadData()
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

    // MARK: - UICollectionView

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return comps.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CompCell", for: indexPath) as! CompCell
        let comp = comps[indexPath.item]

        cell.compDate.text = comp.dateOrRank
        cell.compName.text = comp.name

        if let url = URL(string: comp.imageURL) {
            loadImage(from: url, into: cell.compImage)
        } else {
            cell.compImage.image = nil
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 100, height: 160)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Get the selected competition
        let selectedComp = comps[indexPath.item]
        
        // Perform the segue to the competition description view
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let compInfoVC = storyboard.instantiateViewController(withIdentifier: "CompDescriptionViewController") as? CompDescriptionViewController {
            compInfoVC.competitionID = selectedComp.id  //pass the comp ID to CompDescriptionViewController
            self.navigationController?.pushViewController(compInfoVC, animated: true)
        }
    }
}

class CompCell: UICollectionViewCell {
    @IBOutlet weak var compImage: UIImageView!
    @IBOutlet weak var compName: UILabel!
    @IBOutlet weak var compDate: UILabel!
}

struct CompCollectionViewCell {
    let id: String
    let dateOrRank: String     // date (or rank if comp happened alr)
    let name: String      // comp name
    let imageURL: String  // bannerURL
}
