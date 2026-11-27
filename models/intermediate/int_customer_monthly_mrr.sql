with subscription_months as (
    select * from {{ ref('int_subscription_months') }}
),

customer_mrr as (
    select
        customer_id,
        date_month,
        sum(mrr_amount) as mrr
    from subscription_months
    group by customer_id, date_month
),

-- The spine runs one month past the last active month so that a customer who
-- leaves for good gets a zero-MRR row: that row is where the churn is recorded.
-- Customers still active at the end of the date spine get no extra row,
-- because the join below cannot go past the spine.
customer_bounds as (
    select
        customer_id,
        min(date_month) as first_active_month,
        cast(max(date_month) + interval '1 month' as date) as churn_month
    from customer_mrr
    group by customer_id
),

date_spine as (
    select * from {{ ref('int_date_spine') }}
),

customer_spine as (
    select
        cb.customer_id,
        ds.date_month
    from customer_bounds cb
    inner join date_spine ds
        on ds.date_month >= cb.first_active_month
        and ds.date_month <= cb.churn_month
),

gap_filled as (
    select
        cs.customer_id,
        cs.date_month,
        cast(coalesce(cm.mrr, 0) as numeric(12, 2)) as mrr
    from customer_spine cs
    left join customer_mrr cm
        on cs.customer_id = cm.customer_id
        and cs.date_month = cm.date_month
),

with_previous as (
    select
        customer_id,
        date_month,
        mrr,
        lag(mrr) over (partition by customer_id order by date_month) as previous_month_mrr
    from gap_filled
)

select * from with_previous