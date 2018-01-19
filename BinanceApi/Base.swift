//
//  Base.swift
//  BinanceApi
//
//  Created by Sumant Manne on 10/22/17.
//  Copyright © 2017 Sumant Manne. All rights reserved.
//

import Alamofire
import CommonCrypto

extension Data {
    func hmac(base64key key: String) -> String {
        let algorithm = CCHmacAlgorithm(kCCHmacAlgSHA256)
        let keyLength = key.lengthOfBytes(using: .utf8)
        let digestLength = Int(CC_SHA256_DIGEST_LENGTH)

        var output = [UInt8](repeating: 0, count: digestLength)

        key.withCString { keyPtr in
            self.withUnsafeBytes { dataPtr in
                CCHmac(algorithm, keyPtr, keyLength, dataPtr, self.count, &output)
            }
        }

        let result = output.map { b in String(format: "%02x", b) }.joined()
        return result
    }
}

extension String {
    func hmac(base64key key: String) -> String {
        let algorithm = CCHmacAlgorithm(kCCHmacAlgSHA256)
        let keyLength = key.lengthOfBytes(using: .utf8)
        let messageLength = self.lengthOfBytes(using: .utf8)
        let digestLength = Int(CC_SHA256_DIGEST_LENGTH)

        var output = [UInt8](repeating: 0, count: digestLength)

        key.withCString { keyPtr in
            self.withCString { messagePtr in
                CCHmac(algorithm, keyPtr, keyLength, messagePtr, messageLength, &output)
            }
        }

        let result = output.map { b in String(format: "%02x", b) }.joined()
        return result
    }
}

public enum BinanceOrderStatus: String, Codable {
    case new = "NEW"
    case partial = "PARTIALLY_FILLED"
    case filled = "FILLED"
    case cancelled = "CANCELED" // Yes, this is correct.
    case pendingCancel = "PENDING_CANCEL"
    case rejected = "REJECTED"
    case expired = "EXPIRED"
}

public enum BinanceOrderType: String, Codable {
    case limit = "LIMIT"
    case market = "MARKET"
}

public enum BinanceOrderSide: String, Codable {
    case buy = "BUY"
    case sell = "SELL"
}

public enum BinanceOrderTime: String, Codable {
    case goodTilCancelled = "GTC"
    case immediateOrCancel = "IOC"
}

public enum BinanceCandlesticksInterval: String, Codable {
    case min1 = "1m"
    case min3 = "3m"
    case min5 = "5m"
    case min15 = "15m"
    case min30 = "30m"
    case hour1 = "1h"
    case hour2 = "2h"
    case hour4 = "4h"
    case hour6 = "6h"
    case hour8 = "8h"
    case hour12 = "12h"
    case day1 = "1d"
    case day3 = "3d"
    case week1 = "1w"
    case month1 = "1M"
}

public struct BinanceApi {
    static let baseUrl = URL(string: "https://api.binance.com/api/")!

    let session: SessionManager

    public init(receiveWindow: TimeInterval? = nil) {
        self.init(apiKey: nil, secretKey: nil, receiveWindow: nil)
    }

    public init(apiKey: String?, secretKey: String?, receiveWindow: TimeInterval? = nil) {
        self.session = BinanceApi.defaultSessionManager
        if let apiKey = apiKey, let secretKey = secretKey {
            self.session.adapter = BinanceRequestAdapter(
                apiKey: apiKey,
                secretKey: secretKey,
                receiveWindow: receiveWindow ?? 5000)
        }
    }

    private static var defaultSessionManager: SessionManager {
        var defaultHeaders = Alamofire.SessionManager.defaultHTTPHeaders
        defaultHeaders.removeValue(forKey: "Accept-Language")
        /// TODO: let urlSessionConfiguration = URLSessionConfiguration()
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = defaultHeaders
        let session = Alamofire.SessionManager(configuration: configuration)
        return session
    }

    @discardableResult
    public func send<T: BinanceRequest>(_ request: T,
                                        completionHandler: ((DataResponse<T.Response>) -> Void)?) -> DataRequest {
        let url = try! request.asURL()
        let parameters = request.asParameters

        return self.session
            .request(url, method: T.method, parameters: parameters)
            .validate(statusCode: 200..<600)
            //.validate(contentType: ["application/json"])
            .responseBinanceResponse(T.Response.self, completionHandler: completionHandler ?? {_ in })
    }
}

