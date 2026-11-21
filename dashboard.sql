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