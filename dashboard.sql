-- 1. Посетители по дням (фильтры: visit_date, utm_source, utm_medium, utm_campaign)
select
    date(s.visit_date) as visit_date,
    s.source as utm_source,
    s.medium as utm_medium,
    s.campaign as utm_campaign,
    count(distinct s.visitor_id) as visitors_count
from sessions as s
where s.medium in (
    'cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social'
)
group by
    date(s.visit_date),
    s.source,
    s.medium,
    s.campaign;

-- 2. Посетители по неделям
select
    date_trunc('week', s.visit_date)::date as visit_week,
    s.source as utm_source,
    count(distinct s.visitor_id) as visitors_count
from sessions as s
where s.medium in (
    'cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social'
)
group by
    date_trunc('week', s.visit_date)::date,
    s.source;

-- 3. Посетители по месяцам
select
    date_trunc('month', s.visit_date)::date as visit_month,
    s.source as utm_source,
    count(distinct s.visitor_id) as visitors_count
from sessions as s
where s.medium in (
    'cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social'
)
group by
    date_trunc('month', s.visit_date)::date,
    s.source;

-- 4. Лиды по дням
select
    date(l.created_at) as visit_date,
    count(distinct l.lead_id) as leads_count
from leads as l
group by date(l.created_at);

-- 5. Расходы по каналам в динамике
select
    date(campaign_date) as visit_date,
    utm_source,
    utm_medium,
    utm_campaign,
    sum(daily_spent) as total_cost
from (
    select campaign_date, utm_source, utm_medium, utm_campaign, daily_spent
    from vk_ads
    union all
    select campaign_date, utm_source, utm_medium, utm_campaign, daily_spent
    from ya_ads
) as ads
group by
    date(campaign_date),
    utm_source,
    utm_medium,
    utm_campaign;

-- 6. Конверсия: визит → лид и лид → оплата (Last Paid Click)
with attributed_sessions as (
    select
        s.visitor_id,
        s.source as utm_source,
        l.lead_id,
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
        'cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social'
    )
)

select
    utm_source,
    count(distinct visitor_id) as visitors_count,
    count(lead_id) as leads_count,
    count(*) filter (
        where status_id = 142
    ) as purchases_count,
    round(
        count(lead_id) * 100.0 / nullif(count(distinct visitor_id), 0),
        2
    ) as conversion_visit_to_lead_pct,
    round(
        count(*) filter (where status_id = 142) * 100.0
        / nullif(count(lead_id), 0),
        2
    ) as conversion_lead_to_purchase_pct
from attributed_sessions
where rn = 1
group by utm_source;

-- 7. Сводная таблица метрик по utm_source (CPU, CPL, CPPU, ROI)
with attributed_sessions as (
    select
        s.visitor_id,
        date(s.visit_date) as visit_date,
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
        'cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social'
    )
),

last_paid_click as (
    select
        visit_date,
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
        visit_date,
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
    group by 1, 2, 3, 4
    union all
    select
        date(campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from ya_ads
    group by 1, 2, 3, 4
),

daily_metrics as (
    select
        lpc.visit_date,
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        lpc.visitors_count,
        lpc.leads_count,
        lpc.purchases_count,
        coalesce(lpc.revenue, 0) as revenue,
        coalesce(costs.total_cost, 0) as total_cost
    from last_paid_click as lpc
    left join ad_costs as costs
        on
            lpc.visit_date = costs.campaign_date
            and lpc.utm_source = costs.utm_source
            and lpc.utm_medium = costs.utm_medium
            and lpc.utm_campaign = costs.utm_campaign
)

select
    visit_date,
    case utm_source
        when 'yandex' then 'Яндекс'
        when 'vk' then 'ВКонтакте'
        when 'telegram' then 'Telegram'
        else utm_source
    end as utm_source_label,
    utm_source,
    sum(visitors_count) as visitors_count,
    sum(leads_count) as leads_count,
    sum(purchases_count) as purchases_count,
    sum(revenue) as revenue,
    sum(total_cost) as total_cost,
    round(
        sum(total_cost) / nullif(sum(visitors_count), 0),
        2
    ) as cpu,
    round(
        sum(total_cost) / nullif(sum(leads_count), 0),
        2
    ) as cpl,
    round(
        sum(total_cost) / nullif(sum(purchases_count), 0),
        2
    ) as cppu,
    round(
        (sum(revenue) - sum(total_cost))
        / nullif(sum(total_cost), 0)
        * 100,
        2
    ) as roi_pct
from daily_metrics
group by
    visit_date,
    utm_source;

-- 8. Детальные метрики по source + medium + campaign (с русскими подписями)
with attributed_sessions as (
    select
        s.visitor_id,
        date(s.visit_date) as visit_date,
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
        'cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social'
    )
),

