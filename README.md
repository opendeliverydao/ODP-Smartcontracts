# ODP-Smartcontracts
EVM Solidity Smartcontracts used by OpenDelivery.app

The smart contracts used for our token (ERC20) and NFT (ERC721) had their ownership transferred to the governance smart contract (DAO GOVERNOR) as soon as they were instantiated and tested.

Thus, any method of the contract that requires the executor to be the owner of the contract will have to be executed from the governance contract, which will execute proposals and vote of the token holders.
