import { expect } from "chai";
import { starknet } from "hardhat";
import { StarknetContract, StarknetContractFactory } from "hardhat/types/runtime";

describe("Starknet", function () {
  this.timeout(700_000); // 5 min
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
  const bettor_id = BigInt(1);
  const counter_bettor_id = 2;
  const bettor_judge_id = 3;
  const counter_bettor_judge_id = 4;
  const admin_id = 5;
    

  it("Test a normal bet flow", async function () {

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
    await masterContract.invoke("bettor_judge_vote", {user_id:BigInt(bettor_id),bet_address:BigInt(betContract.address)});
    await masterContract.invoke("counter_bettor_judge_vote", {user_id:BigInt(bettor_id),bet_address:BigInt(betContract.address)});
    
    //Confirm user 1 is winner and bet is at withdrawal stage
    bet_status = await betContract.call("get_bet_status");
    const bet_winner = bet_status.bet.bet_winner
    bet_state = bet_status.bet.bet_state
    expect(bet_state).to.deep.equal(BigInt(3));
    expect(bet_winner).to.deep.equal(bettor_id);
    console.log('Winner is user ' + bettor_id);

    var bw = await masterContract.call("get_winner",{bet_address:BigInt(betContract.address)});
    console.log('get_winner result:  ' + bw.res);
    //Withdraw funds
    await masterContract.invoke("withdraw_funds", {bet_address:BigInt(betContract.address), account_address: BigInt(accountContractAddress)});
    var balance1 = await accountContract.call("get_balance", {user_id:BigInt(bettor_id)});
    expect(balance1.res).to.deep.equal(BigInt(balance_amount + bet_amount));
    bet_status = await betContract.call("get_bet_status");
    bet_state = bet_status.bet.bet_state
    expect(bet_state).to.deep.equal(BigInt(4));

    console.log('Finished happy flow test');


    
  });

  
  it("Test a bet with a dispute", async function () {

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

    //Judge 1 votes for user 1 and judge 2 votes for user 2
    await masterContract.invoke("bettor_judge_vote", {user_id:bettor_id,bet_address:BigInt(betContract.address)});
    await masterContract.invoke("counter_bettor_judge_vote", {user_id:counter_bettor_id,bet_address:BigInt(betContract.address)});
    
    //Confirm the bet is in Dispute status
    bet_status = await betContract.call("get_bet_status");
    bet_state = bet_status.bet.bet_state;
    expect(bet_state).to.deep.equal(BigInt(5));

    //Admin solves dispute
    await masterContract.invoke("solve_dispute",{user_id:BigInt(bettor_id),bet_address:BigInt(betContract.address)});

    //Confirm user 1 is winner and bet is at withdrawal stage
    bet_status = await betContract.call("get_bet_status");
    const bet_winner = bet_status.bet.bet_winner
    bet_state = bet_status.bet.bet_state
    expect(bet_state).to.deep.equal(BigInt(3));
    expect(bet_winner).to.deep.equal(bettor_id);
    console.log('Winner is user ' + bettor_id);

    //Withdraw funds
    await masterContract.invoke("withdraw_funds", {bet_address:BigInt(betContract.address), account_address: BigInt(accountContractAddress)});
    var balance1 = await accountContract.call("get_balance", {user_id:BigInt(bettor_id)});
    expect(balance1.res).to.deep.equal(BigInt(balance_amount + bet_amount));
    bet_status = await betContract.call("get_bet_status");
    bet_state = bet_status.bet.bet_state
    expect(bet_state).to.deep.equal(BigInt(4));

    console.log('Finished dispute flow test');


    
  });


  it("Test the bet state validations", async function () {

    //Create a new bet
    await generate_bet();

    //Confirm bet is in role assignment stage
    var bet_status = await betContract.call("get_bet_status");
    var bet_state = bet_status.bet.bet_state
    expect(bet_state).to.deep.equal(BigInt(1));

    //Trying to vote before all roles have been assigned should result in error
    await masterContract.invoke("bettor_judge_vote", {user_id:bettor_id,bet_address:BigInt(betContract.address)})
    .catch(error => {
      expect(error.toString()).to.deep.equal("Error: Transaction rejected.");
    });
    await masterContract.invoke("counter_bettor_judge_vote", {user_id:counter_bettor_id,bet_address:BigInt(betContract.address)})
    .catch(error => {
      expect(error.toString()).to.deep.equal("Error: Transaction rejected.");
    });

    //Trying to solve a dispute at this stage should also result in error
    await masterContract.invoke("solve_dispute",{user_id:BigInt(bettor_id),bet_address:BigInt(betContract.address)})
    .catch(error => {
      expect(error.toString()).to.deep.equal("Error: Transaction rejected.");
    });

    //Trying to withdraw funds at this stage should also result in errorTrying to withdraw funds at this stage should also result in error
    await masterContract.invoke("withdraw_funds", {bet_address:BigInt(betContract.address), account_address: BigInt(accountContractAddress)})
    .catch(error => {
      expect(error.toString()).to.deep.equal("Error: Transaction rejected.");
    });

    //Trying to assign an user that already has a role assigned to another role should result in error
    await masterContract.invoke("join_counter_bettor",  {user_id:bettor_id, amount:bet_amount,  bet_address:BigInt(betContract.address), account_address: BigInt(accountContractAddress)})
    .catch(error => {
      expect(error.toString()).to.deep.equal("Error: Transaction rejected.");
    });
    await masterContract.invoke("join_bettor_judge", {user_id:bettor_id, bet_address:BigInt(betContract.address)})
    .catch(error => {
      expect(error.toString()).to.deep.equal("Error: Transaction rejected.");
    });
    await masterContract.invoke("join_counter_bettor_judge", {user_id:bettor_id, bet_address:BigInt(betContract.address)})
    .catch(error => {
      expect(error.toString()).to.deep.equal("Error: Transaction rejected.");
    });

    //Users join the bet
    await masterContract.invoke("join_counter_bettor",  {user_id:counter_bettor_id, amount:bet_amount,  bet_address:BigInt(betContract.address), account_address: BigInt(accountContractAddress)});
    await masterContract.invoke("join_bettor_judge", {user_id:bettor_judge_id, bet_address:BigInt(betContract.address)});
    await masterContract.invoke("join_counter_bettor_judge", {user_id:counter_bettor_judge_id, bet_address:BigInt(betContract.address)});

    //Trying to reassign users to roles should result in error
    await masterContract.invoke("join_counter_bettor",  {user_id:counter_bettor_id, amount:bet_amount,  bet_address:BigInt(betContract.address), account_address: BigInt(accountContractAddress)})
    .catch(error => {
      expect(error.toString()).to.deep.equal("Error: Transaction rejected.");
    });
    await masterContract.invoke("join_bettor_judge", {user_id:bettor_judge_id, bet_address:BigInt(betContract.address)})
    .catch(error => {
      expect(error.toString()).to.deep.equal("Error: Transaction rejected.");
    });
    await masterContract.invoke("join_counter_bettor_judge", {user_id:counter_bettor_judge_id, bet_address:BigInt(betContract.address)})
    .catch(error => {
      expect(error.toString()).to.deep.equal("Error: Transaction rejected.");
    });

    //Confirm bet is in voting stage
    bet_status = await betContract.call("get_bet_status");
    bet_state = bet_status.bet.bet_state;
    expect(bet_state).to.deep.equal(BigInt(2));

    //Trying to solve a dispute at this stage should also result in error
    await masterContract.invoke("solve_dispute",{user_id:BigInt(bettor_id),bet_address:BigInt(betContract.address)})
    .catch(error => {
      expect(error.toString()).to.deep.equal("Error: Transaction rejected.");
    });

    //Judge 1 votes for user 1 and judge 2 votes for user 2
    await masterContract.invoke("bettor_judge_vote", {user_id:bettor_id,bet_address:BigInt(betContract.address)});
    await masterContract.invoke("counter_bettor_judge_vote", {user_id:counter_bettor_id,bet_address:BigInt(betContract.address)});
    
    //Confirm the bet is in Dispute status
    bet_status = await betContract.call("get_bet_status");
    bet_state = bet_status.bet.bet_state;
    expect(bet_state).to.deep.equal(BigInt(5));

    //Trying to withdraw funds at this stage should also result in errorTrying to withdraw funds at this stage should also result in error
    await masterContract.invoke("withdraw_funds", {bet_address:BigInt(betContract.address), account_address: BigInt(accountContractAddress)})
    .catch(error => {
      expect(error.toString()).to.deep.equal("Error: Transaction rejected.");
    });


    //Trying to vote again should result in error
    await masterContract.invoke("bettor_judge_vote", {user_id:bettor_id,bet_address:BigInt(betContract.address)})
    .catch(error => {
      expect(error.toString()).to.deep.equal("Error: Transaction rejected.");
    });
    await masterContract.invoke("counter_bettor_judge_vote", {user_id:counter_bettor_id,bet_address:BigInt(betContract.address)})
    .catch(error => {
      expect(error.toString()).to.deep.equal("Error: Transaction rejected.");
    });

    //Admin solves dispute
    await masterContract.invoke("solve_dispute",{user_id:BigInt(bettor_id),bet_address:BigInt(betContract.address)});

    //Confirm user 1 is winner and bet is at withdrawal stage
    bet_status = await betContract.call("get_bet_status");
    const bet_winner = bet_status.bet.bet_winner
    bet_state = bet_status.bet.bet_state
    expect(bet_state).to.deep.equal(BigInt(3));
    expect(bet_winner).to.deep.equal(bettor_id);
    console.log('Winner is user ' + bettor_id);

    //Withdraw funds
    await masterContract.invoke("withdraw_funds", {bet_address:BigInt(betContract.address), account_address: BigInt(accountContractAddress)});
    var balance1 = await accountContract.call("get_balance", {user_id:BigInt(bettor_id)});
    expect(balance1.res).to.deep.equal(BigInt(balance_amount + bet_amount));
    bet_status = await betContract.call("get_bet_status");
    bet_state = bet_status.bet.bet_state
    expect(bet_state).to.deep.equal(BigInt(4));

    console.log('Finished state validations test');


    
  });

    /*
     *  Helper function to generate a new bet
     */
  async function generate_bet() {
    accountContractFactory = await starknet.getContractFactory("account");
    masterContractFactory = await starknet.getContractFactory("Master");
    accountContract = await accountContractFactory.deploy();
    masterContract = await masterContractFactory.deploy();
    console.log("Deployed Account contract at", accountContract.address);
    console.log("Deployed Master contract at", masterContract.address);
    accountContractAddress = accountContract.address;
    masterContractAddress = masterContract.address;

    betContractFactory = await starknet.getContractFactory("Bet");
    betContract = await betContractFactory.deploy();
    console.log("Deployed Bet contract at", betContract.address);

    //Increase bettor balance
    await accountContract.invoke("add_balance", { user_id: BigInt(bettor_id), amount: balance_amount });
    
    console.log("Increased user 1 amount by " + balance_amount);
    var bettor_balance = await accountContract.call("get_balance", { user_id: BigInt(bettor_id) });
    expect(bettor_balance.res).to.deep.equal(BigInt(balance_amount));
    //Increase counter bettor balance
    await accountContract.invoke("add_balance", { user_id: counter_bettor_id, amount: balance_amount });
    console.log("Increased user 2 amount by " + balance_amount);
    var counter_bettor_balance = await accountContract.call("get_balance", { user_id: counter_bettor_id });
    expect(counter_bettor_balance.res).to.deep.equal(BigInt(balance_amount));
    //Bettor creates the bet at the generated bet contract
    await masterContract.invoke("create_bet", { user_id: BigInt(bettor_id), amount: BigInt(bet_amount), bet_address: BigInt(betContract.address), account_address: BigInt(accountContractAddress), admin_id: BigInt(admin_id) });
    console.log("Created a bet of amount " + bet_amount);
    bettor_balance = await accountContract.call("get_balance", { user_id: BigInt(bettor_id) });
    expect(bettor_balance.res).to.deep.equal(BigInt(balance_amount - bet_amount));
  }
});

