// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;


contract MultiSig {
    
    event SubmitTransaction(address indexed owner, uint256 indexed txIndex, address indexed to, uint256 value, bytes data);
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);

    address[] public owners;
    uint256 public numConfirmationsRequired;
    mapping (address => bool) public isOwner;
    mapping (address => uint256) public balanceOf;
    
    function giveOneEth(address to) public {
        balanceOf[to] += 1 ether;
    }

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }

    Transaction[] public transactions;
       // Track confirmations for each transaction (by index)
    mapping (uint256 => mapping(address => bool)) public isConfirmed;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not owner");
        _;
    }

    modifier txExists(uint256 txIndex) {
        require(txIndex < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 txIndex) {
        require(!transactions[txIndex].executed, "Transaction already executed");
        _;
    }

    modifier notConfirmed(uint256 txIndex) {
        require(!isConfirmed[txIndex][msg.sender], "Transaction already confirmed");
        _;
    }
    constructor(address[] memory _owners, uint256 _numConfirmationsRequired) {
        require(_owners.length > 0, "Owners required");
        require(_numConfirmationsRequired > 0 && _numConfirmationsRequired <= _owners.length, "Invalid number of required confirmations");
        owners = _owners;
        numConfirmationsRequired = _numConfirmationsRequired;
        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Invalid owner");
            require(!isOwner[_owners[i]], "Owner not unique");
            isOwner[_owners[i]] = true;
        }
    }

    receive() external payable {}
    fallback() external payable {}

    // Send a transaction proposal to the wallet
    function submitTransaction(address to, uint256 value, bytes memory data) public onlyOwner {
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        uint256 txIndex = transactions.length;
        // Pending transaction until signed and confirmed
        // Multi sig logic would go here  
        transactions.push(Transaction({
            to: to,
            value: value,
            data: data,
            executed: false,
            numConfirmations: 0
        }));
        emit SubmitTransaction(msg.sender, txIndex, to, value, data);
    }

    function confirmTransaction(uint256 txIndex) public onlyOwner txExists(txIndex) notExecuted(txIndex) notConfirmed(txIndex) {
        Transaction storage transaction = transactions[txIndex];
        require(!transaction.executed, "Transaction already executed");
        require(!isConfirmed[txIndex][msg.sender], "Transaction already confirmed by this owner");

        isConfirmed[txIndex][msg.sender] = true;
        transaction.numConfirmations += 1;

        emit ConfirmTransaction(msg.sender, txIndex);
    }

    function executeTransaction(uint256 txIndex) public onlyOwner txExists(txIndex) notExecuted(txIndex) {
        Transaction storage transaction = transactions[txIndex];
        require(!transaction.executed, "Transaction already executed");
        require(transaction.numConfirmations >= numConfirmationsRequired, "Not enough confirmations");
        transaction.executed = true;

        (bool success,) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, txIndex);
    }
    
    function revokeConfirmation(uint256 txIndex) public onlyOwner txExists(txIndex) notExecuted(txIndex) {
        Transaction storage transaction = transactions[txIndex];
        require(!transaction.executed, "Transaction already executed");
        require(isConfirmed[txIndex][msg.sender], "Transaction not confirmed by this owner");

        isConfirmed[txIndex][msg.sender] = false;
        transaction.numConfirmations -= 1;

        emit RevokeConfirmation(msg.sender, txIndex);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransaction(uint256 txIndex) public view returns(address to, uint256 value, bytes memory data, bool executed, uint256 numConfirmations) {
        Transaction storage transaction = transactions[txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }

    function getConfirmationsCount(uint256 txIndex) public view returns (uint256) {
        Transaction storage transaction = transactions[txIndex];
        return transaction.numConfirmations;
    }
} 