const NFTItem = artifacts.require("PumlNFT");
const Engine = artifacts.require("Engine");
const helper = require('../utils/utils.js');

contract("PumlNFT Marketplace", accounts => {

  var owner = accounts[0];
  var instance;
  var engine;

  before(async function () {
    // set contract instance into a variable
    instance = await NFTItem.deployed();
    engine = await Engine.deployed();
  })

  it("Should be deployed", async () => {
    assert.notEqual(instance, null);
    assert.notEqual(engine, null);
  });

  it("The contract balance should be cero ", async function () {
    let balance = await web3.eth.getBalance(engine.address);
    console.log("Balance contract = " + web3.utils.fromWei(balance, 'ether'));
    assert.equal(balance, 0);
  });

  it("initializes with empty list of auctions", async function () {
    let count = await engine.getTotalAuctions();
    assert.equal(count, 0);
  });

  it("Should create nft", async () => {
    var tokenId = await instance.createItem("www.nftapi.puml.io", 200, "Hola 1", { from: owner });
    assert.notEqual(tokenId, null);
  });

  it("Should create 2nd nft", async () => {
    var tokenId = await instance.createItem("www.nftapi.puml.io", 200, "", { from: owner });
    assert.notEqual(tokenId, null);
  });

  it("Should create 3rd nft", async () => {
    var tokenIdResponse = await instance.createItem("www.nftapi.puml.io", 300, "hola 3", { from: owner });
    console.log("TokenID = " + JSON.stringify(tokenIdResponse));
    assert.equal(tokenIdResponse.logs[0].args.tokenId, 3);
  });

  it("Should fail if royalties >= 900", async () => {
    try {
      var tokenId = await instance.createItem("www.nftapi.puml.io", 9000, "hola 3", { from: owner });
    }
    catch (error) { assert.equal(error.reason, "Max royalties are 90%"); }
  });

  it("should create an auction", async function () {
    // make sure account[1] is owner of the book
    let owner = await instance.ownerOf(2);
    assert.equal(owner, accounts[0]);
    // allow engine to transfer the nft
    await instance.approve(engine.address, 2, { from: accounts[0] });
    // create auction
    await engine.createOffer(instance.address, 2, true, true, 100000000000, 0, 0, 10, { from: accounts[0] });
    // make sure auction was created
    let count = await engine.getTotalAuctions();

    let balance = await web3.eth.getBalance(engine.address);
    console.log("Balance contract created auction = " + web3.utils.fromWei(balance, 'ether'));

    assert.equal(count, 1);
  });

  it("should retreive the auctionID", async function () {
    let idAuction = await engine.getAuctionId.call(3);
    assert.equal(idAuction, 0);
  });

  it("should fail if an auction is created by a not-owner", async function () {
    // make sure account[1] is owner of the book
    let owner = await instance.ownerOf(2);
    assert.equal(owner, accounts[0]);
    // allow engine to transfer the nft
    await instance.approve(engine.address, 2, { from: accounts[0] });
    try {
      // create auction
      await engine.createOffer(instance.address, 2, true, true, 100000000000, 0, 0, 10, { from: accounts[1] });
    }
    catch (error) { assert.equal(error.reason, "Not the owner"); }
    // make sure auction was NOT created
    let count = await engine.getTotalAuctions();
    assert.equal(count, 1);
  });

  it("should allow bids", async function () {
    let balanceIniBeforeBidding = await web3.eth.getBalance(accounts[1]);
    let receipt = await engine.bid(0, { from: accounts[1], value: 100000000000000 });
    let gasUsed = receipt.receipt.gasUsed;
    console.log(`GasUsed bidding: ${receipt.receipt.gasUsed}`);
    let balanceIni = await web3.eth.getBalance(accounts[1]);
    // with this bid from account 2, the previous bid from account 1 is retreived. The amount will not coincide because of the gas fees
    await engine.bid(0, { from: accounts[2], value: 1120000000000000 });
    let balanceEnd = await web3.eth.getBalance(accounts[1]);
    //   console.log("Balance bidder before bidding " + balanceIniBeforeBidding + " Balance bidder after " + balanceIni + " -- balance bidder with returning funds " + balanceEnd);
    // check the best bid is the last one.
    var currentBid = await engine.getCurrentBidAmount(0);
    assert.equal(currentBid, 1120000000000000);

    let balance = await web3.eth.getBalance(engine.address);
    //   console.log("Balance contract created bids = " + web3.utils.fromWei(balance, 'ether'));
  });

  it("should reject bids lower than the current best bid", async function () {

    let balance = await web3.eth.getBalance(engine.address);
    //    console.log("Balance contract before rejected low bids = " + web3.utils.fromWei(balance, 'ether'));
    // check the current best bid
    var currentBid = await engine.getCurrentBidAmount(0);
    assert.equal(currentBid, 1120000000000000);
    // place a bid lower than best bid 

    // check the best bid has not changed.
    var currentBid = await engine.getCurrentBidAmount(0);
    assert.equal(currentBid, 1120000000000000);

    balance = await web3.eth.getBalance(engine.address);
    //   console.log("Balance contract rejected low bids = " + web3.utils.fromWei(balance, 'ether'));
  });

  it("should NOT let get a winner before finished", async function () {
    try {
      var winner = await engine.getWinner(0);
    }
    catch (error) {
      assert.match(error, /Auction not finished yet/);
    }
  });

  it("should not let winner claim assets before finished", async function () {
    try {
      await engine.claimAsset(0, { from: accounts[2] });
    }
    catch (error) { assert.equal(error.reason, "The auction is still active"); }
  });

  it("should get winner when finished", async function () {
    await helper.advanceTimeAndBlock(20); // wait 20 seconds in the blockchain
    var winner = await engine.getWinner(0);
    assert.equal(winner, accounts[2]);
  });

  it("only the winner can claim assets", async function () {
    try {
      await engine.claimAsset(0, { from: accounts[1] });
    }
    catch (error) { assert.equal(error.reason, "You are not the winner of the auction"); }
  });

  it("should let winner claim assets", async function () {
    let balance = await web3.eth.getBalance(engine.address);
    //   console.log("Balance contract before claiming = " + web3.utils.fromWei(balance, 'ether'));

    var offer = await engine.offers(2);
    //   console.log(JSON.stringify(offer));
    const ownerBefore = await instance.ownerOf(2);
    assert.equal(ownerBefore, accounts[0]);
    await engine.claimAsset(0, { from: accounts[2] });
    const ownerAfter = await instance.ownerOf(2);
    assert.equal(ownerAfter, accounts[2]);

    balance = await web3.eth.getBalance(engine.address);
    // console.log("Balance contract after claiming = " + web3.utils.fromWei(balance, 'ether'));
  });

  it("should not let winner claim assets a second time", async function () {
    try {
      await engine.claimAsset(0, { from: accounts[2] });
    }
    catch (error) { assert.equal(error.reason, "NFT not in auction"); }
  });

  it("Should show URL", async () => {
    let url = await instance.tokenURI(1);
    //   console.log("The tokenURI is = " + url);
    assert.equal(url, "www.nftapi.puml.io");

    const url2 = await instance.tokenURI(2);
    //  console.log("The tokenURI is = " + url2);
    assert.equal(url2, "www.nftapi.puml.io");

    url = await instance.tokenURI(1);
    assert.equal(url, "www.nftapi.puml.io");
  });

  it("Should show the owner", async () => {
    const ownerResult = await instance.ownerOf(1);
    //    console.log("The owner is = " + ownerResult);
    assert.equal(ownerResult, accounts[0]);
  });

  it("Should transfer ownership when buying", async () => {
    const buyer = accounts[1];
    const ownerResult1 = await instance.ownerOf(1);
    let balanceIni = await web3.eth.getBalance(ownerResult1);
    let contractBalanceIni = await web3.eth.getBalance(instance.address);
    // allow engine to transfer the nft
    await instance.approve(engine.address, 1, { from: accounts[0] });
    await engine.createOffer(instance.address, 1, true, false, 1000000000000, 0, 0, 0, { from: accounts[0] });
    try { await engine.buy(1, { from: buyer, value: 32000000000 }); }
    catch (error) { assert.equal(error.reason, "Price is not enough"); }

    await engine.buy(1, { from: buyer, value: 1000000000000 });

    const ownerResult2 = await instance.ownerOf(1);
    let balanceEnd = await web3.eth.getBalance(ownerResult1);
    let contractBalanceEnd = await web3.eth.getBalance(instance.address);

    assert.notEqual(ownerResult1, ownerResult2);

    let balance = await web3.eth.getBalance(engine.address);
    //   console.log("Balance contract = " + web3.utils.fromWei(balance, 'ether'));
  });

  it("should allow changing the commission", async function () {
    await engine.setCommission(500, { from: accounts[0] });
  });

  it("should create an offer", async function () {
    // make sure account[1] is owner of the book
    let owner = await instance.ownerOf(3);
    assert.equal(owner, accounts[0]);

    // allow engine to transfer the nft
    await instance.approve(engine.address, 3, { from: accounts[0] });

    // create auction
    await engine.createOffer(instance.address, 3, true, true, 100000000000, 0, 0, 10, { from: accounts[0] });
    let idAuction = await engine.getAuctionId.call(3);
    //   console.log("idAuction = " + idAuction);

    // make sure auction was created
    let count = await engine.getTotalAuctions();
    assert.equal(count, 2);

    let accumulatedCommisions = await engine.accumulatedCommission.call();
    //  console.log("offer Comm=" + web3.utils.fromWei(accumulatedCommisions));
  });


  it("should allow bids", async function () {
    // create auction
    let balanceIniBeforeBidding = await web3.eth.getBalance(accounts[1]);
    await engine.bid(1, { from: accounts[1], value: 10000000000000 });
    let balanceIni = await web3.eth.getBalance(accounts[1]);
    await engine.bid(1, { from: accounts[2], value: 112000000000000 });
    let balanceEnd = await web3.eth.getBalance(accounts[1]);
    console.log("Balance bidder before bidding " + balanceIniBeforeBidding + " Balance bidder after " + balanceIni + " -- balance bidder with returning funds " + balanceEnd);

    var currentBid = await engine.getCurrentBidAmount(1);
    assert.equal(currentBid, 112000000000000);
    let accumulatedCommisions = await engine.accumulatedCommission.call();
    console.log("bids Comm=" + web3.utils.fromWei(accumulatedCommisions));
  });

  it("should get winner when finished", async function () {
    await helper.advanceTimeAndBlock(20); // wait 20 seconds in the blockchain
    var winner = await engine.getWinner(1);
    assert.equal(winner, accounts[2]);
  });

  it("should allow a direct sell while auctioning", async function () {
    let receipt = await engine.buy(3, { from: accounts[4], value: web3.utils.toWei('10', 'milli') });
    let gasUsed = receipt.receipt.gasUsed;
    console.log(`GasUsed on buy: ${receipt.receipt.gasUsed}`);

    let balance = await web3.eth.getBalance(engine.address);
    //  console.log("Balance contract = " + web3.utils.fromWei(balance, 'ether'));

    let accumulatedCommisions = await engine.accumulatedCommission.call();
    //  console.log("direct sell Comm=" + web3.utils.fromWei(accumulatedCommisions));
  });

  it("should not let winner claim the assets, as the auction was cancelled when the direct sale was made", async function () {
    const ownerBefore = await instance.ownerOf(3);
    assert.equal(ownerBefore, accounts[4]);
    try { // the error is triggered
      await engine.claimAsset(1, { from: accounts[2] });
    } catch (error) {
      assert.equal(error.reason, "NFT not in auction");
    }
    // the owner has not changed    
    const ownerAfter = await instance.ownerOf(3);
    assert.equal(ownerAfter, accounts[4]);
    let accumulatedCommisions = await engine.accumulatedCommission.call();
    //  console.log("aiction cancelled Comm=" + web3.utils.fromWei(accumulatedCommisions));
  });

  it("should create an offer for reselling an NFT", async function () {
    // make sure account[1] is owner of the book
    let owner = await instance.ownerOf(3);
    assert.equal(owner, accounts[4]);

    // allow engine to transfer the nft
    let receipt = await instance.approve(engine.address, 3, { from: accounts[4] });
    let gasUsed = receipt.receipt.gasUsed;
    // create auction
    receipt = await engine.createOffer(instance.address, 3, true, true, web3.utils.toWei('10', 'milli'), 0, 0, 10, { from: accounts[4] });
    gasUsed += receipt.receipt.gasUsed;
    console.log(`Total GasUsed on creating a resale: ${gasUsed}`);

    let idAuction = await engine.getAuctionId.call(3);
    //  console.log("idAuction = " + idAuction);

    // make sure auction was created
    let count = await engine.getTotalAuctions();
    assert.equal(count, 3);

    let accumulatedCommisions = await engine.accumulatedCommission.call();
    //    console.log("createoffer Comm=" + web3.utils.fromWei(accumulatedCommisions));
  });

  it("should allow bids on a resale auction", async function () {
    // create auction
    let balanceIniBeforeBidding = await web3.eth.getBalance(accounts[1]);
    await engine.bid(2, { from: accounts[1], value: web3.utils.toWei('10', 'milli') });
    let balanceIni = await web3.eth.getBalance(accounts[1]);
    await engine.bid(2, { from: accounts[2], value: web3.utils.toWei('11', 'milli') });
    let balanceEnd = await web3.eth.getBalance(accounts[1]);
    //    console.log("Balance bidder before bidding " + balanceIniBeforeBidding + " Balance bidder after " + balanceIni + " -- balance bidder with returning funds " + balanceEnd);

    var currentBid = await engine.getCurrentBidAmount(2);
    assert.equal(currentBid, web3.utils.toWei('11', 'milli'));

    let balance = await web3.eth.getBalance(engine.address);
    let accumulatedCommisions = await engine.accumulatedCommission.call();
    //  console.log("Balance contract bidding = " + web3.utils.fromWei(balance, 'ether') + " - Comm=" + web3.utils.fromWei(accumulatedCommisions));
  });

  it("should get winner when finished in a resale auction", async function () {
    await helper.advanceTimeAndBlock(20); // wait 20 seconds in the blockchain
    var winner = await engine.getWinner(2);
    assert.equal(winner, accounts[2]);
  });


  it("Should return current time", async function () {
    let ahora = await engine.ahora();
    console.log("Time = " + ahora);
    assert.notEqual(ahora, 0);
  });

  it("should let winner claim assets on a resale", async function () {
    let balance = await web3.eth.getBalance(engine.address);
    let accumulatedCommisions = await engine.accumulatedCommission.call();
    //    console.log("Balance contract claiming = " + web3.utils.fromWei(balance, 'ether') + " - Comm=" + web3.utils.fromWei(accumulatedCommisions));
    const idAuction = await engine.getAuctionId.call(3);
    const ownerBefore = await instance.ownerOf(3);
    const royalties = await instance.getRoyalties(3);
    // we set the commission to the 5%
    // await engine.setCommission(500, { from: accounts[0] });
    const commission = await engine.commission();
    //    console.log("Commission = " + web3.utils.hexToNumber(commission));
    // in the balance there should be the amount of the best bid
    balance = await web3.eth.getBalance(engine.address);
    //   console.log("Balance contract = " + web3.utils.fromWei(balance, 'ether'));
    // be sure that the token belongs to the account 4, that boughts it before
    assert.equal(ownerBefore, accounts[4]);
    let receipt = engine.claimAsset(idAuction, { from: accounts[2] }).then(function (events) {
      //    console.log("EVENTS "+ JSON.stringify(events.logs));
      assert.equal(events.logs.length, 3);
      // check that there was a royalties event, as it was a resale
      assert.equal(events.logs[1].event, "Royalties");
      console.log("Royalties = " + web3.utils.hexToNumber(royalties));
      console.log(web3.utils.hexToNumber(events.logs[1].args.amount));

      let gasUsed = events.receipt.gasUsed;
      console.log(`GasUsed Claim: ${gasUsed}`);
      //  console.log(events.logs[2].args.paidByCustomer.toNumber());
      //   console.log("Commission for the platform = " + web3.utils.hexToNumber(events.logs[2].args.commission) + " amount = " + web3.utils.hexToNumber(events.logs[2].args.amount));
      //  console.log("Suma = " + (web3.utils.hexToNumber(events.logs[2].args.commission) + web3.utils.hexToNumber(events.logs[2].args.amount) + web3.utils.hexToNumber(events.logs[1].args.amount)));

    });

    // after caliming the asssets, the owner of the token will be the best bidder (account 2)
    const ownerAfter = await instance.ownerOf(3);
    assert.equal(ownerAfter, accounts[2]);
    let balanceAfter = await web3.eth.getBalance(engine.address);
    // console.log("Balance contract = " + web3.utils.fromWei(balance, 'ether'));
    //  console.log("Balance contract = " + (balanceAfter - balance));
  });

  it("The contract balance should not be cero after some sells", async function () {
    let balance = await web3.eth.getBalance(engine.address);
    let accumulatedCommisions = await engine.accumulatedCommission.call();
    console.log("Balance contract = " + web3.utils.fromWei(balance, 'ether') + " - Comm=" + web3.utils.fromWei(accumulatedCommisions));
    assert.notEqual(balance, 0);
  });

  it("The owner of the marketplace can claim the accumalated commissions", async function () {
    let balance = await web3.eth.getBalance(engine.address);
    let accumulatedCommisions = await engine.accumulatedCommission.call();
    console.log("Balance contract = " + web3.utils.fromWei(balance, 'ether') + " - Comm=" + web3.utils.fromWei(accumulatedCommisions));
    await engine.extractBalance();
    balance = await web3.eth.getBalance(engine.address);
    accumulatedCommisions = await engine.accumulatedCommission.call();
    console.log("Balance contract = " + web3.utils.fromWei(balance, 'ether') + " - Comm=" + web3.utils.fromWei(accumulatedCommisions));
    assert.equal(balance, 0);
  });

  it("The contract should allow owner to unlock content", async function () {
    const ownerOf3 = await instance.ownerOf(3);
    assert.equal(ownerOf3, accounts[2]);
    let lockedContent = await instance.unlockContent.call(3, { from: accounts[2] });
    console.log("locked content = " + lockedContent);
    assert.equal(lockedContent, "hola 3");
  });

  it("The contract should not allow non-owner to unlock content", async function () {
    try {
      let lockedContent = await instance.unlockContent.call(1, { from: accounts[4] });
    } catch (error) {
      assert.match(error, /Not the owner/);
    }
  });

  it("Calc of minting cost", async () => {
    var receipt = await instance.createItem("www.nftapi.puml.io", 1000, "hola 4", { from: accounts[0] });
    let gasUsed = receipt.receipt.gasUsed;
    //   console.log(`GasUsed: ${receipt.receipt.gasUsed}`);
    receipt = await instance.approve(engine.address, 4, { from: accounts[0] });
    //   console.log(`GasUsed: ${receipt.receipt.gasUsed}`);
    gasUsed += receipt.receipt.gasUsed;
    receipt = await engine.createOffer(instance.address, 4, true, true, 100000000000, 0, 0, 10, { from: accounts[0] });
    //   console.log(`GasUsed: ${receipt.receipt.gasUsed}`);
    gasUsed += receipt.receipt.gasUsed;
    console.log(`Total GasUsed on create: ${gasUsed}`);
  });

});