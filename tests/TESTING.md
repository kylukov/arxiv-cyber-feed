# Проверка работы кода

## Быстрый старт

Запустите комплексный тест всех функций:

```bash
Rscript test_functionality.R
```

## Ручное тестирование

### 1. Сбор данных из arXiv

```r
source("R/collect_data.R")

# Получить 10 последних публикаций по категории cs.CR (Cryptography and Security)
data <- fetch_arxiv_data(
  categories = "cs.CR",
  max_results = 10,
  verbose = TRUE
)

# Посмотреть структуру данных
str(data)
head(data)
```

### 2. Фильтрация по кибербезопасности

```r
# Базовая фильтрация
filtered <- filter_cybersecurity(data, strict_mode = FALSE)

# Строгая фильтрация (только threat intelligence)
filtered_strict <- filter_cybersecurity(data, strict_mode = TRUE)
```

### 3. Категоризация статей

```r
source("R/analysis_utils.R")

# Присвоение одной основной категории
categorized <- categorize_articles(filtered, mode = "primary", verbose = TRUE)
table(categorized$security_category)

# Множественные категории
categorized_multi <- categorize_articles(filtered, mode = "multi", verbose = TRUE)

# Статистика по категориям
stats <- get_category_stats(categorized, mode = "primary")
print(stats)
```

### 4. Сохранение и хранение данных

```r
source("R/storage_utils.R")

# Нормализация в реляционную схему
tables <- normalize_arxiv_records(categorized)

# Сохранение в Parquet
save_to_parquet(tables, dir = "data-raw")

# Инициализация DuckDB базы данных
con <- init_duckdb_store(tables, db_path = "inst/data/arxiv.duckdb")

# Запрос данных
recent_articles <- query_articles(con, category_term = "cs.CR")
DBI::dbDisconnect(con)
```

### 5. End-to-End Pipeline

```r
# Полный цикл: сбор → фильтрация → категоризация → хранение
result <- e2e_collect_and_store(
  categories = c("cs.CR", "cs.NI"),
  max_results = 100,
  out = "data-raw",
  strict_mode = TRUE,
  categorize = TRUE,
  category_mode = "primary",
  use_duckdb = TRUE,
  duckdb_path = "inst/data/arxiv.duckdb",
  verbose = TRUE
)
```

## Проверка отдельных функций

### Тест API запроса

```r
# Проверка с несколькими категориями
multi_cat <- fetch_arxiv_data(
  categories = c("cs.CR", "cs.AI", "cs.NI"),
  max_results = 20
)
```

### Тест недопустимых параметров

```r
# Должна быть ошибка
try(fetch_arxiv_data(categories = "invalid.CAT"))

# Должно быть предупреждение
try(fetch_arxiv_data(categories = c("cs.CR", "invalid.CAT")))
```

### Тест сохранения

```r
save_collected_data(data, "test_output.rds")
loaded_data <- readRDS("test_output.rds")
identical(data, loaded_data)
```

## Ожидаемые результаты

### Тест 1-2: Сбор и фильтрация
- Получение 10-15 записей из arXiv
- Фильтрация ~70-90% релевантных публикаций по кибербезопасности

### Тест 3-4: Категоризация
- Распределение статей по 12 категориям безопасности
- Primary mode: одна категория на статью
- Multi mode: несколько категорий на статью

### Тест 5: Нормализация
- Создание 3-4 реляционных таблиц:
  - `articles` (основная информация)
  - `authors` (авторы с порядком)
  - `categories` (arxiv категории)
  - `security_categories` (опционально, для multi mode)

### Тест 6-7: Сохранение
- Создание Parquet файлов
- Инициализация DuckDB с представлениями

### Тест 8: Статистика
- Подсчет статей по категориям с процентами

## Требования

Убедитесь, что установлены все необходимые пакеты:

```r
install.packages(c(
  "dplyr", "tidyr", "tibble", "purrr", "stringr",
  "httr", "xml2", "lubridate",
  "arrow", "DBI", "duckdb"
))
```

## Устранение проблем

### Ошибка подключения к arXiv API
- Проверьте интернет-соединение
- arXiv API может быть временно недоступен
- Попробуйте уменьшить `max_results`

### Пустые результаты фильтрации
- Попробуйте `strict_mode = FALSE`
- Проверьте, что категория cs.CR действительно содержит публикации по безопасности

### Ошибка при сохранении
- Проверьте права доступа к директориям
- Убедитесь, что установлен пакет `arrow`

## Визуальная проверка данных

```r
# Посмотреть случайную статью
sample_article <- categorized[sample(nrow(categorized), 1), ]
cat("Title:", sample_article$title, "\n")
cat("Category:", sample_article$security_category, "\n")
cat("Abstract:", substr(sample_article$abstract, 1, 200), "...\n")

# Распределение категорий
barplot(table(categorized$security_category), 
        las = 2, 
        main = "Распределение по категориям безопасности")
```
