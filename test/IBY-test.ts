import { expect } from "chai";
import { starknet } from "hardhat";
import { StarknetContract, StarknetContractFactory } from "hardhat/types/runtime";

describe("Starknet", function () {
  this.timeout(300_000); // 5 min
  let accountContractAddress: string;
  let masterContractAddress: string;
  
  let accountContractFactory: StarknetContractFactory;
  let masterContractFactory: StarknetContractFactory;
  

  // Amount variables
  const balance_amount = 50;
  const bet_amount = 10;

  //Bettor key variables
  const bettor_id = 1
  const counter_bettor_id = 2;
  const bettor_judge_id = 3;
  const counter_bettor_judge_id = 4;
  const admin_id = 5;
    
  before(async function() {
    accountContractFactory = await starknet.getContractFactory("account");
    masterContractFactory = await starknet.getContractFactory("Master");
    const accountContract: StarknetContract = await accountContractFactory.deploy();
    const masterContract: StarknetContract = await masterContractFactory.deploy();
    console.log("Deployed Account contract at", accountContract.address);
    console.log("Deployed Master contract at", masterContract.address);
    accountContractAddress = accountContract.address;
    masterContractAddress = masterContract.address;
  });

  it("Happy flow test (no dispute)", async function () {
    //Create a new bet
    const accountContract: StarknetContract = accountContractFactory.getContractAt(accountContractAddress);
    let betContractFactory: StarknetContractFactory;
    betContractFactory = await starknet.getContractFactory("Bet");
    const betContract: StarknetContract = await betContractFactory.deploy();
    console.log("Deployed Bet contract at", betContract.address);

    //Increase user 1 balance
    await accountContract.invoke("add_balance", {user_id:bettor_id, amount:balance_amount});
    console.log("Increased user 1 amount by " + balance_amount);
    var balance1 = await accountContract.call("get_balance", {user_id:bettor_id});
    expect(balance1.res).to.deep.equal(BigInt(balance_amount));

    //Confirm bet is in role assignment stage
    var bet_status = await betContract.call("get_bet_status");
    var bet_state = bet_status.bet.bet_state
    expect(bet_state).to.deep.equal(BigInt(1));

    
    //Increase user 2 balance
    await accountContract.invoke("add_balance", {user_id:counter_bettor_id, amount:balance_amount});
    console.log("Increased user 2 amount by " + balance_amount);
    var balance2 = await accountContract.call("get_balance", {user_id:counter_bettor_id});
    expect(balance2.res).to.deep.equal(BigInt(balance_amount));    

    //User 1 creates the bet at the generated bet contract
    await betContract.invoke("create_bet", {user_id:bettor_id, amount:bet_amount, bet_address:betContract.address, account_address: accountContractAddress, admin_id: admin_id});
    console.log("Created a bet of amount " + bet_amount);
    balance1 = await accountContract.call("get_balance", {user_id:bettor_id});
    expect(balance1.res).to.deep.equal(BigInt(balance_amount)-BigInt(bet_amount));

    //User 2 joins the bet
    await betContract.invoke("join_counter_bettor",  {user_id:counter_bettor_id,  bet_address:betContract.address, account_address: accountContractAddress});
    console.log("User 2 joined the bet of amount " + bet_amount);
    balance2 = await accountContract.call("get_balance",  {user_id:BigInt("0x"+counter_bettor_id)});
    expect(balance2.res).to.deep.equal(BigInt(balance_amount)-BigInt(bet_amount));

    //Judges join the bet
    await betContract.invoke("join_bettor_judge", {user_id:bettor_judge_id, bet_address:betContract.address});
    await betContract.invoke("join_counter_bettor_judge", {user_id:counter_bettor_judge_id, bet_address:betContract.address});
    console.log("User 3 joined the bet as judge");
    console.log("User 4 joined the bet as judge");

    //Confirm judges are in the bet and bet is in voting stage
    bet_status = await betContract.call("get_bet_status");
    const bettor_judge = bet_status.bet.bettor_judge;
    const counter_bettor_judge = bet_status.bet.counter_bettor_judge;
    bet_state = bet_status.bet.bet_state;
    expect(bettor_judge).to.deep.equal(BigInt(bettor_judge_id));
    expect(counter_bettor_judge).to.deep.equal(BigInt(counter_bettor_judge_id));
    expect(bet_state).to.deep.equal(BigInt(2));

    //Judges vote for user 1
    await betContract.invoke("bettor_judge_vote", {user_id:bettor_id,bet_address:betContract.address});
    await betContract.invoke("counter_bettor_judge_vote", {user_id:bettor_id,bet_address:betContract.address});
    
    //Confirm user 1 is winner and bet is at withdrawal stage
    bet_status = await betContract.call("get_bet_status");
    const bet_winner = bet_status.bet.bet_winner
    bet_state = bet_status.bet.bet_state
    expect(bet_state).to.deep.equal(BigInt(3));
    expect(bet_winner).to.deep.equal(BigInt(bettor_id));
    console.log('Winner is user ' + bettor_id);

    //Withdraw funds
    const masterContract: StarknetContract = masterContractFactory.getContractAt(masterContractAddress);
    await masterContract.invoke("withdraw_funds", {user_id:bettor_id,bet_address:betContract.address});

    balance1 = await accountContract.call("get_balance", {user_id:bettor_id});
    expect(balance1.res).to.deep.equal(BigInt(balance_amount)+BigInt(bet_amount));
    bet_status = await betContract.call("get_bet_status");
    bet_state = bet_status.bet.bet_state
    expect(bet_state).to.deep.equal(BigInt(3));

  });
});