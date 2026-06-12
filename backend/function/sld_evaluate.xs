function "sld_evaluate" {
  description = "End-to-end underwriting. Persists the application + financials, folds in any open loan-book obligations for the business, computes DSCR/DTI/cash-runway via sld_compute_metrics, applies a rules-and-score decision (approve/decline/refer), records the decision with human-readable reasons + suggested terms, and updates the application status."

  input {
    text applicant_name { description = "Legal name of the applicant business" }
    text business_id? { description = "Stable business id used to look up existing obligations in the loan book" }
    decimal requested_amount { description = "Requested loan principal" }
    int term_months { description = "Loan term in months" }
    text purpose? { description = "Stated purpose of the loan" }
    decimal monthly_revenue { description = "Business monthly revenue" }
    decimal monthly_expenses { description = "Business monthly operating expenses (excludes debt service)" }
    decimal existing_debt_payments?=0 { description = "Known existing monthly debt obligations not yet in the loan book" }
    decimal cash_on_hand? { description = "Liquid cash available" }
    decimal annual_interest_rate?=0.12 { description = "Annual interest rate as a decimal (e.g. 0.12 = 12%)" }
  }

  stack {
    // 1. Persist the application.
    db.add "sld_application" {
      data = {
        applicant_name: $input.applicant_name,
        business_id: $input.business_id,
        requested_amount: $input.requested_amount,
        term_months: $input.term_months,
        purpose: $input.purpose,
        status: "pending"
      }
    } as $app

    // 2. Persist the supplied financials snapshot.
    db.add "sld_financials" {
      data = {
        application_id: $app.id,
        monthly_revenue: $input.monthly_revenue,
        monthly_expenses: $input.monthly_expenses,
        net_income: ($input.monthly_revenue - $input.monthly_expenses),
        existing_debt_payments: ($input.existing_debt_payments ?? 0),
        cash_on_hand: $input.cash_on_hand,
        source: "manual"
      }
    } as $fin

    // 3. Fold in open loan-book obligations for this business.
    var $book_payments { value = 0 }
    conditional {
      if (($input.business_id != null) && ($input.business_id != "")) {
        db.query "sld_loan" {
          where = $db.sld_loan.business_id == $input.business_id && $db.sld_loan.status != "closed"
          return = {type: "list"}
        } as $loans
        foreach ($loans) {
          each as $loan {
            var.update $book_payments { value = ($book_payments + (($loan|get:"monthly_payment") ?? 0)) }
          }
        }
      }
    }

    var $combined_existing { value = (($input.existing_debt_payments ?? 0) + $book_payments) }

    // 4. Compute the underwriting metrics.
    function.run "sld_compute_metrics" {
      input = {
        monthly_revenue: $input.monthly_revenue,
        monthly_expenses: $input.monthly_expenses,
        requested_amount: $input.requested_amount,
        term_months: $input.term_months,
        existing_debt_payments: $combined_existing,
        cash_on_hand: $input.cash_on_hand,
        annual_interest_rate: $input.annual_interest_rate
      }
    } as $m

    var $dscr { value = ($m|get:"dscr") }
    var $dti { value = ($m|get:"dti") }
    var $runway { value = ($m|get:"cash_runway_months") }
    var $new_payment { value = ($m|get:"new_payment") }

    // 5. Decision rules.
    var $outcome { value = "referred" }
    conditional {
      if (($dscr != null) && ($dscr >= 1.25) && ($dti != null) && ($dti <= 0.43)) {
        var.update $outcome { value = "approved" }
      }
      elseif (($dscr == null) || ($dscr < 1.0) || (($dti != null) && ($dti > 0.5))) {
        var.update $outcome { value = "declined" }
      }
      else {
        var.update $outcome { value = "referred" }
      }
    }

    // 6. Human-readable reasons.
    var $reasons { value = [] }

    conditional {
      if ($dscr == null) {
        var.update $reasons { value = ($reasons|push:"DSCR could not be computed (no debt service) — manual review required") }
      }
      elseif ($dscr >= 1.25) {
        var.update $reasons { value = ($reasons|push:("DSCR " ~ ($dscr|to_text) ~ " ≥ 1.25 — healthy coverage")) }
      }
      elseif ($dscr >= 1.0) {
        var.update $reasons { value = ($reasons|push:("DSCR " ~ ($dscr|to_text) ~ " between 1.00 and 1.25 — marginal coverage")) }
      }
      else {
        var.update $reasons { value = ($reasons|push:("DSCR " ~ ($dscr|to_text) ~ " < 1.00 — income does not cover debt service")) }
      }
    }

    conditional {
      if ($dti == null) {
        var.update $reasons { value = ($reasons|push:"DTI could not be computed (no monthly revenue)") }
      }
      elseif ($dti <= 0.43) {
        var.update $reasons { value = ($reasons|push:("DTI " ~ ($dti|to_text) ~ " ≤ 0.43 — within policy")) }
      }
      elseif ($dti <= 0.5) {
        var.update $reasons { value = ($reasons|push:("DTI " ~ ($dti|to_text) ~ " between 0.43 and 0.50 — elevated, needs review")) }
      }
      else {
        var.update $reasons { value = ($reasons|push:("DTI " ~ ($dti|to_text) ~ " > 0.50 — over policy limit")) }
      }
    }

    conditional {
      if ($book_payments > 0) {
        var.update $reasons { value = ($reasons|push:("Existing loan-book obligations of $" ~ ($book_payments|to_text) ~ "/mo folded into debt service")) }
      }
    }

    conditional {
      if ($runway != null) {
        var.update $reasons { value = ($reasons|push:("Cash runway " ~ ($runway|to_text) ~ " months at current burn")) }
      }
    }

    // 7. Deterministic 0-100 score, clamped.
    var $raw_score { value = ((($dscr ?? 0) * 40) + ((1 - ($dti ?? 1)) * 60)) }
    var $score { value = ($raw_score|round:0) }
    conditional {
      if ($score < 0) {
        var.update $score { value = 0 }
      }
      elseif ($score > 100) {
        var.update $score { value = 100 }
      }
    }

    // 8. Suggested terms (only when not declined).
    var $suggested_terms { value = null }
    conditional {
      if ($outcome != "declined") {
        var.update $suggested_terms {
          value = {
            approved_amount: $input.requested_amount,
            term_months: $input.term_months,
            est_monthly_payment: $new_payment,
            annual_interest_rate: $input.annual_interest_rate
          }
        }
      }
    }

    // 9. Persist the decision.
    db.add "sld_decision" {
      data = {
        application_id: $app.id,
        outcome: $outcome,
        score: ($score|to_int),
        dscr: $dscr,
        dti: $dti,
        cash_runway_months: $runway,
        est_monthly_payment: $new_payment,
        reasons: $reasons,
        suggested_terms: $suggested_terms
      }
    } as $decision

    // 10. Reflect the outcome on the application.
    db.patch "sld_application" {
      field_name = "id"
      field_value = $app.id
      data = {status: $outcome}
    }

    var $result {
      value = {
        decision_id: $decision.id,
        application_id: $app.id,
        outcome: $outcome,
        score: ($score|to_int),
        dscr: $dscr,
        dti: $dti,
        est_monthly_payment: $new_payment,
        reasons: $reasons,
        suggested_terms: $suggested_terms
      }
    }
  }

  response = $result
  guid = "fG69FUFRmAnWFXMR8r4zKa6VFek"
}
