from operator import ne
from brownie import accounts, TreeBudgetNFT, FlowScource, MarketPlace, network, config, convert, interface
from brownie.network.gas.strategies import GasNowStrategy

network.max_fee("5 gwei")
network.priority_fee("2 gwei")


host = convert.to_address("0x22ff293e14F1EC3A09B137e9e06084AFd63adDF9")
cfa = convert.to_address("0xEd6BcbF6907D4feEEe8a8875543249bEa9D308E8")
ida = convert.to_address("0xfDdcdac21D64B639546f3Ce2868C7EF06036990c")
daix = convert.to_address("0xF2d68898557cCb2Cf4C10c3Ef2B034b2a69DAD00")
fdai = convert.to_address("0x88271d333C72e51516B67f5567c728E702b3eeE8")

host_mumbai = convert.to_address("0xEB796bdb90fFA0f28255275e16936D25d3418603")
cfa_mumbai = convert.to_address("0x49e565Ed1bdc17F3d220f72DF0857C26FA83F873")
ida_mumbai = convert.to_address("0x804348D4960a61f2d5F9ce9103027A3E849E09b8")
daix_mumbai = convert.to_address("0x5D8B4C2554aeB7e86F387B4d6c00Ac33499Ed01f")
fdai_mumbai = convert.to_address("0xbe91b305ebdb0253abafe1da0cdfb0fd9d4fd4b8")


host_kovan = convert.to_address("0xF0d7d1D47109bA426B9D8A3Cde1941327af1eea3")
cfa_kovan = convert.to_address("0xECa8056809e7e8db04A8fF6e4E82cD889a46FE2F")
ida_kovan = convert.to_address("0x556ba0b3296027Dd7BCEb603aE53dEc3Ac283d2b")
daix_kovan = convert.to_address("0xe3cb950cb164a31c66e32c320a800d477019dcff")
fdai_kova = convert.to_address("0xb64845d53a373d35160b72492818f0d2f51292c0")

flow_to_mother = 100000000000000
flow_to_child = 10000000000000
flow_to_gchild = 1000000000000
flow_to_ggchild = 100000000000

address_deploy = convert.to_address("0xaC18157FFFdc96C9724eB1CF42eb05F8f70e645B")
address_mother = convert.to_address("0xBCD9A216ba2c6346615B637Bb3A9CaC5117618e2")
address_child = convert.to_address("0x955685Ad5B73CD9FF99e636862c319223B8f36fd")
address_gchild = convert.to_address("0x633DBb3048CB220e2Cf046FA6FF0D279d09B7b60")
address_ggchild = convert.to_address("0x7b35Fa78BDf45770FeF2b658153b9284f9af76e1")
address_buyer = convert.to_address("0xC225c9Af6F51f0e82b5dA08e1dd58854F5e76a38")

dainormal = interface.IERC20(fdai_mumbai)
acceptedToken = interface.IERC20(daix_mumbai)
_cfa = interface.IConstantFlowAgreementV1(cfa_mumbai)


def get_account(role):
    if role == 1:
        return accounts.add(config["wallets"]["from_dep"])
    if role ==2:
        return accounts.add(config["wallets"]["from_mother"])
    if role ==3:
        return accounts.add(config["wallets"]["from_child"])
    if role ==4:
        return accounts.add(config["wallets"]["from_gchild"])
    if role ==5:
        return accounts.add(config["wallets"]["from_ggchild"])
    elif role ==6:
        return accounts.add(config["wallets"]["from_buyer"])

def transferSuperTokens(sender, receiver):
    acceptedToken.transferFrom(
        sender,
        receiver,
        convert.to_uint("100000000000000000000"),
        {"from": get_account(1)}
    )

def get_flow(token, sender, _receiver, account):
    return _cfa.getFlow(
        token,
        sender,
        _receiver,
         {"from": get_account(account)}
    )

    
def create_flow(token, receiver, flowRate, account):
    return _cfa.createFlow(
        token,
        receiver,
        flowRate,
        "",
        {"from": get_account(account)}
    )