last_paid_click as (
    select
        visit_date,
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
        visit_date,
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
    group by 1, 2, 3, 4
    union all
    select
        date(campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from ya_ads
    group by 1, 2, 3, 4
)

select
    lpc.visit_date,
    case lpc.utm_source
        when 'yandex' then 'Яндекс'
        when 'vk' then 'ВКонтакте'
        when 'telegram' then 'Telegram'
        else lpc.utm_source
    end as utm_source_label,
    lpc.utm_source,
    lpc.utm_medium,
    case lpc.utm_campaign
        when 'prof-python' then 'Профессия Python'
        when 'prof_python_search' then 'Профессия Python, поиск'
        when 'prof-frontend' then 'Профессия Frontend'
        when 'prof-java' then 'Профессия Java'
        when 'prof-data-analytics' then 'Профессия «Аналитик данных»'
        when 'freemium' then 'Freemium'
        when 'freemium-frontend' then 'Freemium Frontend'
        when 'base-python' then 'ПК Python'
        when 'base-frontend' then 'ПК Frontend'
        when 'dod-php' then 'ДОД PHP'
        when 'hexlet-blog' then 'Блог Hexlet'
        else replace(replace(lpc.utm_campaign, '-', ' '), '_', ' ')
    end as utm_campaign_label,
    lpc.utm_campaign,
    lpc.visitors_count,
    lpc.leads_count,
    lpc.purchases_count,
    coalesce(lpc.revenue, 0) as revenue,
    coalesce(costs.total_cost, 0) as total_cost,
    round(
        coalesce(costs.total_cost, 0)
        / nullif(lpc.visitors_count, 0),
        2
    ) as cpu,
    round(
        coalesce(costs.total_cost, 0) / nullif(lpc.leads_count, 0),
        2
    ) as cpl,
    round(
        coalesce(costs.total_cost, 0)
        / nullif(lpc.purchases_count, 0),
        2
    ) as cppu,
    round(
        (coalesce(lpc.revenue, 0) - coalesce(costs.total_cost, 0))
        / nullif(coalesce(costs.total_cost, 0), 0)
        * 100,
        2
    ) as roi_pct,
    case
        when coalesce(costs.total_cost, 0) = 0 then null
        when coalesce(lpc.revenue, 0) > coalesce(costs.total_cost, 0) then 'Окупается'
        else 'Не окупается'
    end as payback_label
from last_paid_click as lpc
left join ad_costs as costs
    on
        lpc.visit_date = costs.campaign_date
        and lpc.utm_source = costs.utm_source
        and lpc.utm_medium = costs.utm_medium
        and lpc.utm_campaign = costs.utm_campaign;

-- 9. Окупаемость каналов (для слайда «Есть ли окупаемые каналы?»)
with attributed_sessions as (
    select
        s.visitor_id,
        s.source as utm_source,
        l.amount,
        l.status_id,
        l.closing_reason,
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
        'cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social'
    )
),

channel_revenue as (
    select
        utm_source,
        count(*) as visitors_count,
        count(*) filter (where closing_reason = 'successful_sale' or status_id = 142)
            as purchases_count,
        sum(amount) filter (
            where closing_reason = 'successful_sale' or status_id = 142
        ) as revenue
    from attributed_sessions
    where rn = 1
    group by utm_source
),

