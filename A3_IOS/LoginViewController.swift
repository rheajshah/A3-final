//
//  LoginViewController.swift
//  A3_IOS
//
//  Created by Rhea Shah on 4/2/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class LoginViewController: UIViewController {
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var togglePasswordVisibilityBtn: UIButton!
    
    private var isPasswordVisible = false

    override func viewDidLoad() {
        super.viewDidLoad()
        passwordTextField.isSecureTextEntry = true
        togglePasswordVisibilityBtn.setImage(UIImage(systemName: "eye"), for: .normal)

        // Add tap gesture recognizer to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    // Dismiss the keyboard
    @objc private func dismissKeyboard() {
        print("Tapped background")
        view.endEditing(true)
    }
    
    @IBAction func loginButtonPressed(_ sender: Any) {
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            showAlert(title: "Error", message: "Please enter both email and password.")
            return
        }

        authenticateUser(email: email, password: password)
    }
    
    //Firebase Authentication
    private func authenticateUser(email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            if let error = error {
                self.showAlert(title: "Login Failed", message: error.localizedDescription)
                return
            }

            // Ensure Firebase returns a valid user
            if let user = authResult?.user {
                print("User logged in: \(user.email ?? "Unknown Email")")

                // Now fetch dark mode setting from Firestore
                let db = Firestore.firestore()
                db.collection("users").document(user.uid).getDocument { document, error in
                    if let document = document, document.exists {
                        let data = document.data()
                        let isDarkModeEnabled = data?["darkMode"] as? Bool ?? false

                        // Save to UserDefaults
                        UserDefaults.standard.set(isDarkModeEnabled, forKey: "darkMode")

                        // Apply dark mode immediately
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            for window in windowScene.windows {
                                window.overrideUserInterfaceStyle = isDarkModeEnabled ? .dark : .light
                            }
                        }
                    } else {
                        print("No user settings found or error fetching document: \(error?.localizedDescription ?? "unknown error")")
                    }

                    // After fetching settings (whether successful or not), navigate home
                    self.showAlert(title: "Success", message: "Welcome back, \(user.email ?? "user")!") {
                        self.navigateToHome()
                    }
                }

            } else {
                self.showAlert(title: "Error", message: "Authentication failed. Please try again.")
            }
        }
    }

    //Helper Functions
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })
        present(alertController, animated: true, completion: nil)
    }

    private func navigateToHome() {
        if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
           let storyboard = UIStoryboard(name: "Main", bundle: nil)
           if let tabBarVC = storyboard.instantiateViewController(withIdentifier: "TabBarController") as? UITabBarController {
               sceneDelegate.window?.rootViewController = tabBarVC
               sceneDelegate.window?.makeKeyAndVisible()
           }
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
    
    @IBAction func togglePasswordBtnVisibility(_ sender: Any) {
        isPasswordVisible.toggle()
        passwordTextField.isSecureTextEntry = !isPasswordVisible

        let iconName = isPasswordVisible ? "eye.slash" : "eye"
        togglePasswordVisibilityBtn.setImage(UIImage(systemName: iconName), for: .normal)
    }
}
