import UIKit

class ImagePreviewPageViewController: UIPageViewController, UIPageViewControllerDataSource {

    var imageURLs: [String] = []
    var currentIndex: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        dataSource = self
        view.backgroundColor = .black

        if let startingVC = viewControllerForIndex(currentIndex) {
            setViewControllers([startingVC], direction: .forward, animated: true)
        }
    }

    func viewControllerForIndex(_ index: Int) -> SingleImageViewController? {
        guard index >= 0 && index < imageURLs.count else { return nil }
        let vc = SingleImageViewController()
        vc.imageURL = imageURLs[index]
        vc.imageIndex = index
        return vc
    }

    // MARK: - Page View Controller Data Source

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let currentVC = viewController as? SingleImageViewController,
              let index = currentVC.imageIndex else { return nil }
        return viewControllerForIndex(index - 1)
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let currentVC = viewController as? SingleImageViewController,
              let index = currentVC.imageIndex else { return nil }
        return viewControllerForIndex(index + 1)
    }
}
