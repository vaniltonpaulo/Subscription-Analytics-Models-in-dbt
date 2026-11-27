{{
    config(
        materialized='table'
    )
}}

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

customer_bounds as (
    select
        customer_id,
        min(date_month) as first_active_month,
        max(date_month) as last_active_month
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
        and ds.date_month <= cb.last_active_month
),

gap_filled as (
    select
        cs.customer_id,
        cs.date_month,
        coalesce(cm.mrr, 0) as mrr
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