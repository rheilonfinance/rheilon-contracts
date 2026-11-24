// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {RheilonRegistry} from "./RheilonRegistry.sol";
import {ISwapAdapter} from "./interfaces/ISwapAdapter.sol";
import {IValueOracle} from "./interfaces/IValueOracle.sol";

/// @title RheilonAccount
/// @notice One shared account per crew. Nobody outside the crew has any power over it.
///  - Members deposit the base asset (USDG) for non-transferable shares priced at the account's current value.
///  - Trades, new members, rule changes and registry moves are proposals each member signs with their own key.
///  - A passed proposal waits out a cool-off (skipped when unanimous) so anyone who disagrees can leave first.
///  - Members can withdraw part of their share or leave entirely at any time, in kind, without a vote.
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
        MoveRegistry // abi.encode(address newRegistry)
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

    uint256 public constant MAX_MEMBERS = 10;
    uint256 public constant VOTE_DELAY = 3 days; // self-joined members of open crews vote after this
    uint32 public constant OPEN_MIN_COOL_OFF = 12 hours;
    uint256 public constant MAX_ASSETS = 20;
    uint256 public constant PROPOSAL_TTL = 3 days;
    uint256 public constant MAX_COOL_OFF = 2 days;
    uint16 public constant MAX_FEE_BPS = 20; // 0.20%, whatever any registry says
    uint256 internal constant VIRTUAL_SHARES = 1e6; // blunts first-deposit / donation share inflation

    RheilonRegistry public registry;
    address public immutable baseAsset;
    VoteMode public immutable voteMode;
    bool public immutable open;
    uint8 public immutable seats;
    uint256 public immutable minJoin;
    string public name;

    uint16 public thresholdBps = 6666; // two-thirds, rounded up
    uint32 public coolOff = 12 hours;

    address[] internal _members;
    mapping(address => bool) public isMember;
    mapping(address => uint256) public sharesOf;
    // Bumped every time an address joins, so approvals from an earlier membership never count again.
    mapping(address => uint256) public memberEpoch;
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
    ///         You can vote after VOTE_DELAY; you can withdraw or leave at any time.
    function join(uint256 amount) external nonReentrant returns (uint256 minted) {
        if (!open) revert Closed();
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
        uint256 value = accountValue();
        uint256 cap = registry.maxCrewValue();
        if (cap != 0 && value + amount > cap) revert OverCap(cap);
        minted = (amount * (totalShares + VIRTUAL_SHARES)) / (value + 1);
        if (minted == 0) revert ZeroAmount();
        IERC20(baseAsset).safeTransferFrom(to, address(this), amount);
        sharesOf[to] += minted;
        totalShares += minted;
    }

    /// @notice Take part of your share out, in kind, and stay in the crew. No vote, no fee.
    function withdraw(uint256 shares) external onlyMember nonReentrant {
        if (shares == 0 || shares > sharesOf[msg.sender]) revert ZeroAmount();
        _payOut(msg.sender, shares);
    }

    /// @notice Leave at any time, taking your whole share of every asset as it sits. No vote, no fee.
    function leave() external onlyMember nonReentrant {
        uint256 s = sharesOf[msg.sender];
        _removeMember(msg.sender);
        if (s > 0) _payOut(msg.sender, s);
        emit MemberLeft(msg.sender);
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
            if (yes < needed) p.readyAt = 0; // dropped below: the cool-off starts over next time
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
        require(msg.sender == p.proposer, "only proposer");
        p.cancelled = true;
        emit Cancelled(id);
    }

    function execute(uint256 id) external onlyMember nonReentrant {
        _requireActive(id);
        (uint256 yes, uint256 needed) = tally(id);
        if (yes < needed) revert ThresholdNotMet();

        Proposal storage p = _proposals[id];
        if (signerCount(id) < voterCount()) {
            if (p.readyAt == 0) revert CoolOffRunning(block.timestamp + coolOff); // call poke() first
            uint256 at = p.readyAt + coolOff;
            if (block.timestamp < at) revert CoolOffRunning(at);
        }

        p.executed = true;
        if (p.kind == Kind.Trade) {
            _trade(id, p.data);
        } else if (p.kind == Kind.AddMember) {
            _addMember(abi.decode(p.data, (address)));
        } else if (p.kind == Kind.SetRules) {
            (uint16 t, uint32 c) = abi.decode(p.data, (uint16, uint32));
            thresholdBps = t;
            coolOff = c;
            emit RulesChanged(t, c);
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

    function memberCount() external view returns (uint256) {
        return _members.length;
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

    function seatsLeft() external view returns (uint256) {
        return seats - _members.length;
    }

    /// @notice Number of current members who signed.
    function signerCount(uint256 id) public view returns (uint256 n) {
        for (uint256 i; i < _members.length; ++i) {
            if (hasApproved(id, _members[i])) ++n;
        }
    }

    /// @notice Members who can vote right now. Newcomers still waiting don't count in either direction.
    function voterCount() public view returns (uint256 n) {
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
            uint256 bal = IERC20(a).balanceOf(address(this));
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
            uint256 amt = (IERC20(a).balanceOf(address(this)) * s) / supply;
            amounts[i] = amt;
            if (amt > 0) IERC20(a).safeTransfer(to, amt);
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
        if (p.readyAt != 0) return;
        (uint256 yes, uint256 needed) = tally(id);
        if (yes >= needed) {
            p.readyAt = uint64(block.timestamp);
            emit Ready(id, signerCount(id) == voterCount() ? block.timestamp : block.timestamp + coolOff);
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
            if (!registry.isSupported(tokenOut)) revert UnsupportedAsset(tokenOut);
            if (amountIn == 0 || tokenIn == tokenOut) revert ZeroAmount();
        } else if (kind == Kind.AddMember) {
            address m = abi.decode(data, (address));
            if (m == address(0) || isMember[m]) revert AlreadyMember();
        } else if (kind == Kind.SetRules) {
            (uint16 t, uint32 c) = abi.decode(data, (uint16, uint32));
            if (t <= 5000 || t > 10000 || c > MAX_COOL_OFF) revert BadRules();
            if (open && c < OPEN_MIN_COOL_OFF) revert BadRules();
        } else {
            if (open) revert BadRegistry(); // open crews can't be moved: closes the "vote in a fake registry" route
            address r = abi.decode(data, (address));
            if (r == address(0) || r.code.length == 0 || RheilonRegistry(r).baseAsset() != baseAsset) revert BadRegistry();
        }
    }

    function _trade(uint256 id, bytes memory data) internal {
        (address tokenIn, address tokenOut, uint256 amountIn, uint256 minOut) =
            abi.decode(data, (address, address, uint256, uint256));
        if (!isHeld[tokenIn]) revert NotHeld(tokenIn);
        if (!registry.isSupported(tokenOut)) revert UnsupportedAsset(tokenOut);
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

        address adapter = registry.swapAdapter();
        uint256 before = IERC20(tokenOut).balanceOf(address(this));
        IERC20(tokenIn).forceApprove(adapter, swapIn);
        ISwapAdapter(adapter).swap(tokenIn, tokenOut, swapIn, 0, address(this));
        IERC20(tokenIn).forceApprove(adapter, 0);
        uint256 received = IERC20(tokenOut).balanceOf(address(this)) - before;

        if (feeOnOut && rate > 0) {
            fee = (received * rate) / 10000;
            received -= fee;
            if (fee > 0) IERC20(tokenOut).safeTransfer(treasury, fee);
        }
        if (received < minOut) revert Slippage(received, minOut);

        _untrackIfEmpty(tokenIn);
        emit Traded(id, tokenIn, tokenOut, amountIn, received, fee);
    }

    function _addMember(address m) internal {
        if (m == address(0) || isMember[m]) revert AlreadyMember();
        if (_members.length >= seats) revert TooManyMembers();
        isMember[m] = true;
        memberEpoch[m] += 1;
        votesFrom[m] = 0;
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
        if (a == baseAsset || IERC20(a).balanceOf(address(this)) != 0) return;
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
