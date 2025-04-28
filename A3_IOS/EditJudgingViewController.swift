//
//  EditJudgingViewController.swift
//  A3_IOS
//
//  Created by Rhea Shah on 4/7/25.
//

import UIKit
import FirebaseFirestore

class EditJudgingViewController: UIViewController {
    
    @IBOutlet weak var judge1TextField: UITextField!
    @IBOutlet weak var judge2TextField: UITextField!
    @IBOutlet weak var judge3TextField: UITextField!
    @IBOutlet weak var judge4TextField: UITextField!
    @IBOutlet weak var feedbackLink: UITextField!
    @IBOutlet weak var scoresheetLink: UITextField!
    
    var competitionID: String!
        
    override func viewDidLoad() {
        super.viewDidLoad()
        loadJudgingInfo()
    }
    
    private func loadJudgingInfo() {
        let db = Firestore.firestore()
        db.collection("comps").document(competitionID).getDocument { snapshot, error in
            if let error = error {
                print("Error loading judging info: \(error)")
                return
            }
            
            guard let data = snapshot?.data() else {
                print("No data found for comp ID: \(self.competitionID ?? "nil")")
                return
            }

            let judges = data["judges"] as? [String] ?? []
            self.judge1TextField.text = judges.count > 0 ? judges[0] : ""
            self.judge2TextField.text = judges.count > 1 ? judges[1] : ""
            self.judge3TextField.text = judges.count > 2 ? judges[2] : ""
            self.judge4TextField.text = judges.count > 3 ? judges[3] : ""

            self.feedbackLink.text = data["feedbackSheetRef"] as? String ?? ""
            self.scoresheetLink.text = data["scoreSheetRef"] as? String ?? ""
        }
    }

    @IBAction func onSavePressed(_ sender: Any) {
        let judges = [
            judge1TextField.text ?? "",
            judge2TextField.text ?? "",
            judge3TextField.text ?? "",
            judge4TextField.text ?? ""
        ]
        
        let feedback = feedbackLink.text ?? ""
        let scoresheet = scoresheetLink.text ?? ""
        
        let updateData: [String: Any] = [
            "judges": judges,
            "feedbackSheetRef": feedback,
            "scoreSheetRef": scoresheet
        ]
        
        Firestore.firestore().collection("comps").document(competitionID).updateData(updateData) { error in
            if let error = error {
                print("Error updating judging info: \(error)")
                self.showAlert(title: "Error", message: "Failed to update judging info.")
            } else {
                // Notify JudgingSubviewViewController to reload
                NotificationCenter.default.post(name: Notification.Name("JudgingInfoUpdated"), object: nil)
                
                self.dismiss(animated: true)
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(ac, animated: true)
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
