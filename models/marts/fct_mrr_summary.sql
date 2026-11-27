-- Monthly MRR waterfall. Movements are signed so that
--   starting_mrr + net_new_mrr = ending_mrr
-- holds exactly (checked by tests/assert_mrr_waterfall_balances.sql).

with date_spine as (
    select * from {{ ref('int_date_spine') }}
),

movements as (
    select * from {{ ref('fct_mrr_movements') }}
),

monthly as (
    select
        date_month,

        sum(coalesce(previous_month_mrr, 0)) as starting_mrr,
        sum(case when change_category = 'new' then mrr_change else 0 end) as new_mrr,
        sum(case when change_category = 'reactivation' then mrr_change else 0 end) as reactivation_mrr,
        sum(case when change_category = 'expansion' then mrr_change else 0 end) as expansion_mrr,
        sum(case when change_category = 'contraction' then mrr_change else 0 end) as contraction_mrr,
        sum(case when change_category = 'churn' then mrr_change else 0 end) as churned_mrr,
        sum(mrr) as ending_mrr,

        count(case when previous_month_mrr > 0 then 1 end) as starting_customers,
        count(case when change_category = 'new' then 1 end) as new_customers,
        count(case when change_category = 'reactivation' then 1 end) as reactivated_customers,
        count(case when change_category = 'churn' then 1 end) as churned_customers,
        count(case when mrr > 0 then 1 end) as ending_customers
    from movements
    group by date_month
),

-- Every month of the spine gets a row, even one with no activity.
filled as (
    select
        s.date_month,
        cast(coalesce(m.starting_mrr, 0) as numeric(14, 2)) as starting_mrr,
        cast(coalesce(m.new_mrr, 0) as numeric(14, 2)) as new_mrr,
        cast(coalesce(m.reactivation_mrr, 0) as numeric(14, 2)) as reactivation_mrr,
        cast(coalesce(m.expansion_mrr, 0) as numeric(14, 2)) as expansion_mrr,
        cast(coalesce(m.contraction_mrr, 0) as numeric(14, 2)) as contraction_mrr,
        cast(coalesce(m.churned_mrr, 0) as numeric(14, 2)) as churned_mrr,
        cast(coalesce(m.ending_mrr, 0) as numeric(14, 2)) as ending_mrr,
        coalesce(m.starting_customers, 0) as starting_customers,
        coalesce(m.new_customers, 0) as new_customers,
        coalesce(m.reactivated_customers, 0) as reactivated_customers,
        coalesce(m.churned_customers, 0) as churned_customers,
        coalesce(m.ending_customers, 0) as ending_customers
    from date_spine s
    left join monthly m
        on s.date_month = m.date_month
),

final as (
    select
        date_month,

        -- waterfall
        starting_mrr,
        new_mrr,
        reactivation_mrr,
        expansion_mrr,
        contraction_mrr,
        churned_mrr,
        new_mrr + reactivation_mrr + expansion_mrr + contraction_mrr + churned_mrr as net_new_mrr,
        ending_mrr,
        ending_mrr * 12 as ending_arr,

        -- customers
        starting_customers,
        new_customers,
        reactivated_customers,
        churned_customers,
        ending_customers,
        round(ending_mrr / nullif(ending_customers, 0), 2) as arpa,

        -- rates (null when there is nothing to divide by, e.g. the first month)
        round(
            (ending_mrr - starting_mrr) / nullif(starting_mrr, 0), 4
        ) as mrr_growth_rate,
        round(
            churned_customers::numeric / nullif(starting_customers, 0), 4
        ) as customer_churn_rate,
        round(
            -(contraction_mrr + churned_mrr) / nullif(starting_mrr, 0), 4
        ) as gross_mrr_churn_rate,
        round(
            (starting_mrr + expansion_mrr + contraction_mrr + churned_mrr) / nullif(starting_mrr, 0), 4
        ) as net_mrr_retention,
        round(
            (new_mrr + reactivation_mrr + expansion_mrr) / nullif(-(contraction_mrr + churned_mrr), 0), 2
        ) as quick_ratio
    from filled
)

select * from final
