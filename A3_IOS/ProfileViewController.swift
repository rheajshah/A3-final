//
//  ProfileViewController.swift
//  A3_IOS
//
//  Created by Aryan Samal on 3/9/25.
//

import UIKit
import FirebaseAuth
import CoreData
import Foundation
import FirebaseFirestore
import FirebaseStorage

class ProfileViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var fullNameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var selectTeamButton: UIButton!
    @IBOutlet weak var adminYesNoLabel: UILabel!
    @IBOutlet weak var allowNotifsToggle: UISwitch!
    @IBOutlet weak var darkModeToggle: UISwitch!
    
    let db = Firestore.firestore()
    var userID: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        userID = Auth.auth().currentUser?.uid
        emailTextField.isUserInteractionEnabled = false // Email is not editable
        profileImageView.layer.borderWidth = 2
        profileImageView.layer.borderColor = UIColor.gray.cgColor
        profileImageView.clipsToBounds = true
        profileImageView.contentMode = .scaleAspectFill

        selectTeamButton.showsMenuAsPrimaryAction = true
        selectTeamButton.changesSelectionAsPrimaryAction = true
        
        loadUserProfile()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        profileImageView.layer.cornerRadius = profileImageView.frame.size.width / 2
    }

    //Load User Data from Firebase
    func loadUserProfile() {
        guard let userID = userID else { return }

        db.collection("users").document(userID).getDocument { (document, error) in
            if let document = document, document.exists {
                let data = document.data()
                self.fullNameTextField.text = data?["fullName"] as? String
                self.emailTextField.text = data?["email"] as? String
                self.adminYesNoLabel.text = (data?["admin"] as? Bool ?? false) ? "Admin" : "Not Admin"
                self.allowNotifsToggle.isOn = data?["notifications"] as? Bool ?? false
                self.darkModeToggle.isOn = data?["darkMode"] as? Bool ?? false
                
                let selectedTeam = data?["team"] as? String ?? "Select Team"
                self.selectTeamButton.setTitle(selectedTeam, for: .normal)
                self.setupTeamDropdown(selectedTeam: selectedTeam) // Pass it here!

                if let profileURL = data?["profileImage"] as? String {
                    self.loadProfileImage(from: profileURL)
                }
            }
        }
    }
    
    @IBAction func notificationsSwitchToggled(_ sender: UISwitch) {
        if sender.isOn {
           // Request permission from Apple
           UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
               DispatchQueue.main.async {
                   if granted {
                       print("Notification permission granted.")
                       self.fetchCompetitionsAndScheduleNotifications()
                       self.updateNotificationStatusInFirestore(enabled: true)
                   } else {
                       print("Notification permission denied.")
                       sender.setOn(false, animated: true) // Revert toggle if denied
                       self.updateNotificationStatusInFirestore(enabled: false)
                   }
               }
           }
       } else {
           print("Notifications turned off by user.")
           UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
           updateNotificationStatusInFirestore(enabled: false)
       }
    }
    
    // gathering data from database to create notifications
    func fetchCompetitionsAndScheduleNotifications() {
        let db = Firestore.firestore()
        db.collection("comps").getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching competitions: \(error)")
                return
            }

            guard let documents = snapshot?.documents else {
                print("No competitions found")
                return
            }

            for doc in documents {
                let data = doc.data()
                guard let name = data["name"] as? String,
                      let dateString = data["date"] as? String else {
                    continue
                }

                // Expecting date string in "yyyy-MM-dd" format
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM dd yyyy"
                formatter.timeZone = TimeZone(identifier: "America/Chicago") // adjust as needed

                if let competitionDate = formatter.date(from: dateString) {
                    var notificationDate = Calendar.current.date(byAdding: .day, value: -1, to: competitionDate)!

                    // Set time to 9 AM
                    notificationDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: notificationDate)!

                    if notificationDate > Date() {
                        self.scheduleCompetitionNotification(name: name, date: notificationDate)
                    }
                }
            }
        }
    }
    
    // actualy scheduring the competition
    func scheduleCompetitionNotification(name: String, date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Competition"
        content.subtitle = "\(name) is in 24 hours"
        content.sound = .default

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(identifier: "comp_\(name)_\(date)", content: content, trigger: trigger)
        
        if let url = Bundle.main.url(forResource: "A3", withExtension: "jpg") {
            let attachment = try? UNNotificationAttachment(identifier: "icon", url: url, options: nil)
            if let attachment = attachment {
                content.attachments = [attachment]
            }
        }

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notif for \(name): \(error)")
            } else {
                print("Notification scheduled for \(name) at \(date)")
            }
        }
    }

    
    func updateNotificationStatusInFirestore(enabled: Bool) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("User not logged in.")
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData(["notifications": enabled]) {error in
            if let error = error {
                print("Error updating notification status")
            } else {
                print("Notification status updated")
            }
        }
    }
    
    
    //Team Dropdown
    func setupTeamDropdown(selectedTeam: String?) {
        db.collection("teams").getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching teams: \(error)")
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            
            let teamActions = documents.map { doc -> UIAction in
                let teamName = doc.data()["name"] as? String ?? "Unnamed Team"
                return UIAction(title: teamName, state: (teamName == selectedTeam ? .on : .off), handler: { action in
                    self.selectTeamButton.setTitle(action.title, for: .normal)
                })
            }
            
            DispatchQueue.main.async {
                self.selectTeamButton.menu = UIMenu(title: "Select Team", children: teamActions)
            }
        }
    }

    //Edit Profile Photo
    @IBAction func editPhotoButtonPressed(_ sender: UIButton) {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        picker.allowsEditing = true
        present(picker, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let selectedImage = info[.editedImage] as? UIImage {
            profileImageView.image = selectedImage
            uploadProfileImage(selectedImage)
        }
        dismiss(animated: true)
    }

    //Upload Profile Image to Firebase Storage
    func uploadProfileImage(_ image: UIImage) {
        guard let userID = userID, let imageData = image.jpegData(compressionQuality: 0.5) else { return }
        let storageRef = Storage.storage().reference().child("users/profile_pictures/\(userID).jpg")
        
        storageRef.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                print("Failed to upload image: \(error)")
                return
            }
            storageRef.downloadURL { url, _ in
                if let profileURL = url?.absoluteString {
                    self.db.collection("users").document(userID).updateData(["profileImage": profileURL])
                }
            }
        }
    }

    //Load Profile Image from URL
    func loadProfileImage(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        DispatchQueue.global().async {
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.profileImageView.image = image
                }
            }
        }
    }

    //Save Changes to Firebase
    @IBAction func saveChangesButtonPressed(_ sender: Any) {
        guard let userID = userID else { return }
        
        let updatedData: [String: Any] = [
            "fullName": fullNameTextField.text ?? "",
            "team": selectTeamButton.title(for: .normal) ?? "Select Team",
            "allowNotifications": allowNotifsToggle.isOn,
            "darkMode": darkModeToggle.isOn
        ]
        
        db.collection("users").document(userID).updateData(updatedData) { error in
            if let error = error {
                print("Error updating profile: \(error)")
            } else {
                print("Profile updated successfully!")
            }
        }
    }
    
    @IBAction func logoutPressed(_ sender: Any) {
        do {
            try Auth.auth().signOut()
            navigateToLogin()
        } catch {
            print("Sign out error")
        }
    }
    
    private func navigateToLogin() {
        if let loginVC = storyboard?.instantiateViewController(identifier: "LoginVC") as? LoginViewController {
            loginVC.modalPresentationStyle = .fullScreen
            present(loginVC, animated: true, completion: nil)
        }
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
    
    
    @IBAction func darkModeToggled(_ sender: UISwitch) {
        let newStyle: UIUserInterfaceStyle = sender.isOn ? .dark : .light

        // Apply to all windows
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = newStyle
            }
        }
        UserDefaults.standard.set(sender.isOn, forKey: "darkModeEnabled")
        saveDarkModeToFirebase(isEnabled: sender.isOn)
    }

    
    private func saveDarkModeToFirebase(isEnabled: Bool) {
        guard let userID = userID else { return }
        
        db.collection("users").document(userID).updateData(["darkMode": isEnabled]) { error in
            if let error = error {
                print("Error updating dark mode setting: \(error.localizedDescription)")
            } else {
                print("Dark mode setting updated successfully in Firebase.")
            }
        }
    }

}
