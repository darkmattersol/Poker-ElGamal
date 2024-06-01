const {
  prepareShuffleDeck,
  ecX2Delta,
  samplePermutation,
  prepareDecryptData,
  sampleFieldElements,
} = require("./utilities.ts");
const { shuffleEncryptV2Plaintext } = require("./plaintext.ts");
const {
  generateShuffleEncryptV2Proof,
  generateDecryptProof,
  packToSolidityProof,
} = require("./proof.ts");

import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { ethers } from "hardhat";

const buildBabyjub: any = require("circomlibjs").buildBabyjub;
const Scalar: any = require("ffjavascript").Scalar;

describe("Poker Round", function () {
  this.timeout(6000000);

  // deploy contract
  async function deployContractFixture() {
    const encryptVerifierContract = await ethers.getContractFactory(
      "ShuffleEncryptVerifier"
    );
    const encryptVerifier = await encryptVerifierContract.deploy();

    const decryptVerifierContract = await ethers.getContractFactory(
      "DecryptVerifier"
    );
    const decryptVerifier = await decryptVerifierContract.deploy();

    const Poker = await ethers.getContractFactory("Poker");
    const poker = await Poker.deploy(
      await encryptVerifier.getAddress(),
      await decryptVerifier.getAddress()
    );
    return { poker };
  }
  // player register
  async function playerRegister(
    userId: number,
    playerName: string,
    poker: any,
    babyjub: any
  ) {
    const threshold: any = Scalar.exp(2, 251);
    let secret: BigInt;
    do {
      secret = Scalar.fromRprLE(babyjub.F.random());
    } while (Scalar.geq(secret, threshold));

    let pk: Array<BigInt> = babyjub.mulPointEscalar(babyjub.Base8, secret);

    pk = [babyjub.F.toString(pk[0]), babyjub.F.toString(pk[1])];

    await poker.playerRegister(userId, playerName, pk[0], pk[1]);

    return { sk: secret, pk };
  }
  // shuffle encrypt
  async function shuffleEncrypt(babyjub: any, poker: any) {
    let deck: any = await poker.getDeck();

    let key: Array<number> = await poker.queryAggregatePk();
    let aggrPK: Array<BigInt> = [BigInt(key[0]), BigInt(key[1])];
    let aggrPKEC: Array<BigInt> = [
      babyjub.F.e(aggrPK[0]),
      babyjub.F.e(aggrPK[1]),
    ];

    let preprocessedDeck: {
      X0: any;
      X1: any;
      Selector: Array<BigInt>;
      Delta: Array<BigInt>;
    } = prepareShuffleDeck(babyjub, deck, 52);

    let A: BigInt = samplePermutation(Number(52));
    let R: Array<BigInt> = sampleFieldElements(
      babyjub,
      BigInt(251),
      BigInt(52)
    );

    let plaintext_output: {
      X0: Array<BigInt>;
      X1: Array<BigInt>;
      delta0: Array<BigInt>;
      delta1: Array<BigInt>;
      selector: Array<BigInt>;
    } = shuffleEncryptV2Plaintext(
      babyjub,
      52,
      A,
      R,
      aggrPKEC,
      preprocessedDeck.X0,
      preprocessedDeck.X1,
      preprocessedDeck.Delta[0],
      preprocessedDeck.Delta[1],
      preprocessedDeck.Selector
    );
    let full_proof: any = await generateShuffleEncryptV2Proof(
      aggrPK,
      A,
      R,
      preprocessedDeck.X0,
      preprocessedDeck.X1,
      preprocessedDeck.Delta[0],
      preprocessedDeck.Delta[1],
      preprocessedDeck.Selector,
      plaintext_output.X0,
      plaintext_output.X1,
      plaintext_output.delta0,
      plaintext_output.delta1,
      plaintext_output.selector,
      "./resource/shuffle_encrypt.wasm",
      "./resource/shuffle_encrypt.zkey"
    );
    let solidityProof: any = packToSolidityProof(full_proof.proof);
    await poker.shuffleEncryptProof(solidityProof, {
      config: 52,
      X0: full_proof.publicSignals.slice(3 + 52 * 2, 3 + 52 * 3),
      X1: full_proof.publicSignals.slice(3 + 52 * 3, 3 + 52 * 4),
      Y0: [],
      Y1: [],
      selector0: { _data: full_proof.publicSignals[5 + 52 * 4] },
      selector1: { _data: full_proof.publicSignals[6 + 52 * 4] },
    });
  }
  // deal card
  async function dealCard(
    playerIndex: number,
    player: { sk: BigInt; pk: Array<BigInt> },
    cardsToDeal: number,
    babyjub: any,
    poker: any
  ) {
    let cards: Array<number> = getSetBitsPositions(cardsToDeal);
    let proofs: Array<any> = [];
    let decryptedDatas: Array<{ X: BigInt; Y: BigInt }> = [];
    let initDeltas: Array<Array<any>> = [];
    for (let i = 0; i < 52; i++) {
      if (cards[i] == undefined) break;

      let deck: any = await poker.getDeck();
      let Y: Array<BigInt> = prepareDecryptData(
        babyjub,
        deck[0][cards[i]],
        deck[1][cards[i]],
        deck[2],
        deck[3],
        Number(52),
        cards[i]
      );
      let decryptProof: any = await generateDecryptProof(
        Y,
        player.sk,
        player.pk,
        "./resource/decrypt.wasm",
        "./resource/decrypt.zkey"
      );
      let solidityProof: any = packToSolidityProof(decryptProof.proof);

      proofs[i] = solidityProof;
      decryptedDatas[i] = {
        X: decryptProof.publicSignals[0],
        Y: decryptProof.publicSignals[1],
      };
      initDeltas[i] = [ecX2Delta(babyjub, Y[0]), ecX2Delta(babyjub, Y[2])];
    }
    await poker.playerDealCards(
      playerIndex,
      cardsToDeal,
      proofs,
      decryptedDatas,
      initDeltas
    );
  }
  // open card
  async function openCard(
    player: { sk: BigInt; pk: Array<BigInt> },
    cardIndex: number,
    babyjub: any,
    poker: any
  ) {

    let deck = await poker.getDeck();
    let Y = prepareDecryptData(
      babyjub,
      deck[0][cardIndex],
      deck[1][cardIndex],
      deck[2],
      deck[3],
      Number(52),
      cardIndex
    );
    let decryptProof = await generateDecryptProof(
      Y,
      player.sk,
      player.pk,
      "./resource/decrypt.wasm",
      "./resource/decrypt.zkey"
    );


    return decryptProof.publicSignals[0];
  }
  // POKER ROUND
  it("create game, player register, shuffle encrypt, verifier, deal card, open card", async () => {
    const babyjub = await buildBabyjub();
    const { poker } = await loadFixture(deployContractFixture);

    const classicPlayingCard: { suite: Array<string>; value: Array<string> } = {
      suite: ["♣", "♦", "♥", "♠"],
      value: ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"],
    };

    // GAME START
    console.log("--------Poker game start--------");
    await poker.createGame(4);

    // PLAYER REGISTER
    let nDate = new Date();
    const player1: { sk: BigInt; pk: Array<BigInt> } = await playerRegister(1, "andrija", poker, babyjub);
    console.log("andrija registered successfully in " + (new Date().valueOf() - nDate.valueOf()) + "ms");

    nDate = new Date();
    const player2: { sk: BigInt; pk: Array<BigInt> } = await playerRegister(2, "Kobi", poker, babyjub);
    console.log("Kobi registered successfully in " + (new Date().valueOf() - nDate.valueOf()) + "ms");

    nDate = new Date();
    const player3: { sk: BigInt; pk: Array<BigInt> } = await playerRegister(3, "Nico", poker, babyjub);
    console.log("Nico registered successfully in " + (new Date().valueOf() - nDate.valueOf()) + "ms");

    nDate = new Date();
    const player4: { sk: BigInt; pk: Array<BigInt> } = await playerRegister(4,"Tom", poker, babyjub);
    console.log("Tom registered successfully in " + (new Date().valueOf() - nDate.valueOf()) + "ms" + "\n");

    // Each player should run this computation. Alternatively, it can be ran by a smart contract
    // SHUFFLE TIME --------------
    // 1.a Andrija shuffles first
    nDate = new Date();
    await shuffleEncrypt(babyjub, poker); // shuffle encrypt and verify. shuffle encrypt -> frontend. verify -> onchain
    console.log("Andrija shuffled successfully in " + (new Date().valueOf() - nDate.valueOf()) + "ms");

    //2.a Kobi shuffles second
    nDate = new Date();
    await shuffleEncrypt(babyjub, poker); // shuffle encrypt and verify. shuffle encrypt -> frontend. verify -> onchain
    console.log("Kobi shuffled successfully in " + (new Date().valueOf() - nDate.valueOf()) + "ms");

    //3.a Nico shuffles third
    nDate = new Date();
    await shuffleEncrypt(babyjub, poker); // shuffle encrypt and verify. shuffle encrypt -> frontend. verify -> onchain
    console.log("Nico shuffled successfully in " + (new Date().valueOf() - nDate.valueOf()) + "ms");

    //4.a Tom shuffles last
    nDate = new Date();
    await shuffleEncrypt(babyjub, poker); // shuffle encrypt and verify. shuffle encrypt -> frontend. verify -> onchain
    console.log("Tom shuffled successfully in " + (new Date().valueOf() - nDate.valueOf()) + "ms" + "\n");

    // CARDS ARE SHUFFLED. ROUND OF THE GAME CAN BEGIN
    nDate = new Date();
    await dealCard(1, player1, 14, babyjub, poker); // 1110
    console.log("Andrija dealed successfully in " + (new Date().valueOf() - nDate.valueOf()) + "ms");

    nDate = new Date();
    await dealCard(2, player2, 13, babyjub, poker); // 1101
    console.log("Kobi dealed successfully in " + (new Date().valueOf() - nDate.valueOf()) + "ms");
 
    nDate = new Date();
    await dealCard(3, player3, 11, babyjub, poker); // 1011
    console.log("Nico dealed successfully in " + (new Date().valueOf() - nDate.valueOf()) + "ms");
 
    nDate = new Date();
    await dealCard(4, player4, 7, babyjub, poker); // 0111
    console.log("Tom dealed successfully in " + (new Date().valueOf() - nDate.valueOf()) + "ms" + "\n");

    /* Here we can add custom logic of a game:
        1. swap card
        2. place a bet
        3. ...
    */

    //At this moment players reveal their cards to each other and everything becomes public
    nDate = new Date();
    let andrija_card = Number(await poker.openCardNumber(await openCard(player1, 0, babyjub, poker))); // first card
    console.log("andrija opend successfully in " + (new Date().valueOf() - nDate.valueOf()) + "ms");

    nDate = new Date();
    let kobi_card = Number(await poker.openCardNumber(await openCard(player2, 1, babyjub, poker))); // second card
    console.log("kobi opend successfully in " + (new Date().valueOf() - nDate.valueOf()) + "ms");

    nDate = new Date();
    let nico_card = Number(await poker.openCardNumber(await openCard(player3, 2, babyjub, poker))); // first card
    console.log("nico opend successfully in " + (new Date().valueOf() - nDate.valueOf()) + "ms");

    nDate = new Date();
    let tom_card = Number(await poker.openCardNumber(await openCard(player4, 3, babyjub, poker))); // first card
    console.log("tom opend successfully in " + (new Date().valueOf() - nDate.valueOf()) + "ms" + "\n");
    
    console.log(
      `Andrija: ${classicPlayingCard.suite[Math.floor(andrija_card / 13)]} ${
        classicPlayingCard.value[andrija_card % 13]}`
    );
    console.log(
      `Kobi: ${classicPlayingCard.suite[Math.floor(kobi_card / 13)]} ${
        classicPlayingCard.value[kobi_card % 13]}`
    );
    console.log(
      `Nico: ${classicPlayingCard.suite[Math.floor(nico_card / 13)]} ${
        classicPlayingCard.value[nico_card % 13]}`
    );
    console.log(
      `Tom: ${classicPlayingCard.suite[Math.floor(tom_card / 13)]} ${
        classicPlayingCard.value[tom_card % 13]}`
    );
  });

  function getSetBitsPositions(num: number): number[] {
    const binaryString = num.toString(2);
    const setBitsPositions: number[] = [];

    for (let i = binaryString.length - 1; i >= 0; i--) {
      if (binaryString[i] === "1") {
        setBitsPositions.push(binaryString.length - 1 - i);
      }
    }
    return setBitsPositions;
  }
});
