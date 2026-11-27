// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {RheilonRegistry} from "./RheilonRegistry.sol";
import {ISwapAdapter} from "./interfaces/ISwapAdapter.sol";
import {IValueOracle} from "./interfaces/IValueOracle.sol";

/// @dev The part of ERC-8056 (scaled UI amount) that Robinhood Stock Tokens implement and the account reads.
interface IERC8056 {
    function uiMultiplier() external view returns (uint256);
    function newUIMultiplier() external view returns (uint256);
    function effectiveAt() external view returns (uint256);
}

/// @title RheilonAccount
/// @notice One shared account per crew. Nobody outside the crew has any power over it.
///  - Members deposit the base asset (USDG) for non-transferable shares priced at the account's current value.
///  - Trades, new members, rule changes and registry moves are proposals each member signs with their own key.
///  - A passed proposal waits out a cool-off (skipped when unanimous) so anyone who disagrees can leave first.
///  - Members can withdraw part of their share or leave entirely, in kind, without a vote. Money added in the last
///    hour (HOLD) stays in until the hour is up.
///  - Trades pay a protocol fee of at most 0.20%, taken on the USDG side. Deposits and withdrawals are free.
contract RheilonAccount is ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum VoteMode {
        Heads, // one member, one vote
        Shares // votes weighted by shares
    }

    enum Kind {
        Trade, // abi.encode(address tokenIn, address tokenOut, uint256 amountIn, uint256 minOut)
        AddMember, // abi.encode(address member)
        SetRules, // abi.encode(uint16 thresholdBps, uint32 coolOff)
        MoveRegistry, // abi.encode(address newRegistry)
        SetJoins // abi.encode(bool open): an open crew closes (or reopens) itself to joins
    }

    struct Config {
        VoteMode voteMode;
        bool open; // anyone may join while seats are free
        uint8 seats; // 2..10
        uint256 minJoin; // smallest USDG amount to join an open crew
    }

    struct Proposal {
        Kind kind;
        address proposer;
        uint64 createdAt;
        uint64 expiresAt;
        uint64 readyAt; // first moment the threshold was met (0 = not met)
        bool executed;
        bool cancelled;
        bytes data;
        string note;
    }

    uint256 internal constant MAX_MEMBERS = 10;
    uint256 internal constant VOTE_DELAY = 3 days; // self-joined members of open crews vote after this
    uint32 internal constant OPEN_MIN_COOL_OFF = 12 hours;
    uint256 internal constant MAX_ASSETS = 20;
    uint256 internal constant PROPOSAL_TTL = 3 days;
    uint256 internal constant MAX_COOL_OFF = 2 days;
    /// @dev Proposals that have met the bar and are waiting out the cool-off. Every change in voting weight re-checks
    ///      them, so the number is capped to keep exits cheap.
    uint256 public constant MAX_READY = 16;
    /// @notice A trade may receive at most this much less than the oracle value of what it sold, whatever minimum
    ///         the pitch carries. Stops a trade from being run inside someone's sandwich.
    uint256 public constant MAX_TRADE_LOSS_BPS = 300; // 3%
    /// @notice Moving to another registry always waits at least this long unless every member signed.
    uint32 public constant MIN_MOVE_COOL_OFF = 12 hours;
    /// @notice New shares can't be taken out for this long. Shorter than any cool-off, so a newcomer can always leave
    ///         before a pitch made after their join runs; long enough that weight can't be borrowed for a moment.
    uint256 public constant HOLD = 1 hours;

    /// @notice Shares minted to a member within the last HOLD, and when they become free.
    mapping(address => uint256) internal heldShares;
    mapping(address => uint256) public heldUntil;


    /// @notice Assets a leaver or withdrawer was owed but could not be sent (e.g. the token was paused by its
    ///         issuer). Held apart from the crew's money and claimable with `claim` once the token moves again.
    mapping(address => mapping(address => uint256)) public owed;
    mapping(address => uint256) public owedTotal;
    uint16 public constant MAX_FEE_BPS = 20; // 0.20%, whatever any registry says
    uint256 internal constant VIRTUAL_SHARES = 1e6; // blunts first-deposit / donation share inflation

    RheilonRegistry public registry;
    address public immutable baseAsset;
    VoteMode public immutable voteMode;
    /// @notice Anyone may join while seats are free. Only a crew created open can vote to close or reopen (SetJoins).
    bool public open;
    /// @notice Created as an open crew. Its open-crew limits (cool-off floor, no registry moves) stay even while it is
    ///         closed to joins.
    bool public immutable bornOpen;
    uint8 public immutable seats;
    uint256 public immutable minJoin;
    string public name;

    uint16 public thresholdBps = 6666; // two-thirds, rounded up
    uint32 public coolOff = 12 hours;
    /// @notice When the rules (threshold, cool-off) last changed. Readiness from before it doesn't count.
    uint256 public rulesChangedAt;
    /// @notice The latest vote start of a member who has since left. Kept so a vote start stays a reset point after
    ///         its member leaves: stale readiness can't come back to life by that member walking out.
    uint256 public leftVoteStart;

    /// @dev Ids of proposals whose cool-off clock is running (readyAt != 0), re-checked on every weight change.
    uint256[] internal _ready;
    mapping(uint256 => bool) internal _inReady;

    address[] internal _members;
    mapping(address => bool) public isMember;
    mapping(address => uint256) public sharesOf;
    // Bumped every time an address joins, so approvals from an earlier membership never count again.
    mapping(address => uint256) internal memberEpoch;
    // When a self-joined member may start voting (0 = founders and vote-approved members: right away).
    mapping(address => uint256) public votesFrom;
    uint256 public totalShares;

    address[] internal _assets;
    mapping(address => bool) public isHeld;

    Proposal[] internal _proposals;
    mapping(uint256 => mapping(address => uint256)) internal _approvalEpoch;

    event MemberAdded(address indexed member);
    event Joined(address indexed member, uint256 amount, uint256 fee, uint256 shares);
    event MemberLeft(address indexed member);
    event Deposited(address indexed member, uint256 amount, uint256 shares);
    event Withdrawn(address indexed member, uint256 shares, address[] assets, uint256[] amounts);
    event Proposed(uint256 indexed id, address indexed proposer, Kind kind, string note);
    event Approved(uint256 indexed id, address indexed member);
    event Unapproved(uint256 indexed id, address indexed member);
    event Ready(uint256 indexed id, uint256 executableAt);
    event Executed(uint256 indexed id);
    event Cancelled(uint256 indexed id);
    event Traded(uint256 indexed id, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut, uint256 fee);
    event RulesChanged(uint16 thresholdBps, uint32 coolOff);
    event ReadyReset(uint256 indexed id);
    event JoinsSet(bool open);
    event Owed(address indexed member, address indexed asset, uint256 amount);
    event Claimed(address indexed member, address indexed asset, uint256 amount);
    event RegistryMoved(address registry);

    error NotMember();
    error AlreadyMember();
    error TooManyMembers();
    error TooManyAssets();
    error UnsupportedAsset(address asset);
    error NotHeld(address asset);
    error ZeroAmount();
    error NotActive();
    error ThresholdNotMet();
    error CoolOffRunning(uint256 executableAt);
    error BadRules();
    error BadRegistry();
    error OverCap(uint256 cap);
    error Slippage(uint256 received, uint256 minOut);
    error Closed();
    error Full();
    error BelowMinimum(uint256 minJoin);
    error BadConfig();
    error TooManyPending();
    error OracleBound(uint256 valueOut, uint256 valueIn);
    error PartialFill(uint256 spent, uint256 expected);
    error Held(uint256 until);
    error CorporateAction(address asset);
    error ReadySetChanged();

    modifier onlyMember() {
        if (!isMember[msg.sender]) revert NotMember();
        _;
    }

    constructor(RheilonRegistry registry_, string memory name_, address[] memory members_, Config memory cfg) {
        if (cfg.seats < 2 || cfg.seats > MAX_MEMBERS || members_.length == 0 || members_.length > cfg.seats) revert BadConfig();
        // Open crews vote by shares: extra wallets with pocket change carry no weight.
        if (cfg.open && cfg.voteMode != VoteMode.Shares) revert BadConfig();
        registry = registry_;
        baseAsset = registry_.baseAsset();
        voteMode = cfg.voteMode;
        open = cfg.open;
        bornOpen = cfg.open;
        seats = cfg.seats;
        minJoin = cfg.minJoin;
        name = name_;
        for (uint256 i; i < members_.length; ++i) {
            _addMember(members_[i]);
        }
        _track(baseAsset);
    }

    // ================================================================ money in / out

    /// @notice Add USDG. Shares are minted at the account's current value, so nobody gains or loses from it.
    function deposit(uint256 amount) external onlyMember nonReentrant returns (uint256 minted) {
        minted = _mint(msg.sender, amount);
        emit Deposited(msg.sender, amount, minted);
    }

    /// @notice Join an open crew by bringing at least `minJoin` USDG. A join fee (max 0.20%) goes to the protocol.
    ///         You can vote after VOTE_DELAY; you can withdraw or leave once the hour on new shares (HOLD) is up.
    ///         `readySet` is `readyHash()` as you saw it: the join reverts if the set of pitches that could run on your
    ///         money has changed since, so nobody's cool-off moves for a join and you never join into a surprise.
    function join(uint256 amount, bytes32 readySet) external nonReentrant returns (uint256 minted) {
        if (!open) revert Closed();
        if (readySet != readyHash()) revert ReadySetChanged();
        if (isMember[msg.sender]) revert AlreadyMember();
        if (_members.length >= seats) revert Full();
        if (amount < minJoin || amount == 0) revert BelowMinimum(minJoin);

        uint256 rate = registry.joinFeeBps();
        if (rate > MAX_FEE_BPS) rate = MAX_FEE_BPS;
        uint256 fee = (amount * rate) / 10000;
        if (fee > 0) IERC20(baseAsset).safeTransferFrom(msg.sender, registry.treasury(), fee);

        _addMember(msg.sender);
        votesFrom[msg.sender] = block.timestamp + VOTE_DELAY;
        minted = _mint(msg.sender, amount - fee);
        emit Joined(msg.sender, amount, fee, minted);
    }

    function _mint(address to, uint256 amount) internal returns (uint256 minted) {
        if (amount == 0) revert ZeroAmount();
        _noCorporateActionNear();
        uint256 value = accountValue();
        uint256 cap = registry.maxCrewValue();
        if (cap != 0 && value + amount > cap) revert OverCap(cap);
        minted = (amount * (totalShares + VIRTUAL_SHARES)) / (value + 1);
        if (minted == 0) revert ZeroAmount();
        IERC20(baseAsset).safeTransferFrom(to, address(this), amount);
        sharesOf[to] += minted;
        totalShares += minted;
        heldShares[to] = block.timestamp < heldUntil[to] ? heldShares[to] + minted : minted;
        heldUntil[to] = block.timestamp + HOLD;
    }

    /// @notice Take part of your share out, in kind, and stay in the crew. No vote, no fee.
    function withdraw(uint256 shares) external onlyMember nonReentrant {
        if (shares == 0 || shares > sharesOf[msg.sender]) revert ZeroAmount();
        if (shares > freeShares(msg.sender)) revert Held(heldUntil[msg.sender]);
        uint256[] memory signed = _readySignedBy(msg.sender);
        _payOut(msg.sender, shares);
        _resetBelow(signed);
    }

    /// @notice Leave, taking your whole share of every asset as it sits. No vote, no fee. Shares minted in the last
    ///         hour (HOLD) have to wait the hour out first.
    function leave() external onlyMember nonReentrant {
        uint256 s = sharesOf[msg.sender];
        if (s != freeShares(msg.sender)) revert Held(heldUntil[msg.sender]);
        heldShares[msg.sender] = 0;
        heldUntil[msg.sender] = 0;
        uint256[] memory signed = _readySignedBy(msg.sender);
        uint256 v = votesFrom[msg.sender];
        if (v <= block.timestamp && v > leftVoteStart) leftVoteStart = v;
        _removeMember(msg.sender);
        if (s > 0) _payOut(msg.sender, s);
        emit MemberLeft(msg.sender);
        _resetBelow(signed);
    }

    /// @notice Collect an asset you were owed when you withdrew or left but that couldn't be sent at the time.
    function claim(address asset) external nonReentrant {
        uint256 amt = owed[msg.sender][asset];
        if (amt == 0) revert ZeroAmount();
        owed[msg.sender][asset] = 0;
        owedTotal[asset] -= amt;
        IERC20(asset).safeTransfer(msg.sender, amt);
        emit Claimed(msg.sender, asset, amt);
    }

    // ================================================================ proposals

    function propose(Kind kind, bytes calldata data, string calldata note) external onlyMember returns (uint256 id) {
        if (!canVote(msg.sender)) revert NotMember();
        _validate(kind, data);
        id = _proposals.length;
        _proposals.push(
            Proposal({
                kind: kind,
                proposer: msg.sender,
                createdAt: uint64(block.timestamp),
                expiresAt: uint64(block.timestamp + PROPOSAL_TTL),
                readyAt: 0,
                executed: false,
                cancelled: false,
                data: data,
                note: note
            })
        );
        emit Proposed(id, msg.sender, kind, note);
        _approve(id); // proposing counts as signing
    }

    function approve(uint256 id) external onlyMember {
        _requireActive(id);
        if (!canVote(msg.sender)) revert NotMember();
        _approve(id);
    }

    function unapprove(uint256 id) external onlyMember {
        _requireActive(id);
        _approvalEpoch[id][msg.sender] = 0;
        emit Unapproved(id, msg.sender);
        Proposal storage p = _proposals[id];
        if (p.readyAt != 0) {
            (uint256 yes, uint256 needed) = tally(id);
            if (yes < needed) {
                p.readyAt = 0; // dropped below: the cool-off starts over next time
                emit ReadyReset(id);
            }
        }
    }

    /// @notice Starts the cool-off clock if the threshold became met some other way (e.g. a member left).
    function poke(uint256 id) external {
        _requireActive(id);
        _checkpoint(id);
    }

    function cancel(uint256 id) external {
        _requireActive(id);
        Proposal storage p = _proposals[id];
        if (msg.sender != p.proposer) revert NotMember();
        p.cancelled = true;
        emit Cancelled(id);
    }

    function execute(uint256 id) external onlyMember nonReentrant {
        if (!canVote(msg.sender)) revert NotMember();
        _requireActive(id);
        (uint256 yes, uint256 needed) = tally(id);
        if (yes < needed) revert ThresholdNotMet();

        Proposal storage p = _proposals[id];
        if (!unanimous(id)) {
            uint256 wait = coolOff;
            if (p.kind == Kind.MoveRegistry && wait < MIN_MOVE_COOL_OFF) wait = MIN_MOVE_COOL_OFF;
            // not ready, or ready only from before the latest newcomer could vote: call poke() to re-check it first
            // SetJoins moves no money, so a newcomer's vote starting doesn't hold it off (a churner can't keep the door open)
            if (p.readyAt == 0 || (p.kind != Kind.SetJoins && p.readyAt < latestVoteStart())) revert CoolOffRunning(block.timestamp + wait);
            uint256 at = p.readyAt + wait;
            if (block.timestamp < at) revert CoolOffRunning(at);
        }

        p.executed = true;
        if (p.kind == Kind.Trade) {
            _trade(id, p.data);
        } else if (p.kind == Kind.AddMember) {
            _addMember(abi.decode(p.data, (address)));
        } else if (p.kind == Kind.SetJoins) {
            open = abi.decode(p.data, (bool));
            emit JoinsSet(open);
        } else if (p.kind == Kind.SetRules) {
            (uint16 t, uint32 c) = abi.decode(p.data, (uint16, uint32));
            thresholdBps = t;
            coolOff = c;
            emit RulesChanged(t, c);
            rulesChangedAt = block.timestamp;
        } else {
            address r = abi.decode(p.data, (address));
            if (RheilonRegistry(r).baseAsset() != baseAsset) revert BadRegistry();
            registry = RheilonRegistry(r);
            emit RegistryMoved(r);
        }
        emit Executed(id);
    }

    // ================================================================ views

    function members() external view returns (address[] memory) {
        return _members;
    }

    function assets() external view returns (address[] memory) {
        return _assets;
    }

    function proposalCount() external view returns (uint256) {
        return _proposals.length;
    }

    function getProposal(uint256 id) external view returns (Proposal memory) {
        return _proposals[id];
    }

    function hasApproved(uint256 id, address member) public view returns (bool) {
        uint256 e = memberEpoch[member];
        return canVote(member) && e != 0 && _approvalEpoch[id][member] == e;
    }

    /// @notice Members can vote right away, except self-joined members of open crews during their first days.
    function canVote(address member) public view returns (bool) {
        return isMember[member] && block.timestamp >= votesFrom[member];
    }

    /// @notice Number of current members who signed.
    function signerCount(uint256 id) internal view returns (uint256 n) {
        for (uint256 i; i < _members.length; ++i) {
            if (hasApproved(id, _members[i])) ++n;
        }
    }

    /// @notice The latest change in who votes or how: a member gaining their vote (voted in, or a newcomer's
    ///         VOTE_DELAY ending) or new rules. Readiness from before it doesn't count until it passes again.
    function latestVoteStart() public view returns (uint256 t) {
        t = rulesChangedAt > leftVoteStart ? rulesChangedAt : leftVoteStart;
        for (uint256 i; i < _members.length; ++i) {
            uint256 v = votesFrom[_members[i]];
            if (v <= block.timestamp && v > t) t = v;
        }
    }

    /// @notice Fingerprint of the pitches that could run on a newcomer's money: every active ready proposal, by id.
    ///         `join` takes it as consent, so joining never moves anyone's cool-off and a joiner sees what's coming.
    function readyHash() public view returns (bytes32) {
        uint256 since = latestVoteStart();
        uint256[] memory ids = new uint256[](_ready.length);
        uint256 n;
        for (uint256 i; i < _ready.length; ++i) {
            Proposal storage p = _proposals[_ready[i]];
            if (p.readyAt == 0 || p.readyAt < since || p.executed || p.cancelled || block.timestamp > p.expiresAt) continue;
            uint256 id = _ready[i];
            uint256 j = n++;
            while (j > 0 && ids[j - 1] > id) {
                ids[j] = ids[j - 1];
                --j;
            }
            ids[j] = id;
        }
        assembly { mstore(ids, n) }
        return keccak256(abi.encode(ids));
    }

    /// @notice Shares a member can take out right now (everything except what they added in the last HOLD).
    function freeShares(address member) public view returns (uint256) {
        uint256 s = sharesOf[member];
        if (block.timestamp >= heldUntil[member]) return s;
        uint256 h = heldShares[member];
        return h >= s ? 0 : s - h;
    }

    /// @notice Every member signed. A newcomer who can't vote yet can't sign either, so while anyone is still waiting
    ///         nothing is unanimous and the cool-off always applies: they get time to leave before it runs.
    function unanimous(uint256 id) internal view returns (bool) {
        return signerCount(id) == _members.length;
    }

    /// @notice Members who can vote right now. Newcomers still waiting don't count towards the bar.
    function voterCount() internal view returns (uint256 n) {
        for (uint256 i; i < _members.length; ++i) {
            if (canVote(_members[i])) ++n;
        }
    }

    /// @return yes signed weight, needed weight (heads or shares, depending on the crew's vote mode)
    function tally(uint256 id) public view returns (uint256 yes, uint256 needed) {
        uint256 n = _members.length;
        uint256 voterShares;
        uint256 voters;
        for (uint256 i; i < n; ++i) {
            address m = _members[i];
            if (!canVote(m)) continue;
            voters += 1;
            voterShares += sharesOf[m];
        }
        bool byShares = voteMode == VoteMode.Shares && voterShares > 0;
        uint256 total = byShares ? voterShares : voters;
        for (uint256 i; i < n; ++i) {
            address m = _members[i];
            if (hasApproved(id, m)) yes += byShares ? sharesOf[m] : 1;
        }
        needed = (total * thresholdBps + 9999) / 10000;
        if (needed == 0) needed = 1;
    }

    /// @notice Total value of the account in base-asset units, priced by the crew's registry oracle.
    function accountValue() public view returns (uint256 value) {
        IValueOracle o = IValueOracle(registry.oracle());
        for (uint256 i; i < _assets.length; ++i) {
            address a = _assets[i];
            uint256 bal = _free(a);
            if (bal == 0) continue;
            value += a == baseAsset ? bal : o.valueInBase(a, bal);
        }
    }

    /// @notice Fee rate applied to trades, capped at 0.20% regardless of the registry.
    function feeBps() public view returns (uint256) {
        uint256 f = registry.feeBps();
        return f > MAX_FEE_BPS ? MAX_FEE_BPS : f;
    }

    // ================================================================ internals

    function _payOut(address to, uint256 s) internal {
        uint256 supply = totalShares;
        sharesOf[to] -= s;
        totalShares = supply - s;
        uint256 n = _assets.length;
        address[] memory paid = new address[](n);
        uint256[] memory amounts = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            address a = _assets[i];
            paid[i] = a;
            uint256 amt = (_free(a) * s) / supply;
            amounts[i] = amt;
            if (amt > 0 && !_trySend(a, to, amt)) {
                // one paused token must not lock everything else: keep it aside for the member to claim later
                owed[to][a] += amt;
                owedTotal[a] += amt;
                emit Owed(to, a, amt);
            }
        }
        emit Withdrawn(to, s, paid, amounts);
    }

    function _approve(uint256 id) internal {
        _approvalEpoch[id][msg.sender] = memberEpoch[msg.sender];
        emit Approved(id, msg.sender);
        _checkpoint(id);
    }

    function _checkpoint(uint256 id) internal {
        Proposal storage p = _proposals[id];
        if (p.readyAt != 0 && (p.kind == Kind.SetJoins || p.readyAt >= latestVoteStart())) return;
        (uint256 yes, uint256 needed) = tally(id);
        if (yes >= needed) {
            if (!_inReady[id]) {
                _pruneReady();
                if (_ready.length >= MAX_READY) revert TooManyPending();
                _ready.push(id);
                _inReady[id] = true;
            }
            p.readyAt = uint64(block.timestamp);
            emit Ready(id, unanimous(id) ? block.timestamp : block.timestamp + coolOff);
        }
    }

    /// @dev Drops proposals that are no longer waiting (ran, cancelled, expired or reset) from the ready list.
    function _pruneReady() internal {
        uint256 i;
        while (i < _ready.length) {
            uint256 id = _ready[i];
            Proposal storage p = _proposals[id];
            if (p.readyAt == 0 || p.executed || p.cancelled || block.timestamp > p.expiresAt) {
                _inReady[id] = false;
                _ready[i] = _ready[_ready.length - 1];
                _ready.pop();
            } else {
                ++i;
            }
        }
    }

    /// @dev Waiting proposals this member has signed, read before their weight changes.
    function _readySignedBy(address m) internal returns (uint256[] memory ids) {
        _pruneReady();
        uint256 n = _ready.length;
        ids = new uint256[](n);
        uint256 k;
        for (uint256 i; i < n; ++i) if (hasApproved(_ready[i], m)) ids[k++] = _ready[i];
        assembly { mstore(ids, k) }
    }

    /// @dev After a signer's weight fell (they withdrew or left): each proposal they signed that is now below the bar
    ///      loses its readiness, so its cool-off starts over the next time it passes. Someone who never signed can't
    ///      reset a pitch this way; a deposit of theirs is weighed at `execute` instead.
    function _resetBelow(uint256[] memory ids) internal {
        for (uint256 i; i < ids.length; ++i) {
            Proposal storage p = _proposals[ids[i]];
            if (p.readyAt == 0) continue;
            (uint256 yes, uint256 needed) = tally(ids[i]);
            if (yes < needed) {
                p.readyAt = 0;
                emit ReadyReset(ids[i]);
            }
        }
    }

    function _requireActive(uint256 id) internal view {
        Proposal storage p = _proposals[id];
        if (p.executed || p.cancelled || block.timestamp > p.expiresAt) revert NotActive();
    }

    function _validate(Kind kind, bytes calldata data) internal view {
        if (kind == Kind.Trade) {
            (address tokenIn, address tokenOut, uint256 amountIn,) = abi.decode(data, (address, address, uint256, uint256));
            if (!isHeld[tokenIn]) revert NotHeld(tokenIn); // selling a delisted asset stays possible
            if (amountIn > _free(tokenIn)) revert ZeroAmount(); // can't pitch money the crew doesn't have
            if (!registry.isSupported(tokenOut)) revert UnsupportedAsset(tokenOut);
            if (amountIn == 0 || tokenIn == tokenOut) revert ZeroAmount();
        } else if (kind == Kind.AddMember) {
            address m = abi.decode(data, (address));
            if (m == address(0) || isMember[m]) revert AlreadyMember();
        } else if (kind == Kind.SetRules) {
            (uint16 t, uint32 c) = abi.decode(data, (uint16, uint32));
            if (t <= 5000 || t > 10000 || c > MAX_COOL_OFF) revert BadRules();
            if (bornOpen && c < OPEN_MIN_COOL_OFF) revert BadRules();
        } else if (kind == Kind.SetJoins) {
            if (!bornOpen) revert BadRules();
        } else {
            if (bornOpen) revert BadRegistry(); // open crews can't be moved: closes the "vote in a fake registry" route
            address r = abi.decode(data, (address));
            if (r == address(0) || r.code.length == 0 || RheilonRegistry(r).baseAsset() != baseAsset) revert BadRegistry();
        }
    }

    function _trade(uint256 id, bytes memory data) internal {
        (address tokenIn, address tokenOut, uint256 amountIn, uint256 minOut) =
            abi.decode(data, (address, address, uint256, uint256));
        if (!isHeld[tokenIn]) revert NotHeld(tokenIn);
        if (!registry.isSupported(tokenOut)) revert UnsupportedAsset(tokenOut);
        if (amountIn > _free(tokenIn)) revert ZeroAmount(); // never spends what members are owed
        if (_actionNear(tokenIn)) revert CorporateAction(tokenIn);
        if (_actionNear(tokenOut)) revert CorporateAction(tokenOut);
        _track(tokenOut);

        uint256 rate = feeBps();
        address treasury = registry.treasury();
        // The fee is charged on the USDG side when there is one; otherwise on what goes in.
        bool feeOnOut = tokenOut == baseAsset && tokenIn != baseAsset;
        uint256 fee;
        uint256 swapIn = amountIn;
        if (!feeOnOut && rate > 0) {
            fee = (amountIn * rate) / 10000;
            swapIn = amountIn - fee;
            if (fee > 0) IERC20(tokenIn).safeTransfer(treasury, fee);
        }

        uint256 received = _swapExact(tokenIn, tokenOut, swapIn);
        _checkBound(tokenIn, tokenOut, swapIn, received);

        if (feeOnOut && rate > 0) {
            fee = (received * rate) / 10000;
            received -= fee;
            if (fee > 0) IERC20(tokenOut).safeTransfer(treasury, fee);
        }
        if (received < minOut) revert Slippage(received, minOut);

        _untrackIfEmpty(tokenIn);
        emit Traded(id, tokenIn, tokenOut, amountIn, received, fee);
    }

    /// @dev Swaps exactly `swapIn` through the registry's adapter and returns what arrived. Reverts if the account
    ///      didn't spend exactly `swapIn`, or if the adapter kept any of it (a partial fill would leave the rest there).
    function _swapExact(address tokenIn, address tokenOut, uint256 swapIn) internal returns (uint256 received) {
        address adapter = registry.swapAdapter();
        uint256 before = IERC20(tokenOut).balanceOf(address(this));
        uint256 inBefore = IERC20(tokenIn).balanceOf(address(this));
        uint256 adapterBefore = IERC20(tokenIn).balanceOf(adapter);
        IERC20(tokenIn).forceApprove(adapter, swapIn);
        ISwapAdapter(adapter).swap(tokenIn, tokenOut, swapIn, 0, address(this));
        IERC20(tokenIn).forceApprove(adapter, 0);
        if (IERC20(tokenIn).balanceOf(adapter) != adapterBefore) revert PartialFill(swapIn, swapIn);
        uint256 spent = inBefore - IERC20(tokenIn).balanceOf(address(this));
        if (spent != swapIn) revert PartialFill(spent, swapIn);
        received = IERC20(tokenOut).balanceOf(address(this)) - before;
    }

    /// @dev Bound to the oracle: what came in must be worth at least what went out, minus MAX_TRADE_LOSS_BPS, whatever
    ///      minOut a pitch carries. If the oracle can't price what's sold, the trade is refused, except a sale into
    ///      USDG, which runs held to minOut alone so a crew is never stuck holding a token whose feed went stale or
    ///      was retired.
    function _checkBound(address tokenIn, address tokenOut, uint256 swapIn, uint256 received) internal view {
        (bool priced, uint256 vIn) = _tryValueOf(tokenIn, swapIn);
        if (priced) {
            uint256 vOut = _valueOf(tokenOut, received);
            if (vOut * 10000 < vIn * (10000 - MAX_TRADE_LOSS_BPS)) revert OracleBound(vOut, vIn);
        } else if (tokenOut != baseAsset) {
            revert OracleBound(0, 0);
        }
    }

    /// @dev Stock Tokens carry an ERC-8056 multiplier that changes on splits and dividends, and the token and its price
    ///      feed may not step at the same moment. Around a change the oracle can be off, so new money (deposits and
    ///      joins) and trades in that token pause: from 3 days before a pending change of more than 1% (smaller
    ///      dividend steps don't count) until 1 day after any change takes effect. Exits are unaffected. Tokens
    ///      without the extension (USDG, test tokens) are skipped.
    function _actionNear(address a) internal view returns (bool) {
        if (a == baseAsset) return false;
        try IERC8056(a).effectiveAt() returns (uint256 at) {
            if (block.timestamp >= at) return block.timestamp < at + 1 days; // just changed
            if (block.timestamp + 3 days < at) return false; // too far ahead to matter
            uint256 cur = IERC8056(a).uiMultiplier();
            uint256 nxt = IERC8056(a).newUIMultiplier();
            uint256 step = nxt > cur ? nxt - cur : cur - nxt;
            return step * 100 > cur;
        } catch {
            return false;
        }
    }

    function _noCorporateActionNear() internal view {
        for (uint256 i; i < _assets.length; ++i) {
            if (_actionNear(_assets[i])) revert CorporateAction(_assets[i]);
        }
    }

    /// @dev What the crew holds of an asset, not counting what departed members are still owed.
    function _free(address a) internal view returns (uint256) {
        return IERC20(a).balanceOf(address(this)) - owedTotal[a];
    }

    function _valueOf(address a, uint256 amount) internal view returns (uint256) {
        return a == baseAsset ? amount : IValueOracle(registry.oracle()).valueInBase(a, amount);
    }

    function _tryValueOf(address a, uint256 amount) internal view returns (bool, uint256) {
        if (a == baseAsset) return (true, amount);
        try IValueOracle(registry.oracle()).valueInBase(a, amount) returns (uint256 v) {
            return (true, v);
        } catch {
            return (false, 0);
        }
    }

    /// @dev ERC-20 transfer that reports failure instead of reverting (paused token, blocklist, no code).
    function _trySend(address token, address to, uint256 amount) internal returns (bool) {
        if (token.code.length == 0) return false;
        (bool ok, bytes memory ret) = token.call(abi.encodeCall(IERC20.transfer, (to, amount)));
        return ok && (ret.length == 0 || (ret.length == 32 && abi.decode(ret, (bool))));
    }

    function _addMember(address m) internal {
        if (m == address(0) || isMember[m]) revert AlreadyMember();
        if (_members.length >= seats) revert TooManyMembers();
        isMember[m] = true;
        memberEpoch[m] += 1;
        votesFrom[m] = block.timestamp; // votes at once; join() pushes it out by VOTE_DELAY
        _members.push(m);
        emit MemberAdded(m);
    }

    function _removeMember(address m) internal {
        isMember[m] = false;
        uint256 n = _members.length;
        for (uint256 i; i < n; ++i) {
            if (_members[i] == m) {
                _members[i] = _members[n - 1];
                _members.pop();
                return;
            }
        }
    }

    function _track(address a) internal {
        if (isHeld[a]) return;
        if (_assets.length >= MAX_ASSETS) revert TooManyAssets();
        isHeld[a] = true;
        _assets.push(a);
    }

    function _untrackIfEmpty(address a) internal {
        if (a == baseAsset || _free(a) != 0) return;
        isHeld[a] = false;
        uint256 n = _assets.length;
        for (uint256 i; i < n; ++i) {
            if (_assets[i] == a) {
                _assets[i] = _assets[n - 1];
                _assets.pop();
                return;
            }
        }
    }
}
