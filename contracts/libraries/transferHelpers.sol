// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeApprove(
        address token,
        address to,
        uint256 value,
        bytes memory operatorNotificationData
    ) internal {
        // bytes('authorizeOperator(address,bytes32,bytes)');
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(bytes4(keccak256(bytes('authorizeOperator(address,bytes32,bytes)'))), to, value, operatorNotificationData ));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::safeApprove: approve failed'
        );
    }

    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::safeTransfer: transfer failed'
        );
    }


    function safeTransferLSP7(
        address token,
        address from,
        address to,
        uint256 amount,
        bool allowNonLSP1Recipient,
        bytes memory data
    ) internal {
        // bytes('transfer(address,address,uint256,bool,bytes)')
        (bool success, bytes memory _data) = token.call(abi.encodeWithSelector(bytes4(keccak256(bytes('transfer(address,address,uint256,bool,bytes)'))),from, to, amount,allowNonLSP1Recipient,data));
        require(
            success && (_data.length == 0 || abi.decode(_data, (bool))),
            'TransferHelper::safeTransferLSP7: LSP7 transfer failed'
        );
    }


    function safeTransferLSP8(
        address token,
        address from,
        address to,
        bytes32 tokenId,
        bool allowNonLSP1Recipient,
        bytes memory data
    ) internal {
        // bytes('transfer(address,address,bytes32,bool,bytes)')
        (bool success, bytes memory _data) = token.call(abi.encodeWithSelector(bytes4(keccak256(bytes('transfer(address,address,bytes32,bool,bytes)'))),from, to, tokenId,allowNonLSP1Recipient,data));
        require(
            success && (_data.length == 0 || abi.decode(_data, (bool))),
            'TransferHelper::safeTransferLSP8: LSP8 transfer failed'
        );
    }
    

    function safeTransferLYX(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper::safeTransferLYX: LYX transfer failed');
    }
}