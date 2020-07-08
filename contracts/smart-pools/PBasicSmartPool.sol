pragma solidity 0.6.4;

import "../interfaces/IBPool.sol";
import "../interfaces/IPSmartPool.sol";
import "../PCToken.sol";

import "../ReentryProtection.sol";

import {PBasicSmartPoolStorage as PBStorage} from "../storage/PBasicSmartPoolStorage.sol";
import {PCTokenStorage as PCStorage} from "../storage/PCTokenStorage.sol";

import "../libraries/LibJoinPool.sol";
import "../libraries/LibExitPool.sol";
import "../libraries/LibPoolToken.sol";


contract PBasicSmartPool is IPSmartPool, PCToken, ReentryProtection {
  event TokensApproved();
  event ControllerChanged(address indexed previousController, address indexed newController);
  event PublicSwapSetterChanged(address indexed previousSetter, address indexed newSetter);
  event TokenBinderChanged(address indexed previousTokenBinder, address indexed newTokenBinder);
  event PublicSwapSet(address indexed setter, bool indexed value);
  event SwapFeeSet(address indexed setter, uint256 newFee);

  modifier ready() {
    require(address(PBStorage.load().bPool) != address(0), "PBasicSmartPool.ready: not ready");
    _;
  }

  modifier onlyController() {
    require(
      msg.sender == PBStorage.load().controller,
      "PBasicSmartPool.onlyController: not controller"
    );
    _;
  }

  modifier onlyPublicSwapSetter() {
    require(
      msg.sender == PBStorage.load().publicSwapSetter,
      "PBasicSmartPool.onlyPublicSwapSetter: not public swap setter"
    );
    _;
  }

  modifier onlyTokenBinder() {
    require(
      msg.sender == PBStorage.load().tokenBinder,
      "PBasicSmartPool.onlyTokenBinder: not token binder"
    );
    _;
  }

  /**
        @notice Initialises the contract
        @param _bPool Address of the underlying balancer pool
        @param _name Name for the smart pool token
        @param _symbol Symbol for the smart pool token
        @param _initialSupply Initial token supply to mint
    */
  function init(
    address _bPool,
    string calldata _name,
    string calldata _symbol,
    uint256 _initialSupply
  ) external override {
    PBStorage.StorageStruct storage s = PBStorage.load();
    require(address(s.bPool) == address(0), "PBasicSmartPool.init: already initialised");
    require(_bPool != address(0), "PBasicSmartPool.init: _bPool cannot be 0x00....000");
    require(_initialSupply != 0, "PBasicSmartPool.init: _initialSupply can not zero");
    s.bPool = IBPool(_bPool);
    s.controller = msg.sender;
    s.publicSwapSetter = msg.sender;
    s.tokenBinder = msg.sender;
    PCStorage.load().name = _name;
    PCStorage.load().symbol = _symbol;

    LibPoolToken._mint(msg.sender, _initialSupply);
  }

  /**
        @notice Sets approval to all tokens to the underlying balancer pool
        @dev It uses this function to save on gas in joinPool
    */
  function approveTokens() public override noReentry {
    IBPool bPool = PBStorage.load().bPool;
    address[] memory tokens = bPool.getCurrentTokens();
    for (uint256 i = 0; i < tokens.length; i++) {
      IERC20(tokens[i]).approve(address(bPool), uint256(-1));
    }
    emit TokensApproved();
  }

  /**
        @notice Sets the controller address. Can only be set by the current controller
        @param _controller Address of the new controller
    */
  function setController(address _controller) external override onlyController noReentry {
    emit ControllerChanged(PBStorage.load().controller, _controller);
    PBStorage.load().controller = _controller;
  }

  /**
        @notice Sets public swap setter address. Can only be set by the controller
        @param _newPublicSwapSetter Address of the new public swap setter
    */
  function setPublicSwapSetter(address _newPublicSwapSetter)
    external
    override
    onlyController
    noReentry
  {
    emit PublicSwapSetterChanged(PBStorage.load().publicSwapSetter, _newPublicSwapSetter);
    PBStorage.load().publicSwapSetter = _newPublicSwapSetter;
  }

  /**
        @notice Sets the token binder address. Can only be set by the controller
        @param _newTokenBinder Address of the new token binder
    */
  function setTokenBinder(address _newTokenBinder) external override onlyController noReentry {
    emit TokenBinderChanged(PBStorage.load().tokenBinder, _newTokenBinder);
    PBStorage.load().tokenBinder = _newTokenBinder;
  }

  /**
        @notice Enables or disables public swapping on the underlying balancer pool.
                Can only be set by the controller.
        @param _public Public or not
    */
  function setPublicSwap(bool _public) external onlyPublicSwapSetter noReentry {
    emit PublicSwapSet(msg.sender, _public);
    PBStorage.load().bPool.setPublicSwap(_public);
  }

  /**
        @notice Set the swap fee on the underlying balancer pool.
                Can only be called by the controller.
        @param _swapFee The new swap fee
    */
  function setSwapFee(uint256 _swapFee) external onlyController noReentry {
    emit SwapFeeSet(msg.sender, _swapFee);
    PBStorage.load().bPool.setSwapFee(_swapFee);
  }

  /**
        @notice Mints pool shares in exchange for underlying assets.
        @param _amount Amount of pool shares to mint
    */

  function joinPool(uint256 _amount) external virtual override ready noReentry {
    LibJoinPool.joinPool(_amount);
  }

  /**
        @notice Burns pool shares and sends back the underlying assets
        @param _amount Amount of pool tokens to burn
    */
  function exitPool(uint256 _amount) external override ready noReentry {
    LibExitPool.exitPool(_amount);
  }

  /**
        @notice Joinswap single asset pool entry given token amount in
        @param _token Address of entry token
        @param _amountIn Amount of entry tokens
        @return poolAmountOut
    */
  function joinswapExternAmountIn(address _token, uint256 _amountIn)
    external
    virtual
    ready
    noReentry
    returns (uint256 poolAmountOut)
  {
    return LibJoinPool.joinswapExternAmountIn(_token, _amountIn);
  }

  /**
        @notice Joinswap single asset pool entry given pool amount out
        @param _token Address of entry token
        @param _amountOut Amount of entry tokens to deposit into the pool
        @return tokenAmountIn
    */
  function joinswapPoolAmountOut(address _token, uint256 _amountOut)
    external
    virtual
    ready
    noReentry
    returns (uint256 tokenAmountIn)
  {
    return LibJoinPool.joinswapPoolAmountOut(_token, _amountOut);
  }

  /**
        @notice Exitswap single asset pool exit given pool amount in
        @param _token Address of exit token
        @param _poolAmountIn Amount of pool tokens sending to the pool
        @return tokenAmountOut amount of exit tokens being withdrawn
    */
  function exitswapPoolAmountIn(address _token, uint256 _poolAmountIn)
    external
    ready
    noReentry
    returns (uint256 tokenAmountOut)
  {
    return LibExitPool.exitswapPoolAmountIn(_token, _poolAmountIn);
  }

  /**
        @notice Exitswap single asset pool entry given token amount out
        @param _token Address of exit token
        @param _tokenAmountOut Amount of exit tokens
        @return poolAmountIn amount of pool tokens being deposited
    */
  function exitswapExternAmountOut(address _token, uint256 _tokenAmountOut)
    external
    ready
    noReentry
    returns (uint256 poolAmountIn)
  {
    return LibExitPool.exitswapExternAmountOut(_token, _tokenAmountOut);
  }

  /**
        @notice Burns pool shares and sends back the underlying assets leaving some in the pool
        @param _amount Amount of pool tokens to burn
        @param _lossTokens Tokens skipped on redemption
    */
  function exitPoolTakingloss(uint256 _amount, address[] calldata _lossTokens)
    external
    ready
    noReentry
  {
    LibExitPool.exitPoolTakingloss(_amount, _lossTokens);
  }

  /**
        @notice Bind a token to the underlying balancer pool. Can only be called by the token binder
        @param _token Token to bind
        @param _balance Amount to bind
        @param _denorm Denormalised weight
    */
  function bind(
    address _token,
    uint256 _balance,
    uint256 _denorm
  ) external onlyTokenBinder noReentry {
    IBPool bPool = PBStorage.load().bPool;
    IERC20 token = IERC20(_token);
    require(
      token.transferFrom(msg.sender, address(this), _balance),
      "PBasicSmartPool.bind: transferFrom failed"
    );
    token.approve(address(bPool), uint256(-1));
    bPool.bind(_token, _balance, _denorm);
  }

  /**
        @notice Rebind a token to the pool
        @param _token Token to bind
        @param _balance Amount to bind
        @param _denorm Denormalised weight
    */
  function rebind(
    address _token,
    uint256 _balance,
    uint256 _denorm
  ) external onlyTokenBinder noReentry {
    IBPool bPool = PBStorage.load().bPool;
    IERC20 token = IERC20(_token);

    // gulp old non acounted for token balance in the contract
    bPool.gulp(_token);

    uint256 oldBalance = token.balanceOf(address(bPool));
    // If tokens need to be pulled from msg.sender
    if (_balance > oldBalance) {
      require(
        token.transferFrom(msg.sender, address(this), _balance.bsub(oldBalance)),
        "PBasicSmartPool.rebind: transferFrom failed"
      );
      token.approve(address(bPool), uint256(-1));
    }

    bPool.rebind(_token, _balance, _denorm);

    // If any tokens are in this contract send them to msg.sender
    uint256 tokenBalance = token.balanceOf(address(this));
    if (tokenBalance > 0) {
      require(token.transfer(msg.sender, tokenBalance), "PBasicSmartPool.rebind: transfer failed");
    }
  }

  /**
        @notice Unbind a token
        @param _token Token to unbind
    */
  function unbind(address _token) external onlyTokenBinder noReentry {
    IBPool bPool = PBStorage.load().bPool;
    IERC20 token = IERC20(_token);
    // unbind the token in the bPool
    bPool.unbind(_token);

    // If any tokens are in this contract send them to msg.sender
    uint256 tokenBalance = token.balanceOf(address(this));
    if (tokenBalance > 0) {
      require(token.transfer(msg.sender, tokenBalance), "PBasicSmartPool.unbind: transfer failed");
    }
  }

  function getTokens() external override view returns (address[] memory) {
    return PBStorage.load().bPool.getCurrentTokens();
  }

  /**
        @notice Gets the underlying assets and amounts to mint specific pool shares.
        @param _amount Amount of pool shares to calculate the values for
        @return tokens The addresses of the tokens
        @return amounts The amounts of tokens needed to mint that amount of pool shares
    */
  function calcTokensForAmount(uint256 _amount)
    external
    override
    view
    returns (address[] memory tokens, uint256[] memory amounts)
  {
    tokens = PBStorage.load().bPool.getCurrentTokens();
    amounts = new uint256[](tokens.length);
    uint256 ratio = _amount.bdiv(totalSupply());

    for (uint256 i = 0; i < tokens.length; i++) {
      address t = tokens[i];
      uint256 bal = PBStorage.load().bPool.getBalance(t);
      uint256 amount = ratio.bmul(bal);
      amounts[i] = amount;
    }
  }

  /**
        @notice Get the address of the controller
        @return The address of the pool
    */
  function getController() external override view returns (address) {
    return PBStorage.load().controller;
  }

  /**
        @notice Get the address of the public swap setter
        @return The public swap setter address
    */
  function getPublicSwapSetter() external view returns (address) {
    return PBStorage.load().publicSwapSetter;
  }

  /**
        @notice Get the address of the token binder
        @return The token binder address
    */
  function getTokenBinder() external view returns (address) {
    return PBStorage.load().tokenBinder;
  }

  /**
        @notice Get if public swapping is enabled
        @return If public swapping is enabled
    */
  function isPublicSwap() external view returns (bool) {
    return PBStorage.load().bPool.isPublicSwap();
  }

  /**
        @notice Not Supported in PieDAO implementation of Balancer Smart Pools
    */
  function finalizeSmartPool() external view {
    revert("PBasicSmartPool.finalizeSmartPool: unsupported function");
  }

  /**
        @notice Not Supported in PieDAO implementation of Balancer Smart Pools
    */
  function createPool(uint256 initialSupply) external view {
    revert("PBasicSmartPool.createPool: unsupported function");
  }

  /**
        @notice Get the current swap fee
        @return The current swap fee
    */
  function getSwapFee() external view returns (uint256) {
    return PBStorage.load().bPool.getSwapFee();
  }

  /**
        @notice Get the address of the underlying Balancer pool
        @return The address of the underlying balancer pool
    */
  function getBPool() external view returns (address) {
    return address(PBStorage.load().bPool);
  }

  /**
        @notice Get the denormalized weight of a specific token in the underlying balancer pool
        @return the normalized weight of the token in uint
  */
  function getDenormalizedWeight(address _token) external view returns (uint256) {
    return PBStorage.load().bPool.getDenormalizedWeight(_token);
  }

  function getDenormalizedWeights() external view returns (uint256[] memory weights) {
    PBStorage.StorageStruct storage s = PBStorage.load();
    address[] memory tokens = s.bPool.getCurrentTokens();
    weights = new uint256[](tokens.length);
    for (uint256 i = 0; i < tokens.length; i++) {
      weights[i] = s.bPool.getDenormalizedWeight(tokens[i]);
    }
  }
}
