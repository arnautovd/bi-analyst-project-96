# Онлайн-школа

[![hexlet-check](https://github.com/arnautovd/bi-analyst-project-96/actions/workflows/hexlet-check.yml/badge.svg)](https://github.com/arnautovd/bi-analyst-project-96/actions)

Помогите маркетологам онлайн-школы создать систему сквозной аналитики

Учебный проект Хекслета: https://ru.hexlet.io/programs/bi-analyst


## Стек

- Разное

## Установка

<!-- Опишите установку: клонирование, зависимости, переменные окружения -->

```bash
git clone https://github.com/arnautovd/bi-analyst-project-96.git
cd bi-analyst-project-96
```

## Использование

**Основной скрипт проекта:** `dashboard.sql` — запросы для дашборда и презентации (по одному `SELECT` на график в Superset).

Подключение к БД: `marketingdb_v2` (PostgreSQL). Фильтры дашборда: `visit_date`, `utm_source`, `utm_medium`, `utm_campaign`.

Презентация для маркетинга: `presentation.pdf`. Ссылка на дашборд — в файле `dashboard_url.txt` (обновите на URL Superset и пересоберите: `python scripts/build_presentation.py`).

---

<details>
<summary>Автоматические тесты Хекслета</summary>

Тесты запускаются на каждый коммит. За запуск отвечает файл `.github/workflows/hexlet-check.yml` — не удаляйте и не переименовывайте ни его, ни репозиторий.

</details>

## О Хекслете

[Хекслет](https://ru.hexlet.io/) — школа программирования: авторские программы обучения с практикой, поддержкой наставников и реальными проектами, которые остаются в резюме. Этот репозиторий — один из таких проектов.
