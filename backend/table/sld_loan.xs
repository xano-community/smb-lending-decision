table "sld_loan" {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    text business_id? filters=trim
    decimal principal
    decimal outstanding_balance
    decimal monthly_payment
    enum status?="current" {
      values = ["current", "delinquent", "closed"]
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "business_id"}]}
    {type: "btree", field: [{name: "status"}]}
  ]
  guid = "2ASuOE-GeJM5ZQXW2ty70HuQa6Y"
}
