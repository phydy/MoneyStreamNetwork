from operator import ne
from attr import Factory
from brownie import convert, TreeFactory
from brownie.network.gas.strategies import GasNowStrategy
from eth_utils import address
from scripts.deploy_withMarket import get_account 


host_mumbai = convert.to_address("0xEB796bdb90fFA0f28255275e16936D25d3418603")
cfa_mumbai = convert.to_address("0x49e565Ed1bdc17F3d220f72DF0857C26FA83F873")
ida_mumbai = convert.to_address("0x804348D4960a61f2d5F9ce9103027A3E849E09b8")
daix_mumbai = convert.to_address("0x918E0d5C96cAC79674E2D38066651212be3C9C48")
fdai_mumbai = convert.to_address("0x15F0Ca26781C3852f8166eD2ebce5D18265cceb7")

account = get_account(1)

def main():
    factory = (
        TreeFactory.deploy(
            {"from": account}
        )
        if len(TreeFactory) <= 0
        else TreeFactory[-1]
    )

    bytecode = factory.getBytecode(
        host_mumbai,
        cfa_mumbai,
        ida_mumbai,
        daix_mumbai
    )
    #print(bytecode)

    tree_address = factory.getAddress(
        bytecode,
        31
    )
    print(tree_address)




if __name__ =="__main__":
    main()