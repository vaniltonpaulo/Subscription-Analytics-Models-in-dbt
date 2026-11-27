{{
    config(
        materialized='table'
    )
}}

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
                then 'upgrade'
            when mrr < previous_month_mrr and mrr > 0
                then 'downgrade'
            else 'no_change'
        end as change_category,
        mrr - coalesce(previous_month_mrr, 0) as mrr_change
    from customer_mrr
)

select * from classified