channel_cost as (
    select utm_source, sum(daily_spent) as total_cost
    from (
        select utm_source, daily_spent from vk_ads
        union all
        select utm_source, daily_spent from ya_ads
    ) as ads
    group by utm_source
)

select
    r.utm_source,
    r.visitors_count,
    r.purchases_count,
    coalesce(r.revenue, 0) as revenue,
    coalesce(c.total_cost, 0) as total_cost,
    round(
        (coalesce(r.revenue, 0) - coalesce(c.total_cost, 0))
        / nullif(coalesce(c.total_cost, 0), 0)
        * 100,
        1
    ) as roi_pct
from channel_revenue as r
left join channel_cost as c on r.utm_source = c.utm_source
where coalesce(c.total_cost, 0) > 0 or coalesce(r.revenue, 0) > 0
order by roi_pct desc nulls last;

-- 10. ROI по кампаниям (для рекомендаций отключить / масштабировать)
with attributed_sessions as (
    select
        s.visitor_id,
        date(s.visit_date) as visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.amount,
        l.status_id,
        l.closing_reason,
        row_number() over (
            partition by s.visitor_id
            order by s.visit_date desc
        ) as rn
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where
        s.medium in (
            'cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social'
        )
        and s.source in ('yandex', 'vk')
),

daily_lpc as (
    select
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        count(visitor_id) as visitors_count,
        sum(amount) filter (
            where closing_reason = 'successful_sale' or status_id = 142
        ) as revenue
    from attributed_sessions
    where rn = 1
    group by 1, 2, 3, 4
),

ad_costs as (
    select
        date(campaign_date) as campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from vk_ads
    group by 1, 2, 3, 4
    union all
    select
        date(campaign_date),
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent)
    from ya_ads
    group by 1, 2, 3, 4
)

select
    l.utm_source,
    l.utm_campaign,
    sum(l.visitors_count) as visitors_count,
    sum(l.revenue) as revenue,
    sum(coalesce(c.total_cost, 0)) as total_cost,
    round(
        (sum(l.revenue) - sum(coalesce(c.total_cost, 0)))
        / nullif(sum(coalesce(c.total_cost, 0)), 0)
        * 100,
        1
    ) as roi_pct
from daily_lpc as l
left join ad_costs as c
    on
        l.visit_date = c.campaign_date
        and l.utm_source = c.utm_source
        and l.utm_medium = c.utm_medium
        and l.utm_campaign = c.utm_campaign
where l.utm_medium = 'cpc'
group by l.utm_source, l.utm_campaign
having sum(coalesce(c.total_cost, 0)) > 5000
order by roi_pct desc;

-- 11. 90-й перцентиль: дней от платного клика до продажи (срок оценки кампании)
with last_paid_visit as (
    select
        s.visitor_id,
        max(s.visit_date) as paid_visit_at
    from sessions as s
    where s.medium in (
        'cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social'
    )
    group by s.visitor_id
),

sales as (
    select
        lp.paid_visit_at,
        l.created_at
    from last_paid_visit as lp
    inner join leads as l
        on
            lp.visitor_id = l.visitor_id
            and l.created_at >= lp.paid_visit_at
    where l.status_id = 142 or l.closing_reason = 'successful_sale'
)

select
    percentile_disc(0.9) within group (
        order by extract(day from (created_at - paid_visit_at))
    ) as p90_days_click_to_sale
from sales;

-- 12. Органика vs платный Яндекс по неделям (корреляция / halo-эффект)
select
    date_trunc('week', s.visit_date)::date as visit_week,
    count(distinct s.visitor_id) filter (where s.medium = 'organic') as organic_visitors,
    count(distinct s.visitor_id) filter (
        where s.medium = 'cpc' and s.source = 'yandex'
    ) as yandex_cpc_visitors
from sessions as s
where s.visit_date >= '2023-06-01' and s.visit_date < '2023-07-01'
group by 1
order by 1;