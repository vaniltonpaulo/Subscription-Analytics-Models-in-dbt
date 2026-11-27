-- Each month must open exactly where the previous month closed; the first
-- month opens at zero. Catches customers dropping out of the month grid.

with summary as (
    select
        date_month,
        starting_mrr,
        starting_customers,
        lag(ending_mrr, 1, 0) over (order by date_month) as prior_ending_mrr,
        lag(ending_customers, 1, 0) over (order by date_month) as prior_ending_customers
    from {{ ref('fct_mrr_summary') }}
)

select *
from summary
where starting_mrr <> prior_ending_mrr
   or starting_customers <> prior_ending_customers
