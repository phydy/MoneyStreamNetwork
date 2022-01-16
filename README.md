# MoneyStreamNetwork

Short Description
A Tradable Cash-Flow DeFi-NFT that gives a holder the power to leverage their superfluid flow to get loans or funds 

Long Description
The world of DeFi has brought the world many forms of decentralized banking but these forms however efficient, have so many pitfalls that limit mass adoption of blockchain technology into the business model. One of this pitfalls is the having to over-collateralize an agreement with a peer to receive some service. With the Network flow streams, people can use their streams as collateral for a service without having to worry about liquidation calls or the provider risking debt repayment failure.
How does this work exactly?
    • The business creates a flow to the NFT contract and mints a mother token associated with the flow (it can mint many mother tokens for different addresses as long as its flow allows).
    • The Mother token can then create a child token with a flow equal or less than their own flow.
    • The child generates a grandchild
    • grandchild generates a great-grandchild
The project has two contacts that work hand in hand to ensure that the flow works properly. The ERC1155 contract contains the logic of of handling the nfts and the flows and instant distribution agreement. The flows from the source contract to the nft should come from a trusted source like a company using this protocol to pay its employees. The employees receive a mother nft that is linked to the flow assigned to it by its creator. It has the ability to make as many child tokens provided their total flow is equal or less than its assigned flow. These child tokens can create grandchild tokens with the same rules applying as for the mother token. The grandchild tokens can create an instant distribution index that with great-grandchild tokens owning the shares there. Hence, at every level of these ERC1155 tokens (apart from the great-grandchild token), an owner can leverage their streams to receive instant service or cash for a later repayment assured by the source of the flow. This model can be applied in very many aspects of DeFi and the Business world. 

In DeFi, it can be used by protocols to pay their users. For example liquidity providers can receive their intrest in streams and use these streams to do other personal business. It can also be used by new projects who can seek funding by issuing investors with the mother token. The investors can then sell their tokens or create other tokens to sell for their funds. Other than reducing risk in lending and borrowing, it will save may projects that get abandoned by initial investors trough dumping. A project that uses this model to remunerate their stakeholders can avoid such instances by allowing ‘dumbers’ to sell the NFTs to willing buyers who interested in keeping it alive.

In a business application, this project makes recurring payments and debt purchases possible. Companies can link their income to the project and pay for services by creating new nfts that they give to suppliers and other stakeholders they do business with. At a personal level, anyone with an nft on this platform can leverage their flow to receive instant cash in case of an emergency. A business can leverage payment for both its employees and other stakeholders. The supply chain will be the most impacted by this model when applied to it since it will ease the payment process. A business does not have to commit all the goods worth upon receiving but can pay in streams with its  cashflow. This might be inconvenient for the supplier in other forms but if he wants to receive the funds upfront, they can sell the nft or create a child worth the amount required.





How its Made
This Project is the backend of a DApp that contains the logic of of routing superfluid's constant flow agreement streams, from the owner of the mother tokens to other owners of related tokens. Its written in solidity using the brownie framework. The project use the ERC1155 standard to create a generation of related tokens that have their streams linked to one token (the mother token). The ERC1155 standard is mainly used in games hence, enumeration of tokens is not usually required. However, using this standard with a DeFi project requires enumeration of all the tokens for better accounting and dynamic properties. These tokens all have a unique ID (not the ERC1155 token Id but a further enumeration of the individual tokens at their respective generation). Hence, each token has a unique flow or unit (on the IDA index generated by its issuer). This makes it possible to transfer individual tokens and link their flows or IDA share to the receiver. The mother Token creates child tokens which receive their streams from the mother token. The child token can create grand child tokens with streams drawn from the mother token. The grandchild token creates great-grandchild tokens which have a share to an instant distribution index created by the grandchild token. Any of these tokens can be transferred to another party with the flow associated with the token changed to the receiver.

Current state
I hacked solo on this project and being a backend developer, I could only manage to create the smart contract logic. Due to lack of a registration key from superfluid, I could not get a stream to my nft contract from the source contract. Hence, we will deposit funds to the NFT contract when creating a mother token on the source contract. But for production purposes I intend to use a stream that links the two contracts. The contract is far from complete but with time everything should work correctly since the core functionality (flow of funds linked to the nfts works). The goal is to extend it to fit different areas of application as mentioned above.



