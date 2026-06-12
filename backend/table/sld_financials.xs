table "sld_financials" {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int application_id? {
      table = "sld_application"
    }
    decimal annual_revenue?
    decimal monthly_revenue?
    decimal monthly_expenses?
    decimal net_income?
    decimal existing_debt_payments?
    decimal cash_on_hand?
    enum source?="manual" {
      values = ["dynamics365", "manual"]
    }
    json raw?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "application_id"}]}
  ]
  guid = "vuOk5zX_UrxTfCYQzNHpbsnzTN4"
}
