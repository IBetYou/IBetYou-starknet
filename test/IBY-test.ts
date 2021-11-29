import { expect } from "chai";
import { starknet } from "hardhat";
import { StarknetContract, StarknetContractFactory } from "hardhat/types/runtime";

describe("Starknet", function () {
  this.timeout(300_000); // 5 min
  let accountContractAddress: string;
  let masterContractAddress: string;
  
  let accountContractFactory: StarknetContractFactory;
  let masterContractFactory: StarknetContractFactory;

  let accountContract: StarknetContract;
  let masterContract: StarknetContract;
  let betContract: StarknetContract;

  let betContractFactory: StarknetContractFactory;
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
    accountContract = await accountContractFactory.deploy();
    masterContract = await masterContractFactory.deploy();
    console.log("Deployed Account contract at", accountContract.address);
    console.log("Deployed Master contract at", masterContract.address);
    accountContractAddress = accountContract.address;
    masterContractAddress = masterContract.address;
  });

  it("Happy flow test (no dispute)", async function () {

    //Create a new bet
    await generate_bet();

    //Confirm bet is in role assignment stage
    var bet_status = await betContract.call("get_bet_status");
    var bet_state = bet_status.bet.bet_state
    expect(bet_state).to.deep.equal(BigInt(1));

    //Counter bettor joins the bet
    await masterContract.invoke("join_counter_bettor",  {user_id:counter_bettor_id, amount:bet_amount,  bet_address:BigInt(betContract.address), account_address: BigInt(accountContractAddress)});
    var counter_bettor_balance = await accountContract.call("get_balance",  {user_id:BigInt(counter_bettor_id)});
    expect(counter_bettor_balance.res).to.deep.equal(BigInt(balance_amount - bet_amount));
    console.log("Balance of User 2 after joining bet: " + counter_bettor_balance.res);

    //Judges join the bet
    await masterContract.invoke("join_bettor_judge", {user_id:bettor_judge_id, bet_address:BigInt(betContract.address)});
    await masterContract.invoke("join_counter_bettor_judge", {user_id:counter_bettor_judge_id, bet_address:BigInt(betContract.address)});

    //Confirm judges are in the bet and bet is in voting stage
    bet_status = await betContract.call("get_bet_status");
    const bettor_judge = bet_status.bet.bettor_judge;
    const counter_bettor_judge = bet_status.bet.counter_bettor_judge;
    bet_state = bet_status.bet.bet_state;
    expect(bettor_judge).to.deep.equal(BigInt(bettor_judge_id));
    expect(counter_bettor_judge).to.deep.equal(BigInt(counter_bettor_judge_id));
    expect(bet_state).to.deep.equal(BigInt(2));

    //Judges vote for user 1
    await betContract.invoke("bettor_judge_vote", {user_id:bettor_id,bet_address:BigInt(betContract.address)});
    await betContract.invoke("counter_bettor_judge_vote", {user_id:bettor_id,bet_address:BigInt(betContract.address)});
    
    //Confirm user 1 is winner and bet is at withdrawal stage
    bet_status = await betContract.call("get_bet_status");
    const bet_winner = bet_status.bet.bet_winner
    bet_state = bet_status.bet.bet_state
    expect(bet_state).to.deep.equal(BigInt(3));
    expect(bet_winner).to.deep.equal(BigInt(bettor_id));
    console.log('Winner is user ' + bettor_id);

    //Withdraw funds
    await masterContract.invoke("withdraw_funds", {bet_address:BigInt(betContract.address),account_address:BigInt(accountContractAddress)});
    var balance1 = await accountContract.call("get_balance", {user_id:bettor_id});
    expect(balance1.res).to.deep.equal(BigInt(balance_amount)+BigInt(bet_amount));
    bet_status = await betContract.call("get_bet_status");
    bet_state = bet_status.bet.bet_state
    expect(bet_state).to.deep.equal(BigInt(4));

    console.log('Finished happy flow test');


    /*
     *  Helper function to generate a new bet
     */
    async function generate_bet() {
      betContractFactory = await starknet.getContractFactory("Bet");
      betContract = await betContractFactory.deploy();
      console.log("Deployed Bet contract at", betContract.address);

      //Increase bettor balance
      await accountContract.invoke("add_balance", { user_id: bettor_id, amount: balance_amount });
      console.log("Increased user 1 amount by " + balance_amount);
      var bettor_balance = await accountContract.call("get_balance", { user_id: bettor_id });
      expect(bettor_balance.res).to.deep.equal(BigInt(balance_amount));

      //Increase counter bettor balance
      await accountContract.invoke("add_balance", { user_id: counter_bettor_id, amount: balance_amount });
      console.log("Increased user 2 amount by " + balance_amount);
      var counter_bettor_balance = await accountContract.call("get_balance", { user_id: counter_bettor_id });
      expect(counter_bettor_balance.res).to.deep.equal(BigInt(balance_amount));

      //Bettor creates the bet at the generated bet contract
      await masterContract.invoke("create_bet", { user_id: BigInt(bettor_id), amount: bet_amount, bet_address: BigInt(betContract.address), account_address: BigInt(accountContractAddress), admin_id: BigInt(admin_id) });
      console.log("Created a bet of amount " + bet_amount);
      bettor_balance = await accountContract.call("get_balance", { user_id: bettor_id });
      console.log(balance1);
      expect(bettor_balance.res).to.deep.equal(BigInt(balance_amount - bet_amount));
    }
  });
});