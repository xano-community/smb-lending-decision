table "sld_decision" {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int application_id? {
      table = "sld_application"
    }
    enum outcome {
      values = ["approved", "declined", "referred"]
    }
    int score
    decimal dscr?
    decimal dti?
    decimal cash_runway_months?
    decimal est_monthly_payment?
    json reasons
    json suggested_terms?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "application_id"}]}
    {type: "btree", field: [{name: "outcome"}]}
  ]
  guid = "tOEv5YhGpYi0c2NcCx-eOboPqPo"
}
