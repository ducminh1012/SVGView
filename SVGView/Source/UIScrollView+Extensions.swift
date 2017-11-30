//
//  UIScrollView+Extensions.swift
//  comico
//
//  Created by NHNVN on 11/27/17.
//  Copyright © 2017 NHN SINGAPORE PTE LTD. All rights reserved.
//

import UIKit

typealias refreshHandler = ((UIScrollView) -> Void)

extension UIScrollView {
    func enablePullToRefresh(svgFileUrl: URL, handler: refreshHandler?) {
        if let refreshControl = viewWithTag(9999) as? CMCPullToRefreshControl{
            removeObserver(self, forKeyPath: "contentOffset")
        } else {
            var refreshControl = CMCPullToRefreshControl(self)
            refreshControl.tag = 9999
            refreshControl.handler = handler
            refreshControl.svgFileUrl = svgFileUrl
            addObserver(self, forKeyPath: "contentOffset", options: NSKeyValueObservingOptions.new, context: &refreshControl)

        }

    }

    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == "contentOffset" else { return }
        guard let offset = change![NSKeyValueChangeKey.newKey] as? CGPoint else { return }

        self.scroll(offset)

        if offset.y < 0 {
            let refreshControl = viewWithTag(9999) as? CMCPullToRefreshControl
            refreshControl?.fallOut(self)
        }


    }

    func scroll(_ offset: CGPoint) {
        let refreshControl = self .viewWithTag(9999) as? CMCPullToRefreshControl
        if (refreshControl?.isEqual(self.subviews.first))! {
            sendSubview(toBack: refreshControl!)
        }
    }

    func stopRefreshing() {
        guard let refreshControl = viewWithTag(9999) as? CMCPullToRefreshControl else { return }

        refreshControl.endRefreshing()
    }
}
