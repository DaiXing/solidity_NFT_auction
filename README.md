## 

## NFT 拍卖 

拍卖接口 IAuction

拍卖V1 AuctionContractV1

拍卖V2 AuctionContractV2

代理  ERC1967Proxy

NFT MySimpleNFT

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






