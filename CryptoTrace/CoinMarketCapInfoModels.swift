//
//  CoinMarketCapInfoModels.swift
//  FinanceTracker
//
//  Created by Owner on 11/30/25.
//

import Foundation

struct InfoResponse: Codable {
    let data: [String: InfoAsset]
}

struct InfoAsset: Codable {
    let id: Int
    let name: String
    let symbol: String
    let slug: String?
    let logo: String?
    let description: String?
    let urls: InfoURLs?
}

struct InfoURLs: Codable {
    let website: [String]?
    let technical_doc: [String]?
    let twitter: [String]?
    let reddit: [String]?
    let message_board: [String]?
    let announcement: [String]?
    let chat: [String]?
    let explorer: [String]?
    let source_code: [String]?
}
