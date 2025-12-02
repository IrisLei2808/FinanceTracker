//
//  CoinMarketCapAPI.swift
//  FinanceTracker
//
//  Created by Owner on 11/30/25.
//

import Foundation

enum CoinMarketCapAPIError: Error {
    case invalidURL
    case badStatus(Int)
    case decoding(Error)
    case transport(Error)
}

struct CoinMarketCapAPI {
    var apiKey: String

    func latestListings(start: Int = 1, limit: Int = 50, convert: String = "USD") async throws -> [Crypto] {
        var comps = URLComponents(string: "https://pro-api.coinmarketcap.com/v1/cryptocurrency/listings/latest")
        comps?.queryItems = [
            URLQueryItem(name: "start", value: String(start)),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "convert", value: convert)
        ]
        guard let url = comps?.url else { throw CoinMarketCapAPIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(apiKey, forHTTPHeaderField: "X-CMC_PRO_API_KEY")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw CoinMarketCapAPIError.badStatus(-1) }
            guard 200..<300 ~= http.statusCode else {
                throw CoinMarketCapAPIError.badStatus(http.statusCode)
            }
            do {
                let decoded = try JSONDecoder().decode(ListingsResponse.self, from: data)
                return decoded.data
            } catch {
                throw CoinMarketCapAPIError.decoding(error)
            }
        } catch {
            throw CoinMarketCapAPIError.transport(error)
        }
    }

    func info(forIDs ids: [Int]) async throws -> [Int: InfoAsset] {
        guard !ids.isEmpty else { return [:] }
        var comps = URLComponents(string: "https://pro-api.coinmarketcap.com/v2/cryptocurrency/info")
        // API expects comma-separated list of IDs
        comps?.queryItems = [
            URLQueryItem(name: "id", value: ids.map(String.init).joined(separator: ","))
        ]
        guard let url = comps?.url else { throw CoinMarketCapAPIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(apiKey, forHTTPHeaderField: "X-CMC_PRO_API_KEY")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw CoinMarketCapAPIError.badStatus(-1) }
            guard 200..<300 ~= http.statusCode else {
                throw CoinMarketCapAPIError.badStatus(http.statusCode)
            }
            do {
                let decoded = try JSONDecoder().decode(InfoResponse.self, from: data)
                // The response is keyed by String IDs; convert to Int keys
                var map: [Int: InfoAsset] = [:]
                for (key, value) in decoded.data {
                    if let intKey = Int(key) {
                        map[intKey] = value
                    }
                }
                return map
            } catch {
                throw CoinMarketCapAPIError.decoding(error)
            }
        } catch {
            throw CoinMarketCapAPIError.transport(error)
        }
    }
}
