// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


import {
    ISuperfluid,
    ISuperToken,
    ISuperApp,
    ISuperAgreement,
    SuperAppDefinitions
} from "../supercon/interfaces/superfluid/ISuperfluid.sol";

import {SuperAppBase} from "../supercon/apps/SuperAppBase.sol";

import {
    IConstantFlowAgreementV1
} from "../supercon/interfaces/agreements/IConstantFlowAgreementV1.sol";

import {
    IInstantDistributionAgreementV1
} from "../supercon/interfaces/agreements/IInstantDistributionAgreementV1.sol";



//import { Int96SafeMath } from "../supercon/libs/Int96SafeMath.sol";
//import { SignedSafeMath } from "@openzeppelin/contracts/utils/math/SignedSafeMath.sol";
//import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";
//import { SignedMath } from "@openzeppelin/contracts/utils/math/SignedMath.sol";
//import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";



contract TreeBudgetNFT is ERC1155, Ownable /*, SuperAppBase*/ {
    /*
    using Int96SafeMath for int96;
    using SafeMath for uint256;
    using SafeCast for uint256;
    using SignedSafeMath for int256;
    using SafeCast for int256;
    */
    //uint32 public constant INDEX_ID = 0;

    mapping(uint256 => uint32) public tokenIdIndex;//the id of the token that owns the index
    mapping(uint32 => uint256) public indexDuration;//when the iindex will expire
    mapping(uint32 => uint256) public indexLastDistribution;//when the index was last distributed 
    mapping(uint32 => uint256) public indexDistributeFrequency;//how often the distribute should get called
    mapping(uint32 => uint256) public indexActualAmount;//the total to be distributed
    mapping(uint32 => uint256) public indexDistributionAmount;//the total to be distributed every time
    mapping(uint32 => uint256) public indexRemainingAmount;

    ISuperfluid private _host; // host
    IConstantFlowAgreementV1 private _cfa; // the stored constant flow agreement class address
    IInstantDistributionAgreementV1 private _ida;
    
    ISuperToken public _acceptedToken; // accepted token
    address flowSource;
    

    uint256 public constant MOTHER = 0;
    uint256 public constant CHILD = 1;
    uint256 public constant GRANDCHILD = 2;
    uint256 public constant GREATGRANDCHILD = 0;


    mapping(uint => uint) private IdToNumber; //tracks the number ids of all tokens
    mapping(uint => uint[]) public mothersTokens; //an array of ids of all tokens linked to the mother ie child tokens
    mapping(uint => uint[]) public childsTokens; //an array of ids of all tokens linked to the child ie grand child tokens
    mapping(uint => uint[]) public gChildsTokens; //an array of ids of all tokens linked to the gchild ie gGrand child tokens

    mapping(uint => address) public tokenIdSource;

    mapping(address => uint) public addressMotherId;//an address to the mother token id owned
    mapping(address => uint) public addressChildId;//an address to a child token Id owned
    mapping(address => uint) public addressGChildId;//an address to a Gchild token Id owned
    mapping(address => uint) public addressGGchildId;

    struct TokenInfo {
        address tokenParent;
        address tokenOwner;
        int96 flowrate;
        bool conceived;
        bool forSale;
        uint256 price;
    }

    struct MotherInfo {
        address tokenParent;
        address tokenOwner;
        int96 flowrate;
        bool forSale;
        uint256 price;
    }

    struct GGChildInfo {
        address tokenParent;
        address tokenOwner;
        int96 amount;
        bool conceived;
        bool forSale;
        uint256 price;
        uint128 units;

    }

    mapping(uint => MotherInfo) public idMotherInfo;

    mapping(uint => mapping(uint => TokenInfo)) public tokenIdInfo;
    mapping(uint => mapping(address =>uint )) public tokenAddressId;
    mapping(uint => GGChildInfo) public gGChildTokenIdInfo;
    
    struct TreeSource {
        int96 totalFlow;
        uint descendants;
    }
    mapping(address =>TreeSource) public source;
    mapping (address => bool) public isSubscribing;




    event childIssued(address indexed _reciever, uint id, address issuer);
    event motherIssued(address indexed _reciever, uint id, address issuer);
    event gChildIssued(address indexed _reciever, uint id, address issuer);



    constructor(
        
        ISuperfluid host,
        IConstantFlowAgreementV1 cfa,
        IInstantDistributionAgreementV1 ida,
        ISuperToken acceptedToken
        
    ) ERC1155("") {
        
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
    function setTokenPrice(uint256 token, uint256 id, uint256 amount) external {
        require(balanceOf(msg.sender, token) == 1, "you can only open one"); //@dev: should own a mother token first
        require(tokenIdInfo[token][id].tokenOwner == msg.sender);
        tokenIdInfo[token][id].price = amount;
    }

    function generateToken(uint token_, uint256 price, int96 flowRate, uint128 units_) external {
        require(token_ !=0);
        require(balanceOf(msg.sender, (token_ - 1)) == 1, "have a preceding token");
        (, int96 outFlowRate, , ) = _cfa.getFlow(_acceptedToken, address(this), msg.sender);
        require(outFlowRate >= flowRate);
        uint id = IdToNumber[token_];
        tokenIdInfo[token_][id].tokenParent = msg.sender;
        if (token_ == 1 || token_ == 2) {
            tokenIdInfo[token_][id].conceived = true;
            tokenIdInfo[token_][id].flowrate = flowRate;
            tokenIdInfo[token_][id].price = price;
        } else if (token_ == 3) {
            gGChildTokenIdInfo[id].conceived = true;
            gGChildTokenIdInfo[id].units = units_;
            gGChildTokenIdInfo[id].amount = flowRate;
            gGChildTokenIdInfo[id].price = price;

        }
        
        IdToNumber[token_]++;
        
    }

    function distributeTokenDebt(uint32 index) external onlyOwner {
        //require block.timestamp > the index frequency + last distribution
        require(block.timestamp >= (indexLastDistribution[index] + indexDistributeFrequency[index]));
        _distribute(index, indexDistributionAmount[index]);
        indexRemainingAmount[index] -= (indexActualAmount[index]- indexDistributionAmount[index]);


    }

    function createGGchildTokenIndex(
        uint256 actualAmount,
        uint256 id,
        int96 flowrate,
        uint256 expiry,
        uint256 distributeAmount,
        uint256 disFrquiency
        ) external {
        //require one to own a gchild token
        
        uint gchilId = addressGChildId[msg.sender];
        tokenIdIndex[gchilId] = uint32(gchilId);
        uint32 index = uint32(gchilId);
        require(indexActualAmount[index]%indexDistributionAmount[index] == 0, "uneven distribution");
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
        _reduceFlow(msg.sender, flowrate);
        indexDuration[index] = expiry;
        indexActualAmount[index] = actualAmount;
        indexDistributionAmount[index] = distributeAmount;
        indexDistributeFrequency[index] = disFrquiency;
        indexLastDistribution[index] = block.timestamp;
        indexRemainingAmount[index] = actualAmount;
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function _trackId(uint256 _id, address idOwner) internal {
        uint secondId = IdToNumber[_id];//the id of the token monted ie MOTHER, CHILD or GRANDCHILD
        idMotherInfo[secondId].tokenOwner = idOwner;
        IdToNumber[_id] +=1;
    }

    function asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }

    function _beforeTokenTransfer(
        address operator,
        address oldReceiver,
        address newReceiver,
        uint256[] memory tokenId,//could cause transfer issues because is not an array
        uint256[] memory amount,
        bytes memory data
    ) internal /*virtual*/ override {
        //blocks transfers to superApps - done for simplicity, but you could support super apps in a new version!
        require(!_host.isApp(ISuperApp(newReceiver)) || newReceiver == address(this), "New receiver can not be a superApp");
        //uint256 id = tokenId[0];
        //uint256 amount_ = amount[0];
        //int tokeNumber = 
        //super._beforeTokenTransfer(operator, oldReceiver, newReceiver, tokenId, amount, data);
        // @dev delete flowRate of this token from old receiver
        // ignores minting case
        if (tokenId[0] == 0) {
            uint tokenNumber = tokenAddressId[tokenId[0]][oldReceiver];
            //should update the toke struct to change the owner
            //_reduceFlow(oldReceiver, idMotherInfo[tokenNumber].flowrate);
            //_increaseFlow(newReceiver, idMotherInfo[tokenNumber].flowrate);
            idMotherInfo[tokenNumber].tokenOwner = newReceiver;
        }
        if (tokenId[0] > 0 && tokenId[0] < 3 ) {
            uint tokenNumber = tokenAddressId[tokenId[0]][oldReceiver];
            _reduceFlow(oldReceiver, tokenIdInfo[tokenId[0]][tokenNumber].flowrate);
            // @dev create flowRate of this token to new receiver
            // ignores return-to-issuer case 
            _increaseFlow(newReceiver, tokenIdInfo[tokenId[0]][tokenNumber].flowrate);
            tokenIdInfo[tokenId[0]][tokenNumber].tokenOwner = newReceiver;
        } else if (tokenId[0] == 3) {
            //change receiver in index
            uint tokenNumber = tokenAddressId[tokenId[0]][oldReceiver];
            uint128 units = gGChildTokenIdInfo[tokenNumber].units;
            updateIndex(tokenNumber, units , newReceiver);
            updateIndex(tokenNumber, units, oldReceiver);
            gGChildTokenIdInfo[tokenNumber].tokenOwner = newReceiver;

        }
      }

    function checkFlowSource(address from) public view returns(int96) {
        (,int96 inflowRate,,) = _cfa.getFlow(_acceptedToken, from, address(this));
        return inflowRate;
    }

    function mintMother(address account, int96 _flowRate,bytes memory data)
        external
        /*onlyOwner*/
        returns(uint256)
    {   
        require(account != msg.sender);
        require(account != address(this));
        require(account != address(0));
        require(balanceOf(account, 0) == 0, "only one allowed");
        //require(checkFlowSource(msg.sender) >= _flowRate);
        _mint(account, 0, 1, data);
        addressMotherId[account] = IdToNumber[0];

        tokenIdSource[IdToNumber[0]] = msg.sender;
        _trackId(0, account);
        idMotherInfo[addressMotherId[account]].flowrate = _flowRate;
        emit motherIssued(account, addressMotherId[account], msg.sender);
        _createFlow(account, _flowRate);
        return addressMotherId[account];
    }

    function mintChild(address flowOwner, uint id, bytes memory data)
        external
    {   require(tokenIdInfo[1][id].conceived == true, "not available");
        uint motherNumnber = addressMotherId[flowOwner];
        require(msg.sender != flowOwner);
        require(idMotherInfo[motherNumnber].flowrate > tokenIdInfo[1][id].flowrate, "isuficient fr"); //@dev: flowrate from mother should not be zero
        _mint(msg.sender, 1, 1, data);
        addressChildId[msg.sender] = id;
        mothersTokens[motherNumnber].push(id);
        tokenIdInfo[1][id].tokenOwner = msg.sender;
        //_trackId(1, msg.sender);
        //idMotherInfo[motherNumnber].flowrate -= tokenIdInfo[1][id].flowrate;
        _reduceFlow(flowOwner, tokenIdInfo[1][id].flowrate);
        _createFlow(msg.sender, tokenIdInfo[1][id].flowrate);

        emit childIssued(flowOwner, addressChildId[msg.sender], msg.sender);
        
    }


    function mintGChild(uint id, bytes memory data)
        external
    {   
        require(tokenIdInfo[2][id].conceived == true, "not available");
        address flowOwner = tokenIdInfo[2][id].tokenParent;
        uint motherNumnber = addressChildId[flowOwner];
        require(msg.sender != flowOwner);
        require(tokenIdInfo[2][motherNumnber].flowrate > tokenIdInfo[2][id].flowrate, "isuficient fr"); //@dev: flowrate from mother should not be zero
        _mint(msg.sender, 2, 1, data);
        addressGChildId[msg.sender] = id;
        childsTokens[motherNumnber].push(id);
        tokenIdInfo[2][id].tokenOwner = msg.sender;
        //_trackId(2, msg.sender);
        //tokenIdInfo[1][motherNumnber].flowrate -= tokenIdInfo[2][id].flowrate;
        _reduceFlow(flowOwner, tokenIdInfo[2][id].flowrate);
        _createFlow(msg.sender, tokenIdInfo[2][id].flowrate);

        emit childIssued(flowOwner, addressGChildId[msg.sender], msg.sender);
        
    }

    function mintGreatGChild(uint token, uint32 indexId, int96 share) external {
        require(indexActualAmount[indexId] !=0);
        address flowOwner = tokenIdInfo[2][token].tokenParent;
        require(gGChildTokenIdInfo[token].conceived = true, "not available");
        uint motherNumnber = addressGChildId[flowOwner];
        addressGGchildId[msg.sender] = token;
        gChildsTokens[motherNumnber].push(token);
        tokenIdInfo[3][token].tokenOwner = msg.sender;
        //_trackId(1, msg.sender);
        tokenIdInfo[2][motherNumnber].flowrate -= tokenIdInfo[1][token].flowrate;
        _reduceFlow(flowOwner, tokenIdInfo[3][token].flowrate);
        //should show start time to culculate total accumulation
        

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

    function updateIndex(uint tokenId_, uint128 units, address receiver) private {
        _host.callAgreement(
            _ida,
            abi.encodeWithSelector(
                _ida.updateSubscription.selector,
                _acceptedToken,
                tokenIdIndex[tokenId_],
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

            // sanity checks for testing purpose
            //require(publisher == address(this), "DRT: publisher mismatch");
            //require(indexId == tokenIdIndex[tokenId], "DRT: publisher mismatch");

            if (approved) {
                isSubscribing[context.msgSender /* subscriber */] = true;
            }
        }
    }

    function _reduceFlow(address to, int96 flowRate) internal {

        if(to == address(this)) return;
        
        (, int96 outFlowRate, , ) = _cfa.getFlow(_acceptedToken, address(this), to);

        if (outFlowRate == flowRate) {
            _deleteFlow(address(this), to);
        } else if (outFlowRate > flowRate){
            // reduce the outflow by flowRate;
            // shouldn't overflow, because we just checked that it was bigger. 
            _updateFlow(to, outFlowRate - flowRate);
        } 
        // won't do anything if outFlowRate < flowRate
    } 
    
     //this will increase the flow or create it
    function _increaseFlow(address to, int96 flowRate) internal {
        (, int96 outFlowRate, , ) = _cfa.getFlow(_acceptedToken, address(this), to); //returns 0 if stream doesn't exist
        if (outFlowRate == 0) {
             _createFlow(to, flowRate);
        } else {
            // increase the outflow by flowRates[tokenId]
            _updateFlow(to, outFlowRate + flowRate);
        }
    }

    function getliquidationDeposit(uint256 deposit) external returns (int96) {
        bytes memory result =  _host.callAgreement(
            _cfa,
            abi.encodeWithSelector(
                _cfa.getMaximumFlowRateFromDeposit.selector,
                _acceptedToken,
                deposit
            ),
            "0x"
        );
    }
     
    function _createFlow(address to, int96 flowRate) internal {
        if(to == address(this) || to == address(0)) return;
        _host.callAgreement(
            _cfa,
            abi.encodeWithSelector(
                _cfa.createFlow.selector,
                _acceptedToken,
                to,
                flowRate,
                new bytes(0) // placeholder
            ),
            "0x"
        );
    }
    
    function _updateFlow(address to, int96 flowRate) internal {
        if(to == address(this) || to == address(0)) return;
        _host.callAgreement(
            _cfa,
            abi.encodeWithSelector(
                _cfa.updateFlow.selector,
                _acceptedToken,
                to,
                flowRate,
                new bytes(0) // placeholder
            ),
            "0x"
        );
    }
    
    function _deleteFlow(address from, address to) internal {
        _host.callAgreement(
            _cfa,
            abi.encodeWithSelector(
                _cfa.deleteFlow.selector,
                _acceptedToken,
                from,
                to,
                new bytes(0) // placeholder
            ),
            "0x"
        );
    }
/*
    function beforeAgreementCreated(
        ISuperToken superToken,
        address agreementClass,
        bytes32 /* agreementId ,
        bytes calldata /*agreementData,
        bytes calldata /*ctx
    )
        external view override
        returns (bytes memory data)
    {
        require(superToken == _acceptedToken, "DRT: Unsupported cash token");
        require(agreementClass == address(_ida), "DRT: Unsupported agreement");
        return new bytes(0);
    }

    function afterAgreementCreated(
        ISuperToken superToken,
        address  agreementClass,
        bytes32 agreementId,
        bytes calldata /*agreementData,
        bytes calldata /*cbdata,
        bytes calldata ctx
    )
        external override
        returns(bytes memory newCtx)
    {
        require(agreementClass == address(_ida), "DRT: Unsupported agreement");
        _checkSubscription(superToken, ctx, agreementId);
        newCtx = ctx;
    }

    function beforeAgreementUpdated(
        ISuperToken superToken,
        address agreementClass,
        bytes32 /* agreementId ,
        bytes calldata /*agreementData,
        bytes calldata /*ctx
    )
        external view override
        returns (bytes memory data)
    {
        require(superToken == _acceptedToken, "DRT: Unsupported cash token");
        require(agreementClass == address(_ida), "DRT: Unsupported agreement");
        return new bytes(0);
    }

    function afterAgreementUpdated(
        ISuperToken superToken,
        address  agreementClass,
        bytes32 agreementId,
        bytes calldata /*agreementData,
        bytes calldata /*cbdata,
        bytes calldata ctx
    )
        external override
        returns(bytes memory newCtx)

    {
        require(agreementClass == address(_ida), "DRT: Unsupported agreement");
        _checkSubscription(superToken, ctx, agreementId);
        newCtx = ctx;
    }
    


    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyOwner
    {
        _mintBatch(to, ids, amounts, data);
    }
*/
}