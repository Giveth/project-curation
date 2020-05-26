pragma solidity 0.5.16;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { StableMath } from "../../shared/StableMath.sol";
import { MinterRole } from "@openzeppelin/contracts/access/roles/MinterRole.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { EchidnaInterface } from "../interfaces.sol";

/**
 * @dev Implementation of the `IERC20` interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using `_mint`.
 * For a generic mechanism see `ERC20Mintable`.
 *
 * *For a detailed writeup see our guide [How to implement supply
 * mechanisms](https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226).*
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an `Approval` event is emitted on calls to `transferFrom`.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard `decreaseAllowance` and `increaseAllowance`
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See `IERC20.approve`.
 */
contract ERC20WithFee is IERC20, MinterRole {

    using SafeMath for uint256;
    using StableMath for uint256;

    uint256 public feeRate;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    event FeePaid(address indexed sender, uint256 amount);

    /**
     * @dev Sets the values for `name`, `symbol`, and `decimals`. All three of
     * these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name, string memory symbol, uint8 decimals) public {
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei.
     *
     * > Note that this information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * `IERC20.balanceOf` and `IERC20.transfer`.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See `IERC20.totalSupply`.
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See `IERC20.balanceOf`.
     */
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See `IERC20.transfer`.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    /**
     * @dev See `IERC20.allowance`.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See `IERC20.approve`.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev See `IERC20.transferFrom`.
     *
     * Emits an `Approval` event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of `ERC20`;
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `value`.
     * - the caller must have allowance for `sender`'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to `approve` that can be used as a mitigation for
     * problems described in `IERC20.approve`.
     *
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to `approve` that can be used as a mitigation for
     * problems described in `IERC20.approve`.
     *
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to `transfer`, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a `Transfer` event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        uint256 fee = amount.mulTruncate(feeRate);
        uint256 remainder = amount.sub(fee);

        _burn(sender, fee);

        _balances[sender] = _balances[sender].sub(remainder);
        _balances[recipient] = _balances[recipient].add(remainder);
        emit Transfer(sender, recipient, remainder);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a `Transfer` event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

     /**
     * @dev Destoys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a `Transfer` event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 value) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);
        emit Transfer(account, address(0), value);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
     *
     * This is internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an `Approval` event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @dev Destoys `amount` tokens from `account`.`amount` is then deducted
     * from the caller's allowance.
     *
     * See `_burn` and `_approve`.
     */
    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(account, msg.sender, _allowances[account][msg.sender].sub(amount));
    }

    /**
     * @dev See `ERC20._mint`.
     *
     * Requirements:
     *
     * - the caller must have the `MinterRole`.
     */
    function mint(address account, uint256 amount) public onlyMinter returns (bool) {
        _mint(account, amount);
        return true;
    }

    function init_total_supply() public returns(bool){
		return this.totalSupply() >= 0 && this.totalSupply() == initialTotalSupply;
	}

	function init_owner_balance() public returns(bool){
		return initialBalance_owner == this.balanceOf(echidna_owner);
	}

	function init_user_balance() public returns(bool){
		return initialBalance_user == this.balanceOf(echidna_user);
	}

	function init_attacker_balance() public returns(bool){
		return initialBalance_attacker == this.balanceOf(echidna_attacker);
	}

	function init_caller_balance() public returns(bool){
		return this.balanceOf(msg.sender) > 0;
	}

	function init_total_supply_is_balances() public returns(bool){
		return this.balanceOf(echidna_owner) + this.balanceOf(echidna_user) + this.balanceOf(echidna_attacker) == this.totalSupply();
	}
	function echidna_zero_always_empty_ERC20Properties() public returns(bool){
		return this.balanceOf(address(0x0)) == 0;
	}

	function echidna_approve_overwrites() public returns(bool){
		bool approve_return; 
		approve_return = approve(echidna_user, 10);
		require(approve_return);
		approve_return = approve(echidna_user, 20);
		require(approve_return);
		return this.allowance(msg.sender, echidna_user) == 20;
	}

	function echidna_less_than_total_ERC20Properties() public returns(bool){
		return this.balanceOf(msg.sender) <= totalSupply();
	}

	function echidna_totalSupply_consistant_ERC20Properties() public returns(bool){
		return this.balanceOf(echidna_owner) + this.balanceOf(echidna_user) + this.balanceOf(echidna_attacker) <= totalSupply();
	}

	function echidna_revert_transfer_to_zero_ERC20PropertiesTransferable() public returns(bool){
		if (this.balanceOf(msg.sender) == 0){
			revert();
		}
		return transfer(address(0x0), this.balanceOf(msg.sender));
	}

	function echidna_revert_transferFrom_to_zero_ERC20PropertiesTransferable() public returns(bool){
		uint balance = this.balanceOf(msg.sender);
		if (balance == 0){
			revert();
		}
		approve(msg.sender, balance);
		return transferFrom(msg.sender, address(0x0), this.balanceOf(msg.sender));
	}

	function echidna_self_transferFrom_ERC20PropertiesTransferable() public returns(bool){
		uint balance = this.balanceOf(msg.sender);
		bool approve_return = approve(msg.sender, balance);
		bool transfer_return = transferFrom(msg.sender, msg.sender, balance);
		return (this.balanceOf(msg.sender) == balance) && approve_return && transfer_return;
	}

	function echidna_self_transferFrom_to_other_ERC20PropertiesTransferable() public returns(bool){
		uint balance = this.balanceOf(msg.sender);
		bool approve_return = approve(msg.sender, balance);
		address other = echidna_user;
		if (other == msg.sender) {
			other = echidna_owner;
		}
		bool transfer_return = transferFrom(msg.sender, other, balance);
		return (this.balanceOf(msg.sender) == 0) && approve_return && transfer_return;
	}

	function echidna_self_transfer_ERC20PropertiesTransferable() public returns(bool){
		uint balance = this.balanceOf(msg.sender);
		bool transfer_return = transfer(msg.sender, balance);
		return (this.balanceOf(msg.sender) == balance) && transfer_return;
	}

	function echidna_transfer_to_other_ERC20PropertiesTransferable() public returns(bool){
		uint balance = this.balanceOf(msg.sender);
		address other = echidna_user;
		if (other == msg.sender) {
			other = echidna_owner;
		}
		if (balance >= 1) {
			bool transfer_other = transfer(other, 1);
			return (this.balanceOf(msg.sender) == balance-1) && (this.balanceOf(other) >= 1) && transfer_other;
		}
		return true;
	}

	function echidna_revert_transfer_to_user_ERC20PropertiesTransferable() public returns(bool){
		uint balance = this.balanceOf(msg.sender);
		if (balance == (2 ** 256 - 1))
			return true;
		bool transfer_other = transfer(echidna_user, balance+1);
		return transfer_other;
	}

}

