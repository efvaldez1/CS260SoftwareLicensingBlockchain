
pragma solidity ^0.4.19;
  
contract owned {
  address owner;
  
  function owned()  public {
    owner = msg.sender;           //Set the owner as the DOST Account
                                 // To provide check and balance since only the owner can create, delete, activate and transfer
                                 // Software licenes, multisignature contracts can be used.
                                 // To provide a form of two-factor authentication of the owner account, multisignature accounts
                                 // can be used
                                // References
                                // https://medium.com/coinmonks/customizing-and-using-multisig-contracts-for-other-contract-executions-9698fbb6950f
                                // https://solidity.readthedocs.io/en/v0.5.6/solidity-in-depth.html
  }
  
  modifier onlyOwner {
    require(msg.sender == owner);
    _;
  }
  
  function transferOwnership(address newOwner) onlyOwner  public {
    owner = newOwner;
  }
}
  
contract LicenseToken is owned {
  enum LicenseType {WIN, MAC}
  enum LicenseState {ACTIVE, INACTIVE, EXPIRED}
  
  uint constant LICENSE_LIFE_TIME = 30 days;
  
  struct LicenseInfo {
    LicenseType licenseType;
    uint registeredOn;
    uint expiresOn;
    LicenseState state;
    string deviceId;
  }
  
  LicenseInfo[] tokens;
  
  mapping (uint256 => address) public tokenIndexToOwner;
  mapping (address => uint256) ownershipTokenCount;
  mapping (uint256 => address) public tokenIndexToApproved;
  
  event LicenseGiven(address account, uint256 tokenId);
  event Transfer(address from, address to, uint256 tokenId);
  event Approval(address owner, address approved, uint256 tokenId);
  
  function LicenseToken() public {
  }
  
  // ERC-721 functions
  function totalSupply() public view returns (uint256 total) {
    return tokens.length;
  }
  
  function balanceOf(address _account) public view returns (uint256 balance) {
     return ownershipTokenCount[_account];
  }
  
  function ownerOf(uint256 _tokenId) public view returns (address owner) {
    owner = tokenIndexToOwner[_tokenId];
    require(owner != address(0));
  
    return owner;
  }
  
  function transferFrom(address _from, address _to, uint256 _tokenId) onlyOwner public {
    require(_to != address(0));
    require(_to != address(this));
    require(_owns(_from, _tokenId));
  
    _transfer(_from, _to, _tokenId);
  }
  
  function approve(address _to, uint256 _tokenId) public {
    require(_owns(msg.sender, _tokenId));
    tokenIndexToApproved[_tokenId] = _to;
    Approval(tokenIndexToOwner[_tokenId], tokenIndexToApproved[_tokenId], _tokenId);
  }

  // licensing logic
  function giveLicense(address _account, uint _type) onlyOwner public {
    uint256 tokenId = _mint(_account, _type);
    LicenseGiven(_account, tokenId);
  }
  
  function activate(uint _tokenId, string _deviceId) onlyOwner public {
    LicenseInfo storage token = tokens[_tokenId];
    require(token.registeredOn != 0);
    require(token.state == LicenseState.INACTIVE);
  
    token.state = LicenseState.ACTIVE;
    token.expiresOn = now + LICENSE_LIFE_TIME;
    token.deviceId = _deviceId;
  }
  
  function burn(address _account, uint _tokenId) onlyOwner public {
    require(tokenIndexToOwner[_tokenId] == _account);
  
    ownershipTokenCount[_account]--;
    delete tokenIndexToOwner[_tokenId];
    delete tokens[_tokenId];
    delete tokenIndexToApproved[_tokenId];
  }
  
  function isLicenseActive(address _account, uint256 _tokenId) public returns (uint state){
    require(tokenIndexToOwner[_tokenId] == _account);
  
    LicenseInfo memory token = tokens[_tokenId];
    if (token.expiresOn < now && token.state == LicenseState.ACTIVE) {
       return uint(LicenseState.EXPIRED);
    }
  
    return uint(token.state);
  }
  
  function handleExpiredLicense(address _account, uint256 _tokenId) onlyOwner public {
    require(tokenIndexToOwner[_tokenId] == _account);
  
    LicenseInfo storage token = tokens[_tokenId];
    if (token.expiresOn < now && token.state == LicenseState.ACTIVE) {
       burn(_account, _tokenId);
    }
  }
  
  // internal methods
  function _owns(address _claimant, uint256 _tokenId) internal view returns (bool) {
    return tokenIndexToOwner[_tokenId] == _claimant;
  }
  
  function _mint(address _account, uint _type) onlyOwner internal returns (uint256 tokenId) {
    // create new token
    LicenseInfo memory token = LicenseInfo({
        licenseType: LicenseType(_type),
        state: LicenseState.INACTIVE,
        registeredOn: now,
        expiresOn: 0,
        deviceId: ""
    });
    uint id = tokens.push(token) - 1;
  
    _transfer(0, _account, id);
    return id;
  }
  
  function _transfer(address _from, address _to, uint256 _tokenId) internal {
   ownershipTokenCount[_to]++;
   tokenIndexToOwner[_tokenId] = _to;
  
   if (_from != address(0)) {
     ownershipTokenCount[_from]--;
     delete tokenIndexToApproved[_tokenId];
   }
   Transfer(_from, _to, _tokenId);
  }
}
