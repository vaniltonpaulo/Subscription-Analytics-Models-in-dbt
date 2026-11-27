{{
    config(
        materialized='table'
    )
}}

with subscriptions as (
    select * from {{ ref('stg_subscriptions') }}
),

date_spine as (
    select * from {{ ref('int_date_spine') }}
),

subscription_months as (
    select
        s.subscription_id,
        s.customer_id,
        s.plan_name,
        s.mrr_amount,
        d.date_month
    from subscriptions s
    inner join date_spine d
        on s.start_date <= (d.date_month + interval '1 month' - interval '1 day')::date
        and (s.end_date is null or s.end_date >= d.date_month)
)

select * from subscription_months