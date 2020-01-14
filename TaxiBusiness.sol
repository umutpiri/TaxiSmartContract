pragma solidity 0.4.24;

/*
* Author: Umut Piri - 21783872
* 
* A smart contract to unite entrepreneurs who want to join a taxi business
*/
contract TaxiBusiness {
    
    //constant state variables
    uint128 constant fee = 100 ether;
    uint64 constant carExpense = 10 ether;
    uint32 constant expenseInterval = 180 days;
    uint32 constant paymentInterval = 180 days;
    
    struct Participant {
        uint balance;
        bool isExist;
    }
    
    struct Car {
        bytes32 carId;
        uint lastMaintenanceTime;
    }
    
    struct CarPurchaseProposal {
        Car car;
        uint price;
        uint validTime;
        uint8 approval; //number of approvals
        mapping(address => bool) isApproved;
    }
    
    struct Driver {
        address addr;
        uint salary;
        uint balance;
        uint lastPayDay;
    }
    
    struct DriverProposal {
        Driver driver;
        uint8 approval;  //number of approvals
        mapping(address => bool) isApproved;
    }
    
    //state variables
    address manager;
    
    mapping(address => Participant) participants;
    address[] participantWallets;
    
    address carDealer;
    
    CarPurchaseProposal purchaseProposal;
    CarPurchaseProposal repurchaseProposal;
    
    Car taxi;
    
    DriverProposal driverProposal;
    
    Driver driver;
    
    uint contractBalance;
    uint lastPayDay;
    
    constructor() public{
        manager = msg.sender;
    }
    
    modifier onlyManager{
        require(msg.sender == manager, "only manager can call this");_;
    }
    
    modifier onlyCarDealer{
        require(msg.sender == carDealer, "only car dealer can call this");_;
    }
    
    modifier onlyParticipants{
        require(participants[msg.sender].isExist == true, "only participants can call this");_;
    }
    
    modifier onlyDriver{
        require(msg.sender == driver.addr, "only driver can call this");_;
    }
    
    modifier validPurchaseTime{
        require(purchaseProposal.validTime >= now, "purchase proposal time is not valid");_;
    }
    
    modifier validRepurchaseTime{
        require(repurchaseProposal.validTime >= now, "repurchase proposal time is not valid");_;
    }
    
    function join() public payable{
        require(participantWallets.length < 9 , "maximum number of participants is 9");
        require(participants[msg.sender].isExist == false, "participant joined already");
        require(msg.value >= fee, "not sent enough ether");
        participantWallets.push(msg.sender);
        participants[msg.sender].isExist = true;
        contractBalance += msg.value;
    }
     
    function setCarDealer(address _dealer) public onlyManager{
        carDealer = _dealer;
    }
    
    function carProposeToBusiness(bytes32 _carId, uint _price, uint _validTime) public onlyCarDealer{
        Car memory mCar = Car({
            carId: _carId,
            lastMaintenanceTime: 0
        });
        purchaseProposal = CarPurchaseProposal({
            car: mCar,
            price: _price,
            validTime: _validTime,
            approval: 0
        });
        //initialize all participants as not approved
        for(uint8 i=0; i<participantWallets.length; i++){
            purchaseProposal.isApproved[participantWallets[i]] = false;
        }
    }
    
    function approvePurchaseCar() public onlyParticipants validPurchaseTime{
        require(!purchaseProposal.isApproved[msg.sender], "each participant can approve once");
        purchaseProposal.isApproved[msg.sender] = true;
        purchaseProposal.approval++;
    }
    
    function purchaseCar() public onlyManager validPurchaseTime{
        require(purchaseProposal.approval > participantWallets.length/2, "not enough approvals");
        require(contractBalance >= purchaseProposal.price, "not enough ether in contract");
        require(taxi.carId == 0,"contract already has a taxi, sell it before purchasing another");
        if(carDealer.send(purchaseProposal.price)){
            taxi = purchaseProposal.car;
            contractBalance -= purchaseProposal.price;
            delete purchaseProposal;
        }
    }
    
    function repurchaseCarPropose(bytes32  _carId, uint _price, uint _validTime) public onlyCarDealer{
        require(taxi.carId != 0, "there is no taxi to repurchase");
        require(taxi.carId == _carId, "current taxi is not matched with given car id");
        repurchaseProposal = CarPurchaseProposal({
            car: taxi,
            price: _price,
            validTime: _validTime,
            approval: 0
        });
        //initialize all participants as not approved
        for(uint8 i=0; i<participantWallets.length; i++){
            repurchaseProposal.isApproved[participantWallets[i]] = false;
        }
    }
    
    function approveSellProposal() public onlyParticipants validRepurchaseTime{
        require(repurchaseProposal.isApproved[msg.sender] == false,"each participant can approve once");
        repurchaseProposal.isApproved[msg.sender] = true;
        repurchaseProposal.approval++;
    }
    
    function repurchaseCar() public payable onlyCarDealer validRepurchaseTime{
        require(repurchaseProposal.approval > participantWallets.length/2, "not enough approvals");
        require(msg.value >= repurchaseProposal.price, "payment is not enough");
        contractBalance+=msg.value;
        delete taxi;
        delete repurchaseProposal;
    }
    
    function proposeDriver(address _addr, uint _salary) public onlyManager{
        Driver memory mDriver = Driver({
            addr: _addr,
            salary: _salary,
            balance: 0,
            lastPayDay: 0
        });
        driverProposal = DriverProposal({
            driver: mDriver,
            approval: 0
        });
        //initialize all participants as not approved
        for(uint8 i=0; i<participantWallets.length; i++){
            driverProposal.isApproved[participantWallets[i]] = false;
        }
    }
    
    function approveDriver() public onlyParticipants{
        require(driverProposal.isApproved[msg.sender] == false,"each participant can approve once");
        driverProposal.isApproved[msg.sender] = true;
        driverProposal.approval++;
    }
    
    function setDriver() public onlyManager{
        require(driverProposal.approval > participantWallets.length/2, "not enough approvals");
        require(driver.addr == 0, "there is already a driver exists, fire first");
        driver = driverProposal.driver;
    }
    
    function fireDriver() public onlyManager{
        if(driver.addr.send(driver.salary))
            driver = Driver(0,0,0,0);
    }
    
    function getCharge() public payable{
        contractBalance += msg.value;
    }
    
    function releaseSalary() public onlyManager{
        require(driver.addr != 0,"there is no driver to pay salary");
        require(now - 30 days > driver.lastPayDay, "Not 30 days past until last salary release");
        require(contractBalance >= driver.salary,"contract don't have enough money to pay driver salary");
        driver.balance += driver.salary;
        driver.lastPayDay = now;
        contractBalance -= driver.salary;
    }
    
    function getSalary() public onlyDriver{
        require(driver.balance > 0, "zero balance");
        uint amount = driver.balance;
        driver.balance = 0;
        if(!msg.sender.send(amount)){
            driver.balance = amount;
        }
    }
    
    function carExpenses() public onlyManager{
        require(taxi.carId != 0, "there is no taxi to maintenance");
        require(now - expenseInterval > taxi.lastMaintenanceTime, "Not 6 months past until last maintenance");
        require(contractBalance >= carExpense,"contract don't have enough money to pay car expenses");
        uint maintenanceDate = taxi.lastMaintenanceTime;
        taxi.lastMaintenanceTime = now;
        contractBalance -= carExpense;
        if(!carDealer.send(carExpense)){
            //if transfer is failed set old values back
            taxi.lastMaintenanceTime = maintenanceDate;
            contractBalance += carExpense;
        }
    }
    
    function payDividend() public onlyManager{
        require(now - paymentInterval > lastPayDay,"Not 6 months past until last payday");
        require(contractBalance > 0, "There is no profit to divide");
        lastPayDay = now;
        uint paymentPerParticipant = contractBalance / participantWallets.length;
        contractBalance = 0;
        for(uint i=0; i<participantWallets.length; i++){
            participants[participantWallets[i]].balance += paymentPerParticipant;
        }
    }
    
    function getDividend() public onlyParticipants{
        require(participants[msg.sender].balance > 0,"zero balance");
        uint amount = participants[msg.sender].balance;
        participants[msg.sender].balance = 0;
        if(!msg.sender.send(amount)){
            participants[msg.sender].balance = amount;
        }
    }
    
    function () public payable {
        contractBalance += msg.value;
    }
}
