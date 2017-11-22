#!/bin/bash
# ----------------------------------------------------------------------------------------------
# Testing the smart contract
#
# Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2017. The MIT Licence.
# ----------------------------------------------------------------------------------------------

MODE=${1:-test}

GETHATTACHPOINT=`grep ^IPCFILE= settings.txt | sed "s/^.*=//"`
PASSWORD=`grep ^PASSWORD= settings.txt | sed "s/^.*=//"`

SOURCEDIR=`grep ^SOURCEDIR= settings.txt | sed "s/^.*=//"`

APPREGISTRYSOL=`grep ^APPREGISTRYSOL= settings.txt | sed "s/^.*=//"`
APPREGISTRYJS=`grep ^APPREGISTRYJS= settings.txt | sed "s/^.*=//"`

DEPLOYMENTDATA=`grep ^DEPLOYMENTDATA= settings.txt | sed "s/^.*=//"`

INCLUDEJS=`grep ^INCLUDEJS= settings.txt | sed "s/^.*=//"`
TEST1OUTPUT=`grep ^TEST1OUTPUT= settings.txt | sed "s/^.*=//"`
TEST1RESULTS=`grep ^TEST1RESULTS= settings.txt | sed "s/^.*=//"`

CURRENTTIME=`date +%s`
CURRENTTIMES=`date -r $CURRENTTIME -u`

BLOCKSINDAY=10

if [ "$MODE" == "dev" ]; then
  # Start time now
  STARTTIME=`echo "$CURRENTTIME" | bc`
else
  # Start time 1m 10s in the future
  STARTTIME=`echo "$CURRENTTIME+90" | bc`
fi
STARTTIME_S=`date -r $STARTTIME -u`
ENDTIME=`echo "$CURRENTTIME+60*3" | bc`
ENDTIME_S=`date -r $ENDTIME -u`

printf "MODE            = '$MODE'\n" | tee $TEST1OUTPUT
printf "GETHATTACHPOINT = '$GETHATTACHPOINT'\n" | tee -a $TEST1OUTPUT
printf "PASSWORD        = '$PASSWORD'\n" | tee -a $TEST1OUTPUT
printf "SOURCEDIR       = '$SOURCEDIR'\n" | tee -a $TEST1OUTPUT
printf "APPREGISTRYSOL  = '$APPREGISTRYSOL'\n" | tee -a $TEST1OUTPUT
printf "APPREGISTRYJS   = '$APPREGISTRYJS'\n" | tee -a $TEST1OUTPUT
printf "DEPLOYMENTDATA  = '$DEPLOYMENTDATA'\n" | tee -a $TEST1OUTPUT
printf "INCLUDEJS       = '$INCLUDEJS'\n" | tee -a $TEST1OUTPUT
printf "TEST1OUTPUT     = '$TEST1OUTPUT'\n" | tee -a $TEST1OUTPUT
printf "TEST1RESULTS    = '$TEST1RESULTS'\n" | tee -a $TEST1OUTPUT
printf "CURRENTTIME     = '$CURRENTTIME' '$CURRENTTIMES'\n" | tee -a $TEST1OUTPUT
printf "STARTTIME       = '$STARTTIME' '$STARTTIME_S'\n" | tee -a $TEST1OUTPUT
printf "ENDTIME         = '$ENDTIME' '$ENDTIME_S'\n" | tee -a $TEST1OUTPUT

# Make copy of SOL file and modify start and end times ---
# `cp modifiedContracts/SnipCoin.sol .`
`cp $SOURCEDIR/*.sol .`
#`cp $SOURCEDIR/$ECVERIFYSOL .`

