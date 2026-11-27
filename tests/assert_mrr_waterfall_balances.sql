-- Every month, starting MRR plus all movements must equal ending MRR,
-- and starting customers plus inflows minus churn must equal ending customers.
-- Returns the months where either does not hold.

select
    date_month,
    starting_mrr,
    net_new_mrr,
    ending_mrr,
    starting_customers,
    new_customers,
    reactivated_customers,
    churned_customers,
    ending_customers
from {{ ref('fct_mrr_summary') }}
where starting_mrr + net_new_mrr <> ending_mrr
   or starting_customers + new_customers + reactivated_customers - churned_customers <> ending_customers
