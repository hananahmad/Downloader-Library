//
//  Downloder.swift
//  DownloadManager
//
//  Created by Hanan on 12/17/19.
//  Copyright © 2019 HANAN. All rights reserved.
//

import Foundation
import UIKit

//public protocol DownloadManagerProtocol {
//    func didCacheImage()
//}

public typealias DownloaderCallback = (Data, URL) -> Void
public typealias DownloaderAndCacheImageCallback = (UIImage, URL) -> Void
public typealias DownloaderAndCacheCallbackList = [DownloaderCallback]

open class DownloadManager {
    public static let shared: DownloadManager = {
        let instance = DownloadManager()
        return instance
    }()
    
//    public var delegate:DownloadManagerProtocol?

    fileprivate var cacheObj: FileCache
    private var fetchList: [String: DownloaderAndCacheCallbackList] = [:]
    private var fetchListOperationQueue: DispatchQueue = DispatchQueue(label: "com.hanan.downloaderCache",
                                                                       attributes: DispatchQueue.Attributes.concurrent)
    private var sessionConfiguration: URLSessionConfiguration!
    private var sessionQueue: OperationQueue!
    fileprivate lazy var defaultSession: URLSession! = URLSession(configuration:
        self.sessionConfiguration, delegate: nil,
                                                                  delegateQueue: self.sessionQueue)

    func configure(memoryCapacity: Int = 30 * 1024 * 1024,
                   maxConcurrentOperationCount: Int = 10,
                   timeoutIntervalForRequest: Double = 3,
                   expiryDate: ExpiryDate = .everyWeek,
                   isOnlyInMemory: Bool = true) {
        cacheObj.totalCostLimit = memoryCapacity
        cacheObj.expiration = expiryDate
        FileCache.isOnlyInMemory = isOnlyInMemory

        sessionQueue = OperationQueue()
        sessionQueue.maxConcurrentOperationCount = maxConcurrentOperationCount
        sessionQueue.name = "com.hanan.session"
        sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.requestCachePolicy = .useProtocolCachePolicy
        sessionConfiguration.timeoutIntervalForRequest = timeoutIntervalForRequest
    }

    private init(memoryCapacity: Int = 30 * 1024 * 1024,
                 maxConcurrentOperationCount: Int = 10,
                 timeoutIntervalForRequest: Double = 3,
                 expiryDate: ExpiryDate = .everyWeek) {
        cacheObj = FileCache()
        configure(memoryCapacity: memoryCapacity,
                  maxConcurrentOperationCount: maxConcurrentOperationCount,
                  timeoutIntervalForRequest: timeoutIntervalForRequest,
                  expiryDate: expiryDate)
    }
}

extension DownloadManager {
    fileprivate func readFetch(_ key: String) -> DownloaderAndCacheCallbackList? {
        return fetchList[key]
    }

    fileprivate func addFetch(_ key: String, callback: @escaping DownloaderCallback) -> Bool {
        var skip = false
        let list = fetchList[key]
        if list != nil {
            skip = true
        }
        fetchListOperationQueue.sync(flags: .barrier, execute: {
            if var fList = list {
                fList.append(callback)
                self.fetchList[key] = fList
            } else {
                self.fetchList[key] = [callback]
            }
        })
        return skip
    }

    fileprivate func removeFetch(_ key: String) {
        _ = fetchListOperationQueue.sync(flags: .barrier) {
            self.fetchList.removeValue(forKey: key)
        }
    }

    fileprivate func clearFetch() {
        fetchListOperationQueue.async(flags: .barrier) {
            self.fetchList.removeAll()
        }
    }
}

// MARK: - ClearCache

extension DownloadManager {
    public func clearCache() {
        cacheObj.removeAllObjects()
        sessionConfiguration.urlCache?.removeAllCachedResponses()
    }
}

// MARK: - Downloader

open class Downloader: NSObject {
    var task: URLSessionTask?
    public override init() {
        super.init()
    }
}

extension Downloader {
    fileprivate func cacheKeyFromUrl(url: URL) -> String? {
        let path = url.absoluteString
        let cacheKey = path
        return cacheKey
    }

    fileprivate func dataFromFastCache(cacheKey: String) -> Data? {
        return DownloadManager.shared.cacheObj.get(forKey: cacheKey)
    }

    public func loadWith(urlRequest: URLRequest,
                         isRefresh: Bool = false,
                         expirationDate: Date? = nil,
                         callback: @escaping DownloaderCallback) {
        guard let url = urlRequest.url else {
            return
        }
        load(url: url,
             isRefresh: isRefresh,
             expirationDate: expirationDate,
             callback: callback)
    }

    public func load(url: URL,
                     isRefresh: Bool = false,
                     expirationDate: Date? = nil,
                     callback: @escaping DownloaderCallback) {
        guard let fetchKey = self.cacheKeyFromUrl(url: url as URL) else {
            return
        }
        if !isRefresh {
            if let data = self.dataFromFastCache(cacheKey: fetchKey) {
                callback(data, url)
                return
            }
        }
        let cacheCallback = {
            (data: Data) -> Void in
            if let fetchList = DownloadManager.shared.readFetch(fetchKey) {
                DownloadManager.shared.removeFetch(fetchKey)
                DispatchQueue.main.async {
                    for f in fetchList {
                        f(data, url)
                    }
                }
            }
        }
        let skip = DownloadManager.shared.addFetch(fetchKey, callback: callback)
        if skip {
            return
        }
        let session = DownloadManager.shared.defaultSession
        let request = URLRequest(url: url)
        task = session?.dataTask(with: request, completionHandler: { data, _, _ in
            guard let data = data else {
                return
            }
            let object = Cache(value: data as NSData, key: fetchKey, expirationDate: expirationDate)
            DownloadManager.shared.cacheObj.add(object: object)
            cacheCallback(data)
        })
        task?.resume()
    }
}

extension Downloader {
    public func cancelTask() {
        guard let _task = self.task else {
            return
        }
        if _task.state == .running || _task.state == .running {
            _task.cancel()
        }
    }
}
