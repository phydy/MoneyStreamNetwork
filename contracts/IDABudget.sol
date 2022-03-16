// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;
contract TreeFactory {

    event Deployed(address addr, uint salt);

    function getBytecode(
        address _host,
        address _cfa,
        address _ida,
        address _acceptedToken
    ) public pure returns (bytes memory) {
        bytes memory bytecode = type(TreeBudgetNFT).creationCode;

        return abi.encodePacked(
            bytecode,
            abi.encode(
                _host,
                _cfa,
                _ida,
                _acceptedToken
            )
        );
    }


    function getAddress(bytes memory bytecode, uint _salt)
        public
        view
        returns (address)
    {
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode))
        );

        // NOTE: cast last 20 bytes of hash to address
        return address(uint160(uint(hash)));
    }



    // 3. Deploy the contract
    // NOTE:
    // Check the event log Deployed which contains the address of the deployed TestContract.
    // The address in the log should equal the address computed from above.
    function deploy(bytes memory bytecode, uint _salt) public payable {
        address addr;

        /*
        NOTE: How to call create2

        create2(v, p, n, s)
        create new contract with code at memory p to p + n
        and send v wei
        and return the new address
        where new address = first 20 bytes of keccak256(0xff + address(this) + s + keccak256(mem[p…(p+n)))
              s = big-endian 256-bit value
        */
        assembly {
            addr := create2(
                callvalue(), // wei sent with current call
                // Actual code starts after skipping the first 32 bytes
                add(bytecode, 0x20),
                mload(bytecode), // Load the size of code contained in the first 32 bytes
                _salt // Salt from function arguments
            )

            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }

        emit Deployed(addr, _salt);
    }
}


pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


import {
    ISuperfluid,
    ISuperToken,
    ISuperApp,
    ISuperAgreement,
    SuperAppDefinitions
} from "@superfluid/interfaces/superfluid/ISuperfluid.sol";

import {SuperAppBase} from "@superfluid/apps/SuperAppBase.sol";

import {
    IInstantDistributionAgreementV1
} from "@superfluid/interfaces/agreements/IInstantDistributionAgreementV1.sol";

