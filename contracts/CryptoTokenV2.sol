pragma solidity ^0.4.21;

library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    if (a == 0) {
      return 0;
    }
    c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return a / b;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}

library AddressUtils {

  /**
   * Returns whether the target address is a contract
   * @dev This function will return false if invoked during the constructor of a contract,
   *  as the code is not actually created until after the constructor finishes.
   * @param addr address to check
   * @return whether the target address is a contract
   */
  function isContract(address addr) internal view returns (bool) {
    uint256 size;
    // XXX Currently there is no better way to check if there is a contract in an address
    // than to check the size of the code at that address.
    // See https://ethereum.stackexchange.com/a/14016/36603
    // for more details about how this works.
    // TODO Check this again before the Serenity release, because all addresses will be
    // contracts then.
    assembly { size := extcodesize(addr) }  // solium-disable-line security/no-inline-assembly
    return size > 0;
  }

}

contract Ownable {
  address public owner;


  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}

contract AccessControl is Ownable {
  event ContractUpgrade();

  address private MainAdmin;
  address private TechnicalAdmin;
  address private FinancialAdmin;
  address private MarketingAdmin;

  function AccessControl() public {
    MainAdmin = owner;
  }

  modifier onlyMainAdmin() {
    require(msg.sender == MainAdmin);
    _;
  }

  modifier onlyFinancialAdmin() {
    require(msg.sender == FinancialAdmin);
    _;
  }

  modifier onlyMarketingAdmin() {
    require(msg.sender == MarketingAdmin);
    _;
  }

  modifier onlyTechnicalAdmin() {
    require(msg.sender == TechnicalAdmin);
    _;
  }

  modifier onlyAdmins() {
    require(msg.sender == TechnicalAdmin || msg.sender == MarketingAdmin
      || msg.sender == FinancialAdmin || msg.sender == MainAdmin);
    _;
  }

  function setMainAdmin(address _newMainAdmin) external onlyOwner {
    require(_newMainAdmin != address(0));
    MainAdmin = _newMainAdmin;
  }

  function setFinancialAdmin(address _newFinancialAdmin) external onlyMainAdmin {
    require(_newFinancialAdmin != address(0));
    FinancialAdmin = _newFinancialAdmin;
  }

  function setMarketingAdmin(address _newMarketingAdmin) external onlyMainAdmin {
    require(_newMarketingAdmin != address(0));
    MarketingAdmin = _newMarketingAdmin;
  }


  function setTechnicalAdmin(address _newTechnicalAdmin) external onlyMainAdmin {
    require(_newTechnicalAdmin != address(0));
    TechnicalAdmin = _newTechnicalAdmin;
  }

}


contract Pausable is AccessControl {
  event Pause();
  event Unpause();

  bool public paused;


  function Pausable() public {
    paused = true;
  }

  /**
   * @dev Modifier to make a function callable only when the contract is not paused.
   */
  modifier whenNotPaused() {
    require(!paused);
    _;
  }

  /**
   * @dev Modifier to make a function callable only when the contract is paused.
   */
  modifier whenPaused() {
    require(paused);
    _;
  }

  /**
   * @dev called by the owner to pause, triggers stopped state
   */
  function pause() onlyAdmins whenNotPaused public {
    paused = true;
    emit Pause();
  }

  /**
   * @dev called by the owner to unpause, returns to normal state
   */
  function unpause() onlyAdmins whenPaused public {
    paused = false;
    emit Unpause();
  }
}

contract ApproveAndCallFallBack {
    function receiveApproval(address from, uint256 tokens, address token, bytes data) public;
}

contract PullPayment is Pausable {
  using SafeMath for uint256;


  mapping(address => uint256) public payments;
  uint256 public totalPayments;

  /**
  * @dev Withdraw accumulated balance, called by payee.
  */
  function withdrawPayments() whenNotPaused public {
    address payee = msg.sender;
    uint256 payment = payments[payee];

    require(payment != 0);
    require(address(this).balance >= payment);

    totalPayments = totalPayments.sub(payment);
    payments[payee] = 0;

    payee.transfer(payment);
  }

  /**
  * @dev Called by the payer to store the sent amount as credit to be pulled.
  * @param dest The destination address of the funds.
  * @param amount The amount to transfer.
  */
  function asyncSend(address dest, uint256 amount) whenNotPaused internal {
    payments[dest] = payments[dest].add(amount);
    totalPayments = totalPayments.add(amount);
  }
}

contract ERC20Interface {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

contract CryptoToken {

    function totalSupply() external view returns (uint);

    function balanceOf(address tokenOwner) external view returns (uint balance);

       // Transfer the balance from owner's account to another account
    function transfer(address to, uint tokens) public returns (bool success);

    function approve(address spender, uint tokens) public returns (bool success);

    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    function allowance(address tokenOwner, address spender) public returns (uint remaining);

    function approveAndCall(address spender, uint tokens, bytes data) public returns (bool success);

    function transferAnyERC20Token(address tokenAddress, uint tokens) public returns (bool success);
}

contract CryptoTokenV2 is PullPayment, ERC20Interface {

    string public constant name = "CryptoToken";
    string public constant symbol = "CTN";
    uint8 public constant decimals = 18;  // 18 is the most common number of decimal places

    using SafeMath for uint;

    uint public _totalSupply;

    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;


    CryptoToken previousVersion;

    mapping (address => bool) previousBalanceLoaded;

    function CryptoTokenV2(address previousContractAddress) public {
        previousVersion = CryptoToken(previousContractAddress);
        _totalSupply = previousVersion.totalSupply();
    }

    function totalSupply() public constant returns (uint) {
            return _totalSupply  - balances[address(0)];
    }

    function balanceOf(address tokenOwner) public constant returns (uint balance) {
        if(previousBalanceLoaded[tokenOwner] == false){
            return balances[tokenOwner] + previousVersion.balanceOf(tokenOwner);
        }
        return balances[tokenOwner];
    }

       // Transfer the balance from owner's account to another account
    function transfer(address to, uint tokens) public whenNotPaused returns (bool success) {


        if(previousBalanceLoaded[msg.sender] == false){
            balances[msg.sender] =  balances[msg.sender] + previousVersion.balanceOf(msg.sender);
            previousBalanceLoaded[msg.sender] == true;
        }

        require(balances[msg.sender] >= tokens);

        balances[msg.sender] = balances[msg.sender].sub(tokens);
        balances[to] = balances[to].add(tokens);
        emit Transfer(msg.sender, to, tokens);
        return true;
    }

    function approve(address spender, uint tokens) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }

    function transferFrom(address from, address to, uint tokens) public returns (bool success) {
        balances[from] = balances[from].sub(tokens);
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);
        balances[to] = balances[to].add(tokens);
        emit Transfer(from, to, tokens);
        return true;
    }

    function allowance(address tokenOwner, address spender) public constant returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }

    function approveAndCall(address spender, uint tokens, bytes data) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        ApproveAndCallFallBack(spender).receiveApproval(msg.sender, tokens, this, data);
        return true;
    }

    function () public payable {
        revert();
    }

    function transferAnyERC20Token(address tokenAddress, uint tokens) public onlyOwner returns (bool success) {
        return ERC20Interface(tokenAddress).transfer(owner, tokens);
    }
}
