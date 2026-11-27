-- One row per month, from the month of the earliest subscription through the
-- month containing the reporting date. Derived from the data so that new
-- history is never silently cut off by a hardcoded range.

{% set as_of = var('mrr_as_of_date') %}

with bounds as (
    select
        date_trunc('month', min(start_date)) as first_month,
        date_trunc(
            'month',
            {% if as_of %} cast('{{ as_of }}' as date) {% else %} current_date {% endif %}
        ) as last_month
    from {{ ref('stg_subscriptions') }}
)

select
    cast(month_start as date) as date_month
from bounds
cross join lateral generate_series(first_month, last_month, interval '1 month') as month_start