contract EchidnaERC20WithFee is ERC20WithFee {

    constructor (
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _initialRecipient,
        uint256 _initialMint
    )
        ERC20WithFee
    (
        _name,
        _symbol,
        _decimals
    )
        public
    {
        feeRate = 1e15;
        _mint(_initialRecipient, _initialMint.mul(10 ** uint256(_decimals)));
    }

    function init_total_supply() public returns(bool){
		return this.totalSupply() >= 0 && this.totalSupply() == initialTotalSupply;
	}

	function init_owner_balance() public returns(bool){
		return initialBalance_owner == this.balanceOf(echidna_owner);
	}

	function init_user_balance() public returns(bool){
		return initialBalance_user == this.balanceOf(echidna_user);
	}

	function init_attacker_balance() public returns(bool){
		return initialBalance_attacker == this.balanceOf(echidna_attacker);
	}

	function init_caller_balance() public returns(bool){
		return this.balanceOf(msg.sender) > 0;
	}

	function init_total_supply_is_balances() public returns(bool){
		return this.balanceOf(echidna_owner) + this.balanceOf(echidna_user) + this.balanceOf(echidna_attacker) == this.totalSupply();
	}
	function echidna_zero_always_empty_ERC20Properties() public returns(bool){
		return this.balanceOf(address(0x0)) == 0;
	}

	function echidna_approve_overwrites() public returns(bool){
		bool approve_return; 
		approve_return = approve(echidna_user, 10);
		require(approve_return);
		approve_return = approve(echidna_user, 20);
		require(approve_return);
		return this.allowance(msg.sender, echidna_user) == 20;
	}

	function echidna_less_than_total_ERC20Properties() public returns(bool){
		return this.balanceOf(msg.sender) <= totalSupply();
	}

	function echidna_totalSupply_consistant_ERC20Properties() public returns(bool){
		return this.balanceOf(echidna_owner) + this.balanceOf(echidna_user) + this.balanceOf(echidna_attacker) <= totalSupply();
	}

	function echidna_revert_transfer_to_zero_ERC20PropertiesTransferable() public returns(bool){
		if (this.balanceOf(msg.sender) == 0){
			revert();
		}
		return transfer(address(0x0), this.balanceOf(msg.sender));
	}

	function echidna_revert_transferFrom_to_zero_ERC20PropertiesTransferable() public returns(bool){
		uint balance = this.balanceOf(msg.sender);
		if (balance == 0){
			revert();
		}
		approve(msg.sender, balance);
		return transferFrom(msg.sender, address(0x0), this.balanceOf(msg.sender));
	}

	function echidna_self_transferFrom_ERC20PropertiesTransferable() public returns(bool){
		uint balance = this.balanceOf(msg.sender);
		bool approve_return = approve(msg.sender, balance);
		bool transfer_return = transferFrom(msg.sender, msg.sender, balance);
		return (this.balanceOf(msg.sender) == balance) && approve_return && transfer_return;
	}

	function echidna_self_transferFrom_to_other_ERC20PropertiesTransferable() public returns(bool){
		uint balance = this.balanceOf(msg.sender);
		bool approve_return = approve(msg.sender, balance);
		address other = echidna_user;
		if (other == msg.sender) {
			other = echidna_owner;
		}
		bool transfer_return = transferFrom(msg.sender, other, balance);
		return (this.balanceOf(msg.sender) == 0) && approve_return && transfer_return;
	}

	function echidna_self_transfer_ERC20PropertiesTransferable() public returns(bool){
		uint balance = this.balanceOf(msg.sender);
		bool transfer_return = transfer(msg.sender, balance);
		return (this.balanceOf(msg.sender) == balance) && transfer_return;
	}

	function echidna_transfer_to_other_ERC20PropertiesTransferable() public returns(bool){
		uint balance = this.balanceOf(msg.sender);
		address other = echidna_user;
		if (other == msg.sender) {
			other = echidna_owner;
		}
		if (balance >= 1) {
			bool transfer_other = transfer(other, 1);
			return (this.balanceOf(msg.sender) == balance-1) && (this.balanceOf(other) >= 1) && transfer_other;
		}
		return true;
	}

	function echidna_revert_transfer_to_user_ERC20PropertiesTransferable() public returns(bool){
		uint balance = this.balanceOf(msg.sender);
		if (balance == (2 ** 256 - 1))
			return true;
		bool transfer_other = transfer(echidna_user, balance+1);
		return transfer_other;
	}


}
