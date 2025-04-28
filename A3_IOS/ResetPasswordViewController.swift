//
//  ResetPasswordViewController.swift
//  A3_IOS
//
//  Created by Eshitha B on 4/2/25.
//

import UIKit
import FirebaseAuth

class ResetPasswordViewController: UIViewController {

    @IBOutlet weak var emailTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    

    @IBAction func sendEmailResetButtonPressed(_ sender: Any) {
        guard let email = emailTextField.text, !email.isEmpty else {
           showAlert(title: "Error", message: "Please enter your email.")
           return
       }

       Auth.auth().sendPasswordReset(withEmail: email) { error in
           if let error = error {
               self.showAlert(title: "Error", message: error.localizedDescription)
           } else {
               self.showAlert(title: "Success", message: "A password reset email has been sent to \(email). Check your inbox.") {
                   self.navigateToLogin()
               }
           }
       }
    }
    
    private func navigateToLogin() {
        if let loginVC = storyboard?.instantiateViewController(identifier: "LoginViewController") as? LoginViewController {
            loginVC.modalPresentationStyle = .fullScreen
            present(loginVC, animated: true, completion: nil)
        }
    }

    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        }
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
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
