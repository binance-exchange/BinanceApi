//
//  BinanceAPI.swift
//  BinanceAPI
//
//  Created by Sumant Manne on 10/19/17.
//

import Alamofire

// MARK: General endpoints

/// Test connectivity to the REST API.
public struct BinancePingRequest: BinanceRequest, Codable {
    public static let endpoint = "v1/ping"
    public static let method: HTTPMethod = .get
    
    public init () {}
    
    public struct Response: Codable {}
}

/// Test connectivity to the REST API and get the current server time.
public struct BinanceTimeRequest: BinanceRequest {
    public static let endpoint = "v1/time"
    public static let method: HTTPMethod = .get

    public init () {}
    
    public struct Response: Decodable {
        public let localTime = Date()
        public let serverTime: Date

        public var delta: TimeInterval {
            return self.serverTime.timeIntervalSince(self.localTime)
        }
    }
}

// MARK: Market Data endpoints

public struct BinanceDepthRequest: BinanceRequest {
    public static let endpoint = "v1/depth"
    public static let method: HTTPMethod = .get

    public let symbol: String
    /// Default = 100; Max = 100.
    public let limit: Int32?

    public init(symbol: String, limit: Int32? = nil) {
        self.symbol = symbol
        self.limit = limit != 0 ? limit : nil
    }

    public struct Response: Decodable {
        public struct DepthOrder: Decodable {
            public let price: Decimal
            public let quantity: Decimal

            public init(from decoder: Decoder) throws {
                var values = try decoder.unkeyedContainer()
                self.price = try values.decode(Decimal.self)
                self.quantity = try values.decode(Decimal.self)
            }
        }

        public let lastUpdateId: UInt64
        public let bids: [DepthOrder]
        public let asks: [DepthOrder]
    }
}

/// Get compressed, aggregate trades.
/// Trades that fill at the time, from the same order, with the same price will have the quantity aggregated.
/// When both `startTime` and `endTime` are set limit should not be sent AND the distance between `startTime` and `endTime` must be less than 24 hours.
/// If `fromId`, `startTime`, and `endTime` are not set the most recent aggregate trades will be returned.
public struct BinanceAggregateTradesRequest: BinanceRequest, Codable  {
    public static let endpoint = "v1/aggTrades"
    public static let method: HTTPMethod = .get

    public let symbol: String
    /// ID to get aggregate trades from INCLUSIVE.
    public var fromId: UInt64?
    /// Timestamp to get aggregate trades from INCLUSIVE.
    public let startTime: Date?
    /// Timestamp to get aggregate trades until INCLUSIVE.
    public let endTime: Date?
    /// Default = 500; Max = 500.
    public let limit: Int32?

    public init(symbol: String, fromId: UInt64? = nil, startTime: Date? = nil, endTime: Date? = nil, limit: Int32? = nil) {
        self.symbol = symbol
        self.fromId = fromId != 0 ? fromId : nil
        self.startTime = startTime
        self.endTime = endTime
        self.limit = limit != 0 ? limit : nil
    }

    public struct Element: Codable {
        public let aggregateTradeId: UInt64
        public let price: Decimal
        public let quantity: Decimal
        public let firstTradeId: UInt64
        public let lastTradeId: UInt64
        public let timestamp: Date
        public let makerIsBuyer: Bool
        public let matchIsBest: Bool

        enum CodingKeys: String, CodingKey {
            case aggregateTradeId = "a"
            case price = "p"
            case quantity = "q"
            case firstTradeId = "f"
            case lastTradeId = "l"
            case timestamp = "T"
            case makerIsBuyer = "m"
            case matchIsBest = "M"
        }
    }

    public typealias Response = [Element]
}

/// Kline/candlestick bars for a `symbol`. Klines are uniquely identified by their open time.
/// If `startTime` and `endTime` are not set the most recent klines are returned.
public struct BinanceCandlesticksRequest: BinanceRequest {
    public static let endpoint = "v1/klines"
    public static let method: HTTPMethod = .get

