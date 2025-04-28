//
//  SingleImageViewController.swift
//  A3_IOS
//
//  Created by Akhilesh Bitla on 4/17/25.
//

import UIKit

class SingleImageViewController: UIViewController, UIScrollViewDelegate {
    var imageURL: String?
    var imageIndex: Int?

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupScrollView()
        setupImageView()
        loadImage()

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissSelf))
        view.addGestureRecognizer(tap)
    }

    func setupScrollView() {
        scrollView.frame = view.bounds
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        view.addSubview(scrollView)
    }

    func setupImageView() {
        imageView.contentMode = .scaleAspectFit
        imageView.frame = scrollView.bounds
        scrollView.addSubview(imageView)
    }

    func loadImage() {
        guard let urlString = imageURL, let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else { return }
            DispatchQueue.main.async {
                self.imageView.image = UIImage(data: data)
            }
        }.resume()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    @objc func dismissSelf() {
        dismiss(animated: true)
    }
}