# --- Modify parameters ---
# `perl -pi -e "s/bool transferable/bool public transferable/" $TOKENSOL`
# `perl -pi -e "s/MULTISIG_WALLET_ADDRESS \= 0xc79ab28c5c03f1e7fbef056167364e6782f9ff4f;/MULTISIG_WALLET_ADDRESS \= 0xa22AB8A9D641CE77e06D98b7D7065d324D3d6976;/" GimliCrowdsale.sol`
# `perl -pi -e "s/START_DATE = 1505736000;.*$/START_DATE \= $STARTTIME; \/\/ $STARTTIME_S/" GimliCrowdsale.sol`
# `perl -pi -e "s/END_DATE = 1508500800;.*$/END_DATE \= $ENDTIME; \/\/ $ENDTIME_S/" GimliCrowdsale.sol`
# `perl -pi -e "s/VESTING_1_DATE = 1537272000;.*$/VESTING_1_DATE \= $VESTING1TIME; \/\/ $VESTING1TIME_S/" GimliCrowdsale.sol`
# `perl -pi -e "s/VESTING_2_DATE = 1568808000;.*$/VESTING_2_DATE \= $VESTING2TIME; \/\/ $VESTING2TIME_S/" GimliCrowdsale.sol`

DIFFS1=`diff $SOURCEDIR/$APPREGISTRYSOL $APPREGISTRYSOL`
echo "--- Differences $SOURCEDIR/$APPREGISTRYSOL $APPREGISTRYSOL ---" | tee -a $TEST1OUTPUT
echo "$DIFFS1" | tee -a $TEST1OUTPUT

solc --version | tee -a $TEST1OUTPUT

echo "var appRegistryOutput=`solc --optimize --combined-json abi,bin,interface $APPREGISTRYSOL`;" > $APPREGISTRYJS

geth --verbosity 3 attach $GETHATTACHPOINT << EOF | tee -a $TEST1OUTPUT
loadScript("$APPREGISTRYJS");
loadScript("functions.js");

var appRegistryAbi = JSON.parse(appRegistryOutput.contracts["$APPREGISTRYSOL:DeveryAppRegistry"].abi);
var appRegistryBin = "0x" + appRegistryOutput.contracts["$APPREGISTRYSOL:DeveryAppRegistry"].bin;
// var tokenAbi = JSON.parse(tokenOutput.contracts["$CROWDSALESOL:BTTSToken"].abi);
// var tokenBin = "0x" + tokenOutput.contracts["$CROWDSALESOL:BTTSToken"].bin;
// var factoryAbi = JSON.parse(tokenOutput.contracts["$CROWDSALESOL:BTTSTokenFactory"].abi);
// var factoryBin = "0x" + tokenOutput.contracts["$CROWDSALESOL:BTTSTokenFactory"].bin;

// console.log("DATA: appRegistryAbi=" + JSON.stringify(appRegistryAbi));
// console.log("DATA: appRegistryBin=" + JSON.stringify(appRegistryBin));
// console.log("DATA: tokenAbi=" + JSON.stringify(tokenAbi));
// console.log("DATA: tokenBin=" + JSON.stringify(tokenBin));


unlockAccounts("$PASSWORD");
printBalances();
console.log("RESULT: ");



// -----------------------------------------------------------------------------
var deployAppRegistryMessage = "Deploy App Registry Contract";
// -----------------------------------------------------------------------------
console.log("RESULT: " + deployAppRegistryMessage);
var appRegistryContract = web3.eth.contract(appRegistryAbi);
// console.log(JSON.stringify(tokenContract));
var appRegistryTx = null;
var appRegistryAddress = null;

var appRegistry = appRegistryContract.new({from: contractOwnerAccount, data: appRegistryBin, gas: 6000000, gasPrice: defaultGasPrice},
  function(e, contract) {
    if (!e) {
      if (!contract.address) {
        appRegistryTx = contract.transactionHash;
      } else {
        appRegistryAddress = contract.address;
        addAccount(appRegistryAddress, "App Registry");
        addAppRegistryContractAddressAndAbi(appRegistryAddress, appRegistryAbi);
        console.log("DATA: appRegistryAddress=" + appRegistryAddress);
      }
    }
  }
);

while (txpool.status.pending > 0) {
}

