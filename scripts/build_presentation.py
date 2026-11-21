"""Generate presentation.pptx for the online-school marketing analytics project."""

from pathlib import Path

import matplotlib.pyplot as plt
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor

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
    bars = ax.barh(campaigns, roi, color=colors)
    ax.axvline(0, color="#333", linewidth=0.8)
    for bar, value in zip(bars, roi):
        x = bar.get_width()
        offset = 8 if x >= 0 else -8
        ha = "left" if x >= 0 else "right"
        ax.text(
            x + offset,
            bar.get_y() + bar.get_height() / 2,
            f"{value:+d}%",
            va="center",
            ha=ha,
            fontsize=11,
            fontweight="bold",
        )
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
        ax.text(
            i,
            v / 2,
            f"{v:,}".replace(",", " "),
            ha="center",
            va="center",
            color="white",
            fontsize=12,
            fontweight="bold",
        )
    conv_vl = values[1] / values[0] * 100
    conv_lp = values[2] / values[1] * 100
    ax.text(0.5, max(values) * 0.92, f"→ {conv_vl:.1f}%", ha="center", fontsize=11)
    ax.text(1.5, max(values) * 0.92, f"→ {conv_lp:.1f}%", ha="center", fontsize=11)
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


def add_dashboard_link_slide(prs: Presentation, url: str) -> None:
    slide = prs.slides.add_slide(prs.slide_layouts[1])
    slide.shapes.title.text = "Ссылка на дашборд"
    tf = slide.placeholders[1].text_frame
    tf.clear()
    p = tf.paragraphs[0]
    p.text = "Интерактивный дашборд (Apache Superset / Preset):"
    p.font.size = Pt(20)
    p2 = tf.add_paragraph()
    run = p2.add_run()
    run.text = url
    run.font.size = Pt(18)
    run.font.color.rgb = RGBColor(0x15, 0x65, 0xC0)
    run.hyperlink.address = url


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

    dash_url = dashboard_url()
    add_dashboard_link_slide(prs, dash_url)
    add_bullet_slide(
        prs,
        "Дашборд",
        [
            "На дашборде: визиты, лиды, расходы, конверсии, CPU, CPL, CPPU, ROI.",
            "Фильтры: период, utm_source, utm_medium, utm_campaign.",
            "SQL-запросы для графиков: файл dashboard.sql в репозитории проекта.",
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
        "Выводы аналитика",
        [
            "Масштабировать окупаемые связки utm_source + campaign из дашборда.",
            "Сократить расходы на кампании с ROI < 0 и CPL выше медианы.",
            "Оценивать кампании через 25+ дней; до этого смотреть только CPL и объём лидов.",
            "Использовать дашборд для еженедельных решений по бюджету.",
        ],
    )

    out = ROOT / "presentation.pptx"
    prs.save(out)
    print(f"Wrote {out}")


if __name__ == "__main__":
    build()