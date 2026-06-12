// List loan-book entries, optionally filtered by business.
query "loans" verb=GET {
  api_group = "SmbLendingDecision"

  input {
    text business_id? { description = "Filter by business id" }
    int page?=1 filters=min:1
    int per_page?=50 filters=min:1|max:200
  }

  stack {
    db.query "sld_loan" {
      where = $db.sld_loan.business_id ==? $input.business_id
      sort = {created_at: "desc"}
      return = {type: "list", paging: {page: $input.page, per_page: $input.per_page, totals: true}}
    } as $loans
  }

  response = $loans
  guid = "J1VHCtUUeyh9a_YjJaRFD4fkzGA"
}
