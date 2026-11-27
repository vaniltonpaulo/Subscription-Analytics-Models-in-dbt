with spine as (
    {{
        dbt_utils.date_spine(
            datepart="month",
            start_date="cast('2024-01-01' as date)",
            end_date="cast('2025-01-01' as date)"
        )
    }}
)

select
    cast(date_month as date) as date_month
from spine