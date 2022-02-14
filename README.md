# StreamPay

## How to start the project?

Navigate to your prefered directory, then run these commands in your terminal.

**1. Clone the project**
```
git clone https://github.com/phydy/MoneyStreamNetwork.git
```
**2. Navigate to the project directory:**
```
cd MoneyStreamNetwork
```
**3. Install all brownie:**
```
pip3 install eth-brownie
```  
**4. install openzepelin, chainlink and superfluid packages:**
```
brownie pm intsall <package>
```
**5. set your private key in the brownie-config.yaml**
```
export PRIVATE_KEY="0xhdgfyugwOFGF..."
```
```
brownie run scripts/deploy_withMarket.py --network kovan or mumbai
```
