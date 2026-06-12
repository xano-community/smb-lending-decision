function "sld_summarize_banking" {
  description = "Pure cash-flow rollup over a list of banking transactions. Sums credit inflow and debit outflow, returns net and count. No database access."

  input {
    json transactions { description = "Array of {amount, direction} objects; direction is 'credit' (inflow) or 'debit' (outflow)" }
  }

  stack {
    var $inflow { value = 0 }
    var $outflow { value = 0 }
    var $count { value = 0 }

    foreach ($input.transactions) {
      each as $txn {
        var $dir { value = (($txn|get:"direction") ?? "") }
        var $amt { value = (($txn|get:"amount") ?? 0) }
        conditional {
          if ($dir == "credit") {
            var.update $inflow { value = ($inflow + $amt) }
          }
          elseif ($dir == "debit") {
            var.update $outflow { value = ($outflow + $amt) }
          }
        }
        var.update $count { value = ($count + 1) }
      }
    }

    var $result {
      value = {
        inflow: ($inflow|round:2),
        outflow: ($outflow|round:2),
        net: (($inflow - $outflow)|round:2),
        count: $count
      }
    }
  }

  response = $result

  test "rolls up inflow, outflow, net, and count" {
    input = {
      transactions: [
        {amount: 5000, direction: "credit"},
        {amount: 1200, direction: "debit"},
        {amount: 800, direction: "debit"},
        {amount: 2000, direction: "credit"}
      ]
    }
    expect.to_equal ($response.inflow) { value = 7000 }
    expect.to_equal ($response.outflow) { value = 2000 }
    expect.to_equal ($response.net) { value = 5000 }
    expect.to_equal ($response.count) { value = 4 }
  }

  test "empty transaction list nets to zero" {
    input = {transactions: []}
    expect.to_equal ($response.net) { value = 0 }
    expect.to_equal ($response.count) { value = 0 }
  }
  guid = "3J2J5nGjgJPQm1iY5blr37BXJfM"
}
