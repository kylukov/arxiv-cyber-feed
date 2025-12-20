# Полное руководство по visualization.R

Проект: arxiv-cyber-feed  
Файл: R/visualization.R  
Размер: 22KB (550+ строк)  
Описание: Визуализация данных и интерактивный Shiny dashboard

---

## Содержание

1. [Обзор возможностей](#обзор-возможностей)
2. [Структура файла](#структура-файла)
3. [Функции для графиков](#функции-для-графиков)
4. [Shiny Dashboard](#shiny-dashboard)
5. [Примеры использования](#примеры-использования)
6. [Работа с данными](#работа-с-данными)
7. [Кастомизация](#кастомизация)
8. [Troubleshooting](#troubleshooting)

---

## Обзор возможностей

Файл visualization.R предоставляет:

3 основные функции для графиков:
- plot_category_distribution() - распределение статей по категориям
- plot_publication_timeline() - динамика публикаций во времени
- run_visual_dashboard() - интерактивный веб-дашборд

12 интерактивных визуализаций в Shiny:
- Распределение по тематикам
- Динамика во времени
- Анализ авторов
- Тепловые карты
- Воронка пайплайна
- И другие...

---

## Структура файла

visualization.R
│
├─ Зависимости (library() блок)
│  ├─ dplyr        # манипуляция данными
│  ├─ ggplot2      # построение графиков
│  ├─ lubridate    # работа с датами
│  └─ shiny        # интерактивный веб-интерфейс
│
├─ Функция 1: plot_category_distribution()
│  └─ Столбчатая диаграмма распределения категорий
│
├─ Функция 2: plot_publication_timeline()
│  └─ Динамика публикаций (по месяцам/неделям)
│
└─ Функция 3: run_visual_dashboard()
   ├─ UI (пользовательский интерфейс)
   │  ├─ Левая панель: элементы управления
   │  └─ Правая область: 10+ графиков
   │
   └─ Server (обработка событий)
      ├─ Сбор данных из arXiv
      ├─ Фильтрация по кибербезопасности
      ├─ Категоризация статей
      └─ Рендеринг всех графиков

---

## Функции для графиков

### 1. plot_category_distribution()

Назначение: Показать распределение статей по категориям безопасности

Параметры:

```r
plot_category_distribution(
  data,           # Датафрейм из categorize_articles()
  mode = c("primary", "multi"),  # Режим категоризации
  top_n = NULL    # Показать только топ N категорий
)
```

Параметры подробно:

- data (обязательно)
  - Датафрейм, возвращённый из categorize_articles()
  - Должен содержать колонку security_category (при mode="primary") или security_categories (при mode="multi")

- mode (default: "primary")
  - "primary": каждая статья имеет одну основную категорию
  - "multi": статья может иметь несколько категорий
  - Тип: character (выбор из предложенных вариантов)

- top_n (default: NULL, т.е. показывает все)
  - Число: сколько топ-категорий показывать (например, top_n = 5)
  - NULL: показывает все категории
  - Полезно при большом количестве категорий

Результат:

- Объект класса ggplot (можно вывести, сохранить, модифицировать)
- Горизонтальная столбчатая диаграмма (категории слева, количество справа)
- Категории отсортированы по убыванию количества статей

Примеры:

```r
library(arxivThreatIntel)

# Пример 1: Базовое использование (primary режим)
raw <- fetch_arxiv_data(categories = "cs.CR", max_results = 50)
filtered <- filter_cybersecurity(raw)
categorized <- categorize_articles(filtered, mode = "primary")

# Построить график
p <- plot_category_distribution(categorized, mode = "primary")
print(p)

# Пример 2: Multi режим со всеми категориями
categorized_multi <- categorize_articles(filtered, mode = "multi")
p2 <- plot_category_distribution(categorized_multi, mode = "multi")
print(p2)

# Пример 3: Показать только топ-5 категорий
p3 <- plot_category_distribution(categorized, mode = "primary", top_n = 5)
print(p3)

# Пример 4: Сохранить в файл
ggplot2::ggsave("categories_distribution.png", p, width = 10, height = 6)
```

Что видит пользователь:

```
Категория безопасности         Количество статей
────────────────────────────────────────────────
Криптография              |████████████ 45
Сетевая безопасность      |██████████ 38
Контроль доступа          |████████ 32
Вредоносное ПО            |██████ 24
Веб-безопасность          |████ 18
```

---

### 2. plot_publication_timeline()

Назначение: Показать динамику публикаций во времени

Параметры:

```r
plot_publication_timeline(
  data,                    # Датафрейм с published_date
  by = c("month", "week"), # Период агрегации
  facet_by_category = FALSE  # Разные графики для каждой категории?
)
```

Параметры подробно:

- data (обязательно)
  - Датафрейм из categorize_articles()
  - ОБЯЗАТЕЛЬНО содержит колонку published_date (дата публикации)
  - ОПЦИОНАЛЬНО может содержать security_category для фасетирования

- by (default: "month")
  - "month": агрегировать по месяцам
  - "week": агрегировать по неделям
  - Влияет на детальность графика и группировку данных

- facet_by_category (default: FALSE)
  - FALSE: один общий график для всех категорий
  - TRUE: отдельный субграфик для каждой категории
  - Работает только если mode="primary" и есть security_category
  - При TRUE создаёт матрицу подграфиков (например, 3×4 для 12 категорий)

Результат:

- Объект ggplot2 с столбчатой диаграммой времени
- X-ось: временные периоды (месяцы или недели)
- Y-ось: количество публикаций за период

Примеры:

```r
# Пример 1: Динамика по месяцам (общая)
p <- plot_publication_timeline(categorized, by = "month", facet_by_category = FALSE)
print(p)

# Пример 2: Динамика по неделям
p2 <- plot_publication_timeline(categorized, by = "week", facet_by_category = FALSE)
print(p2)

# Пример 3: Для каждой категории отдельно (primary режим)
categorized_primary <- categorize_articles(filtered, mode = "primary")
p3 <- plot_publication_timeline(categorized_primary, 
                                 by = "month", 
                                 facet_by_category = TRUE)
print(p3)
# Результат: матрица графиков, каждый для одной категории

# Пример 4: Multi режим (facet_by_category не работает, т.к. категорий несколько)
p4 <- plot_publication_timeline(categorized_multi, 
                                 by = "month", 
                                 facet_by_category = FALSE)
print(p4)
```

Что видит пользователь:

```
Динамика публикаций по времени
────────────────────────────────
Количество статей
│
│     ┌──┐
│ ┌───┤  ├────┐
│ │   └──┘    │  ┌──┐
│ │           ├──┤  ├──┐
├─┼───────────┼──┴──┴──┴──────────
│ Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec
└────────────────────────────────────────────────
```

---

## Shiny Dashboard

### run_visual_dashboard()

Назначение: Запустить интерактивный веб-дашборд для сбора и анализа данных

Параметры:

```r
run_visual_dashboard(
  host = "0.0.0.0",  # Адрес хоста (0.0.0.0 - доступен для всех)
  port = 3838        # Порт (стандартный для Shiny)
)
```

Запуск:

```r
# Базовый запуск (локально на порте 3838)
run_visual_dashboard()

# Или если нужна кастомизация
run_visual_dashboard(host = "127.0.0.1", port = 8080)
```

Доступ в браузер:

```
http://localhost:3838
```

Интерфейс состоит из:

ЛЕВАЯ ПАНЕЛЬ УПРАВЛЕНИЯ (sidebar):

1. arXiv категории (выбор множества)
   - Список: cs.CR, cs.NI, cs.AI, cs.SE, cs.DC, cs.LG, cs.CY, cs.DB, cs.IR, stat.ML, math.OC
   - Default: cs.CR, cs.NI (Криптография и Сетевая безопасность)
   - Можно выбрать несколько категорий

2. Количество статей (max_results) (слайдер)
   - Диапазон: 10-200
   - Default: 100
   - Больше статей → дольше сбор, но более полные данные

3. Режим категоризации (radio button)
   - primary: одна категория на статью (быстро)
   - multi: несколько категорий на статью (детально)
   - Влияет на все графики

4. Строгий режим фильтрации (checkbox)
   - Default: TRUE (включено)
   - Использует расширенный список терминов кибербезопасности
   - При включении фильтр строже

5. Кнопка "Загрузить и проанализировать"
   - Запускает весь пайплайн:
     1. Сбор из arXiv API
     2. Фильтрация по кибербезопасности
     3. Категоризация статей
     4. Рендеринг всех графиков

ПРАВАЯ ОБЛАСТЬ (12 графиков):

| # | График | Тип | Описание |
|---|---------|-----|----------|
| 1 | Краткий отчёт | Текст | Количество: raw/filtered/categorized |
| 2 | Распределение по тематикам | Столбцы | Статьи по категориям безопасности |
| 3 | Динамика публикаций | Столбцы | Публикации по времени |
| 4 | Авторы на статью | Гистограмма | Распределение числа авторов |
| 5 | Топ-10 авторов | Столбцы | Самые продуктивные авторы |
| 6 | arXiv категории | Столбцы | Исходные категории (топ-15) |
| 7 | Уверенность категоризации | Гистограмма | Распределение confidence scores |
| 8 | Пересечение категорий | Тепловая карта | arXiv × Security категории |
| 9 | Воронка пайплайна | Столбцы | raw → filtered → categorized |
| 10 | Security категории на статью | Гистограмма | Только для multi режима |

---

## Примеры использования

### Сценарий 1: Простой анализ в R консоли

```r
library(arxivThreatIntel)

# 1. Собрать данные
raw <- fetch_arxiv_data(
  categories = c("cs.CR", "cs.NI"),
  max_results = 100,
  verbose = TRUE
)

# 2. Отфильтровать
filtered <- filter_cybersecurity(raw, strict_mode = TRUE)

# 3. Категоризировать
categorized <- categorize_articles(filtered, mode = "primary", verbose = TRUE)

# 4. Статистика
stats <- get_category_stats(categorized, mode = "primary")
print(stats)

# 5. Визуализация 1: Распределение по категориям
p1 <- plot_category_distribution(categorized, mode = "primary", top_n = 10)
print(p1)

# 6. Визуализация 2: Динамика по месяцам
p2 <- plot_publication_timeline(categorized, by = "month", facet_by_category = TRUE)
print(p2)

# 7. Сохранить графики
ggsave("categories.png", p1, width = 12, height = 6)
ggsave("timeline.png", p2, width = 12, height = 8)
```

### Сценарий 2: Интерактивный дашборд

```r
library(arxivThreatIntel)

# Запустить дашборд
run_visual_dashboard()

# Откроется окно браузера с интерфейсом
# Пользователь может:
# - Выбрать категории
# - Задать количество статей
# - Выбрать режим категоризации
# - Нажать кнопку загрузки
# - Увидеть все графики в реальном времени
```

### Сценарий 3: Кастомизированный анализ

```r
library(arxivThreatIntel)
library(ggplot2)

# Собрать и обработать
raw <- fetch_arxiv_data(categories = "cs.CR", max_results = 150)
filtered <- filter_cybersecurity(raw, strict_mode = TRUE)
categorized <- categorize_articles(filtered, mode = "multi")

# Базовый график
p <- plot_category_distribution(categorized, mode = "multi")

# Кастомизация (добавить свой стиль)
p_custom <- p +
  ggplot2::theme_dark() +
  ggplot2::labs(
    title = "Анализ кибербезопасности на arXiv",
    subtitle = "Категоризация 150 последних статей",
    caption = "Источник: arXiv API"
  ) +
  ggplot2::theme(
    plot.title = ggplot2::element_text(size = 16, face = "bold", hjust = 0.5),
    plot.subtitle = ggplot2::element_text(size = 12, hjust = 0.5),
    axis.title = ggplot2::element_text(size = 12)
  )

print(p_custom)
ggsave("custom_analysis.png", p_custom, width = 14, height = 8, dpi = 300)
```

---

## Работа с данными

### Какой формат данных нужен?

Для plot_category_distribution():

```r
categorized <- tibble::tibble(
  arxiv_id = c("2301.00001", "2301.00002", ...),
  title = c("Title 1", "Title 2", ...),
  security_category = c("Cryptography", "Network", ...),  # primary режим
  # ИЛИ
  security_categories = list(c("Cryptography", "Network"), c("Access Control"), ...),  # multi режим
  ...
)
```

Для plot_publication_timeline():

```r
categorized <- tibble::tibble(
  arxiv_id = c("2301.00001", "2301.00002", ...),
  published_date = c(as.POSIXct("2023-01-15"), as.POSIXct("2023-01-20"), ...),
  security_category = c("Cryptography", "Network", ...),  # опционально для facet
  ...
)
```

### Проверка данных перед графиком:

```r
# Проверить структуру
str(categorized)
head(categorized)

# Проверить наличие нужных колонок
"published_date" %in% names(categorized)
"security_category" %in% names(categorized)

# Проверить количество записей
nrow(categorized)

# Проверить пропуски
sum(is.na(categorized$published_date))
sum(is.na(categorized$security_category))
```

---

## Кастомизация

### Изменение цветов

```r
# Базовый график
p <- plot_category_distribution(categorized, mode = "primary")

# Изменить цвет столбцов
p + ggplot2::scale_fill_manual(
  values = c(
    "Cryptography" = "#FF6B6B",
    "Network" = "#4ECDC4",
    "Malware" = "#FFE66D",
    "Access Control" = "#95E1D3"
  )
)

# Или использовать готовую палитру
p + ggplot2::scale_fill_viridis_d()
p + ggplot2::scale_fill_brewer(palette = "Set2")
```

### Изменение темы

```r
# Тёмная тема
p + ggplot2::theme_dark()

# Журнальная тема
p + ggplot2::theme_bw()

# Минимальная (используется по умолчанию)
p + ggplot2::theme_minimal()

# Пустая (только данные)
p + ggplot2::theme_void()
```

### Изменение размеров текста и элементов

```r
p +
  ggplot2::theme(
    # Размеры текста
    plot.title = ggplot2::element_text(size = 18, face = "bold"),
    axis.title = ggplot2::element_text(size = 14),
    axis.text = ggplot2::element_text(size = 12),
    
    # Углы оси X
    axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
    
    # Легенда
    legend.position = "bottom",
    legend.text = ggplot2::element_text(size = 10)
  )
```

### Добавление аннотаций

```r
# Добавить значения на столбцы
p +
  ggplot2::geom_text(
    ggplot2::aes(label = n),
    hjust = -0.3,
    size = 4
  )

# Добавить линию тренда (для timeline)
p +
  ggplot2::geom_smooth(
    method = "loess",
    se = TRUE,
    alpha = 0.2,
    color = "red"
  )
```

---

## Troubleshooting

### Проблема 1: "Пустой набор данных: нечего визуализировать"

Причина: Функция получила пустой датафрейм

Решение:

```r
# Проверить данные
nrow(categorized)  # Должно быть > 0

# Если 0, то проблема в предыдущих шагах:
nrow(raw)       # Было ли чего загружать?
nrow(filtered)  # Сработал ли фильтр по кибербезопасности?

# Попробовать с менее строгим фильтром
filtered <- filter_cybersecurity(raw, strict_mode = FALSE)
```

### Проблема 2: "В данных отсутствует колонка 'published_date'"

Причина: Функция plot_publication_timeline() требует эту колонку

Решение:

```r
# Проверить наличие колонки
"published_date" %in% names(categorized)

# Если её нет, то данные из categorize_articles без даты
# Убедиться, что исходные данные содержали dates
str(categorized)
```

### Проблема 3: "Много предупреждений о NaN"

Причина: Много пропущенных значений в данных

Решение:

```r
# Отфильтровать строки с пропусками
categorized_clean <- categorized %>%
  dplyr::filter(!is.na(security_category), 
                !is.na(published_date))

# Или игнорировать предупреждения (не рекомендуется)
suppressWarnings(plot_category_distribution(categorized))
```

### Проблема 4: Дашборд не запускается

Причина: Порт 3838 занят или недостаточно памяти

Решение:

```r
# Попробовать другой порт
run_visual_dashboard(port = 8080)

# Проверить занятые порты (на Linux/Mac)
# lsof -i :3838

# Или убить процесс на этом порте (нужна осторожность)
# kill -9 <PID>
```

### Проблема 5: Графики выглядят странно

Причина: Разное разрешение, размер окна, font issues

Решение:

```r
# Явно задать размер при сохранении
ggsave("plot.png", p, width = 12, height = 8, dpi = 300)

# Или изменить размер шрифтов
p + ggplot2::theme_minimal(base_size = 14)

# Для дашборда - пересчитать CSS стили (в коде run_visual_dashboard)
```

### Проблема 6: Dашборд медленный или зависает

Причина: Слишком много данных (max_results > 500) или недостаточная память

Решение:

```r
# Уменьшить max_results в UI (по умолчанию 200)
# Или увеличить timeout в Shiny

options(shiny.maxRequestSize = 100*1024^2)  # 100MB
options(shiny.error = browser)  # Для отладки ошибок
```

---

## Быстрая справка по функциям

| Функция | Назначение | Вход | Выход |
|---------|-----------|------|-------|
| plot_category_distribution() | График категорий | Датафрейм + mode | ggplot object |
| plot_publication_timeline() | График времени | Датафрейм + by | ggplot object |
| run_visual_dashboard() | Интерактивный дашборд | host, port | Shiny app |

---

## Связь с другими функциями

fetch_arxiv_data()
        ↓
filter_cybersecurity()
        ↓
categorize_articles()
        ↓ ┌─────────────────────────────────────┐
        └─→ plot_category_distribution()       |
        ├─→ plot_publication_timeline()        | visualization.R
        └─→ run_visual_dashboard()             | функции
            ├─→ (внутри dashboard)             |
            |   └─→ все 12 графиков            |
            └─────────────────────────────────────┘

---

## Лучшие практики

Делайте так:

```r
# 1. Проверяйте данные перед графиком
if (nrow(categorized) == 0) {
  message("Нет данных для визуализации")
} else {
  p <- plot_category_distribution(categorized)
  print(p)
}

# 2. Сохраняйте графики с хорошим качеством
ggsave("analysis.png", p, width = 14, height = 8, dpi = 300)

# 3. Используйте понятные названия
p1 <- plot_category_distribution(categorized, mode = "primary", top_n = 10)
p2 <- plot_publication_timeline(categorized, by = "month")

# 4. Документируйте свои модификации
# Если изменяли функцию, добавьте комментарии
```

Не делайте так:

```r
# 1. Не используйте функции без проверки данных
plot_category_distribution(NULL)  # Ошибка!

# 2. Не игнорируйте предупреждения
suppressWarnings(plot_category_distribution(bad_data))  # Плохо!

# 3. Не передавайте с неправильным режимом
plot_category_distribution(data, mode = "wrong_mode")  # Ошибка!
```

---

## Дополнительные ресурсы

- ggplot2 документация: https://ggplot2.tidyverse.org/
- Shiny документация: https://shiny.rstudio.com/
- R graphics cookbook: https://r-graphics.org/
- Цветовые палитры: https://colorbrewer2.org/

---

Дата создания: 2025-12-20  
Версия: 1.0  
Автор: arxivThreatIntel Team  
Статус: Готово к использованию

Начните с примеров выше и адаптируйте под свои нужды!
