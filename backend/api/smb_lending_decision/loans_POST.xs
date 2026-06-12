// Add a loan to the loan book (existing obligations).
query "loans" verb=POST {
  api_group = "SmbLendingDecision"

  input {
    text business_id? { description = "Business the loan belongs to" }
    decimal principal { description = "Original loan principal" }
    decimal outstanding_balance { description = "Current outstanding balance" }
    decimal monthly_payment { description = "Required monthly payment" }
    text status? { description = "current, delinquent, or closed" }
  }

  stack {
    var $status { value = ($input.status ?? "current") }
    db.add "sld_loan" {
      data = {
        business_id: $input.business_id,
        principal: $input.principal,
        outstanding_balance: $input.outstanding_balance,
        monthly_payment: $input.monthly_payment,
        status: $status
      }
    } as $loan
  }

  response = $loan
  guid = "fkAh1q866nysSK7Bdud4E1Pl7tk"
}
