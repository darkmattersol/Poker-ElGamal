import {
  Proof,
  packToSolidityProof,
  SolidityProof,
} from "@semaphore-protocol/proof";
import { BabyJub, ecX2Delta, prepareDecryptData } from "./utilities";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
const snarkjs = require("snarkjs");

export { packToSolidityProof, SolidityProof };

type Contract = any;

export declare type FullProof = {
  proof: Proof;
  publicSignals: string[];
};

// Generates proof for decryption circuit.
export async function generateDecryptProof(
  Y: bigint[],
  skP: bigint,
  pkP: bigint[],
  wasmFile: string,
  zkeyFile: string
): Promise<FullProof> {
  // eslint-disable-next-line keyword-spacing
  return <FullProof>(
    await snarkjs.groth16.fullProve({ Y, skP, pkP }, wasmFile, zkeyFile)
  );
}

// Generates proof for shuffle encrypt v2 circuit.
export async function generateShuffleEncryptV2Proof(
  pk: bigint[],
  A: bigint[],
  R: bigint[],
  UX0: bigint[],
  UX1: bigint[],
  UDelta0: bigint[],
  UDelta1: bigint[],
  s_u: bigint[],
  VX0: bigint[],
  VX1: bigint[],
  VDelta0: bigint[],
  VDelta1: bigint[],
  s_v: bigint[],
  wasmFile: string,
  zkeyFile: string
): Promise<FullProof> {
  // eslint-disable-next-line keyword-spacing
  return <FullProof>await snarkjs.groth16.fullProve(
    {
      pk,
      A,
      R,
      UX0,
      UX1,
      UDelta0,
      UDelta1,
      VX0,
      VX1,
      VDelta0,
      VDelta1,
      s_u,
      s_v,
    },
    wasmFile,
    zkeyFile
  );
}

// Queries an encrypted card from contract, deals card & generates ZK proof,
// and updates the card on contract.
export async function deal(
  babyjub: BabyJub,
  numCards: number,
  gameId: number,
  cardIdx: number,
  curPlayerIdx: number,
  sk: bigint,
  pk: bigint[],
  playerAddr: string,
  gameContract: SignerWithAddress,
  stateMachineContract: Contract,
  decryptWasmFile: string,
  decryptZkeyFile: string,
  isFirstDecryption: boolean
): Promise<bigint[]> {
  if (isFirstDecryption) {
    await dealCompressedCard(
      babyjub,
      numCards,
      gameId,
      cardIdx,
      sk,
      pk,
      stateMachineContract,
      decryptWasmFile,
      decryptZkeyFile
    );
    return [];
  } else {
    return await dealUncompressedCard(
      gameId,
      cardIdx,
      sk,
      pk,
      stateMachineContract,
      decryptWasmFile,
      decryptZkeyFile
    );
  }
}

// Queries compressed card from contract, generate zkp, and verify on contract.
export async function dealCompressedCard(
  babyjub: BabyJub,
  numCards: number,
  gameId: number,
  cardIdx: number,
  sk: bigint,
  pk: bigint[],
  stateMachineContract: Contract,
  decryptWasmFile: string,
  decryptZkeyFile: string
) {
  const deck = await stateMachineContract.queryDeck(gameId);
  const Y = prepareDecryptData(
    babyjub,
    deck.X0[cardIdx],
    deck.X1[cardIdx],
    deck.selector0._data,
    deck.selector1._data,
    Number(numCards),
    cardIdx
  );
  const decryptProof = await generateDecryptProof(
    Y,
    sk,
    pk,
    decryptWasmFile,
    decryptZkeyFile
  );
  const solidityProof: SolidityProof = packToSolidityProof(decryptProof.proof);
  const res = await (
    await stateMachineContract.playerDealCards(
      gameId,
      [solidityProof],
      [
        {
          X: decryptProof.publicSignals[0],
          Y: decryptProof.publicSignals[1],
        },
      ],
      [[ecX2Delta(babyjub, Y[0]), ecX2Delta(babyjub, Y[2])]]
    )
  ).wait();
}

// Queries uncompressed card from contract, generate zkp, and verify on contract.
export async function dealUncompressedCard(
  gameId: number,
  cardIdx: number,
  sk: bigint,
  pk: bigint[],
  stateMachineContract: Contract,
  decryptWasmFile: string,
  decryptZkeyFile: string
): Promise<bigint[]> {
  const deck = await stateMachineContract.queryDeck(gameId);
  const decryptProof = await generateDecryptProof(
    [
      deck.X0[cardIdx],
      deck.X1[cardIdx],
      deck.selector0._data,
      deck.selector1._data,
    ],
    sk,
    pk,
    decryptWasmFile,
    decryptZkeyFile
  );
  const solidityProof: SolidityProof = packToSolidityProof(decryptProof.proof);

  await stateMachineContract.playerDealCards(
    gameId,
    [solidityProof],
    [
      {
        X: decryptProof.publicSignals[0],
        Y: decryptProof.publicSignals[1],
      },
    ],
    [[0, 0]]
  );

  // publicSignals contain 8 values.
  // 1~2 is the card value, 3~6 is the Y, 7～8 is the personal public key.
  return [
    BigInt(decryptProof.publicSignals[0]),
    BigInt(decryptProof.publicSignals[1]),
  ];
}

export async function dealMultiCompressedCard(
  babyjub: BabyJub,
  numCards: number,
  gameId: number,
  cards: number[],
  sk: bigint,
  pk: bigint[],
  stateMachineContract: Contract,
  decryptWasmFile: string,
  decryptZkeyFile: string
) {
  const proofs = [];
  const decryptedDatas = [];
  const initDeltas = [];
  for (let i = 0; i < cards.length; i++) {
    const deck = await stateMachineContract.queryDeck(gameId);
    const Y = prepareDecryptData(
      babyjub,
      deck.X0[cards[i]],
      deck.X1[cards[i]],
      deck.selector0._data,
      deck.selector1._data,
      Number(numCards),
      cards[i]
    );
    const decryptProof = await generateDecryptProof(
      Y,
      sk,
      pk,
      decryptWasmFile,
      decryptZkeyFile
    );
    const solidityProof: SolidityProof = packToSolidityProof(
      decryptProof.proof
    );

    proofs[i] = solidityProof;
    decryptedDatas[i] = {
      X: decryptProof.publicSignals[0],
      Y: decryptProof.publicSignals[1],
    };
    initDeltas[i] = [ecX2Delta(babyjub, Y[0]), ecX2Delta(babyjub, Y[2])];
  }
  await (
    await stateMachineContract.playerDealCards(
      gameId,
      proofs,
      decryptedDatas,
      initDeltas
    )
  ).wait();
}