    public let symbol: String
    public let interval: BinanceCandlesticksInterval
    /// Default = 500; Max = 500.
    public let limit: Int32?
    public let startTime: Date?
    public let endTime: Date?

    public init(symbol: String, interval: BinanceCandlesticksInterval, limit: Int32? = nil, startTime: Date? = nil, endTime: Date? = nil) {
        self.symbol = symbol
        self.interval = interval
        self.limit = limit != 0 ? limit : nil
        self.startTime = startTime
        self.endTime = endTime
    }

    public struct Element: Decodable {
        public let openTime: Date
        public let open: Decimal
        public let high: Decimal
        public let low: Decimal
        public let close: Decimal
        public let assetVolume: Decimal
        public let closeTime: Date
        public let quoteVolume: Decimal
        public let trades: UInt64
        public let buyAssetVolume: Decimal
        public let buyQuoteVolume: Decimal
        public let ignored: String?

        public init(from decoder: Decoder) throws {
            var values = try decoder.unkeyedContainer()
            self.openTime = try values.decode(Date.self)
            self.open = try values.decode(Decimal.self)
            self.high = try values.decode(Decimal.self)
            self.low = try values.decode(Decimal.self)
            self.close = try values.decode(Decimal.self)
            self.assetVolume = try values.decode(Decimal.self)
            self.closeTime = try values.decode(Date.self)
            self.quoteVolume = try values.decode(Decimal.self)
            self.trades = try values.decode(UInt64.self)
            self.buyAssetVolume = try values.decode(Decimal.self)
            self.buyQuoteVolume = try values.decode(Decimal.self)
            self.ignored = try values.decodeIfPresent(String.self)
        }
    }

    public typealias Response = [Element]
}

/// 24 hour price change statistics for a `symbol`.
public struct Binance24HourTickerRequest: BinanceRequest, Codable {
    public static let endpoint = "v1/ticker/24hr"
    public static let method: HTTPMethod = .get

    public init(symbol: String) {
        self.symbol = symbol
    }
    
    public let symbol: String

    public struct Response: Codable {
        public let priceChange: Decimal
        public let priceChangePercent: Decimal
        public let weightedAvgPrice: Decimal
        public let prevClosePrice: Decimal
        public let lastPrice: Decimal
        public let bidPrice: Decimal
        public let askPrice: Decimal
        public let openPrice: Decimal
        public let highPrice: Decimal
        public let lowPrice: Decimal
        public let volume: Decimal
        public let quoteVolume: Decimal
        public let openTime: Date
        public let closeTime: Date
        public let firstId: UInt64
        public let lastId: UInt64
        public let count: UInt64
    }
}

/// Latest `price` for all `symbol`s.
public struct BinanceAllPricesRequest: BinanceRequest, Codable {
    public static let endpoint = "v3/ticker/price"
    public static let method: HTTPMethod = .get

    public init () {}
    
    public struct Response: Decodable {
        public let elements: [String: Decimal]

        public init(from decoder: Decoder) throws {
            var dict = [String: Decimal]()
            var container = try decoder.unkeyedContainer()
            if let count = container.count {
                dict.reserveCapacity(count)
            }
            while !container.isAtEnd {
                let e = try container.decode(ResponseElement.self)
                dict[e.symbol] = e.price
            }
            self.elements = dict
        }

        private struct ResponseElement: Codable {
            public let symbol: String
            public let price: Decimal
        }
    }
}

/// Best price/quantity on the order book for all `symbol`s.
public struct BinanceAllBookTickersRequest: BinanceRequest, Codable {
    public static let endpoint = "v1/ticker/allBookTickers"
    public static let method: HTTPMethod = .get

    public init () {}
    
    public struct Element: Codable {
        public let bidPrice: Decimal
        public let bidQuantity: Decimal
        public let askPrice: Decimal
        public let askQuantity: Decimal
    }

    public struct Response: Decodable {
        let elements: [String: Element]

