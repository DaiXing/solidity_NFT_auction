# NFT 拍卖 

拍卖平台，拍卖不同的NFT。

创建拍卖。设置NFT物品，时间范围，起拍价等。

参与拍卖。多人出价，价高者优先。

结束拍卖。如果有人出价，则成功，NFT物品给出价者，金钱给卖家；否则，失败。

## 结构

合约： https://github.com/DaiXing/solidity_NFT_auction

后台： https://github.com/DaiXing/go_NFT_auction

## 合约

拍卖接口 IAuction

拍卖合约V1 AuctionContractV1

拍卖合约V2 AuctionContractV2

代理合约  ERC1967Proxy

NFT合约 MySimpleNFT

## 单测

执行   forge test --gas-report  -vvvvv > test.result.txt

单测结果  test.result.txt

执行   forge coverage --ir-minimum > test.cover.txt 

单测覆盖率 test.cover.txt 

## 部署

环境变量，配置：

export ETH_PRIVATE_KEY=xxx

export ETH_RPC_URL=http://127.0.0.1:8545

部署到网络：

forge script script/Auction.s.sol --rpc-url $ETH_RPC_URL --broadcast

forge script script/MyNft.s.sol --rpc-url $ETH_RPC_URL --broadcast




