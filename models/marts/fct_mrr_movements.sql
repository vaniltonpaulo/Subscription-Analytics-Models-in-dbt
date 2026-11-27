with customer_mrr as (
    select * from {{ ref('int_customer_monthly_mrr') }}
),

classified as (
    select
        customer_id,
        date_month,
        mrr,
        previous_month_mrr,
        case
            when previous_month_mrr is null
                then 'new'
            when mrr = 0 and previous_month_mrr > 0
                then 'churn'
            when mrr > 0 and previous_month_mrr = 0
                then 'reactivation'
            when mrr > previous_month_mrr
                then 'expansion'
            when mrr < previous_month_mrr
                then 'contraction'
            else 'retained'
        end as change_category,
        mrr - coalesce(previous_month_mrr, 0) as mrr_change
    from customer_mrr
    -- Months between a churn and a reactivation carry no revenue and no
    -- movement; they only exist upstream so that lag() sees the gap.
    where not (mrr = 0 and previous_month_mrr = 0)
)

select * from classified
