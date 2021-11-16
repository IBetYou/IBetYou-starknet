import { expect } from "chai";
import { starknet } from "hardhat";
import { StarknetContract, StarknetContractFactory } from "hardhat/types/runtime";


function hex_to_ascii(str1: { toString: () => any; })
 {
	var hex  = str1.toString();
	var str = '';
	for (var n = 0; n < hex.length; n += 2) {
		str += String.fromCharCode(parseInt(hex.substr(n, 2), 16));
	}
	return str;
 }
 
describe("Starknet", function () {
  this.timeout(300_000); // 5 min
  let preservedAddress: string;

  let contractFactory: StarknetContractFactory;

  before(async function() {
    contractFactory = await starknet.getContractFactory("contract");
  });

  it("should work for a fresh deployment", async function () {
   
    const contract: StarknetContract = await contractFactory.deploy();
    console.log("STRING TEST: ");
    const {result: str} =await contract.call("increase_balance", {user_id:1, amount:2});
    console.log(str);
    console.log(str.toString(16));
    console.log(hex_to_ascii(str.toString(16)));
    /*console.log("Deployed at", contract.address);
    preservedAddress = contract.address;
    await contract.invoke("increase_balance", [1, 20]);
    console.log("Increased user 1 amount by 20");
    const balanceStr1 = await contract.call("get_balance", [1]);
    const balance1 = parseInt(balanceStr1);
    expect(balance1).to.equal(20);

    await contract.invoke("increase_balance", [2, 20]);
    console.log("Increased user 2 amount by 20");
    const balanceStr2 = await contract.call("get_balance", [2]);
    const balance2 = parseInt(balanceStr2);
    expect(balance2).to.equal(20);*/

    
  });
/*
  it("user 1 amount should reduce by x after creating a bet of x amount", async function() {
    const contract: StarknetContract = contractFactory.getContractAt(preservedAddress);
    await contract.invoke("create_bet", [1, 10, 10098]);
    console.log("Created a bet of amount 10");
    const balanceStr = await contract.call("get_balance", [1]);
    const balance = parseInt(balanceStr);
    expect(balance).to.equal(10);
  });

  it("user 2 joins the bet and amount should reduce by x after joining the bet of x amount", async function() {
    const contract: StarknetContract = contractFactory.getContractAt(preservedAddress);
    await contract.invoke("joinCounterBettor", [2]);
    console.log("User 2 joined the bet of amount 10");
    const balanceStr = await contract.call("get_balance", [2]);
    const balance = parseInt(balanceStr);
    expect(balance).to.equal(10);
  });

  it("user 3 joins the bet as judge and votes user 1 as winner", async function() {
    const contract: StarknetContract = contractFactory.getContractAt(preservedAddress);
    await contract.invoke("join_judge", [3]);
    console.log("User 3 joined the bet as judge, and voted user 1 as winner");
    await contract.invoke("vote_bettor", [3, 1]);
    const balanceStr = await contract.call("get_balance", [1]);
    const balance = parseInt(balanceStr);
    expect(balance).to.equal(30);
  });*/
});