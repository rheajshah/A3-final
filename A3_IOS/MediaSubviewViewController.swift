//
//  MediaSubviewViewController.swift
//  A3_IOS
//
//  Created by Rhea Shah on 4/4/25.
//

import UIKit
import FirebaseFirestore
import FirebaseStorage

class MediaSubviewViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var editLinkButton: UIButton!
    @IBOutlet weak var officialCompPhotosButton: UIButton!
    @IBOutlet weak var officialCompVideosButton: UIButton!
    @IBOutlet weak var uploadPhotoVideoButton: UIButton!
    @IBOutlet weak var mediaCollectionView: UICollectionView!

    var isAdmin: Bool!
    var competitionID: String!
    var currentPhotosLink: String = ""
    var currentVideosLink: String = ""
    var uploadedMediaURLs: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadMediaLinks()
        fetchUploadedMedia()
        editLinkButton.isHidden = !(isAdmin ?? false)
        mediaCollectionView.delegate = self
        mediaCollectionView.dataSource = self
        
//        configureCollectionViewLayout()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchUploadedMedia()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        configureCollectionViewLayout()
    }

    func loadMediaLinks() {
        let db = Firestore.firestore()
        db.collection("comps").document(competitionID).getDocument { snapshot, error in
            guard let data = snapshot?.data(), error == nil else {
                print("Failed to fetch comp data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            let photosLink = data["photosLink"] as? String ?? ""
            let videosLink = data["videosLink"] as? String ?? ""
            self.currentPhotosLink = photosLink
            self.currentVideosLink = videosLink

            self.configureButton(self.officialCompPhotosButton, with: photosLink)
            self.configureButton(self.officialCompVideosButton, with: videosLink)
        }
    }

    private func configureButton(_ button: UIButton, with link: String?) {
        if let link = link, !link.isEmpty {
            button.isEnabled = true
            button.addAction(UIAction { _ in
                if let url = URL(string: link) {
                    UIApplication.shared.open(url)
                }
            }, for: .touchUpInside)
        } else {
            button.isEnabled = false
        }
    }
    
//    func fetchUploadedMedia() {
//        let db = Firestore.firestore()
//        db.collection("comps").document(competitionID).collection("media").order(by: "uploadedAt").getDocuments { snapshot, error in
//            guard let docs = snapshot?.documents else { return }
//
//            self.uploadedMediaURLs = docs.compactMap { $0["url"] as? String }
//            self.mediaCollectionView.reloadData()
//        }
//    }
    func fetchUploadedMedia() {
        let db = Firestore.firestore()
        db.collection("comps").document(competitionID).collection("media").order(by: "uploadedAt").getDocuments { snapshot, error in
            guard let docs = snapshot?.documents else {
                print("No media found or failed to fetch.")
                return
            }

            self.uploadedMediaURLs = docs.compactMap { $0["url"] as? String }
            self.mediaCollectionView.reloadData()

            DispatchQueue.main.async {
                self.configureCollectionViewLayout()
            }
        }
    }

    @IBAction func uploadPhotoVideoButtonTapped(_ sender: Any) {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        picker.allowsEditing = true
        present(picker, animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        guard let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage else { return }
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }

        let fileName = UUID().uuidString + ".jpg"
        let storageRef = Storage.storage().reference().child("comps/\(competitionID!)/media/\(fileName)")

        storageRef.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                print("Upload failed: \(error.localizedDescription)")
                return
            }

            storageRef.downloadURL { url, error in
                guard let downloadURL = url else {
                    print("Failed to get download URL")
                    return
                }

                let db = Firestore.firestore()
                let mediaRef = db.collection("comps").document(self.competitionID).collection("media").document()

                mediaRef.setData([
                    "url": downloadURL.absoluteString,
                    "uploadedAt": Timestamp(date: Date())
                ]) { error in
                    if let error = error {
                        print("Failed to save media link: \(error.localizedDescription)")
                    } else {
                        print("Successfully uploaded media")
                        self.fetchUploadedMedia()
                    }
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return uploadedMediaURLs.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MediaCell", for: indexPath) as! MediaCell
        let url = uploadedMediaURLs[indexPath.row]
        cell.configure(with: url)
        return cell
    }
    
//    func configureCollectionViewLayout() {
//        if let layout = mediaCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
//            let spacing: CGFloat = 10
//            let itemsPerRow: CGFloat = 4
//            let totalSpacing = spacing * (itemsPerRow + 1)
//            let width = (mediaCollectionView.bounds.width - totalSpacing) / itemsPerRow
//            layout.itemSize = CGSize(width: width, height: width)
//            layout.minimumInteritemSpacing = spacing
//            layout.minimumLineSpacing = spacing
//            mediaCollectionView.contentInset = UIEdgeInsets(top: spacing, left: spacing, bottom: spacing, right: spacing)
//        }
//    }
    
    func configureCollectionViewLayout() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let layout = self.mediaCollectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }

            let spacing: CGFloat = 10
            let itemsPerRow: CGFloat = 4

            let totalSpacing = spacing * (itemsPerRow + 1)
            let width = self.mediaCollectionView.bounds.width

            // Only proceed if layout width is ready
            guard width > 0 else { return }

            let itemWidth = (width - totalSpacing) / itemsPerRow
            layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
            layout.minimumInteritemSpacing = spacing
            layout.minimumLineSpacing = spacing
            layout.sectionInset = UIEdgeInsets(top: spacing, left: spacing, bottom: spacing, right: spacing)
            self.mediaCollectionView.reloadData()
        }
    }

    @IBAction func editLinkButtonTapped(_ sender: Any) {
        let alert = UIAlertController(title: "Edit Links", message: "Update the URLs for official competition photos and videos.", preferredStyle: .alert)
            
            alert.addTextField { textField in
                textField.placeholder = "Official Photos Link"
                textField.text = self.currentPhotosLink
            }
            
            alert.addTextField { textField in
                textField.placeholder = "Official Videos Link"
                textField.text = self.currentVideosLink
            }
            
            let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
                let newPhotosLink = alert.textFields?[0].text ?? ""
                let newVideosLink = alert.textFields?[1].text ?? ""
                
                // Save to Firestore
                let db = Firestore.firestore()
                db.collection("comps").document(self.competitionID).updateData([
                    "photosLink": newPhotosLink,
                    "videosLink": newVideosLink
                ]) { error in
                    if let error = error {
                        print("❌ Failed to update links: \(error.localizedDescription)")
                    } else {
                        print("✅ Links updated")
                        self.loadMediaLinks() // Refresh button titles
                    }
                }
            }
            
            alert.addAction(saveAction)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
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
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let pageVC = ImagePreviewPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        pageVC.modalPresentationStyle = .fullScreen
        pageVC.imageURLs = uploadedMediaURLs
        pageVC.currentIndex = indexPath.row
        present(pageVC, animated: true)
    }


}