def deployment_path():
    print("deploying nft contract...")
    nft_contract = (
        TreeBudgetNFT.deploy(
            host_mumbai,
            cfa_mumbai ,
           # ida_mumbai ,
            daix_mumbai,
            {"from": get_account(1)}
       
        )
        if len(TreeBudgetNFT) <= 0
        else TreeBudgetNFT[-1]
    )
    print("nft contract deployed at: ")
    nft_address = nft_contract.address
    print(nft_address)
    print("deploying Source contract...")
    source_contract = (
        FlowScource.deploy(
            host_mumbai,
            cfa_mumbai,
            daix_mumbai,
            nft_address,
            {"from": get_account(1)}
       
        )
        if len(FlowScource) <= 0
        else FlowScource[-1]
    )
    flowSource = source_contract.address
    print("Source contract deployed at: ") 
    print(flowSource)

    print("deploying marketPlace")
    market_contract = (MarketPlace.deploy(
            nft_address,
            daix_mumbai,
            #fdai_mumbai,
            {"from": get_account(1)}
        )
        if len(MarketPlace) <= 0
        else MarketPlace[-1]
    )
    print("martket contract deployed")
    market_address = market_contract.address
    print(market_address)
    print("adding market")
    nft_contract.addMarket(
        market_address,
        {"from": get_account(1)}
    )
    print("market address added")
    print("adding flow source")
    nft_contract.addFlowSource(
        flowSource,
        {"from": get_account(1)}
    ) #we add the flow source address to the nft contract
    ####nft_contract.transferOwnership(flowSource, {"from": get_account(1)})#we transfer ownership of the nft contract to the flowsource address to allow it to create mother tokens
    print(source_contract.currentReceiver())
    print("testing flow recepient contracts") 
    create_flow(
        daix_mumbai,
        nft_address,
        convert.to_int("7 gwei"),
        1
    )
    print("approving the flow source to spend super DAI")
    acceptedToken.approve(
        flowSource, convert.to_uint("200000000000000000000"),
        {"from": get_account(1)}
    ) #we approve the flow source to spend our DAIx
    print("approved")
    previous_balance = acceptedToken.balanceOf(nft_contract)
    print("previous balance:") 
    print(previous_balance)
    print("minting mother token...")
    source_contract.fund(
        address_mother,
        flow_to_mother,
        {"from": get_account(1)}
    )
    current_balance = acceptedToken.balanceOf(nft_contract)
    print("cheking reverse flow")

    print("transfering funds to source")

    acceptedToken.transfer(
        flowSource,
        20000000000000000000,
        {"from": get_account(1)}
    )


    source_contract.createFlow({"from": get_account(1)})


    print(get_flow(acceptedToken, flowSource, nft_address, 1))
    print("current balance:") 
    print(current_balance)
    print("getting mother token flow info...")
    mother_flow_info = _cfa.getFlow(
        daix_mumbai,
        nft_address,
        address_mother,
         {"from": get_account(1)}
    )
    print(mother_flow_info)
    print("This confirms that the mother token is active and working")
    print("generating child token...")

    nft_contract.generateToken(
        1,
        10000000000000000000,
        flow_to_child,
        36000,
        {"from": get_account(2)}
    )
    print("child token generated")

    daiad = market_contract._dai()
    tran = interface.IERC20(daiad)
    acceptedToken.approve(
        market_address,
        10000000000000000000,
        {"from": get_account(3)}
    )
    print("allowancw to market is...")
    print(acceptedToken.allowance(market_address, get_account(3)))

    amount = nft_contract.tokenIdInfo(1,0)
    print("Amount is...")
    print(amount)
    print("minting Child Token...")
    market_contract.mintToken(
        1,
        0,
        {"from": get_account(3)}
    )
    print("child token minted")
    print("getting child token flow info...")
    child_flow_info = _cfa.getFlow(
        daix_mumbai,
        nft_address,
        address_child
    )
    print(child_flow_info)
    print("new mother token info")
    mother_flow_info = _cfa.getFlow(
        daix_mumbai,
        nft_address,
        address_mother
    )
    print(mother_flow_info)
    print("generating grand child token...")
    nft_contract.generateToken(
        2,
        10000000000000000000,
        flow_to_gchild,
        0,
        {"from": get_account(3)}
    )
    print("minting grandchild token...")
    dainormal.approve(
        market_address, convert.to_uint("10000000000000000000"),
        {"from": get_account(4)}
    )
    market_contract.mintToken(
        2,
        0,
        {"from": get_account(4)}
    )
    print("grand child token minted")
    print("getting grandchild token flow info...")
    gchild_flow_info = _cfa.getFlow(
        daix_mumbai,
        nft_address,
        address_gchild
    )
    print(gchild_flow_info)

    print("getting child token flow info...")
    child_flow_info = _cfa.getFlow(
        daix_mumbai,
        nft_address,
        address_child
    )
    print(child_flow_info)

    print("transfering nft")
    nft_contract.safeTransferFrom(
        address_child,
        address_buyer,
        1,
        1,
        convert.to_bytes(""),
        {"from": get_account(3)}
    )
    print("transfered")
    print("getting new owner info..")
    flo = _cfa.getFlow(
        daix_mumbai,
        nft_address,
        address_buyer
    )
    print(flo)
    ##print("setting a token price")
    #nft_contract.setTokenPrice(
    #    1,
    #    0,
    #    100000000000000000000,
    #    {"from": get_account(3)}
    #)
    #print("token price set")
#
    #print("buyer approving amount to spend")
    #acceptedToken.approve(
    #    market_address,
    #    100000000000000000000,
    #    {"from": get_account(6)}
    #)
    #print("approved")
    #print("flow to buyer before tranfer")
    #flow1_to_buyer = _cfa.getFlow(
    #    daix_kovan,
    #    nft_address,
    #    address_buyer
    #)
    #print(flow1_to_buyer)
    #print("Buying token")
    #market_contract.buyToken(
    #    1,
    #    0,
    #    {"from": get_account(6)}
    #)
    #print("token bought!")
    #print("confirming flow to buyer")
    #print("confirming")
    ##flow_to_buyer = _cfa.getFlow(
    ##    daix_kovan,
    ##    nft_address,
    ##    address_buyer
    ##)
    #print(flow_to_buyer)
#
def main():
    deployment_path()

if __name__ == "__main__()":
    main()
