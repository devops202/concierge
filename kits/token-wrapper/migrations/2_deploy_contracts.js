/* global artifacts */
var TokenWrapper = artifacts.require('TokenWrapper.sol');
var ERC20Sample = artifacts.require('ERC20Sample.sol');
var MiniMeToken = artifacts.require('MiniMeToken.sol');

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

module.exports = function(deployer) {
  deployer.deploy(TokenWrapper)
    .then(() => {
      return deployer.deploy(ERC20Sample)
        .then(() => {
          return deployer.deploy(MiniMeToken, ZERO_ADDRESS, ZERO_ADDRESS, 0, 'Token', 18, 'TWR', false)
            .then(async () => {
              const token = await MiniMeToken.deployed();
              await token.changeController(TokenWrapper.address);
            });
        });
    });
};
