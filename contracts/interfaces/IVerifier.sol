// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title IVerifier
 * @dev Interface for ZK-SNARK verifier contracts
 * @notice This interface is implemented by Groth16 verifier contracts
 *         generated from circom/snarkjs
 */
interface IVerifier {
    /**
     * @notice Verify a ZK-SNARK proof
     * @param proof The proof bytes containing [a], [b], [c] elements
     * @param pubSignals Array of public signals (inputs)
     * @return True if proof is valid, false otherwise
     */
    function verifyProof(
        bytes calldata proof,
        uint256[] calldata pubSignals
    ) external view returns (bool);
}
