from operator import ne
from brownie import accounts, TreeBudgetNFT, FlowScource, network, config, convert
from scripts.helpful_scripts import get_account


host = convert.to_address("0x22ff293e14F1EC3A09B137e9e06084AFd63adDF9")
cfa = convert.to_address("0xEd6BcbF6907D4feEEe8a8875543249bEa9D308E8")
ida = convert.to_address("0xfDdcdac21D64B639546f3Ce2868C7EF06036990c")
daix = convert.to_address("0xF2d68898557cCb2Cf4C10c3Ef2B034b2a69DAD00")
fdai = convert.to_address("0x88271d333C72e51516B67f5567c728E702b3eeE8")

host_mumbai = convert.to_address("0xEB796bdb90fFA0f28255275e16936D25d3418603")
cfa_mumbai = convert.to_address("0x49e565Ed1bdc17F3d220f72DF0857C26FA83F873")
ida_mumbai = convert.to_address("0x804348D4960a61f2d5F9ce9103027A3E849E09b8")
daix_mumbai = convert.to_address("0x5D8B4C2554aeB7e86F387B4d6c00Ac33499Ed01f")
fdai_mumbai = convert.to_address("0x15F0Ca26781C3852f8166eD2ebce5D18265cceb7")


host_kovan = convert.to_address("0xF0d7d1D47109bA426B9D8A3Cde1941327af1eea3")
cfa_kovan = convert.to_address("0xECa8056809e7e8db04A8fF6e4E82cD889a46FE2F")
ida_kovan = convert.to_address("0x556ba0b3296027Dd7BCEb603aE53dEc3Ac283d2b")
daix_kovan = convert.to_address("0xe3cb950cb164a31c66e32c320a800d477019dcff")





def deployment_path():
    #account1 = accounts.load("0")
    #account2 = accounts.load("1")
    account = get_account() 
    nft_contract = (
        TreeBudgetNFT.deploy(
            host_mumbai,
            cfa_mumbai ,
            ida_mumbai ,
            daix_mumbai,
            {"from": account}
       
        )
        if len(TreeBudgetNFT) <= 0
        else TreeBudgetNFT[-1]
    )
    print(nft_contract.address)
    nft_address = nft_contract.address
    source_contract = (
        FlowScource.deploy(
            host_mumbai,
            cfa_mumbai,
            daix_mumbai,
            nft_address,
            fdai_mumbai,
            {"from": account}
       
        )
        if len(FlowScource) <= 0
        else FlowScource[-1]
    )
    flowSource = source_contract.address
    print(flowSource)
    nft_contract.addFlowSource(flowSource, {"from": account}) #we add the flow source address to the nft contract
    nft_contract.transferOwnership(flowSource, {"from": account})#we transfer ownership of the nft contract to the flowsource address to allow it to create mother tokens
    print(source_contract.currentReceiver())
    nft_contract.mintMother("0xBCD9A216ba2c6346615B637Bb3A9CaC5117618e2", 1, "", {"from": account})
    source_contract.fund("0xBCD9A216ba2c6346615B637Bb3A9CaC5117618e2", 1, {"from": account})
    source_contract.createMother("0x633DBb3048CB220e2Cf046FA6FF0D279d09B7b60", 1, {"from": account})
    nft_contract.generateToken(1, 80000000000000000000, 1, 0, {"from": account})
    nft_contract.mintChild("0xBCD9A216ba2c6346615B637Bb3A9CaC5117618e2", 0, "", {"from": account})
def main():
    deployment_path()

if __name__ == "__main__()":
    main()