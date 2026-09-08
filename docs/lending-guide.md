# MicroLend — Complete Guide to Issuing a Loan

A plain-English walkthrough for lenders. No technical background needed. This explains every field on the **Issue New Loan** screen, what it does to the money, and how to choose the right settings for your situation.

## Part 1 — The Big Picture
When you give out a loan in MicroLend, there are three ways you earn or protect your money, and they work independently:
1. Interest (Interest Method) — the profit added on top of the money you lend. The borrower pays this back over time.
2. Upfront Deduction — a fee you subtract before handing over the cash. The borrower gets less than the loan amount, but still owes the full amount.
3. Penalty — an extra charge that only applies if the borrower pays late.
You can use all three at once, or just one.

## Part 2 — Filling Out the Form, Field by Field
- Borrower: Pick the person borrowing. You must add the person as a borrower first before they show up here.
- Frequency: Daily / Weekly / Bi-weekly / Monthly — how often the borrower makes a payment.
- Interest Method: Reducing / Flat / Interest-Only / One-Time — how the profit (interest) is calculated.
- Principal: The loan amount you are lending (the app shows a "$" sign, but it uses your chosen currency, e.g. pesos).
- Rate (%): The interest rate. For some methods this is treated as a yearly rate — see the warning below.
- Term: How many payment periods. The label changes based on frequency (months, weeks, or days).
- Upfront Deduction: None / Fixed Amount / Percentage — a fee taken out before you hand over the cash.
- Penalty: None / Fixed / Percent / Fixed once — the late charge if the borrower misses a due date.
- Purpose: Reason for the loan (for your records).
- Disbursement Date: The date you release the money; due dates are counted from here.

## Part 3 — Interest Method Explained (The Most Important Choice)
1. Reducing Balance — Interest is calculated on the remaining balance, so it shrinks as the borrower pays down the loan. This gives the lowest total interest. Important: the rate you enter is treated as a yearly rate and split across the year. Entering "12%" with monthly payments charges about 1% per month — not 12% of the whole loan.
2. Flat / Add-on ("5-6") — Interest is a straight percentage of the loan amount: loan × rate. Lend 3,000 at 12% = exactly 360 interest, regardless of term. Closest match to traditional "5-6" lending and the most predictable.
3. Interest-Only — The borrower pays only interest each period, then pays the entire loan amount in one lump at the end (balloon). The longer the term, the more total interest collected.
4. One-Time Payment — Only a single payment: loan amount plus interest, all due at once. Warning: even if you type a term like 6 months, the app forces this to a single payment; the term is ignored for this method.

Quick comparison (lending 3,000 at 12%, monthly):
| Method | Total Interest | Total the borrower repays |
| --- | --- | --- |
| Reducing Balance | ~106 | ~3,106 |
| Flat ("5-6") | 360 | 3,360 |
| Interest-Only | 180 (over 6 months) | 3,180 |
| One-Time | 360 | 3,360 |

## Part 4 — Upfront Deduction Explained (Advance Fee)
Money you take out before giving the cash. Not interest — a service/processing fee.
- None — no fee; borrower receives the full amount.
- Fixed Amount — a set fee (e.g. 150), capped so it can never exceed the loan itself.
- Percentage (%) — a percentage of the loan (e.g. 5% of 3,000 = 150).
Key: the borrower still owes the full loan amount even though they received less. Example: lend 3,000 with 5% upfront deduction → fee 150, borrower receives 2,850, borrower still repays 3,000 + interest.

## Part 5 — Dynamic Term (How the Term Affects Each Method)
| Interest Method | Effect of a longer term |
| --- | --- |
| Reducing Balance | Interest goes up slightly |
| Flat ("5-6") | No effect — interest stays the same |
| Interest-Only | Interest goes up the most (grows steadily) |
| One-Time | No effect — always a single payment |

## Part 6 — Penalty Explained
Penalties only apply if a payment becomes overdue. If the borrower always pays on time, no penalty is charged.
- None — no late charge.
- Fixed per overdue period — a set amount for each late period (e.g. 50 per late period).
- Percent per overdue period — a percentage of the unpaid amount, for each late period.
- Fixed once when overdue — a single charge that applies only once for the whole loan.

## Part 7 — Reading the Live Preview
As you type, the app shows a running summary: Upfront Fee Deduction, Net Disbursed to Borrower (actual cash received), Installments (count and amount per payment), and Total Interest / Total Repayable. Always check these before saving.

## Part 8 — Saving the Loan
When you submit: (1) the app checks your entries are valid (amount, rate, term, frequency); (2) the loan is created with a "Pending" status. A pending loan is not active yet — it must be approved before the money is considered released and the schedule starts. This is a safety check.

## Part 9 — Putting It All Together (Combined Examples)
Lending 3,000 at 12%, monthly. Total profit = interest + upfront fee.
| Interest Method | Term | Upfront Fee | Borrower receives | Borrower repays | Your profit |
| --- | --- | --- | --- | --- | --- |
| Reducing | 6 months | None | 3,000 | 3,106 | 106 |
| Reducing | 6 months | 150 | 2,850 | 3,106 | 256 |
| Flat ("5-6") | any term | None | 3,000 | 3,360 | 360 |
| Flat ("5-6") | any term | 150 | 2,850 | 3,360 | 510 |
| Interest-Only | 6 months | 150 | 2,850 | 3,180 | 330 |
| One-Time | any term | 150 | 2,850 | 3,360 | 510 |

## Part 10 — Licensing and Unlocking Full Features
MicroLend operates in an Unlicensed edition by default, which supports up to 5 borrowers.
To unlock full features and unlimited borrowers:
1. Go to **Settings** in the main menu.
2. Locate the **Full Features** card.
3. Enter the master unlock code (`MICROLEND-FULL-UNLOCK`) into the unlock input field.
4. Click **Unlock**. Once unlocked, full functionality and unlimited borrower creation will be permanently enabled on your instance unless re-locked manually.

## Part 11 — Recommendations for a Non-Techy Lender
- For traditional "5-6" lending, choose Flat / Add-on — most predictable and familiar.
- Add an Upfront Deduction to collect part of your profit immediately.
- Use Penalty to protect against late payers.
- Avoid Reducing Balance unless you want bank-style amortized interest — total interest looks much smaller because the rate is treated as yearly.
- Always read the Net Disbursed and Total Repayable lines in the preview before saving.
