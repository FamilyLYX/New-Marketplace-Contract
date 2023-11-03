// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {IPlaceholder} from './IPlaceholder.sol';
import './constants.sol';
contract Verifier{

    error InvalidFamilySignature();


    function _isValidSignature(
        address _owner,
        bytes32 dataHash,
        bytes memory signature
    ) internal view  returns (bytes4 magicValue) {

        // If owner is a contract
        if (_owner.code.length > 0) {
            (bool success, bytes memory result) = _owner.staticcall(
                abi.encodeWithSelector(
                    IERC1271.isValidSignature.selector,
                    dataHash,
                    signature
                )
            );

            bool isValid = (success &&
                result.length == 32 &&
                abi.decode(result, (bytes32)) == bytes32(_ERC1271_MAGICVALUE));

            return isValid ? _ERC1271_MAGICVALUE : _ERC1271_FAILVALUE;
        }
        // If owner is an EOA
        else {
            // if isValidSignature fail, the error is catched in returnedError
            (address recoveredAddress, ECDSA.RecoverError returnedError) = ECDSA
                .tryRecover(dataHash, signature);

            // if recovering throws an error, return the fail value
            if (returnedError != ECDSA.RecoverError.NoError)
                return _ERC1271_FAILVALUE;

            // if recovering is successful and the recovered address matches the owner's address,
            // return the ERC1271 magic value. Otherwise, return the ERC1271 fail value
            // matches the address of the owner, otherwise return fail value
            return
                recoveredAddress == _owner
                    ? _ERC1271_MAGICVALUE
                    : _ERC1271_FAILVALUE;
        }
    }
    
    function verify(address _placeholder, string memory uid, bytes memory signature ){
        address _owner= IPlaceholder(_placeholder).owner();
        bytes32 messageHash = keccak256(bytes.concat(_MSG_HASH_PREFIX, bytes(uid)));
        if (_isValidSignature(_owner, messageHash, signature) != _ERC1271_MAGICVALUE) {
            revert InvalidFamilySignature();
        }
    }
}