/// RequestAdapter to add authentification to requests with a `timestamp` parameter.
public struct BinanceRequestAdapter: RequestAdapter {
    let apiKey: String?
    let secretKey: String?
    let receiveWindow: TimeInterval

    public init(apiKey: String? = nil, secretKey: String? = nil, receiveWindow: TimeInterval = 5000) {
        self.apiKey = apiKey
        self.secretKey = secretKey
        self.receiveWindow = receiveWindow
    }

    public func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
        guard let url = urlRequest.url else { throw BinanceApiError.unknown }

        let urlHost = url.host!
        assert(urlHost.contains("binance.com"))

        let query = (url.query ?? "").removingPercentEncoding ?? ""
        let body = String(data: urlRequest.httpBody ?? Data(), encoding: .utf8) ?? ""

        if !query.contains("timestamp=") && !body.contains("timestamp=") {
            return urlRequest
        }

        guard let apiKey = self.apiKey else { throw BinanceApiError.noApiKeySpecified }
        guard let secretKey = self.secretKey else { throw BinanceApiError.noApiKeySpecified }

        // Add apikey header
        var urlRequest = urlRequest
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-Mbx-Apikey")

        // Add receive window to query parameters
        var result: URLRequest
        result = try URLEncoding.queryString.encode(urlRequest, with: ["recvWindow": self.receiveWindow])

        let signable = query.appending(body)
        let signature = signable.hmac(base64key: secretKey)

        // Add HMAC signature to query parameters
        result = try URLEncoding.queryString.encode(urlRequest, with: ["signature": signature])
        return result
    }
}

public protocol BinanceRequest: Encodable, URLConvertible, URLRequestConvertible {
    associatedtype Response: Decodable
    static var endpoint: String { get }
    static var method: HTTPMethod { get }

    func asURL() throws -> URL
    func asURLRequest() throws -> URLRequest
}

public extension BinanceRequest {
    public func asURL() throws -> URL {
        let baseUrl = URL(string: "https://api.binance.com/api/")!
        return URL(string: Self.endpoint, relativeTo: baseUrl)!.absoluteURL
    }

    public func asURLRequest() throws -> URLRequest {
        let url = try self.asURL()
        let request = try URLRequest(url: url, method: Self.method)
        return request
    }

}

public protocol BinanceSignedRequest: BinanceRequest {
    var timestamp: Date { get }
}

public enum BinanceApiError: Error {
    case unknown
    case emptyKeyPath
    case noApiKeySpecified
    case errorResponse(BinanceErrorResponse)
}

public struct BinanceErrorResponse: Codable, Error {
    let code: Int64
    let message: String

    enum CodingKeys: String, CodingKey {
        case code
        case message = "msg"
    }
}

public enum BinanceResponse<T: Decodable>: Decodable {
    case error(BinanceErrorResponse)
    case result(T)

    /// TODO: cleanup
    public init(from decoder: Decoder) throws {
        do {
            self = .error(try BinanceErrorResponse(from: decoder))
        } catch (error: DecodingError.keyNotFound(_, _)) {
            self = .result(try T(from: decoder))
        } catch (error: DecodingError.typeMismatch(_, _)) {
            self = .result(try T(from: decoder))
        }
    }
}

public struct BinanceOrder: Codable {
    let symbol: String
    let orderId: UInt64
    let clientOrderId: String
    let price: Decimal
    let originalQuantity: Decimal
    let executedQuantity: Decimal
    let status: BinanceOrderStatus
    let timeInForce: BinanceOrderTime
    let type: BinanceOrderType
    let side: BinanceOrderSide
    let stopPrice: Decimal
    let icebergQuantity: Decimal
    let time: Date

    enum CodingKeys: String, CodingKey {
        case symbol, orderId, clientOrderId, price
        case originalQuantity = "origQty"
        case executedQuantity = "executedQty"
        case status, timeInForce, type, side, stopPrice
        case icebergQuantity = "icebergQty"
        case time
    }
}

extension BinanceOrder: CustomStringConvertible {
    public var description: String {
        return "BinanceOrder(\(self.symbol), \(self.orderId), \(self.clientOrderId))"
    }
}
