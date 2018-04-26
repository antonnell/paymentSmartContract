pragma solidity 0.4.22;
import "./SafeMath.sol";


contract PaymentApprovalContract {
    using SafeMath for uint;

    address private payerAddress;
    address private payeeAddress;
    address private usufructAddress;

    uint private paymentAmount;
    uint private payerBalance = 0;
    uint private payeeBalance = 0;

    ContractStages private currentStage;

    enum ContractStages { Created, Approved, Terminated }

    struct Authorisation {
        bool payerAuthorised;
        bool payeeAuthorised;
        address toAddress;
    }

    Authorisation private payerUpdateAuthorised;
    Authorisation private payeeUpdateAuthorised;
    Authorisation private usufructUpdateAuthorised;
    Authorisation private approvePayoutAuthorised;
    Authorisation private terminateContractAuthorised;

    event Transfer(address indexed from, address indexed to, uint256 value);

    event ContractCreated();
    event ContractApproveRequested();
    event ContractApproved();
    event ContractTerminatedRequested();
    event ContractTerminated();

    event FundsDeposited(uint payerBalance);
    event DepositWithdrawn(uint payerBalance);
    event PaymentsWithdrawn(uint payeeBalance);

    event PayerUpdated(address _fromAddress, address _toAddress);
    event PayerUpdateRequested(address _fromAddress, address _toAddress, address _byAddress);
    event PayerUpdateAuthorised(address _fromAddress, address _toAddress, address _byAddress);
    event PayerUpdateRejected(address _fromAddress, address _toAddress, address _byAddress);

    event PayeeUpdated(address _fromAddress, address _toAddress);
    event PayeeUpdateRequested(address _fromAddress, address _toAddress, address _byAddress);
    event PayeeUpdateAuthorised(address _fromAddress, address _toAddress, address _byAddress);
    event PayeeUpdateRejected(address _fromAddress, address _toAddress, address _byAddress);

    event UsufructUpdateRequested(address _fromAddress, address _toAddress, address _byAddress);
    event UsufructUpdateAuthorised(address _fromAddress, address _toAddress, address _byAddress);
    event UsufructUpdateRejected(address _fromAddress, address _toAddress, address _byAddress);

    modifier validAddress(address addr) {
        require(addr != address(0x0));
        require(addr != address(this));
        _;
    }

    /// Only the Payer has access to the functionality
    modifier onlyPayer {
        require(msg.sender == payerAddress);
        _;
    }

    /// Only the Payee has access to the functionality
    modifier onlyPayee {
        require(msg.sender == payeeAddress);
        _;
    }

    /// Only the Payer or the Payee have access to the functionality
    modifier payerOrPayee {
        require(msg.sender == payerAddress || msg.sender == payeeAddress);
        _;
    }

    /// Only the Usufruct has access to the functionality
    modifier onlyUsufruct {
        require(msg.sender == usufructAddress);
        _;
    }

    /// Only the Payer, Payee or Usufruct have access to the functionality
    modifier onlyAuthorised {
        require(msg.sender == payerAddress || msg.sender == payeeAddress || msg.sender == usufructAddress);
        _;
    }

    /**
     * Constrctor function
     *
     * Initializes contract with payer, payee, payment interval and payement per interval
     *
     * @param _payerAddress The address of the contract payer
     * @param _payeeAddress The address of the contract payee
     * @param _paymentAmount The amount of funds to be received per interval
     */
    function PaymentApprovalContract(
        address _payerAddress,
        address _payeeAddress,
        uint _paymentAmount
    )
        public
        validAddress(_payerAddress)
        validAddress(_payeeAddress)
    {

        payerAddress = _payerAddress;
        payeeAddress = _payeeAddress;
        paymentAmount = _paymentAmount;
        currentStage = ContractStages.Created;

        emit ContractCreated();
    }

    /**
     * Standard revert function to return accidentally sent Eth
     */
    function () public payable {
        revert();
    }

    /// get contract address details
    function getContractDetails() public view returns
    (
        address _payerAddress,
        address _payeeAddress,
        address _usufructAddress,
        string _contractType,
        uint _paymentAmount,
        uint _payerBalance,
        uint _payeeBalance
    )
    {
        _payerAddress = payerAddress;
        _payeeAddress = payeeAddress;
        _usufructAddress = usufructAddress;
        _paymentAmount = paymentAmount;
        _contractType = "Approval";
        _payerBalance = payerBalance;
        _payeeBalance = payeeBalance;

        return
        (
            _payerAddress,
            _payeeAddress,
            _usufructAddress,
            _contractType,
            _paymentAmount,
            _payerBalance,
            _payeeBalance
        );
    }

    /**
     * Deposit funds into the contract by the payer
     *
     * @param _amount the amount of funds to be depositted
     */
    function depositFunds(uint _amount)
        public
        payable
        onlyPayer
        returns (bool)
    {
        require(msg.value == _amount);

        payerBalance = payerBalance.add(_amount);
        emit FundsDeposited(payerBalance);

        return true;
    }

    /**
     * Withdraw funds from the contract by the payer
     *
     * @param _amount the amount of funds to be withdrawn
     *
     */
    function withdrawFunds(uint _amount)
        public
        onlyPayer
        returns (bool)
    {
        require(payerBalance.sub(paymentAmount) >= _amount);

        payerBalance = payerBalance.sub(_amount);

        _transfer(payerAddress, _amount);
        emit DepositWithdrawn(payerBalance);

        return true;
    }

    /**
     * Withdraw payments made to the payee
     *
     * @param _amount the amount of funds to be withdrawn
     */
    function withdrawPayment(uint _amount)
        public
        onlyPayee
        returns (bool)
    {
        require(payeeBalance >= _amount);

        payeeBalance = payeeBalance.sub(_amount);

        _transfer(payeeAddress, _amount);
        emit PaymentsWithdrawn(payeeBalance);

        return true;
    }

    /**
     * Returns current stage of the contract (Created, Approved, Terminated)
     */
    function getContractState()
        public
        view
        returns (ContractStages)
    {
        return currentStage;
    }

    /**
    * Request that the contract be started
    */
    function approvePayout()
        public
        onlyAuthorised
        returns (bool)
    {
        require(currentStage == ContractStages.Created);
        require(payerBalance >= paymentAmount);

        if (msg.sender == payerAddress) {
            approvePayoutAuthorised.payerAuthorised = true;
        }
        if (msg.sender == payeeAddress) {
            approvePayoutAuthorised.payeeAuthorised = true;
        }

        if (approvePayoutAuthorised.payerAuthorised == true && approvePayoutAuthorised.payeeAuthorised == true) {
            currentStage = ContractStages.Approved;
            payerBalance = payerBalance.sub(paymentAmount);
            payeeBalance = payeeBalance.add(paymentAmount);
            emit ContractApproved();
        } else {
            emit ContractApproveRequested();
        }

        return true;
    }

    /**
    * Request that the contract be terminated
    */
    function terminateContract()
        public
        onlyAuthorised
        returns (bool)
    {
        require(currentStage == ContractStages.Approved || currentStage == ContractStages.Created);

        if (msg.sender == payerAddress) {
            terminateContractAuthorised.payerAuthorised = true;
        }
        if (msg.sender == payeeAddress) {
            terminateContractAuthorised.payeeAuthorised = true;
        }

        if (terminateContractAuthorised.payerAuthorised == true &&
            terminateContractAuthorised.payeeAuthorised == true) {
            currentStage = ContractStages.Terminated;
            emit ContractTerminated();
        } else {
            emit ContractTerminatedRequested();
        }

        return true;
    }

    /// Returns remaining balance in the payer wallet
    function getPayerBalance() public view returns (uint) { return payerBalance; }

    /// Returns payer address
    function getPayerAddress() public view returns (address) { return payerAddress; }

    /**
     * Sets new payer address
     *
     * @param _address Address of the new Payer
     */
    function setPayerAddress(address _address)
        public
        onlyPayer
        validAddress(_address)
        returns (bool)
    {
        emit PayerUpdated(payerAddress, _address);
        payerAddress = _address;

        return true;
    }

    /**
     * Request that the payer be changed
     *
     * @param _address Address of the new Payer
     */
    function requestPayerUpdate(address _address) public onlyAuthorised validAddress(_address) returns (bool) {
        if (payerUpdateAuthorised.toAddress == _address) {
            if (msg.sender == payerAddress) {
                payerUpdateAuthorised.payerAuthorised = true;
            }
            if (msg.sender == payeeAddress) {
                payerUpdateAuthorised.payeeAuthorised = true;
            }

            if (payerUpdateAuthorised.payerAuthorised == true && payerUpdateAuthorised.payeeAuthorised == true) {
                emit PayerUpdateAuthorised(payerAddress, _address, msg.sender);
                payerAddress = _address;
            } else {
                emit PayerUpdateRequested(payerAddress, _address, msg.sender);
            }
        } else {
            bool payerAuthorised = msg.sender == payerAddress;
            bool payeeAuthorised = msg.sender == payeeAddress;
            payerUpdateAuthorised = Authorisation(payerAuthorised, payeeAuthorised, _address);

            emit PayerUpdateRequested(payerAddress, _address, msg.sender);
        }

        return true;
    }

    /**
     * Reject the request for a payer to be updated
     *
     * @param _address Address of the rejected Payer
     */
    function rejectPayerUpdate(address _address) public payerOrPayee validAddress(_address) returns (bool) {
        if (payerUpdateAuthorised.toAddress == _address) {
            payerUpdateAuthorised = Authorisation(false, false, address(0));
            emit PayerUpdateRejected(payerAddress, _address, msg.sender);
        }

        return true;
    }

    /**
     * Returns pending payer update
     */
    function getPendingPayerUpdate() public view returns (bool, bool, address) {
        Authorisation memory auth = payerUpdateAuthorised;
        return (auth.payerAuthorised, auth.payeeAuthorised, auth.toAddress);
    }

    /// Returns remaining balance in the payee wallet
    function getPayeeBalance() public view returns (uint) { return payeeBalance; }

    /// Returns payee address
    function getPayeeAddress() public view returns (address) { return payeeAddress; }

    /**
     * Sets new payee address
     *
     * @param _address Address of the new Payee
     */
    function setPayeeAddress(address _address)
        public
        onlyPayee
        validAddress(_address)
        returns (bool)
    {
        emit PayeeUpdated(payeeAddress, _address);
        payeeAddress = _address;

        return true;
    }

    /**
     * Request that the payee be changed
     *
     * @param _address Address of the new Payee
     */
    function requestPayeeUpdate(address _address) public onlyAuthorised validAddress(_address) returns (bool) {
        if (payeeUpdateAuthorised.toAddress == _address) {
            if (msg.sender == payerAddress) {
                payeeUpdateAuthorised.payerAuthorised = true;
            }
            if (msg.sender == payeeAddress) {
                payeeUpdateAuthorised.payeeAuthorised = true;
            }

            if (payeeUpdateAuthorised.payerAuthorised == true && payeeUpdateAuthorised.payeeAuthorised == true) {
                emit PayeeUpdateAuthorised(payeeAddress, _address, msg.sender);
                payeeAddress = _address;
            } else {
                emit PayerUpdateRequested(payeeAddress, _address, msg.sender);
            }
        } else {
            bool payerAuthorised = msg.sender == payerAddress;
            bool payeeAuthorised = msg.sender == payeeAddress;
            payeeUpdateAuthorised = Authorisation(payerAuthorised, payeeAuthorised, _address);

            emit PayeeUpdateRequested(payeeAddress, _address, msg.sender);
        }

        return true;
    }

    /**
     * Reject the request for a payee to be updated
     *
     * @param _address Address of the rejected Payee
     */
    function rejectPayeeUpdate(address _address) public payerOrPayee validAddress(_address) returns (bool) {
        if (payeeUpdateAuthorised.toAddress == _address) {
            payeeUpdateAuthorised = Authorisation(false, false, address(0));
            emit PayeeUpdateRejected(payeeAddress, _address, msg.sender);
        }

        return true;
    }

    /**
     * Returns pending payee update
     */
    function getPendingPayeeUpdate() public view returns (bool, bool, address) {
        Authorisation memory auth = payeeUpdateAuthorised;
        return (auth.payerAuthorised, auth.payeeAuthorised, auth.toAddress);
    }

    /// Returns usufruct address
    function getUsufruct() public view returns (address) { return usufructAddress; }

    /**
     * Request that the usufruct be changed
     *
     * @param _address Address of the new Usufruct
     */
    function requestUsufructUpdate(address _address) public onlyAuthorised validAddress(_address) returns (bool) {
        if (usufructUpdateAuthorised.toAddress == _address) {
            if (msg.sender == payerAddress) {
                usufructUpdateAuthorised.payerAuthorised = true;
            }
            if (msg.sender == payeeAddress) {
                usufructUpdateAuthorised.payeeAuthorised = true;
            }

            if (usufructUpdateAuthorised.payerAuthorised == true && usufructUpdateAuthorised.payeeAuthorised == true) {
                emit UsufructUpdateAuthorised(usufructAddress, _address, msg.sender);
                usufructAddress = _address;
            } else {
                emit PayerUpdateRequested(usufructAddress, _address, msg.sender);
            }
        } else {
            bool payerAuthorised = msg.sender == payerAddress;
            bool payeeAuthorised = msg.sender == payeeAddress;
            usufructUpdateAuthorised = Authorisation(payerAuthorised, payeeAuthorised, _address);

            emit UsufructUpdateRequested(usufructAddress, _address, msg.sender);
        }

        return true;
    }

    /**
     * Reject the request for a usufruct to be updated
     *
     * @param _address Address of the rejected Usufruct
     */
    function rejectUsufructUpdate(address _address) public payerOrPayee validAddress(_address) returns (bool) {
        if (usufructUpdateAuthorised.toAddress == _address) {
            usufructUpdateAuthorised = Authorisation(false, false, address(0));
            emit UsufructUpdateRejected(usufructAddress, _address, msg.sender);
        }

        return true;
    }

    /**
     * Returns pending usufruct update
     */
    function getPendingUsufructUpdate() public view returns (bool, bool, address) {
        Authorisation memory auth = usufructUpdateAuthorised;
        return (auth.payerAuthorised, auth.payeeAuthorised, auth.toAddress);
    }

    /**
     * Transfers the amount of ether to the address specified
     *
     * @param _to Address to transfer ether to
     * @param _amount Amount of ether to transfer
     */
    function _transfer(address _to, uint _amount) internal {
        _to.transfer(_amount);

        emit Transfer(msg.sender, _to, _amount);
    }
}
