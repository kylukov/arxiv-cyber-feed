# Шпаргалка по visualization.R

## Быстрый старт (5 минут)

```r
library(arxivThreatIntel)

# 1. Получить данные
raw <- fetch_arxiv_data(categories = "cs.CR", max_results = 100)
filtered <- filter_cybersecurity(raw)
categorized <- categorize_articles(filtered, mode = "primary")

# 2. Три основных способа использования

# Способ A: Простой график в консоли
plot_category_distribution(categorized, mode = "primary")

# Способ B: Интерактивный веб-дашборд
run_visual_dashboard()  # http://localhost:3838

# Способ C: Сохранить в файл
p <- plot_category_distribution(categorized, mode = "primary")
ggsave("graph.png", p, width = 12, height = 8)
```

---

## Три главные функции

### 1. Распределение по категориям

```r
plot_category_distribution(
  data = categorized,        # Данные из categorize_articles()
  mode = "primary",          # или "multi"
  top_n = NULL               # или 10 (топ-10)
)
```

Результат: Горизонтальная столбчатая диаграмма

---

### 2. Динамика по времени

```r
plot_publication_timeline(
  data = categorized,                 # Данные с published_date
  by = "month",                       # или "week"
  facet_by_category = FALSE           # или TRUE (отдельные графики)
)
```

Результат: Временной график (столбцы по периодам)

---

### 3. Интерактивный дашборд

```r
run_visual_dashboard()                # или с параметрами:
run_visual_dashboard(host = "0.0.0.0", port = 3838)
```

Результат: Веб-интерфейс со всеми графиками

Адрес: http://localhost:3838

---

## Полный рабочий пример

```r
library(arxivThreatIntel)

# Шаг 1: Собрать данные
raw <- fetch_arxiv_data(
  categories = c("cs.CR", "cs.NI"),  # Крипто + Сеть
  max_results = 150,
  verbose = TRUE
)

# Шаг 2: Фильтр
filtered <- filter_cybersecurity(raw, strict_mode = TRUE)

# Шаг 3: Категоризация - ВЫБОР РЕЖИМА
# Вариант A: primary (одна категория)
categorized <- categorize_articles(filtered, mode = "primary", verbose = TRUE)

# Вариант B: multi (несколько категорий на статью)
# categorized <- categorize_articles(filtered, mode = "multi", verbose = TRUE)

# Шаг 4: Статистика
stats <- get_category_stats(categorized, mode = "primary")
print(stats)

# Шаг 5: Визуализация - НА ВЫБОР
# Вариант 1: График распределения
p1 <- plot_category_distribution(categorized, mode = "primary", top_n = 8)
print(p1)

# Вариант 2: График времени
p2 <- plot_publication_timeline(categorized, by = "month", facet_by_category = TRUE)
print(p2)

# Вариант 3: Сохранить оба графика
ggsave("categories.png", p1, width = 12, height = 6, dpi = 300)
ggsave("timeline.png", p2, width = 14, height = 10, dpi = 300)

# Вариант 4: Интерактивный дашборд (полный анализ в браузере)
# run_visual_dashboard()
```

---

## Популярные модификации

### Изменить цвет

```r
p <- plot_category_distribution(categorized, mode = "primary")
p + ggplot2::scale_fill_viridis_d()  # Фиолетовые тона
p + ggplot2::scale_fill_brewer(palette = "Set2")  # Яркие цвета
```

### Изменить тему

```r
p + ggplot2::theme_dark()       # Тёмная
p + ggplot2::theme_bw()         # Чёрно-белая
p + ggplot2::theme_minimal()    # Минимальная (по умолчанию)
```

### Больше деталей

```r
p +
  ggplot2::geom_text(ggplot2::aes(label = n), hjust = -0.3) +  # Числа на столбцах
  ggplot2::theme(
    axis.text = ggplot2::element_text(size = 12),
    plot.title = ggplot2::element_text(size = 16, face = "bold")
  )
```

---

## Частые ошибки и их решение

### "Пустой набор данных"

```r
# Проверить
nrow(raw)
nrow(filtered)
nrow(categorized)

# Если filtered или categorized пусто, попробовать
filtered <- filter_cybersecurity(raw, strict_mode = FALSE)  # Менее строгий фильтр
```

### "Колонка 'published_date' не найдена"