        public init(from decoder: Decoder) throws {
            var dict = [String: Element]()
            var container = try decoder.unkeyedContainer()
            if let count = container.count {
                dict.reserveCapacity(count)
            }
            while !container.isAtEnd {
                let e = try container.decode(ResponseElement.self)
                dict[e.symbol] = Element(bidPrice: e.bidPrice, bidQuantity: e.bidQuantity, askPrice: e.askPrice, askQuantity: e.askQuantity)
            }
            self.elements = dict
        }

        private struct ResponseElement: Codable {
            public let symbol: String
            public let bidPrice: Decimal
            public let bidQuantity: Decimal
            public let askPrice: Decimal
            public let askQuantity: Decimal

            enum CodingKeys: String, CodingKey {
                case symbol, bidPrice
                case bidQuantity = "bidQty"
                case askPrice
                case askQuantity = "askQty"
            }
        }
    }
}

// MARK: Account endpoints

/// Send in a new order.
public struct BinanceNewOrderRequest: BinanceSignedRequest, Codable {
    public static let endpoint = "v3/order"
    public static let method = HTTPMethod.post
    
    public let symbol: String
    public let side: BinanceOrderSide
    public let type: BinanceOrderType
    /// Should not be sent for a market order.
    public let timeInForce: BinanceOrderTime?
    public let quantity: Decimal
    /// Should not be sent for a market order.
    public let price: Decimal?
    /// A unique id for the order. Automatically generated if not sent.
    public let newClientOrderId: String?
    /// Used with stop orders.
    public let stopPrice: Decimal?
    /// Used with iceberg orders.
    public let icebergQuantity: Decimal?
    public let timestamp: Date

    public init(symbol: String, side: BinanceOrderSide, type: BinanceOrderType, quantity: Decimal,
                price: Decimal? = nil, timeInForce: BinanceOrderTime? = nil, newClientOrderId: String? = nil,
                stopPrice: Decimal? = nil, icebergQuantity: Decimal? = nil, timestamp: Date = Date()) {
        self.symbol = symbol
        self.side = side
        self.type = type
        self.quantity = quantity
        self.newClientOrderId = newClientOrderId
        self.stopPrice = stopPrice
        self.icebergQuantity = icebergQuantity
        self.timestamp = timestamp

        switch type {
        case .limit:
            assert(timeInForce != nil, "timeInForce should not be nil for a limit order")
            self.timeInForce = timeInForce
            assert(price != nil, "price should not be nil for a limit order")
            self.price = price
            break
        case .market:
            self.timeInForce = nil
            self.price = nil
            break
        }
    }

    enum CodingKeys: String, CodingKey {
        case symbol, side, type, timeInForce, quantity, price, newClientOrderId, stopPrice
        case icebergQuantity = "icebergQty"
        case timestamp
    }

    public struct Response: Codable {
        public let symbol: String
        public let orderId: UInt64
        public let clientOrderId: String
        public let transactTime: Date
    }
}

/// Test new order creation.
/// Creates and validates a new order but does not send it into the matching engine.
public struct BinanceTestNewOrderRequest: BinanceSignedRequest, Codable {
    public static let endpoint = "v3/order/test"
    public static let method = HTTPMethod.post

    public let symbol: String
    public let side: BinanceOrderSide
    public let type: BinanceOrderType
    /// Should not be sent for a market order.
    public let timeInForce: BinanceOrderTime?
    public let quantity: Decimal
    /// Should not be sent for a market order.
    public let price: Decimal?
    /// A unique id for the order. Automatically generated if not sent.
    public let newClientOrderId: String?
    /// Used with stop orders.
    public let stopPrice: Decimal?
    /// Used with iceberg orders.
    public let icebergQuantity: Decimal?
    public let timestamp: Date

