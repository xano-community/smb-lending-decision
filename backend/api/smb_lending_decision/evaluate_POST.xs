// Run the full DSCR/DTI underwriting decision and persist it.
query "evaluate" verb=POST {
  api_group = "SmbLendingDecision"

  input {
    text applicant_name { description = "Legal name of the applicant business" }
    text business_id? { description = "Stable business id used to fold in loan-book obligations" }
    decimal requested_amount { description = "Requested loan principal" }
    int term_months { description = "Loan term in months" }
    text purpose? { description = "Stated purpose of the loan" }
    decimal monthly_revenue { description = "Business monthly revenue" }
    decimal monthly_expenses { description = "Business monthly operating expenses" }
    decimal existing_debt_payments?=0 { description = "Existing monthly debt not in the loan book" }
    decimal cash_on_hand? { description = "Liquid cash available" }
    decimal annual_interest_rate?=0.12 { description = "Annual interest rate as a decimal (0.12 = 12%)" }
  }

  stack {
    function.run "sld_evaluate" {
      input = {
        applicant_name: $input.applicant_name,
        business_id: $input.business_id,
        requested_amount: $input.requested_amount,
        term_months: $input.term_months,
        purpose: $input.purpose,
        monthly_revenue: $input.monthly_revenue,
        monthly_expenses: $input.monthly_expenses,
        existing_debt_payments: $input.existing_debt_payments,
        cash_on_hand: $input.cash_on_hand,
        annual_interest_rate: $input.annual_interest_rate
      }
    } as $result
  }

  response = $result
  guid = "dMVnaNJw8bs6Z33gP2JyZnOI_6w"
}
