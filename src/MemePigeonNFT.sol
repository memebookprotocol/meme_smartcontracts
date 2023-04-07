/**                                
                                  :^~!77!^:                           
                               ^?J?!~^^^^!7??^                        
                             .JJ^      .~!!~~?Y^.~???.                
                            .P!       75~^~7J7:5G!: YY.:^.            
                           .5J       .B^:G#Y:YJ ?Y:~5P?7!P!           
                          .G@^ .!?7:  57.B@@Y.B~.GY!:    G7           
                          ^#B^ :BBGG. .57:YP!.G~.:     .57            
                          .BB7  7PY!   .?Y7~!Y?       ^P!:!.          
                           J#G   ..      .^~^.       ~B5JJB! ^75^     
                            !B7                   .:^Y#?!~PPYYJ#:     
                             :B:                  .!!!?7!!!7!!G!      
                              75             ^~~~~~!!!!!!!!~7G!       
                               JJ       ... ^!!!!!!!!!!!!!!YP^        
                                Y?     ~!!!~!!!!!!!!!!!!!JP?.         
                                 JJ:::^!!!!!!!!!!!!!!!7J5?:           
                                  !5J!!!!!!!!!!!!!7?YY?~.             
                                   .JYJ??77777??YYY#J                 
                                     .^~7????JGY::?PP                 
                                            .7PY   !:                 
                                              :.       
                        website: https://www.memebook.xyz/home
                        twitter: https://twitter.com/memebook_xyz
                        whitepapper_en: https://whitepaper.memebook.xyz/en/
                        whitepapper_zh: https://whitepaper.memebook.xyz/zh/
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

import "./PercentageMath.sol";

error MaxSupply();
error ExceedLimit();
error ExistPartner();
error NoHatchingYet();
error IllegalCaller();
error IllegalParameter();
error MintPriceNotPaid();
error WithdrawTransfer();

contract MemePigeonNFT is
    Initializable,
    ERC1155Upgradeable,
    OwnableUpgradeable,
    ERC1155SupplyUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using PercentageMath for uint256;
    using StringsUpgradeable for uint256;

    struct Pigeon {
        uint256 groupSize;
        uint256 limit;
        uint256 mintPrice;
        uint256 promotionalPrice;
        uint256 efficiency;
        uint256 cap;
    }

    // Ordinary Rare Legend Epic Myth
    // ancient will never exist
    enum Rarity {
        Ancient,
        Myth,
        Epic,
        Legend,
        Rare,
        Ordinary
    }

    uint256 public promotionStartTime;
    uint256 public promotionDuration;
    uint256 public promotionInterval;
    uint256 public partnerMintReward;
    address public feeto;
    address public hatchingNest;
    bool public startHatching;

    mapping(uint256 => Pigeon) public pigeons;
    mapping(address => address) public partners;

    event BindingPartner(address indexed customer, address indexed partner);
    event ShareReward(
        address indexed customer,
        address indexed partner,
        uint256 reward
    );
    event StartHatching();
    event PromotionUpdated();
    event UpdateMintPrice(
        uint256 indexed id,
        uint256 mintPrice,
        uint256 promotionalPrice
    );
    event UpdateAbility(uint256 indexed id, uint256 efficiency, uint256 caps);
    event RevokeToken(address receipt, address token, uint256 amount);

    modifier onlyHatchingNest() {
        if (!startHatching || hatchingNest == address(0)) {
            revert NoHatchingYet();
        }
        if (msg.sender != hatchingNest) {
            revert IllegalCaller();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC1155_init(
            "ipfs://QmZTHCXT4QiMQq1PYSdqThyqDKFQdCfNYKA8p6s6wuXzVV/"
        );
        __Ownable_init();
        __ERC1155Supply_init();
        __UUPSUpgradeable_init();

        pigeons[uint256(Rarity.Myth)] = Pigeon({
            groupSize: 1000,
            limit: 0,
            mintPrice: 1.99 ether,
            promotionalPrice: 1.194 ether,
            efficiency: 300,
            cap: 4000
        });

        pigeons[uint256(Rarity.Epic)] = Pigeon({
            groupSize: 10000,
            limit: 0,
            mintPrice: 0.69 ether,
            promotionalPrice: 0.414 ether,
            efficiency: 100,
            cap: 1500
        });

        pigeons[uint256(Rarity.Legend)] = Pigeon({
            groupSize: 50000,
            limit: 0,
            mintPrice: 0.39 ether,
            promotionalPrice: 0.234 ether,
            efficiency: 50,
            cap: 800
        });

        pigeons[uint256(Rarity.Rare)] = Pigeon({
            groupSize: type(uint256).max,
            limit: 0,
            mintPrice: 0.09 ether,
            promotionalPrice: 0.0054 ether,
            efficiency: 10,
            cap: 200
        });

        pigeons[uint256(Rarity.Ordinary)] = Pigeon({
            groupSize: type(uint256).max,
            limit: 1,
            mintPrice: 0,
            promotionalPrice: 0,
            efficiency: 1,
            cap: 1
        });

        // todo modify before produce
        promotionStartTime = block.timestamp + 1 days;
        promotionDuration = 4 days;
        promotionInterval = 1 days;
        partnerMintReward = 15e2; // 15%
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        address newPartner
    ) public payable nonReentrant {
        if (id < 1 || id > 5) {
            revert IllegalParameter();
        }
        if (totalSupply(id) + amount > getMaxPigeon(id)) {
            revert MaxSupply();
        }

        if (
            pigeons[id].limit > 0 &&
            balanceOf(account, id) + amount > pigeons[id].limit
        ) {
            revert ExceedLimit();
        }

        uint256 payment = amount * getMintPrice(id);
        if (msg.value < payment) {
            revert MintPriceNotPaid();
        }

        address currentPartner = partners[account];
        if (newPartner != currentPartner) {
            if (currentPartner != address(0)) {
                revert ExistPartner();
            }
            // todo this will give partner to msg.sender
            if (id <= 4 || tx.origin == account) {
                partners[account] = newPartner;
                currentPartner = newPartner;
                emit BindingPartner(account, newPartner);
            }
        }
        // share partner reward
        if (currentPartner != address(0)) {
            uint256 reward = payment.percentMul(partnerMintReward);
            (bool sent, ) = currentPartner.call{value: reward}(new bytes(0));
            if (!sent) {
                revert WithdrawTransfer();
            }
            emit ShareReward(account, currentPartner, reward);
        }

        _mint(account, id, amount, "");
    }

    // eggs change
    function doHatching(
        address account,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external onlyHatchingNest returns (bool) {
        if (ids.length != amounts.length) {
            revert IllegalParameter();
        }
        for (uint256 i = 0; i < ids.length; ++i) {
            if (ids[i] < 1 || ids[i] > 5) {
                revert IllegalParameter();
            }

            // todo maybe no need
            if (totalSupply(ids[i]) + amounts[i] > getMaxPigeon(ids[i])) {
                revert MaxSupply();
            }
        }

        _mintBatch(account, ids, amounts, new bytes(0));
        return true;
    }

    // todo private befroe product
    function bindPartner(address newPartner) public {
        partners[msg.sender] = newPartner;
        emit BindingPartner(msg.sender, newPartner);
    }

    // ================== onlyOwner ==============================

    function setHatchingStart(bool flag, address _hatching) external onlyOwner {
        startHatching = flag;
        hatchingNest = _hatching;
        emit StartHatching();
    }

    function updatePromotion(uint256[] memory times) external onlyOwner {
        require(times.length == 3, "Illege arg length");
        promotionStartTime = times[0];
        promotionDuration = times[1];
        promotionInterval = times[2];
        emit PromotionUpdated();
    }

    function updateMintPrice(
        uint256[] memory ids,
        uint256[] memory mintPrice,
        uint256[] memory promotionalPrice
    ) external onlyOwner {
        if (
            ids.length != mintPrice.length ||
            ids.length != promotionalPrice.length
        ) {
            revert IllegalParameter();
        }
        for (uint i = 0; i < ids.length; ++i) {
            Pigeon memory pigeon = pigeons[ids[i]];
            pigeon.mintPrice = mintPrice[i];
            pigeon.promotionalPrice = promotionalPrice[i];
            pigeons[ids[i]] = pigeon;
            emit UpdateMintPrice(ids[i], mintPrice[i], promotionalPrice[i]);
        }
    }

    function updateAbility(
        uint256[] memory ids,
        uint256[] memory efficiency,
        uint256[] memory caps
    ) public onlyOwner {
        if (ids.length != efficiency.length || ids.length != caps.length) {
            revert IllegalParameter();
        }
        for (uint i = 0; i < ids.length; ++i) {
            Pigeon memory pigeon = pigeons[ids[i]];
            pigeon.efficiency = efficiency[i];
            pigeon.cap = caps[i];
            pigeons[ids[i]] = pigeon;
            emit UpdateAbility(ids[i], efficiency[i], caps[i]);
        }
    }

    function setURI(string memory newuri) public onlyOwner {
        super._setURI(newuri);
    }

    function withdrawPayments(address payable payee) external onlyOwner {
        uint256 balance = address(this).balance;
        (bool transferTx, ) = payee.call{value: balance}(new bytes(0));
        if (!transferTx) {
            revert WithdrawTransfer();
        }
    }

    function revokeWrongToken(address token_) external onlyOwner {
        if (token_ == address(0x0)) {
            (bool sent, ) = msg.sender.call{value: address(this).balance}(
                new bytes(0)
            );
            if (!sent) {
                revert WithdrawTransfer();
            }
            return;
        }
        IERC20Upgradeable token = IERC20Upgradeable(token_);
        uint256 amount = token.balanceOf(address(this));
        token.transfer(msg.sender, amount);

        emit RevokeToken(msg.sender, token_, amount);
    }

    //==================== status view ===================================
    function name() public pure returns (string memory) {
        return "Meme Pigeon NFT";
    }

    function symbol() public pure returns (string memory) {
        return "MPF";
    }

    function current() public view returns (uint256) {
        return block.timestamp;
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return
            string(
                abi.encodePacked(
                    super.uri(tokenId),
                    tokenId.toString(),
                    ".json"
                )
            );
    }

    function getMintPrice(uint256 id) public view returns (uint256) {
        if (current() < promotionStartTime) {
            return pigeons[id].promotionalPrice;
        } else if (current() - promotionStartTime >= promotionDuration) {
            return pigeons[id].mintPrice;
        } else {
            uint256 steps = (current() - promotionStartTime) /
                promotionInterval;
            return
                pigeons[id].promotionalPrice + (steps * getPromotionUpStep(id));
        }
    }

    function getPromotionUpStep(uint256 id) public view returns (uint256) {
        return
            (pigeons[id].mintPrice - pigeons[id].promotionalPrice) /
            (promotionDuration / promotionInterval);
    }

    /// common pigeon will not add efficiency either cap
    function getUserPower(
        address target
    ) public view returns (uint256 efficiency, uint256 cap) {
        for (uint i = 1; i <= 4; ) {
            (uint256 efftemp, uint256 captemp) = getUserPigeonPower(i, target);
            efficiency += efftemp;
            cap += captemp;
            i++;
        }
        if (
            efficiency == 0 &&
            cap == 0 &&
            balanceOf(target, uint256(Rarity.Ordinary)) >= 1
        ) {
            efficiency = 1;
            cap = 1;
        }
    }

    function getUserPigeonPower(
        uint256 id,
        address target
    ) public view returns (uint256 efficiency, uint256 cap) {
        uint256 amount = balanceOf(target, id);
        if (amount == 0) {
            return (0, 0);
        }
        Pigeon memory pigeon = pigeons[id];
        return ((amount * pigeon.efficiency), (amount * pigeon.cap));
    }

    function getMaxPigeon(uint256 id) public view returns (uint256) {
        return pigeons[id].groupSize;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155Upgradeable, ERC1155SupplyUpgradeable) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function getPigeonInfo()
        public
        view
        returns (
            Pigeon memory,
            Pigeon memory,
            Pigeon memory,
            Pigeon memory,
            Pigeon memory
        )
    {
        // return (pigeons[1], pigeons[2], pigeons[3], pigeons[4], pigeons[5]);
        // Ordinary Rare Legend Epic Myth
        return (
            pigeons[uint256(Rarity.Myth)],
            pigeons[uint256(Rarity.Epic)],
            pigeons[uint256(Rarity.Legend)],
            pigeons[uint256(Rarity.Rare)],
            pigeons[uint256(Rarity.Ordinary)]
        );
    }
}
