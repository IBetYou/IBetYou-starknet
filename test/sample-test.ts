import { expect } from "chai";
import { starknet } from "hardhat";
import { StarknetContract, StarknetContractFactory } from "hardhat/types/runtime";

const starkwareCrypto = require("../lib/crypto/starkware/crypto/signature/signature.js");

describe("Starknet", function () {
  this.timeout(300_000); // 5 min
  let preservedAddress: string;

  let contractFactory: StarknetContractFactory;

  // Amount variables
  const balance_amount = 50;
  const bet_amount = 10;


  //Bettor key variables
  const bettor_private_key = 12345;
  const bettor_key_pair = starkwareCrypto.ec.keyFromPrivate(bettor_private_key, 'hex');
  const bettor_public_key = starkwareCrypto.ec.keyFromPublic(bettor_key_pair.getPublic(true, 'hex'), 'hex').pub.getX().toString(16);
  
  //Counter bettor key variables
  const counter_bettor_private_key = 54321;
  const counter_bettor_key_pair = starkwareCrypto.ec.keyFromPrivate(counter_bettor_private_key, 'hex');
  const counter_bettor_public_key = starkwareCrypto.ec.keyFromPublic(counter_bettor_key_pair.getPublic(true,'hex'), 'hex').pub.getX().toString(16);
    
  before(async function() {
    contractFactory = await starknet.getContractFactory("contract");
    const contract: StarknetContract = await contractFactory. deploy();
    console.log("Deployed at", contract.address);
    preservedAddress = contract.address;
  });

  it("users 1 and 2 amount should increase by x", async function () {
    const contract: StarknetContract = contractFactory.getContractAt(preservedAddress);
    //Balance increase message signature
    const balance_ammount_message_hash = starkwareCrypto.pedersen([balance_amount,0]);
    const balance_signature_bettor = starkwareCrypto.sign(bettor_key_pair, balance_ammount_message_hash);
    const balance_signature_counter_bettor = starkwareCrypto.sign(counter_bettor_key_pair, balance_ammount_message_hash);
    
    //Increase user 1 balance
    var r = "0x" + balance_signature_bettor.r.toString(16);
    var s = "0x" + balance_signature_bettor.s.toString(16);
    await contract.invoke("increase_balance", {user_id:BigInt("0x"+bettor_public_key), amount:balance_amount},[BigInt(r),BigInt(s)]);
    console.log("Increased user 1 amount by " + balance_amount);
    const balance1 = await contract.call("get_balance", {user_id:BigInt("0x"+bettor_public_key)});
    expect(balance1.res).to.deep.equal(BigInt(balance_amount));
    
    //Increase user 2 balance
    r = "0x" + balance_signature_counter_bettor.r.toString(16);
    s = "0x" + balance_signature_counter_bettor.s.toString(16);
    await contract.invoke("increase_balance", {user_id:BigInt("0x"+counter_bettor_public_key), amount:balance_amount},[BigInt(r),BigInt(s)]);
    console.log("Increased user 2 amount by " + balance_amount);
    const balance2 = await contract.call("get_balance", {user_id:BigInt("0x"+counter_bettor_public_key)});
    expect(balance2.res).to.deep.equal(BigInt(balance_amount));    
  });

  it("user 1 amount should reduce by x after creating a bet of x amount", async function() {
    const contract: StarknetContract = contractFactory.getContractAt(preservedAddress);

    //Bet creation message signature
    const bet_amount_message_hash = starkwareCrypto.pedersen([bet_amount]);
    const bet_amount_signature_bettor = starkwareCrypto.sign(bettor_key_pair,bet_amount_message_hash)
    const r = "0x" + bet_amount_signature_bettor.r.toString(16);
    const s = "0x" + bet_amount_signature_bettor.s.toString(16);

    await contract.invoke("createBet", {user_id:BigInt("0x"+bettor_public_key), amount:bet_amount, bet:12345},[BigInt(r),BigInt(s)]);
    console.log("Created a bet of amount " + bet_amount);
    const balance = await contract.call("get_balance", {user_id:BigInt("0x"+bettor_public_key)});
    expect(balance.res).to.deep.equal(BigInt(balance_amount)-BigInt(bet_amount));
  });

  it("user 2 joins the bet and amount should reduce by x after joining the bet of x amount", async function() {
    const contract: StarknetContract = contractFactory.getContractAt(preservedAddress);
    await contract.invoke("joinCounterBettor",  {user_id:BigInt("0x"+counter_bettor_public_key)});
    console.log("User 2 joined the bet of amount " + bet_amount);
    const balance = await contract.call("get_balance",  {user_id:BigInt("0x"+counter_bettor_public_key)});
    expect(balance.res).to.deep.equal(BigInt(balance_amount)-BigInt(bet_amount));
  });

  it("user 3 joins the bet as judge and votes user 1 as winner", async function() {
    //Judge key variables
    const judge_private_key = 121212;
    const judge_key_pair = starkwareCrypto.ec.keyFromPrivate(judge_private_key, 'hex');
    const judge_public_key =   starkwareCrypto.ec.keyFromPublic(judge_key_pair.getPublic(true,'hex'), 'hex').pub.getX().toString(16);
    const contract: StarknetContract = contractFactory.getContractAt(preservedAddress);
    await contract.invoke("joinJudge", {user_id:BigInt("0x"+judge_public_key)});
    console.log("User 3 joined the bet as judge, and voted user 1 as winner");
    //Judge voting message signature
    const judge_message_hash = starkwareCrypto.pedersen([bettor_public_key]);
    const judge_signature = starkwareCrypto.sign(judge_key_pair,judge_message_hash)
    const r = "0x" + judge_signature.r.toString(16);
    const s = "0x" + judge_signature.s.toString(16);
    await contract.invoke("voteBettor", {judge:BigInt("0x"+judge_public_key),bettor_id:BigInt("0x"+bettor_public_key)},[BigInt(r),BigInt(s)]);
    const balance = await contract.call("get_balance", {user_id:BigInt("0x"+bettor_public_key)});console.log("here5");
    expect(balance.res).to.deep.equal(BigInt(balance_amount)+BigInt(bet_amount));
  });
});