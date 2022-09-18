// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract MultiSignatureWallet {

    event Deposit(address indexed sender, uint value);
    event Submission(uint indexed transactionId);
    event Confirmation(address indexed sender, uint indexed transactionId);
    event Execution(uint indexed transactionId);
    event ExecutionFailure(uint indexed transactionId);
    event Revoke(address indexed caller , uint transactionId);

    struct Transaction {
      bool executed;
      address destination;
      uint value;
      bytes data;
    }

    address[] public owners;
    uint public required;
    address public owner;
    mapping (address => bool) public isOwner;
    uint public transactionCount;
    mapping (uint => Transaction) public transactions;
    mapping (uint => mapping (address => bool)) public confirmations;

           modifier validRequirement(uint ownerCount, uint _required) {
        if (_required > ownerCount || _required == 0 || ownerCount == 0)
            revert();
        _;
    }
    
     //Sets initial owners and required number of confirmations
    constructor(address[] memory _owners, uint _required) validRequirement(_owners.length, _required){
         for (uint i=0; i<_owners.length; i++) {
            isOwner[_owners[i]] = true;
        }
        owners = _owners;
        required = _required;
        
    }

     // Fallback
    fallback()external payable {
        if (msg.value > 0) {
            emit Deposit(msg.sender, msg.value);
	}
    }

     receive() external payable {
        }
   
  //Allows an owner to submit and confirm a transaction
    function submitTransaction(address destination, uint value, bytes calldata data) public returns (uint transactionId){
            require(isOwner[msg.sender],"Not owner");
            transactionId = addTransaction(destination, value, data);
            confirmTransaction(transactionId);
    }
 
    
    //Adds a new transaction to the transaction mapping, if transaction does not yet exist
    function addTransaction(address destination, uint value, bytes calldata data) internal returns (uint transactionId) {
        transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            destination: destination,
            value: value,
            data: data,
            executed: false
        });
        transactionCount += 1;
        emit Submission(transactionId);
    }

    //Allows an owner to confirm a transaction
    function confirmTransaction(uint transactionId) public {
    require(isOwner[msg.sender]);
    require(transactions[transactionId].destination != address(0)); 
    require(confirmations[transactionId][msg.sender] == false); 
    confirmations[transactionId][msg.sender] = true;
    emit Confirmation(msg.sender, transactionId);
    executeTransaction(transactionId);
    }
    
    //Allows anyone to execute a confirmed transaction
    function executeTransaction(uint transactionId) public {
        require(transactions[transactionId].executed == false);
         if (isConfirmed(transactionId)) {
            Transaction storage t = transactions[transactionId];
            t.executed = true;
            (bool success, ) = t.destination.call{value:t.value}(t.data);
            if (success){
                emit Execution(transactionId);
            }
            else {
                emit ExecutionFailure(transactionId);
                t.executed = false;
            }
        }
    }
        
     //Returns the confirmation status of a transaction
        function isConfirmed(uint transactionId) internal view returns (bool confirmed) {
        uint count = 0;
        for(uint i=0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]]){
                count += 1;
            }
            if (count == required){
                return true;
            }
        }
    }

    //Allows an owner to revoke a confirmation for a transaction
    function revokeConfirmation(uint transactionId) public {
        require(transactions[transactionId].executed == false);
        confirmations[transactionId][msg.sender] = false;
        emit Revoke(msg.sender, transactionId);
    }
   
}
