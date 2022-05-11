// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

//多签钱包
contract MultiSigWallet {
  //存款事件
  event Deposit(address indexed sender, uint amount);
  //提交交易申请
  event Submit(uint indexed txId);
  //授权批准
  event Approve(address indexed owner, uint indexed txId);
  //撤销批准
  event Revoke(address indexed owner, uint indexed txId);
  //执行
  event Execute(uint indexed txId);

  //1.创建一个数组，保存所有签名人
  address[] public owners;
  //数组中不要循环 浪费gas，所以做一个 地址到bool值的映射，判断是否是签名人。
  mapping(address => bool) public isOwner;
  //要有多少人需要确认,才可交易
  uint public required;

  //2.创建交易结构体
  struct Transaction {
    address to; //发送到地址
    uint value; //交易值
    bytes data; //如果发送到的地址 是合约 可以执行 此合约代码
    bool executed; //是否执行
  }

  //3.创建数组 储存提交的交易
  Transaction[] public transactions;
  //4.创建一个映射，交易index 对应 签名人的地址  看 签名人是否同意交易
  mapping(uint => mapping(address => bool)) public approved;

  //5.在构造函数中 初始化 签名人 和 确认数量
  constructor(address[] memory _owners, uint _required){
    require(_owners.length>0,"owners is required");
    require(_required>0&& _required<=_owners.length,"invalid require nmuber of owners");
    
    for (uint256 index = 0; index < _owners.length; index++) {
      address _owner = _owners[index];
      require(_owner != address(0),"invalid owner");
      require(!isOwner[_owner],"owner had");
      isOwner[_owner] = true;
      owners.push(_owner);
    }

    required = _required;
  }
  //6.receive 使合约可以接受主币
  receive() external payable {
    //触发事件 记录 存款地址 和 数量
    emit Deposit(msg.sender, msg.value);
  }
  //7.定义是否在签名人数组的修饰器
  modifier onlyOwner() {
    require(isOwner[msg.sender],"invalid is owner");
    _;
  }
  //8.提交交易申请
  function submit(address _to, uint _value, bytes calldata _data) external onlyOwner {
    transactions.push(Transaction({to:_to,value:_value,data:_data,executed:false}));
    //txId 是 transactions的index
    emit Submit(transactions.length - 1);
  }

  //9. 是否存在 txId 的修饰器
  modifier isTxId(uint _txId) {
    require(_txId<transactions.length,"invalid txId");
    _;
  }

  //10. txId 是否被授权
  modifier notApproved(uint _txId) {
    require(!approved[_txId][msg.sender],"had approved");
    _;
  }

  //11.看 txId 是否执行过
  modifier notExecuted(uint _txId) {
    require(!transactions[_txId].executed,"had executed");
    _;
  }

  //12.签名人确认授权
  function approve(uint _txId) external onlyOwner isTxId(_txId) notApproved(_txId) notExecuted(_txId) {
    approved[_txId][msg.sender] = true;
    emit Approve(msg.sender, _txId);
  }

  //13.获取交易的批准数量
  function _getApproveCount(uint _txId) private view returns (uint count){
    for (uint256 index = 0; index < owners.length; index++) {
      address owner = owners[index];
      if(approved[_txId][owner]){
        count++;
      }
    }
  }

  //14.执行方法
  function execute(uint _txId) external isTxId(_txId) notExecuted(_txId) {
    require(_getApproveCount(_txId) >= required,"ApproveCount < required");
    Transaction storage transaction = transactions[_txId];
    transaction.executed = true;
    (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
    require(success,"failed");
    emit Execute(_txId);
  }

  //15.撤销批准
  function revoke(uint _txId) external onlyOwner isTxId(_txId) notExecuted(_txId) {
    //撤销批准需要 已经授权批准
    require(approved[_txId][msg.sender],"not approved");
    approved[_txId][msg.sender] = false;
    emit Revoke(msg.sender,_txId);
  }
}
