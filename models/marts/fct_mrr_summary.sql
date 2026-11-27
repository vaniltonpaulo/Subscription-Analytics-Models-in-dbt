with movements as (
    select * from {{ ref('fct_mrr_movements') }}
),

monthly_summary as (
    select
        date_month,
        sum(case when change_category = 'new' then mrr else 0 end) as new_mrr,
        sum(case when change_category = 'reactivation' then mrr else 0 end) as reactivation_mrr,
        sum(case when change_category = 'upgrade' then mrr_change else 0 end) as expansion_mrr,
        sum(case when change_category = 'downgrade' then mrr_change else 0 end) as contraction_mrr,
        sum(case when change_category = 'churn' then previous_month_mrr else 0 end) as churned_mrr,
        sum(mrr) as ending_mrr,
        count(distinct case when mrr > 0 then customer_id end) as active_customers,
        count(distinct case when change_category = 'new' then customer_id end) as new_customers,
        count(distinct case when change_category = 'churn' then customer_id end) as churned_customers
    from movements
    group by date_month
),

with_starting as (
    select
        date_month,
        ending_mrr - new_mrr - reactivation_mrr - expansion_mrr - contraction_mrr + churned_mrr as starting_mrr,
        new_mrr,
        reactivation_mrr,
        expansion_mrr,
        contraction_mrr,
        churned_mrr,
        ending_mrr,
        active_customers,
        new_customers,
        churned_customers
    from monthly_summary
)

select * from with_starting
order by date_month