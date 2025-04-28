//
//  SignupViewController.swift
//  A3_IOS
//
//  Created by Rhea Shah on 4/2/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class SignupViewController: UIViewController {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var fullNameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var createAccountButton: UIButton!
    @IBOutlet weak var togglePasswordVisibilityBtn: UIButton!
    
    private var isPasswordVisible = false

    
    override func viewDidLoad() {
        super.viewDidLoad()
        passwordTextField.isSecureTextEntry = true
        togglePasswordVisibilityBtn.setImage(UIImage(systemName: "eye"), for: .normal)
    }
    
    
    @IBAction func createAccountButtonPressed(_ sender: Any) {
        guard let fullName = fullNameTextField.text, !fullName.isEmpty,
              let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            showAlert(title: "Error", message: "All fields are required.")
            return
        }
        
        if password.count < 6 {
            showAlert(title: "Error", message: "Password must be at least 6 characters.")
            return
        }

        createAccount(email: email, password: password, fullName: fullName) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.showAlert(title: "Success", message: "Account created successfully!", isSuccess: true)
                case .failure(let error):
                    self.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func createAccount(email: String, password: String, fullName: String, completion: @escaping (Result<Void, Error>) -> Void) {
       Auth.auth().createUser(withEmail: email, password: password) { result, error in
           if let error = error {
               completion(.failure(error))
               return
           }
           
           guard let userId = result?.user.uid else {
               completion(.failure(NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve user ID"])))
               return
           }
           
           
           let db = Firestore.firestore()
           let userData: [String: Any] = [
               "uid": userId,         // Store UID
               "fullName": fullName,
               "email": email,
               "admin": false, // Default role (change if needed)
               "team": "team name",
               "notifications": false,
               "darkMode": false,
           ]
           
           db.collection("users").document(userId).setData(userData) { error in
               if let error = error {
                   completion(.failure(error))
               } else {
                   completion(.success(()))
               }
           }
       }
   }
    
    private func showAlert(title: String, message: String, isSuccess: Bool = false) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default) { _ in
            if isSuccess {
                self.clearFields()
                self.dismiss(animated: true, completion: nil) // Dismiss signup screen on success
            }
        }
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }
    
    private func clearFields() {
        fullNameTextField.text = ""
        emailTextField.text = ""
        passwordTextField.text = ""
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
    
    
    @IBAction func togglePasswordBtnVisibility(_ sender: Any) {
        isPasswordVisible.toggle()
        passwordTextField.isSecureTextEntry = !isPasswordVisible

        let iconName = isPasswordVisible ? "eye.slash" : "eye"
        togglePasswordVisibilityBtn.setImage(UIImage(systemName: iconName), for: .normal)
    }
}
