pragma solidity ^0.5.0;

contract Auction {
    uint productIndex;
    struct Product{
        uint id;
        string name;
        string category;
        //hash of pic
        string imageLink;
        //hash of description
        string descLink;

        uint startPrice;
        uint auctionStartTime;
        uint auctionEndTime;
        //status if the product
        ProductStatus status;
        //new or used
        ProductCondition condition;

        uint highestBid;
        uint secondHighestBid;
        address payable highestBidder;
        uint totalBids;
        //everyone could bid many times. bytes32 is the hash of the ideal price and the password
        mapping(address=>mapping(bytes32=>Bid)) bids;
    }
    enum ProductStatus {OPEN,SOLD,UNSOLD}
    enum ProductCondition {USED,NEW}

    mapping(address=>mapping(uint=>Product)) stores;

    mapping(uint=>address payable) public productIdToOwmer;

    function addProductToStore(
    string memory _name,
    string memory _category,
    string memory _imageLink,
    string memory _descLink,
    uint _startPrice,
    uint _auctionStartTime,
    uint _auctionEndTime,
    ProductCondition _condition) public{
        productIndex++;
        Product memory pro =  Product({
            id:productIndex,
            name:_name,
            category:_category,
            imageLink:_imageLink,
            descLink:_descLink,
            startPrice:_startPrice,
            auctionStartTime:_auctionStartTime,
            auctionEndTime:_auctionEndTime,
            status:ProductStatus.OPEN,
            condition:_condition,
            highestBid:0,
            secondHighestBid:0,
            highestBidder:address(0),
            totalBids:0
        });

        stores[msg.sender][productIndex]=pro;
        productIdToOwmer[productIndex]=msg.sender;
    }
    //test function
    // function getProductById(uint _index)public view returns(uint,string memory,string memory,string memory,
    // string memory,uint,uint,uint,ProductStatus,ProductCondition){
    //     address owner = productIdToOwmer[_index];
    //     Product memory pro = stores[owner][_index];
    //     return (pro.id,pro.name,pro.category,pro.imageLink,pro.descLink,pro.startPrice,pro.auctionStartTime,
    //     pro.auctionEndTime,pro.status,pro.condition);
    // }

    struct Bid {
        uint productId;
        uint price2Show;
        bool isRevealed;
        address bidder;
    }



    function bid(uint _productIndex,uint _idealPrice,string memory _password) public payable{
        bytes memory bidInfo = abi.encodePacked(_idealPrice,_password);
        bytes32 bytesInfo = keccak256(bidInfo);

        //get the storage style of the Product,to change the "totalBids"
        address owner = productIdToOwmer[_productIndex];
        Product storage product = stores[owner][_productIndex];
        product.totalBids++;

        Bid memory b = Bid(_productIndex, msg.value, false, msg.sender);
        product.bids[msg.sender][bytesInfo]=b;


    }

    //test function
    // function getBidById(uint _productIndex,uint _idealPrice,string memory _password)
    // public view returns(uint,uint,bool,address){
    //     address owner = productIdToOwmer[_productIndex];
    //     bytes memory bidInfo = abi.encodePacked(_idealPrice,_password);
    //     bytes32 bidBytes = keccak256(bidInfo);
    //     Product storage pro = stores[owner][_productIndex];
    //     Bid memory b = pro.bids[msg.sender][bidBytes];
    //     return (b.productId,b.price2Show,b.isRevealed,b.bidder);
    // }

    function getBalance() public view returns(uint){
        return address(this).balance;
    }


    event revealEvent(uint _productIndex,bytes32 bidBytes,uint highestBid,uint sencondHighestBid,uint refund);

    function revealBid(uint _productIndex,uint _idealPrice,string memory password)public {
        address owner = productIdToOwmer[_productIndex];
        Product storage pro = stores[owner][_productIndex];

        bytes memory bidInfo = abi.encodePacked(_idealPrice,password);
        bytes32 bidBytes = keccak256(bidInfo);

        Bid storage curBid =pro.bids[msg.sender][bidBytes];
        //check
        require(!curBid.isRevealed);
        //this bid is found,show that ur password is right
        require(curBid.bidder!=address(0));
        curBid.isRevealed=true;

        uint confusedPrice = curBid.price2Show;
        uint idealPrice = _idealPrice;
        uint refund = 0;

        if(confusedPrice<idealPrice){
            refund = confusedPrice;
        }else{
            if(idealPrice>pro.highestBid){
                //the first one to reveal bid
                if(pro.highestBidder==address(0)){
                    //update the product
                    pro.highestBid=idealPrice;
                    pro.secondHighestBid=pro.startPrice;
                    pro.highestBidder=msg.sender;
                    refund = confusedPrice - idealPrice;
                }else{
                    pro.highestBidder.transfer(pro.highestBid);
                    pro.secondHighestBid = pro.highestBid;
                    pro.highestBid = idealPrice;
                    pro.highestBidder=msg.sender;
                    refund = confusedPrice-idealPrice;
                }
            }else{
                //
                if(idealPrice>pro.secondHighestBid){
                    pro.secondHighestBid = idealPrice;
                }
                refund = confusedPrice;
            }
        }


        if(refund>0){
            msg.sender.transfer(refund);
        }
        emit revealEvent(_productIndex,bidBytes,pro.highestBid,pro.secondHighestBid,refund);
    }

    function getInfoBack(uint _productIndex) public view returns(address,uint,uint,uint){
        Product storage pro = stores[productIdToOwmer[_productIndex]][_productIndex];
        return (pro.highestBidder,pro.highestBid,pro.secondHighestBid,pro.totalBids);
    }

    mapping(uint=>Arbitration) proIndex2Arbitration;

    function finalizeAuction(uint _productIndex)public payable{
        address payable seller = productIdToOwmer[_productIndex];
        Product storage pro = stores[seller][_productIndex];
        address payable buyer = pro.highestBidder;
        address payable arbitrator = msg.sender;

        require(arbitrator!=seller && arbitrator!=buyer);
        //you can't finalize the auction before the end of bidding
        //require(now>=pro.auctionEndTime);
        require(pro.status==ProductStatus.OPEN);

        if(pro.totalBids==0){
            pro.status=ProductStatus.UNSOLD;
        }else{
            pro.status=ProductStatus.SOLD;
        }

        Arbitration arb = (new Arbitration).value(pro.highestBid)(arbitrator,seller,buyer);

        proIndex2Arbitration[_productIndex]=arb;

        buyer.transfer(pro.highestBid-pro.secondHighestBid);
    }


}

