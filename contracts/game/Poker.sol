// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../PokerManager/ECC.sol";
import "../PokerManager/BitMaps.sol";
import "../PokerManager/Deck.sol";
import "../PokerManager/PlayerInfo.sol";
import "../verifier/shuffle_encrypt_verifier.sol";
import "../verifier/decrypt_verifier.sol";
import "hardhat/console.sol";

/**
 * @title Shuffle Manager
 * @dev manage all ZK Games
 */
contract Poker {
    // aggregated PK X coordinate
    uint256 aggregatePkX;
    // aggregated PK Y coordinate
    uint256 aggregatePkY;
    // player info
    mapping(uint256 => PlayerInfo) playerinfo;
    // the current deck of the game
    Deck deck;
    // all player count
    uint256 numPlayers;
    // nonce
    uint256 nonce;
    // encryptVerifier
    ShuffleEncryptVerifier encryptVerifier;
    // decryptVerifier
    DecryptVerifier decryptVerifier;
    // decryptRecord
    mapping(uint256 => BitMaps.BitMap256) decryptRecord;
    // current player count
    uint256 playerCount;
    // real card number
    mapping(uint256 => uint8) cardNumber;

    struct Card {
        uint256 X;
        uint256 Y;
    }

    function _shuffleEncPublicInput(Deck memory encDeck, Deck memory oldDeck, uint256 fronNonce, uint256 aggPkX, uint256 aggPkY) private pure returns (uint256[] memory) {
        uint256 _deckSize = 52;
        uint256[] memory input = new uint256[](7 + _deckSize * 4);
        input[0] = fronNonce;
        input[1] = aggPkX;
        input[2] = aggPkY;
        for (uint256 i = 0; i < _deckSize; i++) {
            input[i + 3] = oldDeck.X0[i];
            input[i + 3 + _deckSize] = oldDeck.X1[i];
            input[i + 3 + _deckSize * 2] = encDeck.X0[i];
            input[i + 3 + _deckSize * 3] = encDeck.X1[i];
        }
        input[3 + 4 * _deckSize] = oldDeck.selector0._data;
        input[4 + 4 * _deckSize] = oldDeck.selector1._data;
        input[5 + 4 * _deckSize] = encDeck.selector0._data;
        input[6 + 4 * _deckSize] = encDeck.selector1._data;
        return input;
    }
    function _setDeckUnsafe(Deck memory compDeck) private {
        deck.X0 = compDeck.X0;
        deck.X1 = compDeck.X1;
        deck.selector0 = compDeck.selector0;
        deck.selector1 = compDeck.selector1;
    }

    constructor (address _encryptVerifier, address _decryptVerifier) {
        encryptVerifier = ShuffleEncryptVerifier(_encryptVerifier);
        decryptVerifier = DecryptVerifier(_decryptVerifier);
    }

    function createGame(uint _numPlayers) external {
        // data blob: 52 X-coordinate of BabyJubJub
        uint256[52] memory INIT_X1 = [
            5299619240641551281634865583518297030282874472190772894086521144482721001553,
            10031262171927540148667355526369034398030886437092045105752248699557385197826,
            2763488322167937039616325905516046217694264098671987087929565332380420898366,
            12252886604826192316928789929706397349846234911198931249025449955069330867144,
            11480966271046430430613841218147196773252373073876138147006741179837832100836,
            10483991165196995731760716870725509190315033255344071753161464961897900552628,
            20092560661213339045022877747484245238324772779820628739268223482659246842641,
            7582035475627193640797276505418002166691739036475590846121162698650004832581,
            4705897243203718691035604313913899717760209962238015362153877735592901317263,
            153240920024090527149238595127650983736082984617707450012091413752625486998,
            21605515851820432880964235241069234202284600780825340516808373216881770219365,
            13745444942333935831105476262872495530232646590228527111681360848540626474828,
            2645068156583085050795409844793952496341966587935372213947442411891928926825,
            6271573312546148160329629673815240458676221818610765478794395550121752710497,
            5958787406588418500595239545974275039455545059833263445973445578199987122248,
            20535751008137662458650892643857854177364093782887716696778361156345824450120,
            13563836234767289570509776815239138700227815546336980653685219619269419222465,
            4275129684793209100908617629232873490659349646726316579174764020734442970715,
            3580683066894261344342868744595701371983032382764484483883828834921866692509,
            18524760469487540272086982072248352918977679699605098074565248706868593560314,
            2154427024935329939176171989152776024124432978019445096214692532430076957041,
            1816241298058861911502288220962217652587610581887494755882131860274208736174,
            3639172054127297921474498814936207970655189294143443965871382146718894049550,
            18153584759852955321993060909315686508515263790058719796143606868729795593935,
            5176949692172562547530994773011440485202239217591064534480919561343940681001,
            11782448596564923920273443067279224661023825032511758933679941945201390953176,
            15115414180166661582657433168409397583403678199440414913931998371087153331677,
            16103312053732777198770385592612569441925896554538398460782269366791789650450,
            15634573854256261552526691928934487981718036067957117047207941471691510256035,
            13522014300368527857124448028007017231620180728959917395934408529470498717410,
            8849597151384761754662432349647792181832839105149516511288109154560963346222,
            17637772869292411350162712206160621391799277598172371975548617963057997942415,
            17865442088336706777255824955874511043418354156735081989302076911109600783679,
            9625567289404330771610619170659567384620399410607101202415837683782273761636,
            19373814649267709158886884269995697909895888146244662021464982318704042596931,
            7390138716282455928406931122298680964008854655730225979945397780138931089133,
            15569307001644077118414951158570484655582938985123060674676216828593082531204,
            5574029269435346901610253460831153754705524733306961972891617297155450271275,
            19413618616187267723274700502268217266196958882113475472385469940329254284367,
            4150841881477820062321117353525461148695942145446006780376429869296310489891,
            13006218950937475527552755960714370451146844872354184015492231133933291271706,
            2756817265436308373152970980469407708639447434621224209076647801443201833641,
            20753332016692298037070725519498706856018536650957009186217190802393636394798,
            18677353525295848510782679969108302659301585542508993181681541803916576179951,
            14183023947711168902945925525637889799656706942453336661550553836881551350544,
            9918129980499720075312297335985446199040718987227835782934042132813716932162,
            13387158171306569181335774436711419178064369889548869994718755907103728849628,
            6746289764529063117757275978151137209280572017166985325039920625187571527186,
            17386594504742987867709199123940407114622143705013582123660965311449576087929,
            11393356614877405198783044711998043631351342484007264997044462092350229714918,
            16257260290674454725761605597495173678803471245971702030005143987297548407836,
            3673082978401597800140653084819666873666278094336864183112751111018951461681
        ];
        deck.X0 = new uint256[](52);
        deck.X1 = new uint256[](52);
        deck.Y0 = new uint256[](52);
        deck.Y1 = new uint256[](52);
        for (uint8 i = 0; i < 52; i++) {
            deck.X0[i] = 0;
            deck.X1[i] = INIT_X1[i];
            cardNumber[INIT_X1[i]] = i;
        }
        deck.selector0 = BitMaps.BitMap256(4503599627370495);
        deck.selector1 = BitMaps.BitMap256(4503599627370495);
        numPlayers = _numPlayers;
        playerCount = 0;
    }
    function playerRegister(uint256 _userId, string memory _playerName, uint pkx, uint pky) external {
        require(playerCount < numPlayers, "Game full");
        // player info        
        playerinfo[_userId].playerPKX = pkx;
        playerinfo[_userId].playerPKY = pky;
        playerinfo[_userId].playerName = _playerName;

        // update aggregated PK
        if (playerCount == 0) {
            aggregatePkX = pkx;
            aggregatePkY = pky;
        } else {
            (aggregatePkX, aggregatePkY) = CurveBabyJubJub.pointAdd(
                aggregatePkX,
                aggregatePkY,
                pkx,
                pky
            );
        }
        playerCount = playerCount + 1;
        // if this is the last player to join
        if (playerCount == numPlayers) {
            nonce = mulmod(
                aggregatePkX,
                aggregatePkY,
                CurveBabyJubJub.Q
            );
        }
    }
    function getPK(uint256 _userId) external view returns (uint, uint) {
        return (playerinfo[_userId].playerPKX, playerinfo[_userId].playerPKY);
    }
    function getDeck() external view returns (uint[] memory, uint[] memory, BitMaps.BitMap256 memory, BitMaps.BitMap256 memory) {
        return (deck.X0, deck.X1, deck.selector0, deck.selector1);
    }
    // 
    function shuffleEncryptProof(uint256[] memory proof, Deck memory compDeck) external {
        encryptVerifier.verifyProof(
            [proof[0], proof[1]],
            [[proof[2], proof[3]], [proof[4], proof[5]]],
            [proof[6], proof[7]],
            _shuffleEncPublicInput(
                compDeck,
                deck,
                nonce,
                aggregatePkX,
                aggregatePkY
            )
        );
        _setDeckUnsafe(compDeck);
    }
    //
    function playerDealCards(
        uint256 curPlayerIndex,
        uint256 cardsToDeal,
        uint[8][] memory proofs,
        Card[] memory _decryptedCards,
        uint256[2][] memory initDeltas
    ) external {
        BitMaps.BitMap256 memory cardsDeal;
        cardsDeal._data = cardsToDeal;    // ...0001
        uint256 counter = 0;
        for (uint256 cid = 0; cid < 52; cid++) {
            if (BitMaps.get(cardsDeal, cid)) {
                // update decrypted card
                _updateDecryptedCard(
                    curPlayerIndex,
                    cid,
                    proofs[counter],
                    _decryptedCards[counter],
                    initDeltas[counter]
                );
                counter++;
            }
            if (counter == (numPlayers - 1)) {
                break;
            }
        }
    }

    function _updateDecryptedCard (
        uint curPlayerIndex,
        uint256 cardIndex,
        uint[8] memory proof,
        Card memory decryptedCard,
        uint256[2] memory initDelta
    ) internal {
        // recover Y0 and Y1 from the current X0 and X1
        if (decryptRecord[cardIndex]._data == 0) {
            deck.Y0[cardIndex] = CurveBabyJubJub.recoverY(
                deck.X0[cardIndex],
                initDelta[0],
                BitMaps.get(deck.selector0, cardIndex)
            );
            deck.Y1[cardIndex] = CurveBabyJubJub.recoverY(
                deck.X1[cardIndex],
                initDelta[1],
                BitMaps.get(deck.selector1, cardIndex)
            );
        }

        uint256[] memory input = new uint256[](8);
        input[0] = decryptedCard.X;
        input[1] = decryptedCard.Y;
        input[2] = deck.X0[cardIndex];
        input[3] = deck.Y0[cardIndex];
        input[4] = deck.X1[cardIndex];
        input[5] = deck.Y1[cardIndex];
        input[6] = playerinfo[curPlayerIndex].playerPKX;
        input[7] = playerinfo[curPlayerIndex].playerPKY;
        decryptVerifier.verifyProof(
            [proof[0], proof[1]],
            [[proof[2], proof[3]], [proof[4], proof[5]]],
            [proof[6], proof[7]],
            input
        );
        // update X1 and Y1 in the deck
        deck.X1[cardIndex] = decryptedCard.X;
        deck.Y1[cardIndex] = decryptedCard.Y;
        BitMaps.set(decryptRecord[cardIndex], curPlayerIndex);
    }



    function queryAggregatePk() external view returns (uint, uint) {
        return (aggregatePkX, aggregatePkY);
    }

    function openCardNumber(uint256 encryptedNumber) external view returns (uint8) {
        return cardNumber[encryptedNumber];
    }















}