printTxData("appRegistryAddress=" + appRegistryAddress, appRegistryTx);
printBalances();
failIfTxStatusError(appRegistryTx, deployAppRegistryMessage);
printAppRegistryContractDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var registerAppsMessage = "Register Apps";
// -----------------------------------------------------------------------------
console.log("RESULT: " + registerAppsMessage);
var registerApps1Tx = appRegistry.register("Bevery", beveryFeeAccount, {from: beveryAppAccount, gas: 500000, gasPrice: defaultGasPrice});
var registerApps2Tx = appRegistry.register("Mevery", meveryFeeAccount, {from: meveryAppAccount, gas: 500000, gasPrice: defaultGasPrice});
var registerApps3Tx = appRegistry.register("Zevery", zeveryFeeAccount, {from: zeveryAppAccount, gas: 500000, gasPrice: defaultGasPrice});
while (txpool.status.pending > 0) {
}
printTxData("registerApps1Tx", registerApps1Tx);
printTxData("registerApps2Tx", registerApps2Tx);
printTxData("registerApps3Tx", registerApps3Tx);
printBalances();
failIfTxStatusError(registerApps1Tx, registerAppsMessage + " - Bevery");
failIfTxStatusError(registerApps2Tx, registerAppsMessage + " - Mevery");
failIfTxStatusError(registerApps3Tx, registerAppsMessage + " - Zevery");
printAppRegistryContractDetails();
console.log("RESULT: ");


exit;

// -----------------------------------------------------------------------------
var deployLibraryMessage = "Deploy Crowdsale/Token Contract";
// -----------------------------------------------------------------------------
console.log("RESULT: " + deployLibraryMessage);
var libContract = web3.eth.contract(libAbi);
// console.log(JSON.stringify(tokenContract));
var libTx = null;
var libAddress = null;

var lib = libContract.new({from: contractOwnerAccount, data: libBin, gas: 6000000, gasPrice: defaultGasPrice},
  function(e, contract) {
    if (!e) {
      if (!contract.address) {
        libTx = contract.transactionHash;
      } else {
        libAddress = contract.address;
        addAccount(libAddress, "Lib SafeMath");
        console.log("DATA: libAddress=" + libAddress);
      }
    }
  }
);

while (txpool.status.pending > 0) {
}

printTxData("libAddress=" + libAddress, libTx);
printBalances();
failIfTxStatusError(libTx, deployLibraryMessage);
printTokenContractDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var deployFactoryMessage = "Deploy BTTSTokenFactory";
// -----------------------------------------------------------------------------
console.log("RESULT: " + deployFactoryMessage);
// console.log("RESULT: old='" + factoryBin + "'");
var newFactoryBin = factoryBin.replace(/__BTTSToken100\.sol\:SafeMath_____________/g, libAddress.substring(2, 42));
// console.log("RESULT: new='" + newFactoryBin + "'");

var factoryContract = web3.eth.contract(factoryAbi);
// console.log(JSON.stringify(factoryAbi));
// console.log(factoryBin);
var factoryTx = null;
var factoryAddress = null;

var factory = factoryContract.new({from: contractOwnerAccount, data: newFactoryBin, gas: 6000000, gasPrice: defaultGasPrice},
  function(e, contract) {
    if (!e) {
      if (!contract.address) {
        factoryTx = contract.transactionHash;
      } else {
        factoryAddress = contract.address;
        addAccount(factoryAddress, "BTTSTokenFactory");
        addFactoryContractAddressAndAbi(factoryAddress, factoryAbi);
        console.log("DATA: factoryAddress=" + factoryAddress);
      }
    }
  }
);

while (txpool.status.pending > 0) {
}

printTxData("factoryAddress=" + factoryAddress, factoryTx);
printBalances();
failIfTxStatusError(factoryTx, deployFactoryMessage);
printFactoryContractDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var tokenMessage = "Deploy Crowdsale/Token Contract";
// console.log("RESULT: old='" + tokenBin + "'");
var newTokenBin = tokenBin.replace(/__BTTSToken100\.sol\:SafeMath_____________/g, libAddress.substring(2, 42));
// console.log("RESULT: new='" + newTokenBin + "'");
var symbol = "GZETest";
var name = "GazeCoin Test";
var decimals = 18;
var initialSupply = "10000000000000000000000000";
var mintable = true;
var transferable = false;
// -----------------------------------------------------------------------------
console.log("RESULT: " + tokenMessage);
var tokenContract = web3.eth.contract(tokenAbi);
// console.log(JSON.stringify(tokenContract));
var tokenTx = null;
var tokenAddress = null;

