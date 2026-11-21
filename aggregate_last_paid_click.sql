with attributed_sessions as (
    select
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.amount,
        l.closing_reason,
        l.status_id,
        row_number() over (
            partition by s.visitor_id
            order by s.visit_date desc
        ) as rn
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where s.medium in (
        'cpc',
        'cpm',
        'cpa',
        'youtube',
        'cpp',
        'tg',
        'social'
    )
),

last_paid_click as (
    select
        date(visit_date) as visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        count(visitor_id) as visitors_count,
        count(lead_id) as leads_count,
        count(*) filter (
            where status_id = 142 or closing_reason = 'successful_sale'
        ) as purchases_count,
        sum(amount) filter (
            where status_id = 142 or closing_reason = 'successful_sale'
        ) as revenue
    from attributed_sessions
    where rn = 1
    group by
        date(visit_date),
        utm_source,
        utm_medium,
        utm_campaign
),

ad_costs as (
    select
        date(campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from vk_ads
    group by
        date(campaign_date),
        utm_source,
        utm_medium,
        utm_campaign
    union all
    select
        date(campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from ya_ads
    group by
        date(campaign_date),
        utm_source,
        utm_medium,
        utm_campaign
)

select
    lpc.visit_date,
    lpc.visitors_count,
    lpc.utm_source,
    lpc.utm_medium,
    lpc.utm_campaign,
    costs.total_cost,
    lpc.leads_count,
    lpc.purchases_count,
    lpc.revenue
from last_paid_click as lpc
left join ad_costs as costs
    on
        lpc.visit_date = costs.campaign_date
        and lpc.utm_source = costs.utm_source
        and lpc.utm_medium = costs.utm_medium
        and lpc.utm_campaign = costs.utm_campaign
order by
    lpc.revenue desc nulls last,
    lpc.visit_date asc,
    lpc.visitors_count desc,
    lpc.utm_source asc,
    lpc.utm_medium asc,
    lpc.utm_campaign asc;