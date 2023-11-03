// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@lukso/lsp-smart-contracts/contracts/LSP4DigitalAssetMetadata/LSP4Constants.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP17ContractExtension/LSP17Constants.sol";

bytes4 constant _INTERFACEID_CAPPED_LSP8 = 0x52058d8a;
bytes4 constant _INTERFACEID_IDENTIFIABLE_PHYTIGAL_ASSET = 0x7b03ca1d;

bytes10 constant _LSP8_TOKEN_METADATA_KEY_PREFIX = 0x1339e76a390b7b9ec901;

bytes32 constant _DATAKEY_TOKENID_TYPE = 0x715f248956de7ce65e94d9d836bfead479f7e70d69b718d47bfe7b00e05b4fe4;

bytes28 constant _MSG_HASH_PREFIX = 0x19457468657265756d205369676e6564204d6573736167653a0a3232;

bytes4 constant _ERC1271_MAGICVALUE = 0x1626ba7e;
bytes4 constant _ERC1271_FAILVALUE = 0xffffffff;

// bytes10(keccak256('SupportedStandards')) + bytes2(0) + bytes20(keccak256('LSP3Profile'))
bytes32 constant _LSP3_SUPPORTED_STANDARDS_KEY = 0xeafec4d89fa9619884b600005ef83ad9559033e6e941db7d7c495acdce616347;

// bytes4(keccak256('LSP3UniversalProfile'))
bytes constant _LSP3_SUPPORTED_STANDARDS_VALUE = hex"5ef83ad9";

bytes32 constant _PERMISSION_SIGN = 0x0000000000000000000000000000000000000000000000000000000000200000;