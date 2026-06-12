// Fetch a single persisted decision by id.
query "decisions/{id}" verb=GET {
  api_group = "SmbLendingDecision"

  input {
    int id { description = "Decision id" }
  }

  stack {
    db.get "sld_decision" {
      field_name = "id"
      field_value = $input.id
    } as $decision

    precondition ($decision != null) {
      error_type = "notfound"
      error = "Decision not found: " ~ ($input.id|to_text)
    }
  }

  response = $decision
  guid = "NOMYxCAqFl1mFMdezxH4Zw4KjOs"
}
