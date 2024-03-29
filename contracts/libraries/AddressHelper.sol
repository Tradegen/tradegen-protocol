// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

library AddressHelper {
  /**
   * @notice try a contract call via assembly.
   * @param to the contract address.
   * @param data the call data.
   * @return success if the contract call is successful or not.
   */
  function tryAssemblyCall(address to, bytes memory data) internal returns (bool success) {
    assembly {
      success := call(gas(), to, 0, add(data, 0x20), mload(data), 0, 0)
      switch iszero(success)
        case 1 {
          let size := returndatasize()
          returndatacopy(0x00, 0x00, size)
          revert(0x00, size)
        }
    }
  }

  /**
   * @notice try a contract delegatecall via assembly.
   * @param to the contract address.
   * @param data the call data.
   * @return success if the contract call is successful or not.
   */
  function tryAssemblyDelegateCall(address to, bytes memory data) internal returns (bool success) {
    assembly {
      success := delegatecall(gas(), to, add(data, 0x20), mload(data), 0, 0)
      switch iszero(success)
        case 1 {
          let size := returndatasize()
          returndatacopy(0x00, 0x00, size)
          revert(0x00, size)
        }
    }
  }
}