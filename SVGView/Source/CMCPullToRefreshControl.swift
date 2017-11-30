//
//  CMCPullToRefreshControl.swift
//  comico
//
//  Created by NHNVN on 11/27/17.
//  Copyright © 2017 NHN SINGAPORE PTE LTD. All rights reserved.
//

import UIKit

class CMCPullToRefreshControl: UIView {
    
    var handler: refreshHandler?
    var scrollView = UIScrollView()
    var svgView: CMCSVGView?
    var svgFileUrl: URL? {
        didSet{
            guard let url = svgFileUrl else { return }
            animation(url)
        }
    }
    var refreshing = false
    var executing = false
    var threshold: CGFloat = 0
    var defaultInsets = UIEdgeInsets.zero
    
    init(_ scrollView: UIScrollView) {
        super.init(frame: CGRect(x: 0, y: -44, width: scrollView.bounds.width, height: 44))
        
        backgroundColor = UIColor.clear
        self.scrollView = scrollView
        self.scrollView.addSubview(self)
        self.defaultInsets = self.scrollView.contentInset
        self.threshold = 22
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func fallOut(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y + scrollView.contentInset.top
        let rate = min(1.0, abs(offsetY)/(self.bounds.size.height + self.threshold))

        if (!refreshing) {
            svgView?.progress = rate
        }else {
            if (offsetY >= -(self.frame.size.height)) {

                scrollView.contentInset = UIEdgeInsets(top: defaultInsets.top + bounds.height, left: defaultInsets.left, bottom: defaultInsets.bottom, right: defaultInsets.right)
                execute()
            }
        }

        if (!scrollView.isDragging && rate >= 1.0) {
            beginRefreshing()
        }
//        else {
//            print("progress \(offsetY)")
//            svgView?.progress = rate
//        }
    }
    
    func beginRefreshing() {
        let y = -(self.scrollView.contentInset.top + self.frame.size.height)
        
        guard !refreshing else { return }
        executing = false
        refreshing = true
        scrollView.isUserInteractionEnabled = false
        scrollView.setContentOffset(CGPoint(x: 0, y: y), animated: true)
        animate()
    }
    
    func endRefreshing() {
        refreshing = false
        executing = false
    }
    
    func execute() {
        guard !executing else { return }
        
        guard let handler = self.handler else { return }
        
        executing = true
        handler(self.scrollView)
        
    }
    
    func animation(_ url: URL) {
        svgView = CMCSVGView(frame: CGRect(x: 0, y: 5, width: bounds.width, height: 34))
        addSubview(svgView!)
        svgView?.svgFileUrl = url
    }
    
    func animate() {
        guard let svgView = self.svgView, !svgView.animating else { return }

        svgView.animate(withDuration: 1.0, completion: {
            if !self.refreshing && !self.executing {
                self.scrollView.isUserInteractionEnabled = true
                UIView.animate(withDuration: 0.3, animations: {
                    self.scrollView.contentInset = self.defaultInsets
                })
            }else {
                self.animate()
            }
        })
    }
}