import {IMarketPlace} from "../interfaces/IMarketPlace.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract IDABudgetNFT is ERC1155 , Ownable, ReentrancyGuard {

    ISuperfluid private _host; // host
    //IInstantDistributionAgreementV1 private _ida;
    
    ISuperToken public _acceptedToken; // accepted token
    address flowSource;
    IMarketPlace marketPlace;
    

    uint256 public constant MOTHER = 0;
    uint256 public constant CHILD = 1;
    uint256 public constant GRANDCHILD = 2;


    mapping(uint => uint) private IdToNumber; //tracks the number ids of all tokens
    mapping(uint => uint[]) public mothersTokens; //an array of ids of all tokens linked to the mother ie child tokens
    mapping(uint => uint[]) public childsTokens; //an array of ids of all tokens linked to the child ie grand child tokens

    mapping(address => uint32) public souceToIndex;

    mapping(uint => address) public tokenIdSource;

    mapping(address => uint) public addressMotherId;//an address to the mother token id owned
    mapping(address => uint) public addressChildId;//an address to a child token Id owned
    
    mapping(uint256 => uint32) public tokenIdIndex;//the id of the token that owns the index

    mapping(uint32 => IndexInfo) public indexInformation;

    uint private round;
    uint private constant freequency = 30 days;

    mapping(uint => mapping(uint32 => uint)) private roundIndexDistribution;

    struct TokenInfo {
        uint256 tokenParent;
        uint32 index;
        address tokenOwner;
        uint128 units;
        bool conceived;
        bool forSale;
        uint256 price;
        uint lifeSpan;
    }

    struct MotherInfo {
        address tokenParent;
        address tokenOwner;
        uint256 children;
        uint totalOwed;
    }

    struct IndexInfo {
        uint duration;
        uint startTime;
        uint actualAmount;
    }

    mapping(uint => MotherInfo) public idMotherInfo;//mother tpken information
    mapping(uint => TokenInfo) public tokenIdInfo; //child and grandchild information

    
    struct TreeSource {
        int96 totalFlow;
        uint descendants;
    }
    mapping(address =>TreeSource) public source;
    mapping (address => bool) public isSubscribing;




    event childIssued(address indexed _reciever, uint id, address issuer);
    event motherIssued(address indexed _reciever, uint id, address issuer);



    constructor(
        
        ISuperfluid host,
        IConstantFlowAgreementV1 cfa,
        IInstantDistributionAgreementV1 ida,
        ISuperToken acceptedToken
    ) ERC1155("STREAM NETWORK") {
        
        require(address(host) != address(0));
        require(address(cfa) != address(0));
        require(address(acceptedToken) != address(0));
        _host = host;
        _cfa = cfa;
        _ida =ida;
        _acceptedToken = acceptedToken;

        uint256 configWord =
            SuperAppDefinitions.APP_LEVEL_FINAL |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP |
            SuperAppDefinitions.AFTER_AGREEMENT_TERMINATED_NOOP;

        _host.registerApp(configWord);
    }

    function addFlowSource(address _flowSource) external onlyOwner {
        flowSource = _flowSource;
    }

    function addMarket(IMarketPlace _market) external onlyOwner {
        marketPlace = _market;
    }

    function toUnint(int96 _number) internal pure returns(uint256) {
        int256 number = _number;
        return(uint256(number));
    }
    function setTokenPrice(
        uint256 token,
        uint256 id,
        uint256 amount
    ) external nonReentrant {
        require(token == 1 || token == 2, "wrong token");
        require(tokenIdInfo[id].tokenOwner == msg.sender);
        tokenIdInfo[id].forSale = true;
        tokenIdInfo[id].price = amount;
        uint128 units = tokenIdInfo[id].units;
        uint duration = amount/toUnint(flowRate);
        marketPlace.addTokenDetails(
            token,
            id,
            amount,
            units,
            duration,
            msg.sender,
            true
        );
    }

    function getIndexDistributions() private view returns(uint128) {

    }
    function generateToken(
        uint256 price,
        uint128 units,
        uint256 _duration
    ) external returns(uint256) {
        require(balanceOf(msg.sender, 0) == 1, "have a preceding token");
        (, int96 outFlowRate, , ) = _cfa.getFlow(_acceptedToken, address(this), msg.sender);
        require(outFlowRate > flowRate);
        uint id = IdToNumber[1];
        tokenIdInfo[id] = TokenInfo(
            msg.sender,
            address(0),
            units,
            true,
            false,
            price,
            _duration
        );
        IdToNumber[1]++;
        uint amount = toUnint(flowRate);
        marketPlace.addTokenDetails(
            1,
            id,
            amount,
            units,
            _duration,
            msg.sender,
            false
        );
        return id;
    }

    function distributeTokenDebt() external onlySource {
        uint32 index = uint32(addressGChildId[msg.sender]);
        require(block.timestamp >= ((indexInformation[index].startTime) + indexInformation[index].duration));
        _distribute(index, indexInformation[index].actualAmount);
        indexInformation[index].remainingAmount = 0;
        //delete index
    }

    function createMotherTokenIndex(
        int96 flowrate,
        uint256 expiry
    ) external {
        //require(balanceOf(msg.sender, 2) == 1); //one to own a gchild token
        uint actualAmount = toUnint(flowrate) * expiry;//not for production
        uint gchilId = addressGChildId[msg.sender];
        //tokenIdIndex[gchilId] = uint32(gchilId);
        uint32 index = uint32(gchilId);
        //require(actualAmount%distributeAmount == 0, "uneven distribution");
        _host.callAgreement(
            _ida,
            abi.encodeWithSelector(
                _ida.createIndex.selector,
                _acceptedToken,
                index,
                new bytes(0) // placeholder ctx
            ),
            new bytes(0) // user data
        );
        indexInformation[index] = IndexInfo(
            expiry,
            actualAmount,
            actualAmount,
            block.timestamp
        );
        marketPlace.addIndex(
            index,
            expiry,
            actualAmount
        );
    }


    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }
    
    function _trackId(uint256 _id, address idOwner) internal {
        uint secondId = IdToNumber[_id];//the id of the token monted ie MOTHER, CHILD or GRANDCHILD
        idMotherInfo[secondId].tokenOwner = idOwner;
        IdToNumber[_id] +=1;
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public override {
        require(id == 1);
        require(amount == 1);
        uint tokenNumber = addressChildId[from];
        _reduceFlow(from, tokenIdInfo[tokenNumber].flowrate);
        _increaseFlow(to, tokenIdInfo[tokenNumber].flowrate);
        tokenIdInfo[1][tokenNumber].tokenOwner = to;
        addressChildId[to] = tokenNumber;
        delete addressChildId[from];
         delete addressGChildId[from];
        super.safeTransferFrom(from, to, 1, amount, data);

    }
/*
  {
            //change receiver in index
            uint tokenNumber = addressGGchildId[from];
            uint motherNumber = addressGChildId[gGChildTokenIdInfo[tokenNumber].tokenParent];
            uint128 units = gGChildTokenIdInfo[tokenNumber].units;
            updateIndex(uint32(motherNumber), units , to);
            updateIndex(uint32(motherNumber), 0, from);
            gGChildTokenIdInfo[tokenNumber].tokenOwner = to;

    }
*/
    function checkFlowSource(address from) public view returns(int96) {
        (,int96 inflowRate,,) = _cfa.getFlow(_acceptedToken, from, address(this));
        return inflowRate;
    }

    function addTokenSource(uint id, address _source) external onlySource {
        tokenIdSource[id] = _source;
        source[_source].descendants +=1;

    }
    function mintMother(
        address account,
        int96 _flowRate,
        bytes memory data
    )
        external
        onlySource
        returns(uint256)
    {   
        require(account != msg.sender);
        require(balanceOf(account, 0) == 0, "only one allowed");
        //require(checkFlowSource(msg.sender) >= _flowRate);
        idMotherInfo[addressMotherId[account]].flowrate = _flowRate;
        addressMotherId[account] = IdToNumber[0];
        createIndex_(uint32(IdToNumber[0]));
        _trackId(0, account);
        idMotherInfo[addressMotherId[account]].flowrate = _flowRate;
        _mint(account, 0, 1, data);
        emit motherIssued(account, addressMotherId[account], msg.sender);
        return addressMotherId[account];
    }

    function mintChild(
        uint id,
        address newOwner,
        bytes memory data
    )
        external onlyMarket nonReentrant
    {   require(tokenIdInfo[id].conceived == true, "not available");
        address flowOwner = tokenIdInfo[id].tokenParent;
        uint motherNumnber = addressMotherId[flowOwner];
        require(newOwner != flowOwner, "owner");
        require(idMotherInfo[motherNumnber].units > tokenIdInfo[id].units, "isuficient fr"); //@dev: flowrate from mother should not be zero
        _mint(newOwner, 1, 1, data);
        addressChildId[newOwner] = id;
        mothersTokens[motherNumnber].push(id);
        tokenIdInfo[id].tokenOwner = newOwner;
        //_trackId(1, msg.sender);
        idMotherInfo[motherNumnber].units -= tokenIdInfo[id].units;

        emit childIssued(flowOwner, addressChildId[newOwner], newOwner);
        
    }


    function createIndex_( uint32 index) private {
        _host.callAgreement(
            _ida,
            abi.encodeWithSelector(
                _ida.createIndex.selecot,
                _acceptedToken,
                index,
                new bytes(0)
            ),
            new bytes(0)
        );
    }

    function _distribute(uint32 id, uint256 actualSum) private {
        _host.callAgreement(
            _ida,
            abi.encodeWithSelector(
                _ida.distribute.selector,
                _acceptedToken,
                id,
                actualSum,
                new bytes(0) // placeholder ctx
            ),
            new bytes(0) // user data
        );
    }


    function updateIndex(uint token, uint128 units, address receiver) private {
        _host.callAgreement(
            _ida,
            abi.encodeWithSelector(
                _ida.updateSubscription.selector,
                _acceptedToken,
                uint32(token),
                receiver,
                units,
                new bytes(0) // placeholder ctx
            ),
            new bytes(0) // user data
        );
    }

    function _checkSubscription(
        ISuperToken superToken,
        bytes calldata ctx,
        bytes32 agreementId
    )
        private
    {
        ISuperfluid.Context memory context = _host.decodeCtx(ctx);
        // only interested in the subscription approval callbacks
        if (context.agreementSelector == IInstantDistributionAgreementV1.approveSubscription.selector) {
            address publisher;
            uint32 indexId;
            bool approved;
            uint128 units;
            uint256 pendingDistribution;
            (publisher, indexId, approved, units, pendingDistribution) =
                _ida.getSubscriptionByID(superToken, agreementId);

            //sanity checks for testing purpose
            //require(publisher == address(this), "DRT: publisher mismatch");
            //require(indexId == tokenIdIndex[tokenId], "DRT: publisher mismatch");

            if (approved) {
                isSubscribing[context.msgSender /* subscriber*/ ] = true;
            }
        }
    }

    //for functions that can only get called from the source contract
    modifier onlySource {
        require(msg.sender == flowSource, "Only source");
        _;
    }

    //for functions that can only be called from the market place 
    modifier onlyMarket {
        require(msg.sender == address(marketPlace), "Only source");
        _;
    }
    function motherInfo(uint id) external view returns(
        address tokenParent,
        address tokenOwner,
        uint128 units,
        uint256 price,
        bool forSale,
        uint lifeSpan
    ) 
    {
        tokenParent = idMotherInfo[id].tokenParent;
        tokenOwner = idMotherInfo[id].tokenOwner;
        lifeSpan = idMotherInfo[id].lifeSpan;
        units = idMotherInfo[id].units;
        forSale = idMotherInfo[id].forSale;
        price = idMotherInfo[id].price;

    }

    function tokenInfo(
        uint id_
    ) external view returns(
        address tokenParent,
        address tokenOwner,
        uint128 units,
        bool conceived,
        bool forSale,
        uint256 price,
        uint lifeSpan
    ) {
        tokenParent = tokenIdInfo[id_].tokenParent;
        tokenOwner = tokenIdInfo[id_].tokenOwner;
        units = tokenIdInfo[id_].units;
        conceived = tokenIdInfo[id_].conceived;
        forSale = tokenIdInfo[id_].forSale;
        price = tokenIdInfo[id_].price;
        lifeSpan = tokenIdInfo[id_].lifeSpan;
    }


    function beforeAgreementCreated(
        ISuperToken superToken,
        address agreementClass,
        bytes32 /* agreementId */,
        bytes calldata /*agreementData */,
        bytes calldata /*ctx */
    )
        external view override
        returns (bytes memory data)
    {
        require(superToken == _acceptedToken, "DRT: Unsupported cash token");
        return new bytes(0);

        
    }
    function afterAgreementCreated(
        ISuperToken superToken,
        address  agreementClass,
        bytes32 agreementId,
        bytes calldata /*agreementData*/,
        bytes calldata /*cbdata*/,
        bytes calldata ctx
    )
        external override
        returns(bytes memory newCtx)
    {   
        if(agreementClass == address(_ida)) return new bytes(0);
        else if (agreementClass == address(_ida)) {
            _checkSubscription(superToken, ctx, agreementId);
            newCtx = ctx;
        }
    }

    function beforeAgreementUpdated(
        ISuperToken superToken,
        address agreementClass,
        bytes32  agreementId ,
        bytes calldata agreementData,
        bytes calldata ctx
    )
        external view override
        returns (bytes memory data)
    {
        require(superToken == _acceptedToken, "DRT: Unsupported cash token");
        return new bytes(0);
        
    }

    function afterAgreementUpdated(
        ISuperToken superToken,
        address  agreementClass,
        bytes32 agreementId,
        bytes calldata /*agreementData*/,
        bytes calldata /*cbdata*/,
        bytes calldata ctx
    )
        external override
        returns(bytes memory newCtx)

    {
        if (agreementClass == address(_cfa)) return new bytes(0);
        else if (agreementClass == address(_ida)) {
            _checkSubscription(superToken, ctx, agreementId);
            newCtx = ctx;
        }
    }
    

/*
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyOwner
    {
        _mintBatch(to, ids, amounts, data);
    }
*/
}