    public init(symbol: String, side: BinanceOrderSide, type: BinanceOrderType, quantity: Decimal,
                price: Decimal? = nil, timeInForce: BinanceOrderTime? = nil, newClientOrderId: String? = nil,
                stopPrice: Decimal? = nil, icebergQuantity: Decimal? = nil, timestamp: Date = Date()) {
        self.symbol = symbol
        self.side = side
        self.type = type
        self.quantity = quantity
        self.newClientOrderId = newClientOrderId
        self.stopPrice = stopPrice
        self.icebergQuantity = icebergQuantity
        self.timestamp = timestamp

        switch type {
        case .limit:
            assert(timeInForce != nil, "timeInForce should not be nil for a limit order")
            self.timeInForce = timeInForce
            assert(price != nil, "price should not be nil for a limit order")
            self.price = price
            break
        case .market:
            self.timeInForce = nil
            self.price = nil
            break
        }
    }

    enum CodingKeys: String, CodingKey {
        case symbol, side, type, timeInForce, quantity, price, newClientOrderId, stopPrice
        case icebergQuantity = "icebergQty"
        case timestamp
    }
    
    public struct Response: Codable {}
}

/// Check an order's status.
/// Either `orderId` or `originalClientOrderId` must be sent.
public struct BinanceQueryOrderRequest: BinanceSignedRequest, Codable {
    public static let endpoint = "v3/order"
    public static let method = HTTPMethod.get

    public let symbol: String
    public let orderId: UInt64?
    public let originalClientOrderId: String?
    public let timestamp: Date

    public init(symbol: String, orderId: UInt64? = nil, originalClientOrderId: String? = nil, timestamp: Date = Date()) {
        assert((orderId != nil && orderId != 0) || originalClientOrderId != nil, "Either orderId or originalClientOrderId must be provided")
        self.orderId = orderId != 0 ? orderId : nil
        self.symbol = symbol
        self.originalClientOrderId = originalClientOrderId
        self.timestamp = timestamp
    }

    enum CodingKeys: String, CodingKey {
        case symbol, orderId
        case originalClientOrderId = "origClientOrderId"
        case timestamp
    }

    public typealias Response = BinanceOrder
}

public struct BinanceCancelOrderRequest: BinanceSignedRequest, Codable {
    public static let endpoint = "v3/order"
    public static let method: HTTPMethod = .delete

    public let symbol: String
    public let orderId: UInt64?
    public let originalClientOrderId: String?
    /// Used to uniquely identify this cancel. Automatically generated by default.
    public let newClientOrderId: String?
    public let timestamp: Date

    public init(symbol: String, orderId: UInt64? = nil, originalClientOrderId: String? = nil, newClientOrderId: String? = nil, timestamp: Date = Date()) {
        self.symbol = symbol
        self.orderId = orderId != 0 ? orderId : nil
        self.originalClientOrderId = originalClientOrderId
        self.newClientOrderId = newClientOrderId
        self.timestamp = timestamp
    }

    enum CodingKeys: String, CodingKey {
        case symbol, orderId
        case originalClientOrderId = "origClientOrderId"
        case newClientOrderId, timestamp
    }

    public struct Response: Codable {
        public let symbol: String
        public let origClientOrderId: String
        public let orderId: UInt64
        public let clientOrderId: String
    }
}

/// Get all open orders for a `symbol`.
public struct BinanceOpenOrdersRequest: BinanceSignedRequest, Codable {
    public static let endpoint = "v3/openOrders"
    public static let method = HTTPMethod.get

    public let symbol: String
    public let timestamp: Date

    public init(symbol: String, timestamp: Date = Date()) {
        self.symbol = symbol
        self.timestamp = timestamp
    }

    public typealias Response = [BinanceOrder]
}

/// Get all account orders: active, canceled, or filled.
/// If `orderId` is set it will get orders >= `orderId`. Otherwise the most recent orders are returned.
public struct BinanceAllOrdersRequest: BinanceSignedRequest, Codable {
    public static let endpoint = "v3/allOrders"
    public static let method = HTTPMethod.get

    public let symbol: String
    public let orderId: UInt64?
    /// Default = 500; Max = 500.
    public let limit: Int32?
    public let timestamp: Date