// Now deploying using factory
if (false) {
var token = tokenContract.new(symbol, name, decimals, initialSupply, mintable, transferable,
    {from: contractOwnerAccount, data: newTokenBin, gas: 6000000, gasPrice: defaultGasPrice},
  function(e, contract) {
    if (!e) {
      if (!contract.address) {
        tokenTx = contract.transactionHash;
      } else {
        tokenAddress = contract.address;
        addAccount(tokenAddress, "Token '" + token.symbol() + "' '" + token.name() + "'");
        addTokenContractAddressAndAbi(tokenAddress, tokenAbi);
        console.log("DATA: tokenAddress=" + tokenAddress);
      }
    }
  }
);
}

var deployTokenTx = factory.deployBTTSTokenContract(symbol, name, decimals, initialSupply, mintable, transferable, {from: contractOwnerAccount, gas: 4000000, gasPrice: defaultGasPrice});

while (txpool.status.pending > 0) {
}

printTxData("deployTokenTx", deployTokenTx);
printBalances();
var bttsTokens = getBTTSFactoryTokenListing();
console.log("RESULT: bttsTokens=#" + bttsTokens.length + " " + JSON.stringify(bttsTokens));

// Can check, but the rest will not work anyway - if (bttsTokens.length == 1)
tokenAddress = bttsTokens[0];
token = web3.eth.contract(tokenAbi).at(tokenAddress);
// console.log("RESULT: token=" + JSON.stringify(token));

addAccount(tokenAddress, "Token '" + token.symbol() + "' '" + token.name() + "'");
addTokenContractAddressAndAbi(tokenAddress, tokenAbi);

printFactoryContractDetails();
printTokenContractDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var mintTokensMessage = "Mint Tokens";
// -----------------------------------------------------------------------------
console.log("RESULT: " + mintTokensMessage);
var mintTokens1Tx = token.mint(account3, "1000000000000000000000000", {from: contractOwnerAccount, gas: 100000, gasPrice: defaultGasPrice});
var mintTokens2Tx = token.mint(account4, "1000000000000000000000000", {from: contractOwnerAccount, gas: 100000, gasPrice: defaultGasPrice});
while (txpool.status.pending > 0) {
}
printTxData("mintTokens1Tx", mintTokens1Tx);
printTxData("mintTokens2Tx", mintTokens2Tx);
printBalances();
failIfTxStatusError(mintTokens1Tx, mintTokensMessage + " - mint 1,000,000 tokens 0x0 -> ac3");
failIfTxStatusError(mintTokens2Tx, mintTokensMessage + " - mint 1,000,000 tokens 0x0 -> ac4");
printTokenContractDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var startTransfersMessage = "Start Transfers";
// -----------------------------------------------------------------------------
console.log("RESULT: " + startTransfersMessage);
var startTransfers1Tx = token.disableMinting({from: contractOwnerAccount, gas: 100000, gasPrice: defaultGasPrice});
var startTransfers2Tx = token.enableTransfers({from: contractOwnerAccount, gas: 100000, gasPrice: defaultGasPrice});
while (txpool.status.pending > 0) {
}
printTxData("startTransfers1Tx", startTransfers1Tx);
printTxData("startTransfers2Tx", startTransfers2Tx);
printBalances();
failIfTxStatusError(startTransfers1Tx, startTransfersMessage + " - Disable Minting");
failIfTxStatusError(startTransfers2Tx, startTransfersMessage + " - Enable Transfers");
printTokenContractDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
// BTTS support functions
// -----------------------------------------------------------------------------
function signedTransferCheckResultString(e) {
  var text = "Unknown";
  if (e == 0) {
    text = "Success"
  } else if (e == 1) {
    text = "NotTransferable";
  } else if (e == 2) {
    text = "NotExecutable";
  } else if (e == 3) {
    text = "SignerMismatch";
  } else if (e == 4) {
    text = "AlreadyExecuted";
  } else if (e == 5) {
    text = "InsufficientApprovedTokens";
  } else if (e == 6) {
    text = "InsufficientApprovedTokensForFees";
  } else if (e == 7) {
    text = "InsufficientTokens";
  } else if (e == 8) {
    text = "InsufficientTokensForFees";
  } else if (e == 9) {
    text = "OverflowError";
  } else {
    text = "Unknown";
  }
  return text;
}

