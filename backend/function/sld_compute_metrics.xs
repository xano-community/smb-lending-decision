function "sld_compute_metrics" {
  description = "Pure underwriting math. Computes the deterministic simple-interest monthly payment for a requested loan, then derives net operating income (NOI), total debt service, DSCR, DTI, and cash runway. Divide-by-zero cases return null for the affected ratio. No database access."

  input {
    decimal monthly_revenue { description = "Business monthly revenue" }
    decimal monthly_expenses { description = "Business monthly operating expenses (excludes debt service)" }
    decimal requested_amount { description = "Requested loan principal" }
    int term_months { description = "Loan term in months" }
    decimal existing_debt_payments?=0 { description = "Existing monthly debt obligations" }
    decimal cash_on_hand? { description = "Liquid cash available" }
    decimal annual_interest_rate?=0.12 { description = "Annual interest rate as a decimal (e.g. 0.12 = 12%)" }
  }

  stack {
    // Deterministic simple-interest payment: principal + total interest, spread evenly over the term.
    var $new_payment { value = 0 }
    conditional {
      if ($input.term_months > 0) {
        var $total_repay { value = ($input.requested_amount * (1 + ($input.annual_interest_rate * ($input.term_months / 12)))) }
        var.update $new_payment { value = (($total_repay / $input.term_months)|round:2) }
      }
    }

    var $noi { value = (($input.monthly_revenue - $input.monthly_expenses)|round:2) }
    var $existing { value = ($input.existing_debt_payments ?? 0) }
    var $total_debt_service { value = (($existing + $new_payment)|round:2) }

    // DSCR = NOI / total debt service (guard divide-by-zero -> null)
    var $dscr { value = null }
    conditional {
      if ($total_debt_service > 0) {
        var.update $dscr { value = (($noi / $total_debt_service)|round:2) }
      }
    }

    // DTI = total debt service / monthly revenue (guard divide-by-zero -> null)
    var $dti { value = null }
    conditional {
      if ($input.monthly_revenue > 0) {
        var.update $dti { value = (($total_debt_service / $input.monthly_revenue)|round:2) }
      }
    }

    // Cash runway = cash on hand / monthly expenses, only when both present and expenses > 0
    var $cash_runway_months { value = null }
    conditional {
      if (($input.cash_on_hand != null) && ($input.monthly_expenses > 0)) {
        var.update $cash_runway_months { value = (($input.cash_on_hand / $input.monthly_expenses)|round:2) }
      }
    }

    var $result {
      value = {
        new_payment: $new_payment,
        noi: $noi,
        total_debt_service: $total_debt_service,
        dscr: $dscr,
        dti: $dti,
        cash_runway_months: $cash_runway_months
      }
    }
  }

  response = $result

  test "strong borrower clears a 1.25 DSCR" {
    input = {
      monthly_revenue: 50000,
      monthly_expenses: 30000,
      requested_amount: 100000,
      term_months: 24,
      existing_debt_payments: 2000
    }
    expect.to_be_greater_than ($response.dscr) { value = 1.25 }
  }

  test "thin borrower falls below a 1.0 DSCR" {
    input = {
      monthly_revenue: 20000,
      monthly_expenses: 19000,
      requested_amount: 200000,
      term_months: 12
    }
    expect.to_be_less_than ($response.dscr) { value = 1.0 }
  }

  test "computes cash runway when cash on hand is supplied" {
    input = {
      monthly_revenue: 50000,
      monthly_expenses: 25000,
      requested_amount: 50000,
      term_months: 36,
      cash_on_hand: 100000
    }
    expect.to_equal ($response.cash_runway_months) { value = 4 }
  }

  test "zero monthly revenue yields a null DTI" {
    input = {
      monthly_revenue: 0,
      monthly_expenses: 0,
      requested_amount: 10000,
      term_months: 12
    }
    expect.to_be_null ($response.dti)
  }
  guid = "SpXUuYWPh_7iM1CDS3HEj6Rr_9I"
}
