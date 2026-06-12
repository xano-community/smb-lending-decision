// List loan applications, optionally filtered by status or business.
query "applications" verb=GET {
  api_group = "SmbLendingDecision"

  input {
    text status? { description = "Filter by status (pending, approved, declined, referred)" }
    text business_id? { description = "Filter by business id" }
    int page?=1 filters=min:1
    int per_page?=50 filters=min:1|max:200
  }

  stack {
    db.query "sld_application" {
      where = $db.sld_application.status ==? $input.status && $db.sld_application.business_id ==? $input.business_id
      sort = {created_at: "desc"}
      return = {type: "list", paging: {page: $input.page, per_page: $input.per_page, totals: true}}
    } as $applications
  }

  response = $applications
  guid = "EMoQQkOrNjuV5ZxN6FZtF-BN-qU"
}
