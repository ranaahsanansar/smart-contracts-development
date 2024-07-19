// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "./IDO-staking_uups.sol";
import "contracts/Elysium Launchpad/UpgradableFactoryContracts/LaunchpadV2/StakingContract/StakingProxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract IDOStakingFactory is Ownable(msg.sender) {
    event IDOStakingDeployed(address indexed idoContractAddress, address indexed owner);

    mapping(address tokenAddress => address proxyContract) public stakingContractsRecord;

    function createIDO_staking(  uint256 tierOneAmount,
        uint256 tierTwoAmount,
        uint256 tierThreeAmount,
        address _pyrTokenAddress,
        address owner) public onlyOwner {
        ElysiumLaunchpadIDOStaking_upgradeable IDO_Staking = new ElysiumLaunchpadIDOStaking_upgradeable();
        bytes memory data = abi.encodeWithSelector(IDO_Staking.initialize.selector, tierOneAmount,tierTwoAmount, tierThreeAmount,_pyrTokenAddress,owner);
        ERC1967Proxy proxy = new ERC1967Proxy(address(IDO_Staking), data);

        stakingContractsRecord[_pyrTokenAddress] = address(proxy);

        emit IDOStakingDeployed(address(proxy), msg.sender);
    }
}