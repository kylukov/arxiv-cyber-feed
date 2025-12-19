# Cyber Threat Intelligence Enrichment (Arxiv Collector)

Проект представляет собой R‑пакет для сбора, хранения и анализа научных публикаций из arxiv.org по темам информационной безопасности, threat intelligence и наступательной кибербезопасности. Цель — обогащение материалов киберразведки актуальными исследованиями и формирование тематического корпуса текстов.

## Структура проекта
```
arxiv-cyber-feed/
├── DESCRIPTION          # метаданные пакета (название, авторы, зависимости)
├── NAMESPACE            # экспортируемые функции
├── README.md            # этот файл - описание проекта
├── .gitignore           # исключения для git
│
├── R/                   # основной код пакета
│   ├── collect_data.R       # функции для сбора данных из arXiv API
│   ├── storage_utils.R      # нормализация, сохранение (Parquet, DuckDB)
│   ├── analysis_utils.R     # категоризация статей по тематикам безопасности
│   ├── visualization.R      # визуализация и дашборды
│   ├── integration.R        # интеграция и вспомогательные функции
│   └── db_utils.R           # утилиты для работы с базами данных
│
├── data-raw/            # директория для сырых данных и Parquet файлов
│
├── inst/                # дополнительные материалы
│   ├── shiny-app/           # Shiny-приложение для визуализации
│   └── data/                # база данных DuckDB
│
├── man/                 # документация функций (генерируется roxygen2)
│
├── tests/               # тесты пакета
│   ├── README.md            # документация по тестам
│   ├── TESTING.md           # подробное руководство по тестированию
│   ├── CATEGORIZATION_REPORT.md  # отчёт о тестировании категоризации
│   ├── testthat.R           # конфигурация testthat
│   ├── testthat/            # автоматические unit-тесты
│   └── manual/              # ручные интеграционные тесты
│       ├── quick_test_categorization.R
│       ├── test_functionality.R
│       ├── test_categorization.R
│       └── analyze_categorization_quality.R
│
├── vignettes/           # учебные примеры и виньетки
│
├── Dockerfile           # контейнеризация
└── docker-compose.yml   # оркестрация контейнеров
```

## Быстрый старт

### Установка зависимостей

```r
install.packages(c(
  "dplyr", "tidyr", "tibble", "purrr", "stringr",
  "httr", "xml2", "lubridate",
  "arrow", "DBI", "duckdb"
))
```

### Тестирование функционала

Быстрая проверка категоризации (1-2 минуты):
```bash
Rscript tests/manual/quick_test_categorization.R
```

Полное тестирование всех функций (2-3 минуты):
```bash
Rscript tests/manual/test_functionality.R
```

Подробная документация по тестированию: [`tests/README.md`](tests/README.md)

### Использование

```r
# Загрузка модулей
source("R/collect_data.R")
source("R/analysis_utils.R")
source("R/storage_utils.R")

# Сбор данных из arXiv
data <- fetch_arxiv_data(
  categories = "cs.CR",
  max_results = 50,
  verbose = TRUE
)

# Фильтрация по кибербезопасности
filtered <- filter_cybersecurity(data, strict_mode = FALSE)

# Категоризация статей
categorized <- categorize_articles(filtered, mode = "primary", verbose = TRUE)

# Статистика по категориям
stats <- get_category_stats(categorized, mode = "primary")
print(stats)

# Сохранение в Parquet и DuckDB
tables <- normalize_arxiv_records(categorized)
save_to_parquet(tables, dir = "data-raw")

# Или всё сразу (end-to-end)
result <- e2e_collect_and_store(
  categories = c("cs.CR", "cs.NI"),
  max_results = 100,
  categorize = TRUE,
  category_mode = "primary",
  use_duckdb = TRUE,
  verbose = TRUE
)
```

## Основные компоненты

### 1. Сбор данных (`collect_data.R`)
- `fetch_arxiv_data()` - получение статей из arXiv API
- `filter_cybersecurity()` - фильтрация статей по темам безопасности
- `save_collected_data()` - сохранение собранных данных

### 2. Категоризация (`analysis_utils.R`)
- `categorize_articles()` - категоризация статей по 12 темам безопасности
- `get_category_stats()` - статистика по категориям
- Поддержка режимов: primary (одна категория) и multi (несколько категорий)

### 3. Хранение (`storage_utils.R`)
- `normalize_arxiv_records()` - нормализация в реляционную схему
- `save_to_parquet()` - сохранение в Parquet формат
- `init_duckdb_store()` - инициализация DuckDB базы данных
- `e2e_collect_and_store()` - end-to-end pipeline

### 4. Категории безопасности

1. Криптография
2. Сетевая безопасность
3. Вредоносное ПО и угрозы
4. Контроль доступа
5. Конфиденциальность и соответствие
6. Киберразведка
7. Веб-безопасность
8. IoT и встроенные системы
9. Безопасность ИИ
10. Блокчейн и криптовалюты
11. Реагирование на инциденты
12. Безопасная разработка

## Документация

- [`tests/README.md`](tests/README.md) - документация по тестам
- [`tests/TESTING.md`](tests/TESTING.md) - руководство по тестированию
- [`tests/CATEGORIZATION_REPORT.md`](tests/CATEGORIZATION_REPORT.md) - отчёт о категоризации
- `man/` - документация функций (roxygen2)