function padLeft0(s, n) {
  var result = s.toString();
  while (result.length < n) {
    result = "0" + result;
  }
  return result;
}

function bytes4ToHex(bytes4) {
  if (bytes4.substring(0, 2) == "0x") {
    return padLeft0(bytes4.substring(2, 10), 8);
  } else {
    return padLeft0(bytes4.substring(0, 8), 8);
  } 
}

function addressToHex(address) {
  if (address.substring(0, 2) == "0x") {
    return padLeft0(address.substring(2, 42).toLowerCase(), 40);
  } else {
    return padLeft0(address.substring(0, 40).toLowerCase(), 40);
  } 
}

function uint256ToHex(number) {
  var bigNumber = new BigNumber(number).toString(16);
  if (bigNumber.substring(0, 2) == "0x") {
    return padLeft0(bigNumber.substring(2, 66).toLowerCase(), 64);
  } else {
    return padLeft0(bigNumber.substring(0, 64).toLowerCase(), 64);
  } 
}

function getSigR(sig) {
  if (sig.substring(0, 2) == "0x") {
    return "0x" + sig.substring(2, 66);
  } else {
    return "0x" + sig.substring(0, 64)
  } 
}

function getSigS(sig) {
  if (sig.substring(0, 2) == "0x") {
    return "0x" + sig.substring(66, 130);
  } else {
    return "0x" + sig.substring(64, 128)
  } 
}

function getSigV(sig) {
  if (sig.substring(0, 2) == "0x") {
    return "0x" + sig.substring(130, 132);
  } else {
    return "0x" + sig.substring(128, 130)
  } 
}


// -----------------------------------------------------------------------------
var signedTransferMessage = "Signed Transfers";
var functionSig = web3.sha3("signedTransfer(address,address,uint256,uint256,uint256,bytes,address)").substring(0,10);
var tokenContractAddress = tokenAddress;
var from = account3;
var to = account5;
var tokens = new BigNumber("1000000000000000000");
var fee = new BigNumber("10000000000000000");
var feeToken = token;
var nonce = "0";
// -----------------------------------------------------------------------------

var hashOf = "0x" + bytes4ToHex(functionSig) + addressToHex(tokenContractAddress) + addressToHex(from) + addressToHex(to) + uint256ToHex(tokens) + uint256ToHex(fee) + uint256ToHex(nonce);
console.log("RESULT: hashOf=" + hashOf);
var hash = web3.sha3(hashOf, {encoding: 'hex'});
console.log("RESULT: hash=" + hash);

// -----------------------------------------------------------------------------
console.log("RESULT: " + signedTransferMessage);
console.log("RESULT: functionSig=" + functionSig + " (should be '0x7532eaac')");

console.log("RESULT: from=" + from);
console.log("RESULT: to=" + to);
console.log("RESULT: tokens=" + tokens + " " + tokens.shift(-decimals));
console.log("RESULT: fee=" + fee + " " + fee.shift(-decimals));
console.log("RESULT: nonce=" + nonce);
var signedTransferHash = token.signedTransferHash(from, to, tokens, fee, nonce);
console.log("RESULT: signedTransferHash=" + signedTransferHash);
var sig = web3.eth.sign(from, signedTransferHash);
console.log("RESULT: sig=" + sig);

var signedTransfer1Check = token.signedTransferCheck(from, to, tokens, fee, nonce, sig, feeAccount);
console.log("RESULT: signedTransfer1Check=" + signedTransfer1Check + " " + signedTransferCheckResultString(signedTransfer1Check));
var signedTransfer1Tx = token.signedTransfer(from, to, tokens, fee, nonce, sig, feeAccount, 
  {from: contractOwnerAccount, gas: 200000, gasPrice: defaultGasPrice});
while (txpool.status.pending > 0) {
}
printTxData("signedTransfer1Tx", signedTransfer1Tx);
printBalances();
failIfTxStatusError(signedTransfer1Tx, signedTransferMessage + " - Signed Transfer ");
printTokenContractDetails();
console.log("RESULT: ");


