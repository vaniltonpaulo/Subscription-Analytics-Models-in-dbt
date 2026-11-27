-- Ending MRR in the summary must equal the MRR of all subscriptions active
-- in that month, computed independently from the subscription grain.
-- Returns the months where the two disagree, or exist on one side only.

with from_subscriptions as (
    select
        date_month,
        sum(mrr_amount) as mrr
    from {{ ref('int_subscription_months') }}
    group by date_month
),

from_summary as (
    select
        date_month,
        ending_mrr as mrr
    from {{ ref('fct_mrr_summary') }}
    where ending_mrr <> 0
)

select
    coalesce(s.date_month, m.date_month) as date_month,
    s.mrr as subscription_mrr,
    m.mrr as summary_mrr
from from_subscriptions s
full outer join from_summary m
    on s.date_month = m.date_month
where s.mrr is distinct from m.mrr
