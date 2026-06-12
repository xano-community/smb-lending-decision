// Create a loan application.
query "applications" verb=POST {
  api_group = "SmbLendingDecision"

  input {
    text applicant_name { description = "Legal name of the applicant business" }
    text business_id? { description = "Stable business id" }
    decimal requested_amount { description = "Requested loan principal" }
    int term_months { description = "Loan term in months" }
    text purpose? { description = "Stated purpose of the loan" }
  }

  stack {
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
  }

  response = $app
  guid = "ffDU79waonHDcLA-_M2dgwoqB9U"
}