var signedTransfer2Check = token.signedTransferCheck(from, to, tokens, fee, nonce, sig, feeAccount);
console.log("RESULT: signedTransfer2Check=" + signedTransfer2Check + " " + signedTransferCheckResultString(signedTransfer2Check));
var signedTransfer2Tx = token.signedTransfer(from, to, tokens, fee, nonce, sig, feeAccount,
  {from: contractOwnerAccount, gas: 200000, gasPrice: defaultGasPrice});
while (txpool.status.pending > 0) {
}
printTxData("signedTransfer2Tx", signedTransfer2Tx);
printBalances();
passIfTxStatusError(signedTransfer2Tx, signedTransferMessage + " - Duplicated Signed Transfers - Expecting Failure");
printTokenContractDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var signedApproveMessage = "Signed Approve";
var functionSig = web3.sha3("signedApprove(address,address,uint256,uint256,uint256,bytes,address)").substring(0,10);
var tokenContractAddress = tokenAddress;
var owner = account4;
var spender = account6;
var tokens = "50000000000000000000";
var fee = "500000000000000000";
var nonce = "0";
// -----------------------------------------------------------------------------

var signedApproveHash = token.signedApproveHash(tokenContractAddress,
  owner, spender, tokens, fee);
console.log("RESULT: signedApproveHash=" + signedApproveHash);

// -----------------------------------------------------------------------------
console.log("RESULT: " + signedApproveMessage);
console.log("RESULT: functionSig=" + functionSig + " (should be '0xe9afa7a1')");

var hashOf = "0x" + bytes4ToHex(functionSig) + addressToHex(tokenContractAddress) + addressToHex(owner) + addressToHex(spender) + uint256ToHex(tokens) + uint256ToHex(fee) + uint256ToHex(nonce);
console.log("RESULT: hashOf=" + hashOf);
var hash = web3.sha3(hashOf, {encoding: 'hex'});
console.log("RESULT: hash=" + hash);
var sig = web3.eth.sign(account4, hash);

// var sig = web3.eth.sign(account4, signedApproveHash);
console.log("RESULT: sig=" + sig);
var r = getSigR(sig);
var s = getSigS(sig);
var v = getSigV(sig);
console.log("RESULT: sigR=" + r);
console.log("RESULT: sigS=" + s);
console.log("RESULT: sigV=" + v);

var signedApprove1Check = token.signedApproveCheck(owner, spender, tokens, fee, nonce, sig, feeAccount);
console.log("RESULT: signedApprove1Check=" + signedApprove1Check + " " + signedTransferCheckResultString(signedApprove1Check));
var signedApprove1Tx = token.signedApprove(owner, spender, tokens, fee, nonce, sig, feeAccount,
  {from: contractOwnerAccount, gas: 200000, gasPrice: defaultGasPrice});
while (txpool.status.pending > 0) {
}
var signedApprove2Check = token.signedApproveCheck(owner, spender, tokens, fee, nonce, sig, feeAccount);
console.log("RESULT: signedApprove2Check=" + signedApprove2Check + " " + signedTransferCheckResultString(signedApprove2Check));
var signedApprove2Tx = token.signedApprove(owner, spender, tokens, fee, nonce, sig, feeAccount,
  {from: contractOwnerAccount, gas: 200000, gasPrice: defaultGasPrice});
while (txpool.status.pending > 0) {
}
printTxData("signedApprove1Tx", signedApprove1Tx);
printTxData("signedApprove2Tx", signedApprove2Tx);
printBalances();
failIfTxStatusError(signedApprove1Tx, signedApproveMessage + " - Signed Approve ");
passIfTxStatusError(signedApprove2Tx, signedApproveMessage + " - Duplicated Signed Approve - Expecting Failure");
printTokenContractDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var signedTransferFromMessage = "Signed TransferFrom";
var functionSig = web3.sha3("signedTransferFrom(address,address,address,uint256,uint256,uint256,bytes,address)").substring(0,10);
var tokenContractAddress = tokenAddress;
var spender = account6;
var from = account4;
var to = account7;
var tokens = "3000000000000000000";
var fee = "30000000000000000";


