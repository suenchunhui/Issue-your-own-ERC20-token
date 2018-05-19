pragma solidity ^0.4.18;
import "./erc20_tutorial.sol";

contract TradingContract {
    
    //Trading state types
    enum tradingState { idle, deposited, funded, transit, completed}

    //contract state
    struct tradeParams {
        //state-machine main contract state
        tradingState state;

        //trading token parameters
        uint256 trans_amt;

        //trading & inspection partners
        address importer;
        address treasury;
        address exporter;
        address logistics;

    }

    //global trading table
    mapping(uint256 => tradeParams) tradeTable;

    //global admin params---
    //key identities
    address platformOwner;
    TradeToken token;

    //Events
    event StateChange(
        uint256 tradeId,
        tradingState state
    );


    //constructor
    function TradingContract(address tokAddr) public {
        platformOwner = msg.sender;
        token = TradeToken(tokAddr);
    }
    
    modifier onlyBy(address _account)
    {
        require(msg.sender == _account);
        _;
    }


    //query functions
    /* function getTradeParams(uint256 tradeId) public constant returns (tradeParams) {
        return tradeTable[tradeId];
    }*/

    function getTradeState(uint256 tradeId) public constant returns (tradingState) {
        return tradeTable[tradeId].state;
    }

    function getTradeAmount(uint256 tradeId) public constant returns (uint256) {
        return tradeTable[tradeId].trans_amt;
    }

    function getTradeAmount2(uint256 tradeId) public constant returns (uint256) {
        return tradeTable[tradeId].trans_amt / 10;
    }

    function getTradeAmount3(uint256 tradeId) public constant returns (uint256) {
        return tradeTable[tradeId].trans_amt - tradeTable[tradeId].trans_amt / 10;
    }

    //trade functions
    function initTrade (uint256 tradeId, uint256 trans_amt, address exporter) public
    {
        //require trade entry doesnt previously exist
        require(tradeTable[tradeId].state == tradingState.idle);

        //escrow trans_amt of tokens as deposit
        require(token.transferFrom(msg.sender, this, tradeTable[tradeId].trans_amt / 10));
        
        //create trade struct (state = deposited)
        tradeTable[tradeId] = tradeParams(
            tradingState.deposited,  //starting state=pre_initialized
            trans_amt, msg.sender, address(0), exporter, address(0)
        );

        return;
    }

    
    function fundTrade(uint256 tradeId, address logistics) public {

        //correct state
        require(tradeTable[tradeId].state == tradingState.deposited);
        
        //escrow KTF tokens for full payment
        require(token.transferFrom(msg.sender, this, 
            tradeTable[tradeId].trans_amt - tradeTable[tradeId].trans_amt / 10 ));

        tradeTable[tradeId].treasury = msg.sender;
        tradeTable[tradeId].logistics = logistics;

        //next state
        tradeTable[tradeId].state = tradingState.funded;
    }
    
    
    function confirmReceipt(uint256 tradeId) public {

        //correct state
        require(tradeTable[tradeId].state == tradingState.funded);
        
        //require caller is logistics
        require(tradeTable[tradeId].logistics == msg.sender);

        require(token.transfer(tradeTable[tradeId].exporter,
            tradeTable[tradeId].trans_amt));
        
        tradeTable[tradeId].state = tradingState.transit;
        StateChange(tradeId, tradeTable[tradeId].state);

    }


    function finalPayment(uint256 tradeId) public {

        //correct state
        require(tradeTable[tradeId].state == tradingState.transit);


        require(token.transferFrom(msg.sender, tradeTable[tradeId].treasury, 
            tradeTable[tradeId].trans_amt));

        //next state
        tradeTable[tradeId].state = tradingState.completed;
        StateChange(tradeId, tradeTable[tradeId].state);
    }

}