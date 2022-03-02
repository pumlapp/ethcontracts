var NFTToken = artifacts.require("PumlNFT");
var engine = artifacts.require("Engine");

module.exports = function(deployer) {
    deployer.deploy(NFTToken, "PUML DEV321", "PUML DESCRIPT");
    deployer.deploy(engine);
};