```r
# Проверить
"published_date" %in% names(categorized)

# Убедиться что данные содержат даты
str(categorized)
```

### "Дашборд не запускается"

```r
# Порт занят, попробовать другой
run_visual_dashboard(port = 8080)

# Или убедиться что Shiny установлен
install.packages("shiny")
library(shiny)
```

### "Warning: Removed X rows with missing values"

```r
# Нормальное предупреждение (есть пустые значения)
# Если мешает, можно проверить
sum(is.na(categorized$security_category))
sum(is.na(categorized$published_date))
```

---

## Полезные команды

```r
# Просмотр доступных параметров функции
?plot_category_distribution
?plot_publication_timeline
?run_visual_dashboard

# Просмотр примеров в справке
example(plot_category_distribution)

# Сохранить последний график
ggsave("last_plot.png")

# Сохранить с высоким качеством
ggsave("high_quality.png", dpi = 600, width = 16, height = 10)

# Размеры в разных единицах
ggsave("plot.png", width = 12, height = 8)           # дюймы
ggsave("plot.png", width = 30, height = 20, units = "cm")  # см
ggsave("plot.png", width = 1920, height = 1080, units = "px")  # пиксели
```

---

## Параметры функций (шпаргалка)

| Параметр | Значение | Пример |
|----------|----------|--------|
| mode | "primary" / "multi" | mode = "primary" |
| by | "month" / "week" | by = "month" |
| top_n | число или NULL | top_n = 10 |
| facet_by_category | TRUE / FALSE | facet_by_category = TRUE |
| strict_mode | TRUE / FALSE | strict_mode = TRUE |
| host | IP адрес | host = "0.0.0.0" |
| port | номер порта | port = 3838 |

---

## Когда что использовать

| Задача | Решение |
|--------|---------|
| Быстро посмотреть график | plot_category_distribution() |
| Анализ динамики | plot_publication_timeline() |
| Полный интерактивный анализ | run_visual_dashboard() |
| Сохранить для презентации | ggsave() |
| Изменить цвета/оформление | + ggplot2::theme... |
| Экспортировать данные | write.csv() на stats объекте |

---

## Дашборд: что это дает?

При запуске run_visual_dashboard() вы получаете:

Слева (управление):
- Выбор категорий arXiv
- Количество статей (слайдер)
- Режим (primary/multi)
- Строгость фильтра

Справа (12 графиков):
1. Отчёт (текст)
2. Распределение категорий
3. Динамика по времени
4. Авторы (распределение)
5. Топ-10 авторов
6. arXiv категории
7. Confidence score
8. Тепловая карта
9. Воронка пайплайна
10. Multi-категории
+ + 2 дополнительных

Интерактивно:
- Нажимаете кнопку → обновляются ВСЕ графики
- Меняете параметры → сразу видны результаты

---

## Данные: какой формат?

Минимум для plot_category_distribution():

```r
tibble::tibble(
  security_category = c("Crypto", "Network", "Crypto", ...),  # mode="primary"
  # ИЛИ
  security_categories = list(c("Crypto", "Network"), c("Access"), ...)  # mode="multi"
)
```

Минимум для plot_publication_timeline():

```r
tibble::tibble(
  published_date = as.POSIXct(c("2023-01-15", "2023-01-20", ...)),
  # + опционально security_category для facet_by_category=TRUE
)
```

Что генерирует categorize_articles():
- Все необходимые колонки уже внутри!
- Просто передавайте результат в графики

---

## Производительность

| Операция | Время |
|----------|-------|
| fetch_arxiv_data(100) | 2-5 сек |
| filter_cybersecurity() | <1 сек |
| categorize_articles() | 1-3 сек |
| plot_category_distribution() | <1 сек |
| plot_publication_timeline() | <1 сек |
| run_visual_dashboard() | Открыть браузер ~1 сек |

Дашборд: После нажатия кнопки загрузки, первая визуализация появляется за 5-10 сек

---

## Дальнейшее обучение

Если хотите больше:

1. Прочитайте полный гайд: visualization-guide-clean.md
2. Документация ggplot2: ?ggplot2
3. Примеры: example(plot_category_distribution)
4. RStudio Help: F1 на любой функции

---

Версия: 1.0  
Дата: 2025-12-20  
Статус: Готово