contract Arbitration{
    address payable arbitrator;
    address payable seller;
    address payable buyer;
    uint totalVotes2Seller;
    uint totalVotes2Buyer;
    bool isSpent ;

    //show whether an address is voted
    mapping(address=>bool) isAddressVoted;

    constructor(address payable _arbitrator,address payable _seller,address payable _buyer)public payable{
        arbitrator=_arbitrator;
        seller=_seller;
        buyer=_buyer;
    }

    function getBalance()public view returns(uint){
        return address(this).balance;
    }

    function getAritrationInfo()public view returns(address,address,address,uint,uint){
        return (arbitrator,seller,buyer,totalVotes2Seller,totalVotes2Buyer);
    }

    modifier callerLimit(address _operator){
        require(_operator == arbitrator || _operator == seller || _operator == buyer);
        _;
    }

    function vote2Seller(address _operator) public callerLimit(_operator) {
        require(!isSpent);
        require(!isAddressVoted[_operator]);
        isAddressVoted[_operator]=true;

        if(++totalVotes2Seller==2){
            isSpent=true;
            seller.transfer(address(this).balance);
        }
    }

    function vote2Buyer(address _operator) public callerLimit(_operator) {
        require(!isSpent);
        require(!isAddressVoted[_operator]);
        isAddressVoted[_operator]=true;

        if(++totalVotes2Buyer==2){
            isSpent=true;
            buyer.transfer(address(this).balance);
        }
    }
}

