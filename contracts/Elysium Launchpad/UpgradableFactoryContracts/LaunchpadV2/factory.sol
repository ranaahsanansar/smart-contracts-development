// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "./IDO-Contract...IdoContract.sol";
import "contracts/Elysium Launchpad/UpgradableFactoryContracts/LaunchpadV2/IDO-Contract...IdoContract.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract IDOFactory is Ownable(msg.sender) {
    event IDOContractDeployed(address indexed idoContractAddress, address indexed owner);

    mapping(address _tokenAddress => address _proxyAddress) public idosRecord;

    function createIDO(ElysiumLaunchpadIDOContract.ParamsConstructor memory _parameters, address newOwner)  public  onlyOwner returns(address _idoDeployedContract)  {
        ElysiumLaunchpadIDOContract IDO = new ElysiumLaunchpadIDOContract();
        bytes memory data = abi.encodeWithSelector(IDO.initialize.selector, _parameters, newOwner);
        ERC1967Proxy proxy = new ERC1967Proxy(address(IDO), data);

        idosRecord[_parameters.IDOTokenAddress] = address(proxy);

        emit IDOContractDeployed(address(proxy), msg.sender);
        return  address(proxy);
    }
}
