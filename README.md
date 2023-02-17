# MetaCrafters Task


## CrowdFunding Smart Contract 

### A crowdfunding campaign where users can pledge funds to and claim funds from the contract

## Functions:
   - You can Create goal where you just have to give description, Target value and deadline for the Goal.
   - Users can Fund any request by the Native ERC20 token of the contract namely FUNDTOKEN FTK .
   - If before the deadline the target value is acheived, the Creator of the goal can claim the Fund token by creating a request to the owner of the contract.
   - If the goal is not acheived, funder can request for Refund.
   - All the transaction on Dapp is fascilated by the FundToken, so there is a function to buy the Fund Tokens by ETH.
   
   - Contract FundToken is an Upradable Contract that uses transparent upgradable proxy protocol from openzeppelin.
   - Contract contain multiple Events and created while considering multiple edge cases
   
