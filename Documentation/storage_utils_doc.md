# Логика работы функций хранения данных – анализ и инструкция

## Общее описание

Модуль `storage_utils.R` предоставляет функции для нормализации, денормализации и сохранения данных о научных публикациях в несколько форматов хранения: Parquet (для архивирования) и DuckDB (для аналитических запросов). Модуль осуществляет преобразование сырых данных из arXiv в реляционную схему с поддержкой результатов категоризации.

---

## Архитектура данных

### Денормализация vs Нормализация

**Сырые данные (из API)**:
```
1 статья: { title, abstract, authors: [list], categories: [list] }
```

**Нормализованные данные**:
```
articles    — основная таблица (1 статья = 1 строка)
authors     — таблица авторов (1 автор = 1 строка)
categories  — таблица категорий (1 категория = 1 строка)
```

### Поддержка категоризации

После применения `categorize_articles()`:
- **primary mode**: добавляется колонка `security_category`
- **multi mode**: добавляется колонка `security_categories` (список)
- Обоих случаях: добавляется `category_confidence`

---

## Функции и их назначение

### 1. `normalize_arxiv_records()` — Нормализация данных

**Сигнатура:**
```r
normalize_arxiv_records(df)
```

**Параметры:**
- `df` — `tibble/data.frame` с сырыми данными из `fetch_arxiv_data()` или после `categorize_articles()`

**Возвращает:**
- `list` с нормализованными таблицами:
  ```r
  list(
    articles = tibble,          # основные статьи
    authors = tibble,           # авторы (денормализованные)
    categories = tibble,        # категории arXiv
    security_categories = tibble # только если multi-mode категоризация
  )
  ```

**Логика работы:**

#### Шаг 1: Валидация входных данных
```r
if (is.null(df) || nrow(df) == 0) {
  warning("Нет данных для нормализации")
  return(list(articles = tibble(), authors = tibble(), ...))
}
```

#### Шаг 2: Определение наличия колонок категоризации
```r
has_security_category <- "security_category" %in% names(df)
has_security_categories <- "security_categories" %in% names(df)
has_confidence <- "category_confidence" %in% names(df)
```

#### Шаг 3: Создание таблицы `articles`
```r
articles_base <- df %>%
  transmute(
    arxiv_id = as.character(arxiv_id),
    title = as.character(title),
    abstract = as.character(abstract),
    published_date = as.POSIXct(published_date, tz = "UTC"),
    doi = as.character(doi),
    collection_date = as.POSIXct(collection_date, tz = "UTC")
  )
```

- Преобразует типы в стандартные
- Добавляет колонки безопасности если они есть
- Удаляет дубликаты по `arxiv_id`

#### Шаг 4: Денормализация авторов
```r
authors <- df %>%
  select(arxiv_id, authors) %>%
  unnest_longer(authors, values_to = "author_name") %>%
  group_by(arxiv_id) %>%
  mutate(author_order = row_number()) %>%
  ungroup()
```

- Разворачивает список авторов в строки
- Добавляет порядковый номер автора
- Каждому автору соответствует одна строка

#### Шаг 5: Денормализация категорий arXiv
```r
categories <- df %>%
  select(arxiv_id, categories) %>%
  unnest_longer(categories, values_to = "category_term")
```

- Разворачивает список категорий в строки
- Каждой категории соответствует одна строка

#### Шаг 6: Обработка категорий безопасности (если используется multi-mode)
```r
if (has_security_categories) {
  security_categories <- df %>%
    select(arxiv_id, security_categories) %>%
    unnest_longer(security_categories, values_to = "security_category_term")
}
```
---

### 2. `save_to_parquet()` — Сохранение в Apache Parquet

**Сигнатура:**
```r
save_to_parquet(tables, dir = "data-raw")
```

**Параметры:**
- `tables` — `list` результат от `normalize_arxiv_records()`
- `dir` — директория для сохранения (по умолчанию `"data-raw"`)

**Возвращает:**
- `TRUE` (невидимо) + сообщение о успешном сохранении

**Логика работы:**

1. Проверяет/создает директорию
2. Записывает каждую таблицу отдельным файлом:
   - `articles.parquet`
   - `authors.parquet`
   - `categories.parquet`
   - `security_categories.parquet` (если присутствует)

3. Выводит сообщение с полным путем

---

### 3. `init_duckdb_store()` — Инициализация DuckDB хранилища

**Сигнатура:**
```r
init_duckdb_store(tables, db_path = "inst/data/arxiv.duckdb")
```

**Параметры:**
- `tables` — `list` результат от `normalize_arxiv_records()`
- `db_path` — путь для DuckDB файла (по умолчанию `"inst/data/arxiv.duckdb"`)

**Возвращает:**
- Активное DBI подключение к DuckDB (невидимо)

**Логика работы:**

