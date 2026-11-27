with source as (
    select * from {{ ref('raw_subscriptions') }}
),

cleaned as (
    select
        subscription_id,
        customer_id,
        plan_name,
        mrr_amount,
        start_date,
        end_date
    from source
    where mrr_amount >= 0
      and (end_date is null or end_date >= start_date)
)

select * from cleaned