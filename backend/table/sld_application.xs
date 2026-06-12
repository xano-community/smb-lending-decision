table "sld_application" {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    text applicant_name filters=trim
    text business_id? filters=trim
    decimal requested_amount
    int term_months
    text purpose?
    enum status?="pending" {
      values = ["pending", "approved", "declined", "referred"]
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "business_id"}]}
    {type: "btree", field: [{name: "status"}]}
  ]
  guid = "7BUMMEiYTvd6amYU6QPbYB-Q524"
}
