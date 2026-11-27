# $HEIL perks and the Rheilon agent

$HEIL is Rheilon's community token. The contracts in this repository don't use it: crews, votes, fees and exits
work the same with or without it. The perks below are run by the website (rheilon.com), read from Robinhood Chain,
and never touch a crew's money. Nothing paid for a perk goes to the team: it's burned.

## Holder badge

Hold at least **500,000 $HEIL** and a $HEIL badge shows next to your name in your crews and on your crews in
Discover. It's read from your wallet's balance on chain; there is nothing to sign.

## Feature your crew

A member burns **$5 of $HEIL** from the crew's page and the crew shows first in Discover for **7 days**. Burning again
while it's featured adds 7 more days.

## The Rheilon agent on X

Mention **@rheilonfinance** with a question (markets, news, crypto, how something works, in any language) and the
agent replies on X.

To use it:

1. On rheilon.com, connect your wallet and **link your X**. This needs both an X login and a signature from the
   wallet, so nobody can claim someone else's wallet.
2. Burn **$10 of $HEIL** in total from that wallet, in one go or a bit at a time. Once the total reaches $10 the
   wallet is unlocked for good.

Then each linked, unlocked wallet can ask up to **5 questions a day**.

What it does and doesn't do:

- Answers with Grok (xAI), using web and X search for anything recent. For the 8 Robinhood Stock Tokens it quotes
  the Chainlink prices on Robinhood Chain, the same feeds the crew contracts use. If the model is unavailable it
  replies with those Chainlink prices instead.
- Gives information, not financial advice: it doesn't tell anyone to buy or sell, doesn't predict prices, and never
  comments on the price or future of $HEIL.
- **Can't move money.** It can't sign, join a crew, deposit, pitch, vote or trade for anyone, and it never asks for
  keys, seed phrases or funds. Anything that moves money is done by the member's own wallet on the crew's page.
- Replies without links. Accounts that haven't unlocked it get one reply a week explaining how.

## What counts as a burn

The website checks every burn on chain before it counts:

- A successful transaction in which the sender's own $HEIL goes to `0x0000…0000` (the token's `burn()`) or to the
  dead address `0x0000…dEaD`, where tokens can never move again.
- Each transaction counts once.
- It's valued in dollars when it's claimed, at the token's price on its Pons bonding curve, converted with the
  WETH/USDG pool on Robinhood Chain, with 10% slack for price moves between the click and the block.

## Burned so far

The $HEIL page on rheilon.com shows how much is gone for good: the 1,000,000,000 minted at launch minus today's total
supply (tokens destroyed with `burn()`), plus the balance of the dead address.

| | Address |
| --- | --- |
| $HEIL | [`0xE1a8Ea885047572986f80019B1196d6088DC555e`](https://robinhoodchain.blockscout.com/token/0xE1a8Ea885047572986f80019B1196d6088DC555e) |
| Dead address | [`0x000000000000000000000000000000000000dEaD`](https://robinhoodchain.blockscout.com/address/0x000000000000000000000000000000000000dEaD) |
