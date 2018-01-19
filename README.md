#  Objective-C & Swift 4 Binance API

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

This library enables access to the [Binance REST API](https://www.binance.com/restapipub.html) from an Objective-C or Swift program. It supports unsigned acess to  `v1/api` and signed access to `v3/api` . The Objective-C version returns a lightly-typed `NSDictionary` or `NSArray` of results. For optional numeric parameters you may pass `0` for omission. The Swift version creates a `Alamofire.URLConvertible request` that returns a strongly-typed `struct`.

## Installation

### [Carthage](https://github.com/Carthage/Carthage)

Add the repository to your `Cartfile`:

```
github "dpyro/BinanceApi"
```

Then update your built frameworks.

```shell
$ carthage update
```

Drag the built `BinanceApi.framework` into your Xcode project.

## Usage

### Getting Started

#### API object for signed and unsigned endpoints

##### Objective-C

```objc
BinanceApi *api = [[BinanceApi alloc] initWithApiKey:@"<apikey>" secretKey:@"<secretkey>"];
```

##### Swift

```swift
let api = BinanceApi(apiKey: "<apikey>", secretKey: "<secretkey>")
```

#### API object for just unsigned endpoints

##### Objective-C

```objc
BinanceApi *api = [[BinanceApi alloc] init];
```

##### Swift

```swift
let api = BinanceApi()
```

### Get latest price for all symbols

#### Objective-C

```objc
[api allPricesWithResponseHandler:^(NSDictionary<NSString *,NSDecimalNumber *> * _Nullable result, NSError * _Nullable error) {
    if (error != nil) {
        return;
    }

    for (NSString *symbol in result) {
        NSLog(@"%@: %@", symbol, [result valueForKey:symbol]);
    }
}];
```

#### Swift

```swift
let api = BinanceApi()
let request = BinanceAllPricesRequest()

api.send(request) { response in
    assert(response.result.isSuccess)

    let elements = response.result.value!.elements
    for (symbol, price) in elements {
        print("\(symbol): \(price)")
    }
}
```

### Get market spread for all symbols

#### Objective-C

```objc
[api allBookTickersWithResponseHandler:^(NSDictionary<NSString *, id> * _Nullable result, NSError * _Nullable error) {
    if (error != nil) {
        return;
    }

    for (NSString *asset in result) {
        NSDictionary *dict = [result valueForKey:asset];
        NSDecimalNumber *bidPrice = [dict valueForKey:@"bidPrice"];
        NSDecimalNumber *bidQuantity = [dict valueForKey:@"bidQuantity"];
        NSDecimalNumber *askPrice = [dict valueForKey:@"askPrice"];
        NSDecimalNumber *askQuantity = [dict valueForKey:@"askQuantity"];
        NSLog(@"%@: %@ @ %@ - %@ @ %@", asset, bidPrice, bidQuantity, askPrice, askQuantity);
    }
}];
```

#### Swift

```swift
let request = BinanceAllBookTickersRequest()

api.send(request) { response in
    assert(response.result.isSuccess)

    let elements = response.result.value!.elements
    for (asset, prices) in elements {
        let bidPrice = prices.bidPrice
        let bidQuantity = prices.bidQuantity
        let askPrice = prices.askPrice
        let askQuantity = prices.askQuantity
        print("\(asset): \(bidPrice) @ \(bidQuantity) - \(askPrice) @ \(askQuantity)")
    }
}
```

### Get market depth for a symbol

#### Objective-C

```objc
[api depthWithSymbol:@"ETHBTC" limit:0 responseHandler:^(NSDictionary<NSString *,id> * _Nullable result, NSError * _Nullable error) {
    if (error != nil) {
        return;
    }

    NSLog(@"lastUpdateId: %@", [result valueForKey:@"lastUpdateId"]);
    NSLog(@"bids: %@", [result valueForKey:@"bids"]);
    NSLog(@"asks: %@", [result valueForKey:@"asks"]);
}];
```

#### Swift

```swift
let symbol = "ETHBTC"
let request = BinanceDepthRequest(symbol: symbol)

api.send(request) { response in
    assert(response.result.isSuccess)

    let value = response.result.value!
    print("lastUpdateId: \(value.lastUpdateId)")
    print("bids: \(value.bids)")
    print("asks: \(value.asks)")
}
```

### Get current balances

#### Objective-C

```objc
[api accountInformationWithResponseHandler:^(NSDictionary<NSString *,id> * _Nullable result, NSError * _Nullable error) {
    if (error != nil) {
        return;
    }

    NSDictionary<NSString *, NSDictionary<NSString *, NSDecimalNumber *> *> *balances = [result valueForKey:@"balances"];
    NSLog(@"Balances");

    for (NSString *asset in balances) {
        NSDictionary<NSString *, NSDecimalNumber *> *balance = [balances valueForKey:asset];
        NSLog(@"%@ %@", [balance valueForKey:@"total"], asset); // "free" and "locked" are also available keys
    }
}];
```

#### Swift

```swift
api.send(request) { response in
    assert(response.result.isSuccess)

    let account = response.result.value!
    let balances = account.balances
    for (asset, balance) in balances {
        print("\(balance.total) \(asset)")
    }
}
```

### Place an order

#### Objective-C

```objc
[api testNewOrderWithSymbol:@"ETHBTC" side:BinanceOrderSide.Buy type:BinanceOrderType.Market timeInForce:nil quantity:Decimal(string: "1.1") price:nil newClientOrderId:nil stopPrice:nil icebergQuantity:nil responseHandler:^(NSError * _Nullable error) {
    if (error != nil) {
        return;
    }
}];
```

#### Swift

```swift
let request = BinanceTestNewOrderRequest(
    symbol: "ETHBTC",
    side: .buy,
    type: .market,
    quantity: Decimal(string: "1.1")!)

api.send(request) { response in
    assert(response.result.isSuccess)
}
```

### Query an order's status

```objc
NSString *symbol = @"<order symbol>";
UInt64 orderId = <order id>;

[api queryOrderWithSymbol:symbol orderId:orderId originalClientOrderId:nil responseHandler:^(NSDictionary<NSString *,id> * _Nullable result, NSError * _Nullable error) {
    if (error != nil) {
        return
    }

    NSLog(@"%@: %@", [result valueForKey:@"symbol"], [result valueForKey:@"status"]);
}];
```


```swift
let request = BinanceQueryOrderRequest(symbol: self.querySymbol, orderId: self.queryOrderId)

api.send(request) { response in
    assert(response.result.isSuccess)

    let order = response.result.value!
    print(order)
}
```

### Cancel an order

#### Objective-C

```objc
NSString *symbol = @"<order symbol>";
UInt64 orderId = <order id>;

[api cancelOrderWithSymbol:symbol orderId:orderId originalClientOrderId:nil newClientOrderId:nil responseHandler:^(NSDictionary<NSString *,id> * _Nullable result, NSError * _Nullable error) {
    XCTAssertNil(error);
    XCTAssert(result);

    UInt64 orderId = [[result valueForKey:@"orderId"] unsignedLongLongValue];
    NSLog(@"Cancelled order #%llu", orderId);
}];
```

#### Swift

```swift
let symbol = "<order symbol>"
let orderId = UInt64(<order id>)
let request = BinanceCancelOrderRequest(symbol: symbol, orderId: orderId)

api.send(request) { response in
    assert(request.result.isSuccess)

    let value = response.result.value!
    print("Cancelled order #\(value.orderId)")
}
```

## Testing & Examples

Both an Objective-C and Swift test suite are included. You can use the test code as an example for integration this library. You will need to insert your own apikey, secretkey, and order to query to test the signed endpoints. The new order (not the test version) and cancel order endpoints in the test suite *will* execute on the market but are disabled by default.