    public init(symbol: String, orderId: UInt64? = nil, limit: Int32? = nil, timestamp: Date = Date()) {
        self.symbol = symbol
        self.orderId = orderId != 0 ? orderId : nil
        self.limit = limit != 0 ? limit : nil
        self.timestamp = timestamp
    }

    public typealias Response = [BinanceOrder]
}

/// Get current account information.
public struct BinanceAccountInformationRequest: BinanceSignedRequest {
    public static let endpoint = "v3/account"
    public static let method: HTTPMethod = .get

    public let timestamp: Date

    public init(timestamp: Date = Date()) {
        self.timestamp = timestamp
    }

    public struct Response: Decodable {
        /// Given in basis points (0.01% each)
        public let makerCommission: Int16
        /// Given in basis points (0.01% each)
        public let takerCommission: Int16
        /// Given in basis points (0.01% each)
        public let buyerCommission: Int16
        /// Given in basis points (0.01% each)
        public let sellerCommission: Int16
        public let canTrade: Bool
        public let canWithdraw: Bool
        public let canDeposit: Bool
        public let balances: [String: (free: Decimal, locked: Decimal, total: Decimal)]

        public init(from decoder: Decoder) throws {
            let dict = try decoder.container(keyedBy: CodingKeys.self)
            self.makerCommission = try dict.decode(type(of: self.makerCommission), forKey: .makerCommission)
            self.takerCommission = try dict.decode(type(of: self.takerCommission), forKey: .takerCommission)
            self.buyerCommission = try dict.decode(type(of: self.buyerCommission), forKey: .buyerCommission)
            self.sellerCommission = try dict.decode(type(of: self.sellerCommission), forKey: .sellerCommission)
            self.canTrade = try dict.decode(type(of: self.canTrade), forKey: .canTrade)
            self.canWithdraw = try dict.decode(type(of: self.canWithdraw), forKey: .canWithdraw)
            self.canDeposit = try dict.decode(type(of: self.canDeposit), forKey: .canDeposit)

            var balances = try dict.nestedUnkeyedContainer(forKey: .balances)
            var decodedBalances = [String: (free: Decimal, locked: Decimal, total: Decimal)]()
            while (!balances.isAtEnd) {
                let entry = try balances.decode(BalanceEntry.self)
                if entry.free > 0 || entry.locked > 0 {
                    decodedBalances[entry.asset] = (free: entry.free, locked: entry.locked, total: entry.free + entry.locked)
                }
            }
            self.balances = decodedBalances
        }

        public struct BalanceEntry: Codable {
            public let asset: String
            public let free: Decimal
            public let locked: Decimal
        }

        enum CodingKeys: String, CodingKey {
            case makerCommission, takerCommission,buyerCommission, sellerCommission
            case canTrade, canWithdraw, canDeposit, balances
        }
    }
}

/// Get account trades for a specific `symbol`.
public struct BinanceAccountTradeListRequest: BinanceSignedRequest, Codable {
    public static let endpoint = "v3/myTrades"
    public static let method: HTTPMethod = .get

    public let symbol: String
    /// Default = 500; Max = 500.
    public let limit: Int32?
    /// tradeId to fetch from. Otherwise gets most recent trades.
    public let fromId: UInt64?
    public let timestamp: Date

    public init(symbol: String, limit: Int32? = nil, fromId: UInt64? = nil, timestamp: Date = Date()) {
        self.symbol = symbol
        self.limit = limit
        self.fromId = fromId
        self.timestamp = timestamp
    }

    public struct Element: Codable {
        public let id: UInt64
        public let price: Decimal
        public let quantity: Decimal
        public let commission: Decimal
        public let commissionAsset: String
        public let time: Date
        public let isBuyer: Bool
        public let isMaker: Bool
        public let isBestMatch: Bool

        enum CodingKeys: String, CodingKey {
            case id, price
            case quantity = "qty"
            case commission, commissionAsset, time, isBuyer, isMaker, isBestMatch
        }
    }

    public typealias Response = [Element]
}

// TODO: Websocket endpoints