var signedTransferFromHash = token.signedTransferFromHash(spender, from, to, tokens, fee, nonce);
console.log("RESULT: signedTransferFromHash=" + signedTransferFromHash);

// -----------------------------------------------------------------------------
console.log("RESULT: " + signedTransferFromMessage);
console.log("RESULT: functionSig=" + functionSig + " (should be '0x344bcc7d')");

var hashOf = "0x" + bytes4ToHex(functionSig) + addressToHex(tokenContractAddress) + addressToHex(spender) + addressToHex(from) + addressToHex(to) + uint256ToHex(tokens) + uint256ToHex(fee) + uint256ToHex(nonce);
console.log("RESULT: hashOf=" + hashOf);
var hash = web3.sha3(hashOf, {encoding: 'hex'});
console.log("RESULT: hash=" + hash);
var sig = web3.eth.sign(account6, hash);

// var sig = web3.eth.sign(account4, signedTransferFromHash);
console.log("RESULT: sig=" + sig);
var r = getSigR(sig);
var s = getSigS(sig);
var v = getSigV(sig);
console.log("RESULT: sigR=" + r);
console.log("RESULT: sigS=" + s);
console.log("RESULT: sigV=" + v);

var signedTransferFrom1Check = token.signedTransferFromCheck(spender, from, to, tokens, fee, nonce, sig, feeAccount);
console.log("RESULT: signedTransferFrom1Check=" + signedTransferFrom1Check + " " + signedTransferCheckResultString(signedTransferFrom1Check));
var signedTransferFrom1Tx = token.signedTransferFrom(spender, from, to, tokens, fee, nonce, sig, feeAccount,
  {from: contractOwnerAccount, gas: 200000, gasPrice: defaultGasPrice});
while (txpool.status.pending > 0) {
}
var signedTransferFrom2Check = token.signedTransferFromCheck(spender, from, to, tokens, fee, nonce, sig, feeAccount);
console.log("RESULT: signedTransferFrom2Check=" + signedTransferFrom2Check + " " + signedTransferCheckResultString(signedTransferFrom2Check));
var signedTransferFrom2Tx = token.signedTransferFrom(spender, from, to, tokens, fee, nonce, sig, feeAccount,
  {from: contractOwnerAccount, gas: 200000, gasPrice: defaultGasPrice});
while (txpool.status.pending > 0) {
}
printTxData("signedTransferFrom1Tx", signedTransferFrom1Tx);
printTxData("signedTransferFrom2Tx", signedTransferFrom2Tx);
printBalances();
failIfTxStatusError(signedTransferFrom1Tx, signedTransferMessage + " - Signed TransferFrom ");
passIfTxStatusError(signedTransferFrom2Tx, signedTransferMessage + " - Duplicated Signed TransfersFrom - Expecting Failure");
printTokenContractDetails();
console.log("RESULT: ");

exit;


