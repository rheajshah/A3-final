//
//  CompDescriptionViewController.swift
//  A3_IOS
//
//  Created by Akhilesh Bitla on 3/12/25.
//

import UIKit
import MapKit
import FirebaseFirestore
import FirebaseStorage
import EventKit
import EventKitUI

class CompDescriptionViewController: UIViewController, EKEventEditViewDelegate {

    @IBOutlet weak var compBannerImage: UIImageView!
    @IBOutlet weak var compName: UILabel!
    @IBOutlet weak var locationIcon: UIImageView!
    @IBOutlet weak var compLocation: UILabel!
    @IBOutlet weak var dateIcon: UIImageView!
    @IBOutlet weak var compDate: UILabel!
    @IBOutlet weak var instaIcon: UIImageView!
    @IBOutlet weak var messageIcon: UIImageView!
    
    @IBOutlet weak var compDescSegCtrl: UISegmentedControl!
    @IBOutlet weak var containerView: UIView!
    
    var isAdmin: Bool!
    var competitionID: String!
    
    // Keep track of current child VC (embedded in the container)
    var currentChildVC: UIViewController?
    
    var instagramHandle: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        loadCompDetails()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(openInstagram))
        instaIcon.isUserInteractionEnabled = true
        instaIcon.addGestureRecognizer(tapGesture)

        let dateTapGesture = UITapGestureRecognizer(target: self, action: #selector(addToCalendar))
        dateIcon.isUserInteractionEnabled = true
        dateIcon.addGestureRecognizer(dateTapGesture)
        
        let locationTapGesture = UITapGestureRecognizer(target: self, action: #selector(openMapForPlace))
        locationIcon.isUserInteractionEnabled = true
        locationIcon.addGestureRecognizer(locationTapGesture)
        
        let messageTapGesture = UITapGestureRecognizer(target: self, action: #selector(openMessages))
        messageIcon.isUserInteractionEnabled = true
        messageIcon.addGestureRecognizer(messageTapGesture)


        showSubview(index: compDescSegCtrl.selectedSegmentIndex)
    }
    
    @IBAction func onSegCtrlChanged(_ sender: UISegmentedControl) {
        showSubview(index: sender.selectedSegmentIndex)
    }
    
    func loadCompDetails() {
        let db = Firestore.firestore()
        db.collection("comps").document(competitionID).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching comp: \(error)")
                return
            }
            
            guard let data = snapshot?.data() else { return }
            
            let name = data["name"] as? String ?? "N/A"
            let date = data["date"] as? String ?? "TBD"
            let city = data["city"] as? String ?? ""
            let state = data["state"] as? String ?? ""
            let location = (city.isEmpty && state.isEmpty) ? "Location not available" : "\(city), \(state)"
            self.instagramHandle = data["instagram"] as? String
           
            let bannerPath = data["bannerURL"] as? String ?? ""
            // Only load banner image if the path exists
            if !bannerPath.isEmpty {
                if let bannerURL = URL(string: bannerPath) {
                    self.loadImage(from: bannerURL, into: self.compBannerImage)
                }
            } else {
                print("No banner path found.")
            }

            // Update labels with fetched data
            DispatchQueue.main.async {
                self.compName.text = name
                self.compDate.text = date
                self.compLocation.text = location
            }
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
    
    
    
    @objc func openMapForPlace() {
        let address = self.compLocation.text
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address!) { placemarks, error in
            if let error = error {
                print("Geocoding error: \(error.localizedDescription)")
                return
            }

            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                print("No location found")
                return
            }

            let coordinate = location.coordinate
            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            mapItem.name = address
            mapItem.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
            ])
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
    
    @objc func openMessages() {
        let db = Firestore.firestore()
        db.collection("comps").document(competitionID).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching phone number: \(error.localizedDescription)")
                return
            }

            guard let data = snapshot?.data(),
                  let phoneNumber = data["compDirectorPhoneNumber"] as? String,
                  !phoneNumber.isEmpty else {
                print("Phone number not available")
                return
            }

            // Remove non-numeric characters (like ()- )
            let cleanedNumber = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            
            print(cleanedNumber)
            
            // Open iMessage
            if let smsURL = URL(string: "sms:\(cleanedNumber)"),
               UIApplication.shared.canOpenURL(smsURL) {
                UIApplication.shared.open(smsURL, options: [:], completionHandler: nil)
            } else {
                print("Unable to open Messages.")
            }
        }
    }
    
    func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    @objc func addToCalendar() {
        let eventStore = EKEventStore()
        
        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { granted, error in
                self.handleCalendarPermission(granted: granted, error: error, eventStore: eventStore)
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, error in
                self.handleCalendarPermission(granted: granted, error: error, eventStore: eventStore)
            }
        }
    }
    
    func handleCalendarPermission(granted: Bool, error: Error?, eventStore: EKEventStore) {
        if granted {
            DispatchQueue.main.async {
                let event = EKEvent(eventStore: eventStore)
                event.title = self.compName.text ?? "Competition"
                event.location = self.compLocation.text ?? ""

                let formatter = DateFormatter()
                formatter.dateStyle = .long
                formatter.timeStyle = .none

                guard let dateString = self.compDate.text,
                      let eventDate = formatter.date(from: dateString) else {
                    print("Date formatting failed.")
                    return
                }

                event.startDate = eventDate
                event.endDate = Calendar.current.date(byAdding: .hour, value: 3, to: eventDate)
                event.calendar = eventStore.defaultCalendarForNewEvents

                let eventVC = EKEventEditViewController()
                eventVC.event = event
                eventVC.eventStore = eventStore
                eventVC.editViewDelegate = self
                self.present(eventVC, animated: true, completion: nil)
            }
        } else {
            print("Permission denied: \(error?.localizedDescription ?? "Unknown error")")
        }
    }

    // Show or hide subviews based on the selected segment index
    func showSubview(index: Int) {
        if let child = currentChildVC {
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }

        var newVC: UIViewController

        switch index {
        case 0:
            let vc = storyboard?.instantiateViewController(withIdentifier: "LineupSubviewViewController") as! LineupSubviewViewController
            vc.competitionID = self.competitionID
            vc.isAdmin = self.isAdmin
            newVC = vc
        case 1:
            let vc = storyboard?.instantiateViewController(withIdentifier: "JudgingSubviewViewController") as! JudgingSubviewViewController
            vc.competitionID = self.competitionID
            vc.isAdmin = self.isAdmin
            newVC = vc
        case 2:
            let vc = storyboard?.instantiateViewController(withIdentifier: "MediaSubviewViewController") as! MediaSubviewViewController
            vc.competitionID = self.competitionID
            vc.isAdmin = self.isAdmin
            newVC = vc
        default:
            return
        }

        addChild(newVC)
        newVC.view.frame = containerView.bounds
        containerView.addSubview(newVC.view)
        newVC.didMove(toParent: self)

        currentChildVC = newVC
    }
}