#### Шаг 1: Подготовка директории и подключение
```r
dir.create(dirname(db_path), recursive = TRUE, showWarnings = FALSE)
con <- DBI::dbConnect(duckdb::duckdb(db_path, read_only = FALSE))
```

#### Шаг 2: Запись таблиц
```r
dbWriteTable(con, "articles", tables$articles, overwrite = TRUE)
dbWriteTable(con, "authors", tables$authors, overwrite = TRUE)
dbWriteTable(con, "categories", tables$categories, overwrite = TRUE)
if ("security_categories" %in% names(tables) && nrow(...) > 0) {
  dbWriteTable(con, "security_categories", ..., overwrite = TRUE)
}
```

#### Шаг 3: Создание представления (view)
```sql
CREATE OR REPLACE VIEW v_article_full AS
SELECT a.*, c.category_term, au.author_name, au.author_order
[, sc.security_category_term]
FROM articles a
LEFT JOIN categories c USING(arxiv_id)
LEFT JOIN authors au USING(arxiv_id)
[LEFT JOIN security_categories sc USING(arxiv_id)]
```

Представление позволяет удобно выполнять JOIN запросы без необходимости их указывать каждый раз.



---

### 4. `query_articles()` — Вспомогательная функция для запросов

**Сигнатура:**
```r
query_articles(con, start = NULL, end = NULL, category_term = NULL)
```

**Параметры:**
- `con` — DBI подключение (от `init_duckdb_store()`)
- `start` — `POSIXct` или `character` дата начала
- `end` — `POSIXct` или `character` дата конца
- `category_term` — категория arXiv (e.g., `"cs.CR"`)

**Возвращает:**
- `tibble` с результатами

**Логика работы:**

1. Динамически строит WHERE клаузулы
2. Присоединяет параметры с подготовленными выражениями
3. Выполняет запрос с сортировкой по дате

---

### 5. `e2e_collect_and_store()` — End-to-end pipeline

**Сигнатура:**
```r
e2e_collect_and_store(
  categories = c("cs.CR", "cs.NI"),
  max_results = 200,
  out = "data-raw",
  strict_mode = TRUE,
  categorize = TRUE,
  category_mode = c("primary", "multi"),
  use_duckdb = FALSE,
  duckdb_path = "inst/data/arxiv.duckdb",
  verbose = TRUE
)
```

**Параметры:**
| Параметр | Тип | Описание |
|----------|-----|----------|
| `categories` | `character` | Категории arXiv для сбора |
| `max_results` | `numeric` | Максимум статей на категорию |
| `out` | `character` | Директория для Parquet файлов |
| `strict_mode` | `logical` | Строгая фильтрация по ключевым словам |
| `categorize` | `logical` | Применять категоризацию |
| `category_mode` | `character` | "primary" или "multi" |
| `use_duckdb` | `logical` | Инициализировать DuckDB |
| `duckdb_path` | `character` | Путь к DuckDB файлу |
| `verbose` | `logical` | Вывод прогресса |

**Возвращает:**
- `list` нормализованных таблиц (невидимо)

**Логика работы:**

```
1. fetch_arxiv_data()      → получение статей
2. filter_cybersecurity()  → фильтрация по ключевым словам
3. categorize_articles()   → (опционально) категоризация
4. normalize_arxiv_records() → нормализация
5. save_to_parquet()       → сохранение Parquet файлов
6. init_duckdb_store()     → (опционально) инициализация DuckDB
```

---

## Структура нормализованных таблиц

### Таблица `articles`
```
arxiv_id              (character)  ← primary key
title                 (character)  
abstract              (character)  
published_date        (POSIXct)    
doi                   (character, nullable)
collection_date       (POSIXct)
security_category     (character, nullable, только primary mode)
category_confidence   (numeric, nullable)
```

### Таблица `authors`
```
arxiv_id              (character)  ← foreign key → articles
author_name           (character)
author_order          (integer)    ← порядковый номер
```

### Таблица `categories`
```
arxiv_id              (character)  ← foreign key → articles
category_term         (character)  ← arXiv категория (e.g., 'cs.CR')
```

### Таблица `security_categories` (только для multi-mode)
```
arxiv_id              (character)  ← foreign key → articles
security_category_term (character) ← категория безопасности
```

---

## Интеграция с другими модулями

```
collect_data.R
    ↓ (fetch_arxiv_data, filter_cybersecurity)
analysis_utils.R
    ↓ (categorize_articles, get_category_stats)
storage_utils.R ← ВЫ ЗДЕСЬ
    ↓ (normalize, save_to_parquet, init_duckdb_store)
db_utils.R / visualization.R
    ↓
Результаты / Dashboard
```

---

## Применение

Модуль `storage_utils.R` используется для:
- Эффективного хранения крупных наборов научных данных
- Преобразования нестандартных форматов в реляционную схему
- Создания архивов данных в открытых форматах (Parquet)
- Подготовки данных для аналитики и визуализации
- Интеграции результатов категоризации в хранилище