// -----------------------------------------------------------------------------
var transferTokenMessage = "Transfer Tokens";
// -----------------------------------------------------------------------------
console.log("RESULT: " + transferTokenMessage);
var transferToken1Tx = token.transfer(account3, "100000000000000000000", {from: contractOwnerAccount, gas: 100000, gasPrice: defaultGasPrice});
var transferToken2Tx = token.transfer(account4, "100000000000000000000", {from: contractOwnerAccount, gas: 100000, gasPrice: defaultGasPrice});
while (txpool.status.pending > 0) {
}
printTxData("transferToken1Tx", transferToken1Tx);
printTxData("transferToken2Tx", transferToken2Tx);
printBalances();
failIfTxStatusError(transferToken1Tx, transferTokenMessage + " - transfer 10,000 tokens ac1 -> ac3");
failIfTxStatusError(transferToken2Tx, transferTokenMessage + " - transfer 10,000 tokens ac1 -> ac4");
printTokenContractDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var moveTokenMessage = "Move 0 Tokens After Transfers Allowed";
// -----------------------------------------------------------------------------
console.log("RESULT: " + moveTokenMessage);
var moveToken1Tx = token.transfer(account5, "0", {from: account3, gas: 100000, gasPrice: defaultGasPrice});
var moveToken3Tx = token.transferFrom(account4, account7, "0", {from: account6, gas: 100000, gasPrice: defaultGasPrice});
while (txpool.status.pending > 0) {
}
printTxData("moveToken1Tx", moveToken1Tx);
printTxData("moveToken3Tx", moveToken3Tx);
printBalances();
failIfTxStatusError(moveToken1Tx, moveTokenMessage + " - transfer 0 tokens ac3 -> ac5. SHOULD not throw");
failIfTxStatusError(moveToken3Tx, moveTokenMessage + " - transferFrom 0 tokens ac4 -> ac7 by ac6. SHOULD not throw");
printTokenContractDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var moveTokenMessage = "Move More Tokens Than Owned";
// -----------------------------------------------------------------------------
console.log("RESULT: " + moveTokenMessage);
var moveToken1Tx = token.transfer(account5, "3000000000000000000000001", {from: account3, gas: 100000, gasPrice: defaultGasPrice});
var moveToken2Tx = token.approve(account6,  "3000000000000000000000001", {from: account4, gas: 100000, gasPrice: defaultGasPrice});
while (txpool.status.pending > 0) {
}
var moveToken3Tx = token.transferFrom(account4, account7, "3000000000000000000000001", {from: account6, gas: 100000, gasPrice: defaultGasPrice});
while (txpool.status.pending > 0) {
}
printTxData("moveToken1Tx", moveToken1Tx);
printTxData("moveToken2Tx", moveToken2Tx);
printTxData("moveToken3Tx", moveToken3Tx);
printBalances();
passIfTxStatusError(moveToken1Tx, moveTokenMessage + " - transfer 300K+1e-18 tokens ac3 -> ac5. SHOULD throw");
failIfTxStatusError(moveToken2Tx, moveTokenMessage + " - approve 300K+1e-18 tokens ac4 -> ac6");
passIfTxStatusError(moveToken3Tx, moveTokenMessage + " - transferFrom 300K+1e-18 tokens ac4 -> ac7 by ac6. SHOULD throw");
printTokenContractDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var approveTokenMessage = "Change Approval Without Setting To 0";
// -----------------------------------------------------------------------------
console.log("RESULT: " + approveTokenMessage);
var approveToken2Tx = token.approve(account6,  "3000000000000000000000002", {from: account4, gas: 100000, gasPrice: defaultGasPrice});
while (txpool.status.pending > 0) {
}
printTxData("approveToken2Tx", approveToken2Tx);
printBalances();
passIfTxStatusError(approveToken2Tx, approveTokenMessage + " - approve 300K+2e-18 tokens ac4 -> ac6. SHOULD throw");
printTokenContractDetails();
console.log("RESULT: ");


// -----------------------------------------------------------------------------
var approveTokenMessage = "Change Approval By Setting To 0 In Between";
// -----------------------------------------------------------------------------
console.log("RESULT: " + approveTokenMessage);
var approveToken2Tx = token.approve(account6,  "0", {from: account4, gas: 100000, gasPrice: defaultGasPrice});
while (txpool.status.pending > 0) {
}
var approveToken3Tx = token.approve(account6,  "3000000000000000000000002", {from: account4, gas: 100000, gasPrice: defaultGasPrice});
while (txpool.status.pending > 0) {
}
printTxData("approveToken2Tx", approveToken2Tx);
printTxData("approveToken3Tx", approveToken3Tx);
printBalances();
failIfTxStatusError(approveToken2Tx, approveTokenMessage + " - approve 0 tokens ac4 -> ac6");
failIfTxStatusError(approveToken3Tx, approveTokenMessage + " - approve 300K+2e-18 tokens ac4 -> ac6");
printTokenContractDetails();
console.log("RESULT: ");


EOF
grep "DATA: " $TEST1OUTPUT | sed "s/DATA: //" > $DEPLOYMENTDATA
cat $DEPLOYMENTDATA
grep "RESULT: " $TEST1OUTPUT | sed "s/RESULT: //" > $TEST1RESULTS
cat $TEST1RESULTS
