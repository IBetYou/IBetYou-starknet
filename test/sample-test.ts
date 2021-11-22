import { expect } from "chai";
import { starknet } from "hardhat";
import { StarknetContract, StarknetContractFactory } from "hardhat/types/runtime";

const starkwareCrypto = require('../lib/crypto/starkware/crypto/signature/signature.js');

describe("Starknet", function () {
  this.timeout(300_000); // 5 min
  let preservedAddress: string;

  let contractFactory: StarknetContractFactory;

  // Amount variables
  const balance_amount = 50;
  const bet_amount = 10;
  const balance_ammount_message_hash = starkwareCrypto.pedersen([balance_amount,0]);
  const bet_amount_message_hash = starkwareCrypto.pedersen([bet_amount]);

  //Key definition and generation
  const bettor_private_key = 12345;
  const counter_bettor_private_key = 54321;
  const judge_private_key = 121212;

  const bettor_key_pair = starkwareCrypto.ec.keyFromPrivate(bettor_private_key, 'hex');
  const bettor_public_key = starkwareCrypto.ec.keyFromPublic(bettor_key_pair.getPublic(true, 'hex'), 'hex');
  
  
  const counter_bettor_key_pair = starkwareCrypto.ec.keyFromPrivate(counter_bettor_private_key, 'hex');
  const counter_bettor_public_key = starkwareCrypto.ec.keyFromPublic(counter_bettor_key_pair.getPublic(true,'hex'), 'hex');
  
  
  const judge_key_pair = starkwareCrypto.ec.keyFromPrivate(judge_private_key, 'hex');
  const judge_public_key =   starkwareCrypto.ec.keyFromPublic(judge_key_pair.getPublic(true,'hex'), 'hex');

  //Message hash definition
  const balance_signature_bettor = starkwareCrypto.sign(bettor_key_pair, balance_ammount_message_hash);
  const balance_signature_counter_bettor = starkwareCrypto.sign(counter_bettor_key_pair, balance_ammount_message_hash);

  const bet_amount_signature_bettor = starkwareCrypto.sign(bettor_key_pair,bet_amount_message_hash)

  const bettor_pub_key = "0x"+bettor_public_key.pub.getX().toString(16);
  const counter_bettor_pub_key = "0x"+counter_bettor_public_key.pub.getX().toString(16);
  const judge_pub_key = "0x"+judge_public_key.pub.getX().toString(16);
  const judge_message_hash = starkwareCrypto.pedersen([bettor_public_key.pub.getX().toString(16)]);
  const judge_signature = starkwareCrypto.sign(judge_key_pair,judge_message_hash)
  before(async function() {
    contractFactory = await starknet.getContractFactory("contract");
  });

  it("should work for a fresh deployment", async function () {
    const contract: StarknetContract = await contractFactory.deploy();
    console.log("Deployed at", contract.address);
    preservedAddress = contract.address;
    
    var r = "0x" + balance_signature_bettor.r.toString(16);
    var s = "0x" + balance_signature_bettor.s.toString(16);
    await contract.invoke("increase_balance", {user_id:BigInt(bettor_pub_key), amount:balance_amount},[BigInt(r),BigInt(s)]);
    console.log("Increased user 1 amount by " + balance_amount);
    const balanceStr1 = await contract.call("get_balance", {user_id:BigInt(bettor_pub_key)});
    const balance1 = parseInt(balanceStr1.res);
    expect(balance1).to.equal(balance_amount);

    
    r = "0x" + balance_signature_counter_bettor.r.toString(16);
    s = "0x" + balance_signature_counter_bettor.s.toString(16);
    await contract.invoke("increase_balance", {user_id:BigInt(counter_bettor_pub_key), amount:balance_amount},[BigInt(r),BigInt(s)]);
    console.log("Increased user 2 amount by " + balance_amount);
    const balanceStr2 = await contract.call("get_balance", {user_id:BigInt(counter_bettor_pub_key)});
    const balance2 = parseInt(balanceStr2.res);
    expect(balance2).to.equal(balance_amount);    
  });

  it("user 1 amount should reduce by x after creating a bet of x amount", async function() {
    const contract: StarknetContract = contractFactory.getContractAt(preservedAddress);
    var r = "0x" + bet_amount_signature_bettor.r.toString(16);
    var s = "0x" + bet_amount_signature_bettor.s.toString(16);
    await contract.invoke("createBet", {user_id:BigInt(bettor_pub_key), amount:bet_amount, bet:12345},[BigInt(r),BigInt(s)]);
    console.log("Created a bet of amount " + bet_amount);
    const balanceStr = await contract.call("get_balance", {user_id:BigInt(bettor_pub_key)});
    const balance = parseInt(balanceStr.res);
    expect(balance).to.equal(balance_amount-bet_amount);
  });

  it("user 2 joins the bet and amount should reduce by x after joining the bet of x amount", async function() {
    const contract: StarknetContract = contractFactory.getContractAt(preservedAddress);
    await contract.invoke("joinCounterBettor",  {user_id:BigInt(counter_bettor_pub_key)});
    console.log("User 2 joined the bet of amount " + bet_amount);
    const balanceStr = await contract.call("get_balance",  {user_id:BigInt(counter_bettor_pub_key)});
    const balance = parseInt(balanceStr.res);
    expect(balance).to.equal(balance_amount-bet_amount);
  });

  it("user 3 joins the bet as judge and votes user 1 as winner", async function() {
    const contract: StarknetContract = contractFactory.getContractAt(preservedAddress);
    await contract.invoke("joinJudge", {user_id:BigInt(judge_pub_key)});
    console.log("User 3 joined the bet as judge, and voted user 1 as winner");
    var r = "0x" + judge_signature.r.toString(16);
    var s = "0x" + judge_signature.s.toString(16);
    await contract.invoke("voteBettor", {judge:BigInt(judge_pub_key),bettor_id:BigInt(bettor_pub_key)},[BigInt(r),BigInt(s)]);
    const balanceStr = await contract.call("get_balance", {user_id:BigInt(bettor_pub_key)});
    const balance = parseInt(balanceStr.res);
    expect(balance).to.equal(balance_amount+bet_amount);
  });
});