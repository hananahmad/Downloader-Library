//
//  CacheUIImage.swift
//  DownloadManager
//
//  Created by Hanan on 12/17/19.
//  Copyright © 2019 HANAN. All rights reserved.
//

import Foundation
import UIKit

private var imageUrlKey: Void?
private var imageSetKey: Void?
private let imageLoadHudTag = 99989

public extension UIImageView {
    var cacheImageUrl: URL? {
        get {
            return objc_getAssociatedObject(self, &imageUrlKey) as? URL
        }
        set {
            objc_setAssociatedObject(self, &imageUrlKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    var isImageSet: Bool {
        get {
            return (objc_getAssociatedObject(self, &imageSetKey) as? Bool) ?? false
        }
        set {
            objc_setAssociatedObject(self, &imageSetKey, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }
}

extension UIImageView {
    func showLoading() {
        if let hud = self.viewWithTag(imageLoadHudTag) as? UIActivityIndicatorView {
            hud.startAnimating()
            return
        } else {
            if #available(iOS 13.0, *) {
                let hud = UIActivityIndicatorView(style: .medium)
                hud.tag = imageLoadHudTag
                hud.center = center
                hud.hidesWhenStopped = true
                addSubview(hud)
                bringSubviewToFront(hud)
                hud.center = center
                hud.startAnimating()
            } else {
                // Fallback on earlier versions
                let hud = UIActivityIndicatorView(style: .gray)
                hud.tag = imageLoadHudTag
                hud.center = center
                hud.hidesWhenStopped = true
                addSubview(hud)
                bringSubviewToFront(hud)
                hud.center = center
                hud.startAnimating()
            }
        }
    }
    
    func hideLoading() {
        if let hud = self.viewWithTag(imageLoadHudTag) as? UIActivityIndicatorView {
            hud.stopAnimating()
            return
        }
    }
}

public extension UIImageView {
    private class CacheImageLoaderPar: NSObject {
        var url: URL!
        var isShowLoading: Bool!
        var completionBlock: DownloaderAndCacheImageCallback!
        init(url: URL, showLoading: Bool, completionBlock: @escaping DownloaderAndCacheImageCallback) {
            self.url = url
            isShowLoading = showLoading
            self.completionBlock = completionBlock
        }
    }
    
    func cacheImageLoad(_ url: URL,
                        isShowLoading: Bool,
                        completionBlock: @escaping DownloaderAndCacheImageCallback) {
        cacheImageUrl = url
        if isShowLoading {
            showLoading()
        }
        let loader = Downloader()
        loader.load(url: url) { [weak self] data, url in
            if isShowLoading {
                self?.hideLoading()
            }
            
            guard let _self = self, let cacheImageUrl = _self.cacheImageUrl, let image = UIImage(data: data) else {
                NSLog("no imageView")
                return
            }
            if cacheImageUrl.absoluteString != url.absoluteString {
                NSLog("url not match:\(cacheImageUrl),\(url)")
            } else {
                self?.setImageWith(image)
                completionBlock(image, url)
            }
        }
    }
    
    @objc
    fileprivate func setImageWith(_ image: UIImage) {
        self.image = image
        isImageSet = true
    }
}
