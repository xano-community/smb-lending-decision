# SMB Lending Decision (Xano module)

A self-contained **small-business underwriting engine** for Xano. Feed it a borrower's financials and it returns a deterministic **approve / decline / refer** decision backed by **DSCR**, **DTI**, and **cash-runway** math — plus a 0–100 score, human-readable reasons, and suggested terms. Every decision is persisted.

Drop this module into any Xano workspace. It ships four tables, a small public function surface, and an HTTP API. It combines business financials (e.g. from Dynamics 365), banking cash-flow, and your existing loan book into one decision.

## What you get

**Tables**

| Table | Purpose |
| --- | --- |
| `sld_application` | One row per loan application (amount, term, purpose, status). |
| `sld_financials` | The financials snapshot captured for an application (revenue, expenses, cash, debt). |
| `sld_loan` | The **loan book** — existing obligations per business, used to fold open monthly payments into debt service. |
| `sld_decision` | The persisted decision (outcome, score, DSCR, DTI, runway, reasons, suggested terms). |

**Public function surface** (call from any XanoScript via `function.run`)

| Function | What it does |
| --- | --- |
| `sld_compute_metrics` | Pure math: simple-interest payment → NOI, total debt service, DSCR, DTI, cash runway. Divide-by-zero ⇒ `null`. |
| `sld_summarize_banking` | Pure cash-flow rollup over a `{amount, direction}` transaction list (inflow / outflow / net / count). |
| `sld_evaluate` | End-to-end: persist application + financials, fold in loan-book obligations, score, decide, persist. |

**HTTP endpoints** (API group `smb-lending-decision`)

| Method | Path | Wraps |
| --- | --- | --- |
| `POST` | `/applications` | create `sld_application` |
| `GET`  | `/applications` | list `sld_application` |
| `POST` | `/loans` | seed the loan book |
| `GET`  | `/loans` | list the loan book |
| `POST` | `/evaluate` | `sld_evaluate` |
| `GET`  | `/decisions/{id}` | fetch a persisted decision |

## Decision policy

The engine is deterministic and tunable in `sld_evaluate`:

- **Approve** when `DSCR ≥ 1.25` **and** `DTI ≤ 0.43`.
- **Decline** when `DSCR` is uncomputable, `DSCR < 1.0`, **or** `DTI > 0.5`.
- **Refer** everything in between (marginal coverage or elevated DTI).

`new_payment = requested_amount × (1 + annual_interest_rate × term_months/12) ÷ term_months` (simple interest spread evenly over the term — fully deterministic, no amortization libraries required). `DSCR = NOI / total_debt_service`, `DTI = total_debt_service / monthly_revenue`, where `NOI = monthly_revenue − monthly_expenses` and `total_debt_service = existing_debt_payments + open_loan_book_payments + new_payment`.

## Install

### Option A — Ask Claude Code
With the [Xano MCP](https://github.com/xano-labs/mcp-server) enabled, paste:

> Install the module at https://github.com/xano-community/smb-lending-decision into my Xano workspace.

### Option B — Xano CLI
```sh
git clone https://github.com/xano-community/smb-lending-decision.git
cd smb-lending-decision
xano workspace push backend -w <your-workspace-id>
```

## Usage

```xs
// Seed the loan book once (existing obligations for a business):
function.run "sld_evaluate" {
  input = {
    applicant_name: "Acme LLC",
    business_id: "biz_1",
    requested_amount: 100000,
    term_months: 24,
    monthly_revenue: 50000,
    monthly_expenses: 30000,
    existing_debt_payments: 2000,
    cash_on_hand: 120000
  }
} as $decision
// => { outcome: "approved", score: 78, dscr: 1.4, dti: 0.13, reasons: [...], suggested_terms: {...} }
```

Or via HTTP:

```sh
curl -X POST "$BASE/api:smb-lending-decision/evaluate" \
  -H 'Content-Type: application/json' \
  -d '{"applicant_name":"Acme LLC","requested_amount":100000,"term_months":24,"monthly_revenue":50000,"monthly_expenses":30000,"existing_debt_payments":2000}'
```

### Feeding it (optional companion integrations)

This module is self-contained — it only needs plain numbers. Natural feeders:

- **Dynamics 365 Business Central** → revenue / expenses / net income into the financials snapshot.
- Any of the Xano open-banking integrations (Plaid / MX / Finicity) → bank cash-flow, summarized via `sld_summarize_banking`.

## License

MIT — see [LICENSE](./LICENSE).
