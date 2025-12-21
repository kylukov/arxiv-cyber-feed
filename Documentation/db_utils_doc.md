# Логика работы функций DuckDB – анализ и инструкция

## Общее описание

Модуль `db_utils.R` предоставляет функции для управления подключением к DuckDB базе данных, записи нормализованных данных и выполнения SQL-запросов. DuckDB — это встраиваемая SQL база данных, оптимизированная для аналитических рабочих нагрузок.

---

## Архитектура и концепция

### DuckDB vs Parquet
- **Parquet** — формат хранения, оптимален для долгосрочного архивирования
- **DuckDB** — OLAP база данных, оптимальна для быстрых аналитических запросов

### Схема базы данных
```
Database: arxiv.duckdb
├── papers          # Основная таблица статей
├── authors         # Авторы статей (денормализованная)
└── categories      # arXiv категории статей
```

---

## Функции и их назначение

### 1. `init_duckdb()` — Инициализация подключения

**Сигнатура:**
```r
init_duckdb(db_path = "data/arxiv.duckdb")
```

**Параметры:**
- `db_path` — путь к файлу DuckDB (`character`, по умолчанию `"data/arxiv.duckdb"`)

**Возвращает:**
- DBI подключение к DuckDB

**Логика работы:**
1. Проверяет существование директории для БД
2. Создает директорию рекурсивно, если её нет
3. Создает или открывает DuckDB файл
4. Возвращает активное подключение

**Пример использования:**
```r
con <- init_duckdb("inst/data/arxiv.duckdb")
```

---

### 2. `write_to_duckdb()` — Запись нормализованных данных

**Сигнатура:**
```r
write_to_duckdb(normalized_data, con)
```

**Параметры:**
- `normalized_data` — `list` результат от `normalize_arxiv_records()` с полями:
  - `papers` — основная таблица статей
  - `authors` — денормализованная таблица авторов
  - `categories` — денормализованная таблица категорий
- `con` — активное DBI подключение

**Логика работы:**
1. Берет каждую таблицу из `normalized_data`
2. Записывает её в соответствующую таблицу БД через `dbWriteTable()`
3. `overwrite = TRUE` полностью заменяет существующие таблицы

**Пример использования:**
```r
normalized <- normalize_arxiv_records(df)
con <- init_duckdb()
write_to_duckdb(normalized, con)
close_duckdb(con)
```

---

### 3. `read_from_duckdb()` — Чтение данных из БД [ЭКСПОРТИРОВАНА]

**Сигнатура:**
```r
read_from_duckdb(con, query = NULL)
```

**Параметры:**
- `con` — активное DBI подключение
- `query` — `character` SQL запрос или `NULL` (по умолчанию `"SELECT * FROM papers"`)

**Возвращает:**
- `tibble` с результатами запроса

**Логика работы:**
1. Если `query = NULL`, выполняет стандартный запрос `SELECT * FROM papers`
2. Иначе выполняет переданный SQL запрос
3. Преобразует результат в `tibble`

**Примеры использования:**
```r
# Простое чтение всех статей
papers <- read_from_duckdb(con)

# Кастомный запрос с фильтрацией
recent_papers <- read_from_duckdb(con, 
  query = "SELECT * FROM papers WHERE published_date > '2024-01-01'")

# Join запрос через представление
full_data <- read_from_duckdb(con, 
  query = "SELECT * FROM v_article_full WHERE category_term = 'cs.CR'")
```

---

### 4. `close_duckdb()` — Закрытие подключения

**Сигнатура:**
```r
close_duckdb(con)
```

**Параметры:**
- `con` — активное DBI подключение

**Логика работы:**
1. Корректно завершает все активные транзакции
2. Закрывает подключение к БД
3. Освобождает ресурсы и блокировки файлов
4. `shutdown = TRUE` полностью завершает работу DuckDB движка

**Пример использования:**
```r
con <- init_duckdb()
# ... работа с БД ...
close_duckdb(con)
```

---

## Типовые рабочие потоки

### Рабочий поток 1: Запись и чтение данных

```r
# 1. Инициализация
con <- init_duckdb("inst/data/arxiv.duckdb")

# 2. Получение и нормализация данных
data <- fetch_arxiv_data(categories = "cs.CR", max_results = 100)
normalized <- normalize_arxiv_records(data)

# 3. Запись в БД
write_to_duckdb(normalized, con)

# 4. Чтение из БД
papers <- read_from_duckdb(con)

# 5. Закрытие
close_duckdb(con)
```

### Рабочий поток 2: Аналитический запрос

```r
con <- init_duckdb("inst/data/arxiv.duckdb")

# Запрос: Статьи по криптографии с 2024 года, упорядоченные по дате
query <- "
  SELECT DISTINCT 
    a.arxiv_id,
    a.title,
    a.published_date,
    COUNT(DISTINCT au.author_name) as author_count
  FROM papers a
  LEFT JOIN authors au USING(arxiv_id)
  LEFT JOIN categories c USING(arxiv_id)
  WHERE c.category_term = 'cs.CR'
    AND a.published_date >= '2024-01-01'
  GROUP BY a.arxiv_id, a.title, a.published_date
  ORDER BY a.published_date DESC
  LIMIT 50
"

result <- read_from_duckdb(con, query)
print(result)

close_duckdb(con)
```

### Рабочий поток 3: Безопасная обработка с обработкой ошибок

```r
con <- NULL
tryCatch({
  con <- init_duckdb()
  normalized <- normalize_arxiv_records(data)
  write_to_duckdb(normalized, con)
  result <- read_from_duckdb(con)
  result
}, error = function(e) {
  message("Ошибка при работе с БД: ", e$message)
  NULL
}, finally = {
  if (!is.null(con)) close_duckdb(con)
})
```

---

## Структура таблиц

### Таблица `papers`
```
arxiv_id          (character) — уникальный идентификатор arXiv
title             (character) — название статьи
abstract          (character) — аннотация
published_date    (POSIXct)   — дата публикации
doi               (character) — Digital Object Identifier
collection_date   (POSIXct)   — дата сбора данных
```

### Таблица `authors`
```
arxiv_id      (character) — ссылка на статью
author_name   (character) — имя автора
author_order  (integer)   — порядок автора
```

### Таблица `categories`
```
arxiv_id       (character) — ссылка на статью
category_term  (character) — категория arXiv (e.g., 'cs.CR')
```

---

## Представления (Views)

### `v_article_full` — Полное представление статей с авторами и категориями

Используется для удобных JOIN запросов:
```sql
SELECT * FROM v_article_full
WHERE category_term = 'cs.CR'
ORDER BY published_date DESC
```

---

## Интеграция со storage_utils

`db_utils.R` используется через `storage_utils.R`:

```r
# storage_utils.R использует db_utils функции:
tables <- normalize_arxiv_records(df)
con <- init_duckdb_store(tables, db_path = "inst/data/arxiv.duckdb")
```

---

## Применение

Функции `db_utils.R` используются для:
- Эффективного хранения больших объемов данных о публикациях
- Быстрого выполнения аналитических запросов
- Создания воспроизводимых аналитических workflow
- Интеграции с Shiny приложениями для интерактивных запросов
