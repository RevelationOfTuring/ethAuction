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
    }
    enum ProductStatus {OPEN,SOLD,UNSOLD}
    enum ProductCondition {USED,NEW}
    
    mapping(address=>mapping(uint=>Product)) stores;
    
    mapping(uint=>address) public productIdToOwmer;
    
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
            condition:_condition
        });
        
        stores[msg.sender][productIndex]=pro;
        productIdToOwmer[productIndex]=msg.sender;
    }
    //test function
    function getProductById(uint _index)public view returns(uint,string memory,string memory,string memory,
    string memory,uint,uint,uint,ProductStatus,ProductCondition){
        address owner = productIdToOwmer[_index];
        Product memory pro = stores[owner][_index];
        return (pro.id,pro.name,pro.category,pro.imageLink,pro.descLink,pro.startPrice,pro.auctionStartTime,
        pro.auctionEndTime,pro.status,pro.condition);
    }
    
}

