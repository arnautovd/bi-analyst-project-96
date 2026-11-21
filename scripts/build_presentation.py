"""Generate presentation.pptx for the online-school marketing analytics project."""

from pathlib import Path

import matplotlib.pyplot as plt
from pptx import Presentation
from pptx.util import Inches, Pt

ROOT = Path(__file__).resolve().parents[1]
CHARTS = ROOT / "presentation_charts"
URL_FILE = ROOT / "dashboard_url.txt"


def dashboard_url() -> str:
    if URL_FILE.exists():
        for line in URL_FILE.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                return line
    return "https://github.com/arnautovd/bi-analyst-project-96"

CHARTS.mkdir(exist_ok=True)


def save_roi_chart() -> Path:
    campaigns = [
        "freemium\n(Yandex)",
        "base-frontend\n(Yandex)",
        "freemium-frontend\n(VK)",
        "prof-python\n(VK)",
        "prof-frontend\n(VK)",
    ]
    roi = [423, 563, 329, 145, -100]
    colors = ["#2e7d32" if v > 0 else "#c62828" for v in roi]
    fig, ax = plt.subplots(figsize=(8, 4.5))
    ax.barh(campaigns, roi, color=colors)
    ax.axvline(0, color="#333", linewidth=0.8)
    ax.set_xlabel("ROI, %")
    ax.set_title("Окупаемость ключевых кампаний (июнь 2023)")
    fig.tight_layout()
    path = CHARTS / "roi_campaigns.png"
    fig.savefig(path, dpi=150)
    plt.close(fig)
    return path


def save_funnel_chart() -> Path:
    stages = ["Платные визиты\n(LPC)", "Лиды", "Продажи"]
    values = [34081, 706, 85]
    fig, ax = plt.subplots(figsize=(7, 4))
    ax.bar(stages, values, color=["#1565c0", "#42a5f5", "#66bb6a"])
    ax.set_title("Воронка: Яндекс + VK, июнь 2023")
    for i, v in enumerate(values):
        ax.text(i, v + max(values) * 0.02, f"{v:,}".replace(",", " "), ha="center")
    fig.tight_layout()
    path = CHARTS / "funnel.png"
    fig.savefig(path, dpi=150)
    plt.close(fig)
    return path


def add_title_slide(prs: Presentation) -> None:
    slide = prs.slides.add_slide(prs.slide_layouts[0])
    slide.shapes.title.text = "Сквозная аналитика онлайн-школы"
    slide.placeholders[1].text = (
        "Last Paid Click · CPU / CPL / CPPU / ROI\n"
        "Отчёт для отдела маркетинга · июнь 2023"
    )


def add_bullet_slide(prs: Presentation, title: str, bullets: list[str]) -> None:
    slide = prs.slides.add_slide(prs.slide_layouts[1])
    slide.shapes.title.text = title
    tf = slide.placeholders[1].text_frame
    tf.clear()
    for i, line in enumerate(bullets):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.text = line
        p.level = 0
        p.font.size = Pt(20)


def add_image_slide(prs: Presentation, title: str, image: Path, note: str = "") -> None:
    slide = prs.slides.add_slide(prs.slide_layouts[5])
    slide.shapes.title.text = title
    slide.shapes.add_picture(str(image), Inches(0.8), Inches(1.4), width=Inches(8.4))
    if note:
        box = slide.shapes.add_textbox(Inches(0.8), Inches(6.2), Inches(8.4), Inches(0.8))
        box.text_frame.text = note


def build() -> None:
    roi_img = save_roi_chart()
    funnel_img = save_funnel_chart()

    prs = Presentation()
    add_title_slide(prs)

    add_bullet_slide(
        prs,
        "Задача и метод",
        [
            "Проследили путь пользователя от рекламы до оплаты.",
            "Атрибуция: Last Paid Click — засчитываем последний платный клик.",
            "Источники: PostgreSQL marketingdb_v2 (sessions, leads, vk_ads, ya_ads).",
            "Интерактивный дашборд: Apache Superset (фильтры по дате и UTM).",
        ],
    )

    add_bullet_slide(
        prs,
        "Дашборд",
        [
            f"Ссылка: {dashboard_url()}",
            "На дашборде: визиты, лиды, расходы, конверсии, CPU, CPL, CPPU, ROI.",
            "Фильтры: период, utm_source, utm_medium, utm_campaign.",
            "SQL-запросы лежат в файле dashboard.sql в репозитории проекта.",
        ],
    )

    add_image_slide(
        prs,
        "Воронка по платному трафику",
        funnel_img,
        "Конверсия визит → лид ≈ 2,1%; лид → продажа ≈ 12% (Яндекс + VK).",
    )

    add_image_slide(
        prs,
        "Окупаемость кампаний",
        roi_img,
        "Зелёным — каналы с положительным ROI; красным — убыточные.",
    )

    add_bullet_slide(
        prs,
        "Есть ли окупаемые каналы?",
        [
            "Да. Лучшие: Яндекс freemium (ROI ≈ +423%), base-frontend (+563%), VK freemium-frontend (+329%).",
            "ВКонтакте в целом за месяц окупается: выручка ~1,02 млн ₽ при расходе ~0,75 млн ₽.",
            "Яндекс Директ в сумме чуть ниже нуля (~−10% ROI) — из-за дорогих кампаний без продаж.",
            "Telegram cpp: одна продажа при нулевых расходах в ads — хороший вспомогательный канал.",
        ],
    )

    add_bullet_slide(
        prs,
        "Что отключить / улучшить / не трогать",
        [
            "Отключить или пересобрать: VK prof-frontend, prof-data-analytics, freemium-java (расходы без выручки).",
            "Доработать: Яндекс prof-java, dod-* — много лидов, мало продаж; проверить посадочные и оффер.",
            "Не трогать: freemium и base-* на Яндексе, freemium-frontend и prof-python на VK.",
        ],
    )

    add_bullet_slide(
        prs,
        "Когда смотреть результаты кампании?",
        [
            "90% успешных продаж закрываются в течение 25 дней после платного клика.",
            "Рекомендация: оценивать ROI кампании не раньше чем через 3–4 недели после старта.",
            "Еженедельно на дашборде — операционный контроль расходов и лидов.",
        ],
    )

    add_bullet_slide(
        prs,
        "Органика и реклама",
        [
            "Органический трафик (medium=organic) на порядок больше платного.",
            "В недели с активным Яндекс CPC органика тоже высокая — эффект бренда, не прямая причинность.",
            "Отдельно отслеживать органику после паузы платных кампаний, прежде чем выводить о halo-эффекте.",
        ],
    )

    add_bullet_slide(
        prs,
        "Выводы",
        [
            "Масштабировать окупаемые связки utm_source + campaign из дашборда.",
            "Сократить расходы на кампании с ROI < 0 и CPL выше медианы.",
            "Использовать дашборд для еженедельных решений по бюджету.",
        ],
    )

    out = ROOT / "presentation.pptx"
    prs.save(out)
    print(f"Wrote {out}")


if __name__ == "__main__":
    build()