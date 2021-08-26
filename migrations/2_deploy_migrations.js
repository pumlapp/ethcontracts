const PumlNFT = artifacts.require("PumlNFT");
const PumlNFTMarket = artifacts.require("PumlNFTMarket");

module.exports = function (deployer, network, accounts) {
    deployer.deploy(PumlNFT, "" /* token base URI */)
    .then(() => PumlNFT.deployed())
    .then((instance) => {
        return deployer.deploy(PumlNFTMarket);
    });
}