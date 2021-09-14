var NFTToken = artifacts.require("PumlNFT");
var engine = artifacts.require("Engine");

module.exports = function(deployer) {
    deployer.deploy(NFTToken);
    deployer.deploy(engine);
};