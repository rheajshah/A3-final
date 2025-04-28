    //  CompetitionsViewController.swift
//  A3_IOS
//
//  Created by Akhilesh Bitla on 3/12/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

struct PreviousComp {
    let id: String
    let name: String
    let date: Date
    let logoRef: String
}

struct UpcomingComp {
    let id: String
    let name: String
    let date: Date
    let city: String
    let state: String
    let imageURL: String
}

class CompetitionsViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UITableViewDelegate, UITableViewDataSource{
    
    @IBOutlet weak var addCompButton: UIButton!
    @IBOutlet var previousCompTableView: UITableView!
    @IBOutlet weak var profileButton: UIBarButtonItem!
    @IBOutlet weak var collectionView: UICollectionView!
    
    let db = Firestore.firestore()
    var upcomingComps: [UpcomingComp] = []
    var filteredUpcomingComps: [UpcomingComp] = []
    var previousComps: [PreviousComp] = []
    
    var isAdmin: Bool = false
    var id: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addCompButton.isEnabled = false
        addCompButton.isHidden = true
        addCompButton.isUserInteractionEnabled = false

        if let currentUser = Auth.auth().currentUser {
            let userId = currentUser.uid
            updateProfileButtonImage(userId: userId)
            print("Current User UID: \(userId)") // DEBUG
            id = userId
            db.collection("users").document(userId).getDocument { (document, error) in
                if let document = document, document.exists {
                    let adminField = document.data()?["admin"]
                    print("Fetched isAdmin from Firestore: \(String(describing: adminField))") // DEBUG
                    self.isAdmin = adminField as? Bool ?? false
                    print("Parsed isAdmin as Bool: \(self.isAdmin)") // DEBUG
                    DispatchQueue.main.async {
                        if self.isAdmin {
                            print("User is admin — showing addCompButton") // DEBUG
                            self.addCompButton.isEnabled = true
                            self.addCompButton.isHidden = false
                            self.addCompButton.isUserInteractionEnabled = true
                        } else {
                            print("User is NOT admin — addCompButton remains hidden") // DEBUG
                        }
                    }
                } else {
                    print("User doc not found or error: \(error?.localizedDescription ?? "Unknown error")") // DEBUG
                }
            }
        }

        
        collectionView.dataSource = self
        collectionView.delegate = self
        
        previousCompTableView.dataSource = self
        previousCompTableView.delegate = self
        
