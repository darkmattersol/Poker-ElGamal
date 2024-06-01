// SPDX-License-Identifier: GPL-3.0
/*
    Copyright 2021 0KIMS association.

    This file is generated with [snarkJS](https://github.com/iden3/snarkjs).

    snarkJS is a free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    snarkJS is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
    or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
    License for more details.

    You should have received a copy of the GNU General Public License
    along with snarkJS. If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity >=0.7.0 <0.9.0;

contract DecryptVerifier {
    // Scalar field size
    uint256 constant r    = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    // Base field size
    uint256 constant q   = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    // Verification Key data
    uint256 constant alphax  = 20491192805390485299153009773594534940189261866228447918068658471970481763042;
    uint256 constant alphay  = 9383485363053290200918347156157836566562967994039712273449902621266178545958;
    uint256 constant betax1  = 4252822878758300859123897981450591353533073413197771768651442665752259397132;
    uint256 constant betax2  = 6375614351688725206403948262868962793625744043794305715222011528459656738731;
    uint256 constant betay1  = 21847035105528745403288232691147584728191162732299865338377159692350059136679;
    uint256 constant betay2  = 10505242626370262277552901082094356697409835680220590971873171140371331206856;
    uint256 constant gammax1 = 11559732032986387107991004021392285783925812861821192530917403151452391805634;
    uint256 constant gammax2 = 10857046999023057135944570762232829481370756359578518086990519993285655852781;
    uint256 constant gammay1 = 4082367875863433681332203403145435568316851327593401208105741076214120093531;
    uint256 constant gammay2 = 8495653923123431417604973247489272438418190587263600148770280649306958101930;
    uint256 constant deltax1 = 9180249829974074694978085615959890801351274467017831287821479986291487956845;
    uint256 constant deltax2 = 15684220856133108535771194976255110114343786557448147775170665632161257498597;
    uint256 constant deltay1 = 16216274475145874673072108717844742714735052718521129166374895618763122840315;
    uint256 constant deltay2 = 3954702491578418028420858069025296649418199435808674031286135360705097363877;

    
    uint256 constant IC0x = 21742983616761885656736058194689192089402494953363310534564091829172452322315;
    uint256 constant IC0y = 10107138878624973060629524316471152994587727978670853819852022878743952658884;
    
    uint256 constant IC1x = 2356548366774318003103049455044356486495758144197194473765992549719978810344;
    uint256 constant IC1y = 13546286166277014073764770164366780677965704088408541669841800835181757550850;
    
    uint256 constant IC2x = 5456793293951805067121464739286375784924662853009444910123017915423686835915;
    uint256 constant IC2y = 4426463345464623340615659349808368648455135482836115198295756144514530939352;
    
    uint256 constant IC3x = 323903022487748310232479468309611994509622749547872746217716497068874711543;
    uint256 constant IC3y = 11529782920345838131361276447797250085311872332212117432931512987856872865029;
    
    uint256 constant IC4x = 16283565673898007943741170350940968838711438169392587258005232990007161264500;
    uint256 constant IC4y = 2163694807920156780185675347104980173659455328410146493536072025684457278713;
    
    uint256 constant IC5x = 19963886387952581836166379492332064588659180537776614190066665384792259940255;
    uint256 constant IC5y = 20899092030569882064504638127429546686715881382186258353446523533988783103416;
    
    uint256 constant IC6x = 1430167710713028909933002857000264857937501621997129287631878012089278260683;
    uint256 constant IC6y = 15795751707547150072285223806366714530417488189946703571233906617339836550494;
    
    uint256 constant IC7x = 12211992193319135784972744773328008947270008810975001104556974277299942160396;
    uint256 constant IC7y = 1903526971972001306578192364428430037715004509704627956770705433504747438503;
    
    uint256 constant IC8x = 6374869296136993233257767615084074477763387894014921075092420528511305485707;
    uint256 constant IC8y = 7717697774220196010919614804510119171008733687988834881633757996473483683113;
    
 
    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[] calldata _pubSignals) public view returns (bool) {
        assembly {
            function checkField(v) {
                if iszero(lt(v, r)) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }
            
            // G1 function to multiply a G1 value(x,y) to value in an address
            function g1_mulAccC(pR, x, y, s) {
                let success
                let mIn := mload(0x40)
                mstore(mIn, x)
                mstore(add(mIn, 32), y)
                mstore(add(mIn, 64), s)

                success := staticcall(sub(gas(), 2000), 7, mIn, 96, mIn, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }

                mstore(add(mIn, 64), mload(pR))
                mstore(add(mIn, 96), mload(add(pR, 32)))

                success := staticcall(sub(gas(), 2000), 6, mIn, 128, pR, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }

            function checkPairing(pA, pB, pC, pubSignals, pMem) -> isOk {
                let _pPairing := add(pMem, pPairing)
                let _pVk := add(pMem, pVk)

                mstore(_pVk, IC0x)
                mstore(add(_pVk, 32), IC0y)

                // Compute the linear combination vk_x
                
                g1_mulAccC(_pVk, IC1x, IC1y, calldataload(add(pubSignals, 0)))
                
                g1_mulAccC(_pVk, IC2x, IC2y, calldataload(add(pubSignals, 32)))
                
                g1_mulAccC(_pVk, IC3x, IC3y, calldataload(add(pubSignals, 64)))
                
                g1_mulAccC(_pVk, IC4x, IC4y, calldataload(add(pubSignals, 96)))
                
                g1_mulAccC(_pVk, IC5x, IC5y, calldataload(add(pubSignals, 128)))
                
                g1_mulAccC(_pVk, IC6x, IC6y, calldataload(add(pubSignals, 160)))
                
                g1_mulAccC(_pVk, IC7x, IC7y, calldataload(add(pubSignals, 192)))
                
                g1_mulAccC(_pVk, IC8x, IC8y, calldataload(add(pubSignals, 224)))
                

                // -A
                mstore(_pPairing, calldataload(pA))
                mstore(add(_pPairing, 32), mod(sub(q, calldataload(add(pA, 32))), q))

                // B
                mstore(add(_pPairing, 64), calldataload(pB))
                mstore(add(_pPairing, 96), calldataload(add(pB, 32)))
                mstore(add(_pPairing, 128), calldataload(add(pB, 64)))
                mstore(add(_pPairing, 160), calldataload(add(pB, 96)))

                // alpha1
                mstore(add(_pPairing, 192), alphax)
                mstore(add(_pPairing, 224), alphay)

                // beta2
                mstore(add(_pPairing, 256), betax1)
                mstore(add(_pPairing, 288), betax2)
                mstore(add(_pPairing, 320), betay1)
                mstore(add(_pPairing, 352), betay2)

                // vk_x
                mstore(add(_pPairing, 384), mload(add(pMem, pVk)))
                mstore(add(_pPairing, 416), mload(add(pMem, add(pVk, 32))))


                // gamma2
                mstore(add(_pPairing, 448), gammax1)
                mstore(add(_pPairing, 480), gammax2)
                mstore(add(_pPairing, 512), gammay1)
                mstore(add(_pPairing, 544), gammay2)

                // C
                mstore(add(_pPairing, 576), calldataload(pC))
                mstore(add(_pPairing, 608), calldataload(add(pC, 32)))

                // delta2
                mstore(add(_pPairing, 640), deltax1)
                mstore(add(_pPairing, 672), deltax2)
                mstore(add(_pPairing, 704), deltay1)
                mstore(add(_pPairing, 736), deltay2)


                let success := staticcall(sub(gas(), 2000), 8, _pPairing, 768, _pPairing, 0x20)

                isOk := and(success, mload(_pPairing))
            }

            let pMem := mload(0x40)
            mstore(0x40, add(pMem, pLastMem))

            // Validate that all evaluations ∈ F
            
            checkField(calldataload(add(_pubSignals.offset, 0)))
            
            checkField(calldataload(add(_pubSignals.offset, 32)))
            
            checkField(calldataload(add(_pubSignals.offset, 64)))
            
            checkField(calldataload(add(_pubSignals.offset, 96)))
            
            checkField(calldataload(add(_pubSignals.offset, 128)))
            
            checkField(calldataload(add(_pubSignals.offset, 160)))
            
            checkField(calldataload(add(_pubSignals.offset, 192)))
            
            checkField(calldataload(add(_pubSignals.offset, 224)))
            
            checkField(calldataload(add(_pubSignals.offset, 256)))
            

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals.offset, pMem)

            mstore(0, isValid)
             return(0, 0x20)
         }
     }
 }
