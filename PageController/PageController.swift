//
//  PageController.swift
//  PageController
//
//  Created by Hirohisa Kawasaki on 6/24/15.
//  Copyright (c) 2015 Hirohisa Kawasaki. All rights reserved.
//

import UIKit

public protocol PageControllerDelegate: class {
    func pageController(_ pageController: PageController, didChangeVisibleController visibleViewController: UIViewController, fromViewController: UIViewController?)
}

open class PageController: UIViewController {

    open weak var delegate: PageControllerDelegate?

    open var menuBar: MenuBar = MenuBar(frame: CGRect.zero)
    open var menuBarHeight: CGFloat = 44
    open var underLine = UIView(frame: CGRect.zero)
    open var visibleViewController: UIViewController? {
        didSet {
            if let visibleViewController = visibleViewController {
                delegate?.pageController(self, didChangeVisibleController: visibleViewController, fromViewController: oldValue)
            }
        }
    }
    open var viewControllers: [UIViewController] = [] {
        didSet {
            _reloadData()
        }
    }
    open var durationForAnimation: TimeInterval = 0.2
    open var didFinishFirstLoad = false

    open override func viewDidLoad() {
        super.viewDidLoad()

        _configure()
        _reloadData()
    }

    let scrollView = ContainerView(frame: CGRect.zero)
}

extension PageController {

    public var frameForMenuBar: CGRect {
        var frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: menuBarHeight)
        if let frameForNavigationBar = navigationController?.navigationBar.frame {
            frame.origin.y = frameForNavigationBar.maxY
        }

        return frame
    }

    public var frameForUnderLine: CGRect {
        let width: CGFloat  = menuBar.frame.width / 3
        let height: CGFloat = menuBar.frame.height * 0.1

        return CGRect(x: menuBar.frame.width / 2 - width / 2, y: menuBar.frame.height - height, width: width, height: height)
    }
    
    public var frameForContentController: CGRect {
        return view.bounds
    }

    var frameForLeftContentController: CGRect {
        var frame = frameForContentController
        frame.origin.x = 0
        return frame
    }

    var frameForCenterContentController: CGRect {
        var frame = frameForContentController
        frame.origin.x = frame.width
        return frame
    }

    var frameForRightContentController: CGRect {
        var frame = frameForContentController
        frame.origin.x = frame.width * 2
        return frame
    }

    func _configure() {
        automaticallyAdjustsScrollViewInsets = false

        let frame = frameForContentController
        scrollView.frame = frame
        scrollView.controller = self

        scrollView.contentSize = CGSize(width: frame.width * 3, height: frame.height)
        view.addSubview(scrollView)

        menuBar.frame = frameForMenuBar
        menuBar.controller = self
        view.addSubview(menuBar)

        underLine.frame = frameForUnderLine
        menuBar.addSubview(underLine)
    }

    func _reloadData() {
        if !isViewLoaded {
            return
        }

        menuBar.items = viewControllers.map { $0.title ?? "" }
    }

    public func reloadPages(AtIndex index: Int) {
        for viewController in childViewControllers {
            if viewController != viewControllers[index] {
                hideViewController(viewController)
            }
        }

        scrollView.contentOffset = frameForCenterContentController.origin
        loadPages(AtCenter: index)
    }

    public func switchPage(AtIndex index: Int) {

        if scrollView.isDragging {
            return
        }

        guard let viewController = viewControllerForCurrentPage() else { return }

        let currentIndex = NSArray(array: viewControllers).index(of: viewController)

        if currentIndex != index {
            reloadPages(AtIndex: index)
        }
    }

    func loadPages() {
        if let viewController = viewControllerForCurrentPage() {
            let index = NSArray(array: viewControllers).index(of: viewController)
            loadPages(AtCenter: index)
        }
    }

    func loadPages(AtCenter index: Int) {
        if index >= viewControllers.count { return }
        let visibleViewController = viewControllers[index]
        if visibleViewController == self.visibleViewController { return }

        switchVisibleViewController(visibleViewController)
        // offsetX < 0 or offsetX > contentSize.width
        let frameOfContentSize = CGRect(x: 0, y: 0, width: scrollView.contentSize.width, height: scrollView.contentSize.height)
        for viewController in childViewControllers {
            if viewController != visibleViewController && !viewController.view.include(frameOfContentSize) {
                hideViewController(viewController)
            }
        }

        // center
        displayViewController(visibleViewController, frame: frameForCenterContentController)

        // left
        var exists = childViewControllers.filter { $0.view.include(frameForLeftContentController) }
        if exists.isEmpty {
            displayViewController(viewControllers[(index - 1).relative(viewControllers.count)], frame: frameForLeftContentController)
        }

        // right
        exists = childViewControllers.filter { $0.view.include(frameForRightContentController) }
        if exists.isEmpty {
            displayViewController(viewControllers[(index + 1).relative(viewControllers.count)], frame: frameForRightContentController)
        }
    }

    func switchVisibleViewController(_ viewController: UIViewController) {
        if visibleViewController != viewController {
            visibleViewController = viewController
            if !didFinishFirstLoad {
                didFinishFirstLoad = true
                guard let visibleViewController = visibleViewController else { return }
                changeUnderLineWidth(title: visibleViewController.title!)
            }
        }
    }

    func changeUnderLineWidth(title: String) {
        let label  = UILabel(frame: CGRect(x: 0, y: 0, width: menuBar.frame.width / 3, height: underLine.frame.height))
        label.text = title
        let maxHeight : CGFloat = 10000
        let rect = label.attributedText?.boundingRect(with: CGSize(width: menuBar.frame.width / 3, height: maxHeight),
                                                              options: .usesLineFragmentOrigin, context: nil)
        var frame = label.frame
        frame.size.height = rect!.size.height
        frame.size.width = rect!.size.width - CGFloat(Double(title.characters.count))
        label.frame = frame

        let width = label.frame.width
        let height = underLine.frame.height
        UIView.animate(withDuration: durationForAnimation, animations: {
            self.underLine.frame = CGRect(x: self.menuBar.frame.width / 2 - width / 2,
                                          y: self.underLine.frame.origin.y,
                                          width: width,
                                          height: height)
            }, completion: { _ in
        })
    }
}

extension PageController: UIScrollViewDelegate {

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        viewDidScroll()
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        viewDidScroll()
    }

}

extension PageController {

    func viewDidScroll() {
        guard let visibleViewController = visibleViewController else { return }

        if let viewController = viewControllerForCurrentPage() {

            let from = NSArray(array: viewControllers).index(of: visibleViewController)
            let to = NSArray(array: viewControllers).index(of: viewController)

            if viewController != visibleViewController {
                move(from, to: to)
                return
            }

            if !scrollView.isTracking || !scrollView.isDragging {
                return
            }
            if from == to {
                revert(to)
            }
        }
    }

    func move(_ from: Int, to: Int) {

        let width = scrollView.frame.width
        if scrollView.contentOffset.x > width * 1.5 {
            menuBar.move(from: from, until: to)
        } else if scrollView.contentOffset.x < width * 0.5 {
            menuBar.move(from: from, until: to)
        }
    }

    func revert(_ to: Int) {
        menuBar.revert(to)
    }

    func displayViewController(_ viewController: UIViewController, frame: CGRect) {
        addChildViewController(viewController)
        viewController.view.frame = frame
        scrollView.addSubview(viewController.view)
        viewController.didMove(toParentViewController: self)
    }

    func hideViewController(_ viewController: UIViewController) {
        viewController.willMove(toParentViewController: self)
        viewController.view.removeFromSuperview()
        viewController.removeFromParentViewController()
    }

}