        populateComps()
        filteredUpcomingComps = upcomingComps
        previousCompTableView.reloadData()
        collectionView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        populateComps()  // Fetch teams again when the view appears (after adding a new team)
        if let userId = id {
            updateProfileButtonImage(userId: userId)
        }
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
        performSegue(withIdentifier: "ProfileVCSegue", sender: self)
    }

    
    func populateComps() {
        let dateFormatter = DateFormatter()
        
        dateFormatter.dateFormat = "MMMM dd yyyy"
        let todayDate = Calendar.current.startOfDay(for: Date())

        db.collection("comps").getDocuments() {
            snapshot, error in
            if let error = error {
                print("Error while fetching comps: \(error)")
            }
            
            
            // Return if error while retrieving documents
            guard let documents = snapshot?.documents else { return }
            
            var tempPrevComps: [PreviousComp] = []
            var tempUpcomingComps: [UpcomingComp] = []
            for document in documents {
                let data = document.data()
                guard
                    let name = data["name"] as? String,
                    let logoRef = data["logoURL"] as? String,
                    let dateString = data["date"] as? String,
                    let bannerRef = data["bannerURL"] as? String,
                    let date = dateFormatter.date(from: dateString),
                    let city = data["city"] as? String,
                    let state = data["state"] as? String
                else {
                    continue
                }
                
                print("Date String: \(dateString)")
                print("Date: \(date)")
                
                let compDate = Calendar.current.startOfDay(for: date)

                
                if compDate < todayDate {
                    let comp = PreviousComp (
                        id: document.documentID,
                        name: name,
                        date: date,
                        logoRef: logoRef
                    )
                    tempPrevComps.append(comp)
                } else {
                    let comp = UpcomingComp (		
                        id: document.documentID,
                        name: name,
                        date: date,
                        city: city,
                        state: state,
                        imageURL: bannerRef
                    )
                    tempUpcomingComps.append(comp)
                }
            }
            self.previousComps = tempPrevComps.sorted(by: { $0.date > $1.date})
            self.upcomingComps = tempUpcomingComps.sorted(by: { $0.date <= $1.date})
            self.filteredUpcomingComps = self.upcomingComps
            print(self.upcomingComps)
            DispatchQueue.main.async {
                self.previousCompTableView.reloadData()
                self.collectionView.reloadData()
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 75
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat{
        return 3 // whatever you want space between two cell
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let spacer = UIView()
        spacer.backgroundColor = .clear // Transparent gap
        return spacer
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return previousComps.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "PrevCompCell", for: indexPath) as? PrevCompCell else {
            return UITableViewCell()
        }
        
        let comp = previousComps[indexPath.section]
        
        cell.prevCompName.text = comp.name
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        cell.prevCompDate.text = dateFormatter.string(from: comp.date)
        cell.prevCompImageView.image = nil
        
        if let logoURL = URL(string: comp.logoRef) {
            loadImage(from: logoURL, into: cell.prevCompImageView)
        }
        
        cell.layer.cornerRadius = 5
        cell.clipsToBounds = true
        
        return cell
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
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedComp = previousComps[indexPath.section]
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let compInfoVC = storyboard.instantiateViewController(withIdentifier: "CompDescriptionViewController") as? CompDescriptionViewController {
            compInfoVC.competitionID = selectedComp.id  //pass the comp ID to CompDescriptionViewController
            compInfoVC.isAdmin = isAdmin //pass isAdmin to compInfoVC
            self.navigationController?.pushViewController(compInfoVC, animated: true)
        }
    }
    
    // Swipe action for deleting previous competitions
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard isAdmin else { return nil }
        
        let comp = previousComps[indexPath.section]

        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { (_, _, completionHandler) in
            self.deleteCompetition(compId: comp.id, indexPath: indexPath)
            completionHandler(true)
        }
        deleteAction.backgroundColor = .systemRed

        return UISwipeActionsConfiguration(actions: [deleteAction])
    }

    // Delete competition from Firestore and update tableView
    func deleteCompetition(compId: String, indexPath: IndexPath) {
        db.collection("comps").document(compId).delete { error in
            if let error = error {
                print("Error deleting competition: \(error)")
            } else {
                print("Competition deleted successfully.")
                self.previousComps.remove(at: indexPath.section)
                DispatchQueue.main.async {
                    self.previousCompTableView.deleteSections(IndexSet(integer: indexPath.section), with: .automatic)
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredUpcomingComps.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "UpcomingCompCell", for: indexPath) as! UpcomingCompCell
        let comp = filteredUpcomingComps[indexPath.item]
        cell.compName.text = comp.name
        let location = (comp.city.isEmpty && comp.state.isEmpty) ? "Location not available" : "\(comp.city), \(comp.state)"
        cell.location.text = location
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        cell.date.text = dateFormatter.string(from: comp.date)
        cell.imageView.image = nil
        
        if let logoURL = URL(string: comp.imageURL) {
            loadImage(from: logoURL, into: cell.imageView)
        }
        
        cell.layer.cornerRadius = 5
        cell.clipsToBounds = true
        
        //hide the edit button unless the user is an admin
        cell.editButton.isHidden = !isAdmin
        
        return cell
    }
    
    func isWithinDays(_ compDate: Date, days: Int) -> Bool {
        let today = Date()
        guard let futureDate = Calendar.current.date(byAdding: .day, value: days, to: today) else { return false }
        return compDate >= today && compDate <= futureDate
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 185, height: 170)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedComp = filteredUpcomingComps[indexPath.row]
 
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let compInfoVC = storyboard.instantiateViewController(withIdentifier: "CompDescriptionViewController") as? CompDescriptionViewController {
            compInfoVC.competitionID = selectedComp.id  //pass the comp ID to CompDescriptionViewController
            compInfoVC.isAdmin = isAdmin //pass isAdmin to compInfoVC
            self.navigationController?.pushViewController(compInfoVC, animated: true)
        }
    }
    
    
    @IBAction func filterChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            filteredUpcomingComps = upcomingComps
        case 1:
            filteredUpcomingComps = upcomingComps.filter{ isWithinDays($0.date, days: 7) }
        case 2:
            filteredUpcomingComps = upcomingComps.filter{ isWithinDays($0.date, days: 30) }
        default:
            filteredUpcomingComps = upcomingComps
        }
        collectionView.reloadData()
    }
    
    // Edit button tapped in UpcomingCompCell
    func editUpcomingComp(at indexPath: IndexPath) {
        let compToEdit = filteredUpcomingComps[indexPath.item]
        print("Edit button tapped for: \(compToEdit.name)")
        
        // Handle edit functionality here: show a new screen, update details, etc.
        let storyboard = UIStoryboard(name: "Main", bundle: nil) // Assuming it's in the Main storyboard
        if let editCompVC = storyboard.instantiateViewController(withIdentifier: "CreateCompViewController") as? CreateCompViewController {
            editCompVC.compID = compToEdit.id // Pass the compID of the comp you're editing
            navigationController?.pushViewController(editCompVC, animated: true)
        }
    }
    
    // Action for edit button in collection view cell
    @IBAction func editButtonTapped(_ sender: UIButton) {
        if let cell = sender.superview?.superview as? UpcomingCompCell, let indexPath = collectionView.indexPath(for: cell) {
            editUpcomingComp(at: indexPath)
        }
    }
}
