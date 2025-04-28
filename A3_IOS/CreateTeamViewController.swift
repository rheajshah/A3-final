//
//  CreateTeamViewController.swift
//  A3_IOS
//
//  Created by Akhilesh Bitla on 4/6/25.
//

import UIKit
import FirebaseFirestore
import FirebaseStorage

extension UIImageView {
    func loadImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.image = image
                }
            }
        }.resume()
    }
}

class CreateTeamViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var teamPictureImageView: UIImageView!
    @IBOutlet weak var teamLogoImageView: UIImageView!
    @IBOutlet weak var teamNameTextField: UITextField!
    @IBOutlet weak var teamUniversityTextField: UITextField!
    @IBOutlet weak var cityTextField: UITextField!
    @IBOutlet weak var statePickerView: UIPickerView!
    @IBOutlet weak var instagramTextField: UITextField!
    
    let db = Firestore.firestore()
    let storage = Storage.storage()

    var imagePicker = UIImagePickerController()
    
    var teamId: String?
    
    let states = [
        "Alabama", "Alaska", "American Samoa", "Arizona", "Arkansas", "California", "Colorado",
        "Connecticut", "Delaware", "District of Columbia", "Florida", "Georgia", "Guam", "Hawaii",
        "Idaho", "Illinois", "Indiana", "Iowa", "Kansas", "Kentucky", "Louisiana", "Maine",
        "Maryland", "Massachusetts", "Michigan", "Minnesota", "Minor Outlying Islands",
        "Mississippi", "Missouri", "Montana", "Nebraska", "Nevada", "New Hampshire", "New Jersey",
        "New Mexico", "New York", "North Carolina", "North Dakota", "Northern Mariana Islands",
        "Ohio", "Oklahoma", "Oregon", "Pennsylvania", "Puerto Rico", "Rhode Island",
        "South Carolina", "South Dakota", "Tennessee", "Texas", "U.S. Virgin Islands", "Utah",
        "Vermont", "Virginia", "Washington", "West Virginia", "Wisconsin", "Wyoming"
    ]

    var selectedState: String?
    var isSelectingTeamPicture = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        statePickerView.delegate = self
        statePickerView.dataSource = self
        imagePicker.delegate = self
        
        //set default to Alabama
        let defaultIndex = states.firstIndex(of: "Alabama") ?? 0
        statePickerView.selectRow(defaultIndex, inComponent: 0, animated: false)
        selectedState = states[defaultIndex]
        
        // If we're editing a team, fetch and prepopulate data
        if let teamId = teamId {
            fetchTeamData(teamId: teamId)
        }
        
        //image view styles
        [teamPictureImageView, teamLogoImageView].forEach { imageView in
            imageView?.layer.borderWidth = 2
            imageView?.layer.borderColor = UIColor.gray.cgColor
            imageView?.clipsToBounds = true
            imageView?.contentMode = .scaleAspectFill
        }
    }
    
    func fetchTeamData(teamId: String) {
        db.collection("teams").document(teamId).getDocument { document, error in
            if let error = error {
                print("Error fetching team data: \(error)")
                return
            }
            
            if let document = document, document.exists {
                let data = document.data()
                self.teamNameTextField.text = data?["name"] as? String
                self.teamUniversityTextField.text = data?["university"] as? String
                self.cityTextField.text = data?["city"] as? String
                self.instagramTextField.text = data?["instagram"] as? String
                
                if let state = data?["state"] as? String {
                    self.selectedState = state
                    if let stateIndex = self.states.firstIndex(of: state) {
                        self.statePickerView.selectRow(stateIndex, inComponent: 0, animated: false)
                    }
                }
                
                // Load images if URLs are available
                if let teamLogoURL = data?["teamLogoURL"] as? String, let url = URL(string: teamLogoURL) {
                    self.teamLogoImageView.loadImage(from: url)
                }
                
                if let teamPictureURL = data?["teamPictureURL"] as? String, let url = URL(string: teamPictureURL) {
                    self.teamPictureImageView.loadImage(from: url)
                }
            }
        }
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return states.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return states[row]
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedState = states[row]
    }

    @IBAction func onSelectTeamPictureTapped(_ sender: Any) {
        isSelectingTeamPicture = true
        imagePicker.sourceType = .photoLibrary
        imagePicker.allowsEditing = true
        present(imagePicker, animated: true)
    }
    
    @IBAction func onSelectTeamLogoTapped(_ sender: Any) {
        isSelectingTeamPicture = false
        imagePicker.sourceType = .photoLibrary
        imagePicker.allowsEditing = true
        present(imagePicker, animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let selectedImage = info[.editedImage] as? UIImage {
            if isSelectingTeamPicture {
                teamPictureImageView.image = selectedImage
            } else {
                teamLogoImageView.image = selectedImage
            }
        }
        dismiss(animated: true)
    }

    
    @IBAction func onSaveTeamButtonPressed(_ sender: Any) {
        guard let name = teamNameTextField.text, !name.isEmpty,
              let city = cityTextField.text, !city.isEmpty,
              let state = selectedState else {
            showAlert(title: "Missing Info", message: "Please fill in all required fields.")
            return
        }
        
        let teamID = teamId ?? UUID().uuidString // If teamId exists, use it, else generate a new one
                
        let university = teamUniversityTextField.text ?? ""
        let instagram = instagramTextField.text ?? ""
        let compsAttending: [String] = []
        
        uploadImage(teamPictureImageView.image, path: "teams/team_pictures/\(teamID).jpg") { teamPictureURL in
            self.uploadImage(self.teamLogoImageView.image, path: "teams/team_logos/\(teamID).jpg") { teamLogoURL in
                
                let teamData: [String: Any] = [
                    "id": teamID, //primary key
                    "name": name,
                    "university": university,
                    "city": city,
                    "state": state,
                    "instagram": instagram,
                    "teamPictureURL": teamPictureURL ?? "",
                    "teamLogoURL": teamLogoURL ?? "",
                    "comps": compsAttending,
                    "eloScore": 0.0,
                    "eloRank": 1
                ]
                
                self.db.collection("teams").document(teamID).setData(teamData) { error in
                    if let error = error {
                        print("Error saving team: \(error)")
                        self.showAlert(title: "Error", message: "Failed to save team.")
                    } else {
                        self.showAlert(title: "Success", message: "Team created successfully!")
                    }
                }
            }
        }
    }
    
    func uploadImage(_ image: UIImage?, path: String, completion: @escaping (String?) -> Void) {
        guard let image = image, let imageData = image.jpegData(compressionQuality: 0.5) else {
            completion(nil)
            return
        }
        
        let ref = storage.reference().child(path)
        ref.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                print("Upload error: \(error)")
                completion(nil)
                return
            }
            ref.downloadURL { url, _ in
                completion(url?.absoluteString)
            }
        }
    }

    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // Code to dismiss the keyboard:
    // Called when 'return' key pressed
    func textFieldShouldReturn(_ textField:UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // Called when the user clicks on the view outside of the UITextField
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
}
