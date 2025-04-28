//
//  CreateCompViewController.swift
//  A3_IOS
//
//  Created by Eshitha B on 4/4/25.
//

import UIKit
import FirebaseStorage
import FirebaseFirestore

extension UIImageView {
    func load(url: URL) {
        DispatchQueue.global().async {
            if let data = try? Data(contentsOf: url) {
                DispatchQueue.main.async {
                    self.image = UIImage(data: data)
                }
            }
        }
    }
}

class CreateCompViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate,
                                UIPickerViewDelegate, UIPickerViewDataSource{

    @IBOutlet weak var dateField: UITextField!
    @IBOutlet weak var compImage: UIImageView!
    @IBOutlet weak var compLogo: UIImageView!
    @IBOutlet weak var statePickerView: UIPickerView!
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var cityField: UITextField!
    @IBOutlet weak var instagramField: UITextField!
    @IBOutlet weak var phoneNumField: UITextField!
    @IBOutlet weak var deleteCompButton: UIButton! //only show up if comp alr exists
    
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
    
    
    var compID: String? // Store the competition ID for editing
    var selectedState: String?
    var isSelectingBanner = false
    var imagePicker = UIImagePickerController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setting starting values for the date picker
        let datePicker = UIDatePicker ()
        datePicker.datePickerMode = .date
        datePicker.addTarget(self, action: #selector (dateChange (datePicker:)), for:
        UIControl.Event.valueChanged)
        datePicker.frame.size = CGSize(width: 0, height: 300)
        datePicker.preferredDatePickerStyle = .wheels
        dateField.inputView = datePicker
        dateField.text = formatDate(date: Date())
        
        // setting initial values for the comp image (banner)
        compImage.layer.borderWidth = 2
        compImage.layer.borderColor = UIColor.gray.cgColor
        compImage.clipsToBounds = true
        compImage.contentMode = .scaleAspectFill
        
        // setting initial values for the comp logo
        compLogo.layer.borderWidth = 2
        compLogo.layer.borderColor = UIColor.gray.cgColor
        compLogo.clipsToBounds = true
        compLogo.contentMode = .scaleAspectFill
        
        // State Picker View
        statePickerView.delegate = self
        statePickerView.dataSource = self
        //set default to Alabama
        let defaultIndex = states.firstIndex(of: "Alabama") ?? 0
        statePickerView.selectRow(defaultIndex, inComponent: 0, animated: false)
        selectedState = states[defaultIndex]
        
        // Check if we're editing an existing comp
        if let compID = compID {
            loadCompData(compID: compID) // Load existing comp data for editing
            deleteCompButton.isHidden = false // Show delete button
        } else {
            deleteCompButton.isHidden = true // Hide delete button for new comp
        }
    }
    
    func loadCompData(compID: String) {
        let compRef = Firestore.firestore().collection("comps").document(compID)
        compRef.getDocument { document, error in
            if let document = document, document.exists {
                let data = document.data()
                self.nameField.text = data?["name"] as? String
                self.cityField.text = data?["city"] as? String
                self.selectedState = data?["state"] as? String
                self.dateField.text = data?["date"] as? String
                self.instagramField.text = data?["instagram"] as? String
                self.phoneNumField.text = data?["compDirectorPhoneNumber"] as? String
            
                // Load images and other data
                if let bannerURL = data?["bannerURL"] as? String, let url = URL(string: bannerURL) {
                    self.compImage.load(url: url) // Add extension to load image from URL
                }
                
                if let logoURL = data?["logoURL"] as? String, let url = URL(string: logoURL) {
                    self.compLogo.load(url: url) // Add extension to load image from URL
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
   
    @objc func dateChange(datePicker: UIDatePicker) {
        dateField.text = formatDate(date: datePicker.date)
    }
    
    func formatDate (date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd yyyy"
        return formatter.string (from: date)
    }
    
    @IBAction func chooseCompImage(_ sender: Any) {
        isSelectingBanner = true
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        picker.allowsEditing = true
        present(picker, animated: true)
    }
    
    @IBAction func chooseCompLogo(_ sender: Any) {
        isSelectingBanner = false
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        picker.allowsEditing = true
        present(picker, animated: true)
    }
    
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let selectedImage = info[.editedImage] as? UIImage {
            if isSelectingBanner {
                compImage.image = selectedImage
            } else {
                compLogo.image = selectedImage
            }
            // uploadProfileImage(selectedImage)
            // do stuff above to add to firebase
        }
        dismiss(animated: true)
    }
    
    
    @IBAction func onSaveCompPressed(_ sender: Any) {
        guard let name = nameField.text, !name.isEmpty,
              let city = cityField.text, !city.isEmpty,
              let state = selectedState, !state.isEmpty,
              let date = dateField.text else {
            showAlert(title: "Missing Info", message: "Please fill in all required fields.")
            return
        }
        
        let instagram = instagramField.text ?? ""
        let phoneNumber = phoneNumField.text ?? ""

       
        let compID = self.compID ?? UUID().uuidString // If editing, use the existing ID

        //default values will be added via edit function NOT at time of creation
        let competingTeams: [String] = []
        let compJudges: [String] = []
        let placings: [String] = []
        let scoreSheetRef: String = ""
        let feedbackSheetRef = ""
        let videosLink = ""
        let photosLink = ""

        
        uploadImage(compImage.image, path: "comps/comp_banners/\(compID).jpg") { bannerURL in
            self.uploadImage(self.compLogo.image, path: "comps/comp_logos/\(compID).jpg") { logoURL in
                
                let compData: [String: Any] = [
                    "id": compID,
                    "name": name,
                    "city": city,
                    "state": state,
                    "date": date,
                    "instagram": instagram,
                    "compDirectorPhoneNumber": phoneNumber,
                    "bannerURL": bannerURL ?? "",
                    "logoURL": logoURL ?? "",
                    "teams": competingTeams, //this is filled in lineup subscreen
                    "placings": placings,
                    "judges": compJudges,
                    "scoreSheetRef": scoreSheetRef,
                    "feedbackSheetRef": feedbackSheetRef,
                    "videosLink": videosLink,
                    "photosLink": photosLink,
                    "mediaLink": "comps/media/\(compID)"
                ]
                
                let compRef = Firestore.firestore().collection("comps").document(compID)

                compRef.getDocument { (document, error) in
                    if let error = error {
                        print("Error checking comp existence: \(error)")
                        self.showAlert(title: "Error", message: "Could not check if competition exists.")
                        return
                    }

                    let isUpdate = document?.exists == true

                    compRef.setData(compData) { error in
                        if let error = error {
                            print("Error saving comp: \(error)")
                            self.showAlert(title: "Error", message: "Failed to save competition.")
                        } else {
                            let title = isUpdate ? "Updated" : "Created"
                            let message = isUpdate ? "Competition updated successfully!" : "Competition created successfully!"
                            self.showAlert(title: title, message: message)
                        }
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

        let ref = Storage.storage().reference().child(path)
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
    
    @IBAction func deleteCompPressed(_ sender: Any) {
        guard let compID = compID else {
            showAlert(title: "Error", message: "Competition ID is missing.")
            return
        }

        // Confirm the delete action with the user
        let alert = UIAlertController(title: "Delete Competition", message: "Are you sure you want to delete this competition?", preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
            // Delete the competition data from Firestore
            let compRef = Firestore.firestore().collection("comps").document(compID)

            // Delete associated images from Firebase Storage
            let bannerRef = Storage.storage().reference().child("comps/comp_banners/\(compID).jpg")
            let logoRef = Storage.storage().reference().child("comps/comp_logos/\(compID).jpg")

            // Delete Firestore document and associated images
            compRef.delete { error in
                if let error = error {
                    self.showAlert(title: "Error", message: "Failed to delete competition data: \(error.localizedDescription)")
                } else {
                    // Delete images from Firebase Storage
                    bannerRef.delete { error in
                        if let error = error {
                            print("Error deleting banner image: \(error)")
                        }
                    }
                    logoRef.delete { error in
                        if let error = error {
                            print("Error deleting logo image: \(error)")
                        }
                    }

                    self.showAlert(title: "Success", message: "Competition deleted successfully!")
                    self.navigationController?.popViewController(animated: true)
                }
            }
        }))

        present(alert, animated: true, completion: nil)
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
