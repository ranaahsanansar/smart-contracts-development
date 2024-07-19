// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Vesting is Ownable {
    using SafeERC20 for IERC20;

    uint256 constant SECONDS_PER_DAY = 24 * 60 * 60;
    int256 constant OFFSET19700101 = 2440588;

    struct Beneficiary {
        uint256 allocatedTokens;
        uint256 leftAllocatedTokens;
        uint256 tgeReleased; // amount
        uint256 linearReleased; // amount
        uint256 firstLinearRelease;
        bool isTGEreleased;
    }

    struct VestingDetails {
        string name;
        uint256 totalTokens;
        uint256 tgeDay; //timestamp
        uint256 vestingMonthsCount; // for how many months? like 5
        // uint256 vestingPeriod; // in seconds. --un_necessary
        uint256 tgeReleaseRatio; // in percentage points (e.g., 10 for 10%)
        uint256 linearReleaseRatio; // in percentage points (e.g., 18 for 18%)
        uint256 nextLinearReleaseDate;
        uint256 currentReleasesOccurences; // how many time release has been occurered
    }

    struct VestingPool {
        VestingDetails poolDetails;
        address[] beneficiariesAddresses;
        mapping(address => Beneficiary) beneficiaries;
    }

    IERC20 public token;
    // mapping(address => Beneficiary) public beneficiaries;
    // address[] public beneficiariesAddresses;
    VestingPool public vestingPool;
    uint256 intervalOfRelease; // like 5th of every month , or any other day
    event PoolCreated(
        string name,
        uint256 totalTokens,
        uint256 tgeDay,
        uint256 vestingMonthsCount,
        uint256 tgeReleaseRatio,
        uint256 linearReleaseRatio,
        uint256 nextLinearReleaseDate
    );

    event TGETokensReleased(address indexed beneficiary, uint256 amount);
    event LinearTokensReleased(address indexed beneficiary, uint256 amount);

    constructor(IERC20 _token) Ownable(msg.sender) {
        token = _token;
    }

    // function initializeBeneficiaries(
    //     address[] memory _beneficiariesAddresses,
    //     uint256[] memory beneficiariesAmounts
    // ) external onlyOwner {
    //     require(
    //         _beneficiariesAddresses.length == beneficiariesAmounts.length,
    //         "Addresses and amounts length mismatch"
    //     );

    //     for (uint256 i = 0; i < _beneficiariesAddresses.length; i++) {
    //         beneficiaries[_beneficiariesAddresses[i]] = Beneficiary({
    //             allocatedTokens: beneficiariesAmounts[i],
    //             leftAllocatedTokens: beneficiariesAmounts[i],
    //             tgeReleased: 0,
    //             linearReleased: 0,
    //             firstLinearRelease: 0,
    //             isTGEreleased: false
    //         });
    //         beneficiariesAddresses.push(_beneficiariesAddresses[i]);
    //     }
    // }

    function createPool(
        string memory name,
        uint256 totalTokens,
        uint256 tgeDay,
        uint256 vestingMonthsCount,
        uint256 tgeReleaseRatio,
        uint256 linearReleaseRatio,
        uint256 _intervalOfRelease, // in months lilke 1,2,3.....
        address[] memory _beneficiariesAddresses,
        uint256[] memory beneficiariesAmounts
    ) external onlyOwner {
        require(totalTokens > 0, "Total tokens must be greater than 0");
        require(
            tgeReleaseRatio + linearReleaseRatio > 0,
            "Release ratios must be greater than 0"
        );
        require(
            token.balanceOf(address(this)) >= totalTokens,
            "Not enough tokens in contract"
        );

        require(
            _beneficiariesAddresses.length == beneficiariesAmounts.length,
            "Addresses and amounts length mismatch"
        );

        vestingPool.poolDetails = VestingDetails({
            name: name,
            totalTokens: totalTokens,
            tgeDay: tgeDay,
            vestingMonthsCount: vestingMonthsCount,
            tgeReleaseRatio: tgeReleaseRatio,
            linearReleaseRatio: linearReleaseRatio,
            nextLinearReleaseDate: 0,
            currentReleasesOccurences: 0
        });

        intervalOfRelease = _intervalOfRelease;
        for (uint256 i = 0; i < _beneficiariesAddresses.length; i++) {
            vestingPool.beneficiaries[
                _beneficiariesAddresses[i]
            ] = Beneficiary({
                allocatedTokens: beneficiariesAmounts[i],
                leftAllocatedTokens: beneficiariesAmounts[i],
                tgeReleased: 0,
                linearReleased: 0,
                firstLinearRelease: 0,
                isTGEreleased: false
            });
            vestingPool.beneficiariesAddresses.push(_beneficiariesAddresses[i]);
        }

        emit PoolCreated(
            name,
            totalTokens,
            tgeDay,
            vestingMonthsCount,
            tgeReleaseRatio,
            linearReleaseRatio,
            0
        );
    }

    function tgeReleaseTokensByAdmin() external onlyOwner {
        require(
            block.timestamp >= vestingPool.poolDetails.tgeDay,
            "TGE has not started yet"
        );

        //VestingPool.totalTokens - VestingPool.tgeReleaseRatio 10% ratio
        uint256 totalTGEReleased = 0;
        uint256 maxReleaseAmount = (vestingPool.poolDetails.totalTokens *
            vestingPool.poolDetails.tgeReleaseRatio) / 100;

        for (
            uint256 i = 0;
            i < vestingPool.beneficiariesAddresses.length;
            i++
        ) {
            address addr = vestingPool.beneficiariesAddresses[i];
            Beneficiary storage beneficiary = vestingPool.beneficiaries[addr];

            if (beneficiary.allocatedTokens > 0 && !beneficiary.isTGEreleased) {
                uint256 tgeAmount = (beneficiary.allocatedTokens *
                    vestingPool.poolDetails.tgeReleaseRatio) / 100;

                require(
                    beneficiary.isTGEreleased == false,
                    "TGE already released!"
                );

                if (totalTGEReleased + tgeAmount >= maxReleaseAmount) {
                    break;
                }

                if (tgeAmount > 0) {
                    beneficiary.tgeReleased += tgeAmount;
                    beneficiary.leftAllocatedTokens -= tgeAmount;
                    beneficiary.isTGEreleased = true;
                    beneficiary.firstLinearRelease = _getNextMonthXday(
                        block.timestamp
                    );
                    totalTGEReleased += tgeAmount;
                    token.safeTransfer(addr, tgeAmount);

                    emit TGETokensReleased(addr, tgeAmount);
                }

                if (totalTGEReleased >= maxReleaseAmount) {
                    break;
                }
            }
        }
        vestingPool.poolDetails.nextLinearReleaseDate = _getNextMonthXday(
            block.timestamp
        );

        require(
            totalTGEReleased <= maxReleaseAmount,
            "Total TGE release exceeds limit"
        );
    }

    function tgeReleaseTokensByAdmin(
        address[] memory _beneficiariesAddresses,
        uint256[] memory beneficiariesAmounts
    ) external onlyOwner {
        require(
            block.timestamp >= vestingPool.poolDetails.tgeDay,
            "TGE has not started yet"
        );

        //VestingPool.totalTokens - VestingPool.tgeReleaseRatio 10% ratio
        uint256 totalTGEReleased = 0;
        uint256 maxReleaseAmount = (vestingPool.poolDetails.totalTokens *
            vestingPool.poolDetails.tgeReleaseRatio) / 100;

        for (uint256 i = 0; i < _beneficiariesAddresses.length; i++) {
            address addr = _beneficiariesAddresses[i];
            Beneficiary storage beneficiary = vestingPool.beneficiaries[addr];

            if (beneficiary.allocatedTokens > 0 && !beneficiary.isTGEreleased) {
                uint256 tgeAmount = (beneficiary.allocatedTokens *
                    vestingPool.poolDetails.tgeReleaseRatio) / 100;

                require(
                    beneficiary.isTGEreleased == false,
                    "TGE already released!"
                );

                if (totalTGEReleased + tgeAmount >= maxReleaseAmount) {
                    break;
                }

                if (tgeAmount > 0) {
                    beneficiary.tgeReleased += tgeAmount;
                    beneficiary.leftAllocatedTokens -= tgeAmount;
                    beneficiary.isTGEreleased = true;
                    beneficiary.firstLinearRelease = _getNextMonthXday(
                        block.timestamp
                    );
                    totalTGEReleased += tgeAmount;
                    token.safeTransfer(addr, tgeAmount);

                    emit TGETokensReleased(addr, tgeAmount);
                }

                if (totalTGEReleased >= maxReleaseAmount) {
                    break;
                }
            } else {
                // Incase when user's wallet not exist in our record
                require(
                    beneficiary.isTGEreleased == false,
                    "TGE already released!"
                );
                uint256 tgeAmount = beneficiariesAmounts[i];
                if (totalTGEReleased + tgeAmount >= maxReleaseAmount) {
                    break;
                }
                beneficiary.tgeReleased += tgeAmount;
                //  beneficiary.leftAllocatedTokens -= tgeAmount;
                beneficiary.isTGEreleased = true;
                beneficiary.firstLinearRelease = _getNextMonthXday(
                    block.timestamp
                );
                totalTGEReleased += tgeAmount;
                token.safeTransfer(addr, tgeAmount);

                emit TGETokensReleased(addr, tgeAmount);
                if (totalTGEReleased >= maxReleaseAmount) {
                    break;
                }
            }
        }
        vestingPool.poolDetails.nextLinearReleaseDate = _getNextMonthXday(
            block.timestamp
        );

        require(
            totalTGEReleased <= maxReleaseAmount,
            "Total TGE release exceeds limit"
        );
    }

    function linearReleaseTokensByAdmin() external onlyOwner {
        VestingPool storage pool = vestingPool;
        require(
            block.timestamp >= pool.poolDetails.tgeDay,
            "Vesting has not started yet"
        );
        require(
            _isXdayOfMonth(),
            "Linear release can only be done on the X day of each month"
        );
        // if (pool.currentReleasesOccurences >= 1)
        require(
            block.timestamp >= pool.poolDetails.nextLinearReleaseDate,
            "Next release can only be done on the next month"
        );

        require(
            pool.poolDetails.currentReleasesOccurences <
                pool.poolDetails.vestingMonthsCount,
            "All linear releases done!"
        );

        uint256 totalLinearReleased = 0;
        uint256 maxLinearReleaseAmount = pool.poolDetails.totalTokens -
            ((pool.poolDetails.totalTokens * pool.poolDetails.tgeReleaseRatio) /
                100); // subtract lets say 10% from total value, so remianing will be for linear release

        for (uint256 i = 0; i < pool.beneficiariesAddresses.length; i++) {
            address addr = pool.beneficiariesAddresses[i];
            Beneficiary storage beneficiary = pool.beneficiaries[addr];
            require(beneficiary.isTGEreleased == true, "first release TGE!");

            if (
                block.timestamp >= beneficiary.firstLinearRelease &&
                beneficiary.leftAllocatedTokens > 0
            ) {
                uint256 linearAmount = (beneficiary.allocatedTokens *
                    pool.poolDetails.linearReleaseRatio) / 100;

                if (
                    totalLinearReleased + linearAmount >= maxLinearReleaseAmount
                ) {
                    break;
                }

                if (linearAmount > 0) {
                    beneficiary.leftAllocatedTokens -= linearAmount;
                    beneficiary.linearReleased += linearAmount;
                    totalLinearReleased += linearAmount;
                    token.safeTransfer(addr, linearAmount);

                    emit LinearTokensReleased(addr, linearAmount);
                }

                if (totalLinearReleased >= maxLinearReleaseAmount) {
                    break;
                }
            }
        }

        pool.poolDetails.currentReleasesOccurences += 1;
        pool.poolDetails.nextLinearReleaseDate = _getNextMonthXday(
            block.timestamp
        );
        // pool.nextLinearReleaseDate = _getNextMinute(block.timestamp); // test for 1minute
    }

    function linearReleaseTokensByAdmin(
        address[] memory _beneficiariesAddresses,
        uint256[] memory beneficiariesAmounts
    ) external onlyOwner {
        VestingPool storage pool = vestingPool;
        require(
            block.timestamp >= pool.poolDetails.tgeDay,
            "Vesting has not started yet"
        );
        require(
            _isXdayOfMonth(),
            "Linear release can only be done on the X day of each month"
        );
        // if (pool.currentReleasesOccurences >= 1)
        require(
            block.timestamp >= pool.poolDetails.nextLinearReleaseDate,
            "Next release can only be done on the next month"
        );

        require(
            pool.poolDetails.currentReleasesOccurences <
                pool.poolDetails.vestingMonthsCount,
            "All linear releases done!"
        );

        uint256 totalLinearReleased = 0;
        uint256 maxLinearReleaseAmount = pool.poolDetails.totalTokens -
            ((pool.poolDetails.totalTokens * pool.poolDetails.tgeReleaseRatio) /
                100); // subtract lets say 10% from total value, so remianing will be for linear release

        for (uint256 i = 0; i < _beneficiariesAddresses.length; i++) {
            address addr = _beneficiariesAddresses[i];
            Beneficiary storage beneficiary = pool.beneficiaries[addr];
            require(beneficiary.isTGEreleased == true, "first release TGE!");

            if (
                block.timestamp >= beneficiary.firstLinearRelease &&
                beneficiary.leftAllocatedTokens > 0
            ) {
                uint256 linearAmount = (beneficiary.allocatedTokens *
                    pool.poolDetails.linearReleaseRatio) / 100;

                if (
                    totalLinearReleased + linearAmount >= maxLinearReleaseAmount
                ) {
                    break;
                }

                if (linearAmount > 0) {
                    beneficiary.leftAllocatedTokens -= linearAmount;
                    beneficiary.linearReleased += linearAmount;
                    totalLinearReleased += linearAmount;
                    token.safeTransfer(addr, linearAmount);

                    emit LinearTokensReleased(addr, linearAmount);
                }

                if (totalLinearReleased >= maxLinearReleaseAmount) {
                    break;
                }
            } else {
                // beneficiary.leftAllocatedTokens -= beneficiariesAmounts[i];
                uint256 linearAmount = beneficiariesAmounts[i];
                if (
                    totalLinearReleased + linearAmount >= maxLinearReleaseAmount
                ) {
                    break;
                }
                beneficiary.linearReleased += linearAmount;
                totalLinearReleased += linearAmount;
                token.safeTransfer(addr, linearAmount);

                emit LinearTokensReleased(addr, linearAmount);
                if (totalLinearReleased >= maxLinearReleaseAmount) {
                    break;
                }
            }
        }

        pool.poolDetails.currentReleasesOccurences += 1;
        pool.poolDetails.nextLinearReleaseDate = _getNextMonthXday(
            block.timestamp
        );
        // pool.nextLinearReleaseDate = _getNextMinute(block.timestamp); // test for 1minute
    }

    // function getReleasableAmount(address beneficiaryAddress) external view returns (uint256) {
    //     VestingPool storage pool = vestingPool;
    //     Beneficiary storage beneficiary = beneficiaries[beneficiaryAddress];
    //     uint256 elapsedTime = block.timestamp - pool.tgeDay;
    //     uint256 totalRelease = 0;

    //     if (elapsedTime >= pool.vestingPeriod) {
    //         totalRelease = beneficiary.allocatedTokens;
    //     } else {
    //         uint256 linearAmount = (beneficiary.allocatedTokens * pool.linearReleaseRatio * elapsedTime) / (100 * pool.vestingPeriod);
    //         totalRelease = linearAmount;
    //     }

    //     return totalRelease - beneficiary.linearReleased;
    // }

    function _isXdayOfMonth() public view returns (bool) {
        (, , uint256 day) = _timestampToDate(block.timestamp);
        return day == intervalOfRelease;
    }

    function _daysToDate(uint256 _days)
        internal
        pure
        returns (
            uint256 year,
            uint256 month,
            uint256 day
        )
    {
        int256 __days = int256(_days);

        int256 L = __days + 68569 + OFFSET19700101;
        int256 N = (4 * L) / 146097;
        L = L - (146097 * N + 3) / 4;
        int256 _year = (4000 * (L + 1)) / 1461001;
        L = L - (1461 * _year) / 4 + 31;
        int256 _month = (80 * L) / 2447;
        int256 _day = L - (2447 * _month) / 80;
        L = _month / 11;
        _month = _month + 2 - 12 * L;
        _year = 100 * (N - 49) + _year + L;

        year = uint256(_year);
        month = uint256(_month);
        day = uint256(_day);
    }

    function _timestampToDate(uint256 timestamp)
        public
        pure
        returns (
            uint256 year,
            uint256 month,
            uint256 day
        )
    {
        uint256 dayss = timestamp / SECONDS_PER_DAY;
        (year, month, day) = _daysToDate(dayss);
    }

    function _dateToTimestamp(
        uint256 year,
        uint256 month,
        uint256 day
    ) internal pure returns (uint256 timestamp) {
        int256 _year = int256(year);
        int256 _month = int256(month);
        int256 _day = int256(day);

        int256 __days = _day -
            32075 +
            (1461 * (_year + 4800 + (_month - 14) / 12)) /
            4 +
            (367 * (_month - 2 - ((_month - 14) / 12) * 12)) /
            12 -
            (3 * ((_year + 4900 + (_month - 14) / 12) / 100)) /
            4 -
            OFFSET19700101;

        timestamp = uint256(__days) * SECONDS_PER_DAY;
    }

    function _getNextMonthXday(uint256 timestamp)
        public
        view
        returns (uint256)
    {
        (uint256 year, uint256 month, ) = _timestampToDate(timestamp);

        if (month == 12) {
            year += 1;
            month = 1;
        } else {
            month += 1;
        }

        return _dateToTimestamp(year, month, intervalOfRelease);
    }

    //test code for getting next minute
    // uint256 constant SECONDS_PER_MINUTE = 60;

    // function _getNextMinute(uint256 timestamp) public pure returns (uint256) {
    //     // Add the number of seconds in one minute to the given timestamp
    //     return timestamp + SECONDS_PER_MINUTE;
    // }
}