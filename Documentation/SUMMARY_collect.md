---
title: "SUMMARY_collect"
output: html_document
---
```markdown
# Полная документация: collect_data.R

## Введение

Модуль `collect_data.R` является точкой входа для всего ETL-пайплайна проекта arxiv-cyber-feed. Он отвечает за извлечение (Extract) научных публикаций из arXiv API, их первичную трансформацию (Transform) и подготовку к дальнейшей обработке.

### Назначение модуля

1. **Сбор данных** - автоматизированное получение метаданных публикаций из arXiv
2. **Фильтрация** - отсев нерелевантных публикаций по ключевым словам
3. **Нормализация** - приведение данных к единому формату
4. **Персистентность** - сохранение собранных данных на диск

### Основные возможности

- Поддержка 11 категорий arXiv
- Гибкая фильтрация по ключевым словам (70+ терминов)
- Два режима фильтрации: базовый и строгий
- Автоматическая обработка XML ответов
- Валидация входных параметров
- Обработка сетевых ошибок и таймаутов
- Сохранение в компактном RDS формате
- Логирование всех операций

### Зависимости

```
library(httr)         # HTTP запросы к arXiv API
library(xml2)         # Парсинг XML ответов
library(dplyr)        # Манипуляции с данными
library(stringr)      # Работа со строками
library(tibble)       # Современные датафреймы
library(lubridate)    # Обработка дат и времени
library(purrr)        # Функциональное программирование
```

---

## Архитектура модуля

### Структура компонентов

```
collect_data.R
├── [PUBLIC] fetch_arxiv_data()           # Основная точка входа
├── [PUBLIC] filter_cybersecurity()       # Фильтрация по ключевым словам
├── [PUBLIC] save_collected_data()        # Сохранение данных
├── [PRIVATE] .construct_arxiv_query()    # Построение запроса
├── [PRIVATE] .execute_arxiv_api_request()# Выполнение HTTP запроса
├── [PRIVATE] .parse_arxiv_response()     # Парсинг XML
├── [PRIVATE] .parse_single_entry()       # Парсинг одной статьи
├── [PRIVATE] .extract_doi_from_entry()   # Извлечение DOI
└── [PRIVATE] .parse_datetime()           # Парсинг дат
```

### Поток данных

```
Параметры пользователя
    ↓
Валидация параметров
    ↓
Построение URL запроса (.construct_arxiv_query)
    ↓
HTTP GET запрос к arXiv API (.execute_arxiv_api_request)
    ↓
Получение XML ответа
    ↓
Парсинг XML (.parse_arxiv_response)
    ↓
Извлечение метаданных каждой статьи (.parse_single_entry)
    ↓
Формирование tibble с результатами
    ↓
Возврат пользователю
```

### Типы данных

**Входные данные:**
```
categories: character vector
max_results: integer (1-1000)
verbose: logical
```

**Выходные данные:**
```
tibble с колонками:
- arxiv_id: character
- title: character
- authors: list (character vectors)
- abstract: character
- categories: list (character vectors)
- published_date: POSIXct
- doi: character
- collection_date: POSIXct
```

---

## Основная функция fetch_arxiv_data()

### Полное описание

Главная функция модуля, которая инкапсулирует весь процесс получения данных из arXiv API.

### Сигнатура функции

```
fetch_arxiv_data(
  categories = "cs.CR",
  max_results = 10,
  verbose = TRUE
)
```

### Параметры

#### categories
- **Тип:** `character` (вектор)
- **По умолчанию:** `"cs.CR"` (Cryptography and Security)
- **Описание:** Список категорий arXiv для поиска
- **Валидные значения:**
  - `"cs.CR"` - Cryptography and Security
  - `"cs.AI"` - Artificial Intelligence
  - `"cs.NI"` - Networking and Internet Architecture
  - `"cs.SE"` - Software Engineering
  - `"cs.DC"` - Distributed, Parallel, and Cluster Computing
  - `"cs.LG"` - Machine Learning
  - `"cs.CY"` - Computers and Society
  - `"cs.DB"` - Databases
  - `"cs.IR"` - Information Retrieval
  - `"stat.ML"` - Machine Learning (Statistics)
  - `"math.OC"` - Optimization and Control

**Примеры:**
```
# Одна категория
categories = "cs.CR"

# Несколько категорий
categories = c("cs.CR", "cs.NI", "cs.AI")

# Все поддерживаемые категории
categories = c("cs.CR", "cs.AI", "cs.NI", "cs.SE", "cs.DC", 
               "cs.LG", "cs.CY", "cs.DB", "cs.IR", "stat.ML", "math.OC")
```

#### max_results
- **Тип:** `integer`
- **По умолчанию:** `10`
- **Диапазон:** `1` до `1000`
- **Описание:** Максимальное количество результатов для получения
- **Ограничения arXiv API:**
  - Рекомендуемый максимум: 1000 результатов за запрос
  - Превышение может привести к таймауту

**Примеры:**
```
# Минимальный набор для тестирования
max_results = 5

# Средний набор для анализа
max_results = 100

# Большой набор для исследований
max_results = 1000
```

**Валидация:**
```
# Генерирует ошибку
fetch_arxiv_data(max_results = 0)
# Error: Параметр max_results должен быть в диапазоне от 1 до 1000

fetch_arxiv_data(max_results = 2000)
# Error: Параметр max_results должен быть в диапазоне от 1 до 1000
```

#### verbose
- **Тип:** `logical`
- **По умолчанию:** `TRUE`
- **Описание:** Выводить ли отладочную информацию в консоль

**Когда verbose = TRUE:**
```
Инициализация сбора данных из arXiv API
Категории поиска: cs.CR, cs.NI
Ожидаемое количество записей: 100
Сбор данных завершен успешно
Получено записей: 98
```

**Когда verbose = FALSE:**
```
(нет вывода)
```

### Возвращаемое значение

Функция возвращает объект класса `tibble` (современный датафрейм) со следующими колонками:

| Колонка | Тип | Описание | Пример |
|---------|-----|----------|--------|
| `arxiv_id` | character | Идентификатор статьи в arXiv | "2401.12345" |
| `title` | character | Заголовок статьи | "Advanced Cryptographic Methods..." |
| `authors` | list | Список авторов (вектор строк) | list(c("Smith J.", "Doe A.")) |
| `abstract` | character | Аннотация статьи | "We propose a novel approach..." |
| `categories` | list | Категории arXiv (вектор строк) | list(c("cs.CR", "cs.AI")) |
| `published_date` | POSIXct | Дата публикации | 2024-01-15 10:30:00 |
| `doi` | character | Digital Object Identifier | "10.1234/arxiv.2401.12345" или NA |
| `collection_date` | POSIXct | Дата сбора данных | 2024-12-22 15:00:00 |

### Внутренняя логика работы

#### Этап 1: Валидация параметров

```
# Проверка max_results
if (max_results < 1 || max_results > 1000) {
  stop("Параметр max_results должен быть в диапазоне от 1 до 1000")
}

# Проверка категорий
valid_categories <- c("cs.CR", "cs.AI", "cs.NI", "cs.SE", "cs.DC", 
                     "cs.LG", "cs.CY", "cs.DB", "cs.IR", "stat.ML", "math.OC")
invalid_cats <- setdiff(categories, valid_categories)

if (length(invalid_cats) > 0) {
  warning("Обнаружены недопустимые категории: ", 
          paste(invalid_cats, collapse = ", "))
  categories <- intersect(categories, valid_categories)
}

if (length(categories) == 0) {
  stop("Не указано ни одной допустимой категории")
}
```

#### Этап 2: Построение запроса

```
search_query <- .construct_arxiv_query(categories)
# Результат для одной категории: "cat:cs.CR"
# Результат для нескольких: "(cat:cs.CR OR cat:cs.AI OR cat:cs.NI)"
```

#### Этап 3: Выполнение HTTP запроса

```
response <- .execute_arxiv_api_request(search_query, max_results, verbose)

# Внутри функции:
query_params <- list(
  search_query = search_query,
  start = 0,
  max_results = max_results,
  sortBy = "submittedDate",
  sortOrder = "descending"
)

response <- httr::GET(
  url = "http://export.arxiv.org/api/query",
  query = query_params,
  httr::user_agent("arXiv-Cybersecurity-Collector/1.0"),
  httr::timeout(30)
)
```

#### Этап 4: Обработка ответа

```
# Проверка на ошибки
if (is.null(response) || httr::http_error(response)) {
  if (verbose) message("Не удалось подключиться к arXiv API")
  return(tibble::tibble())  # Возврат пустого tibble
}

# Парсинг XML
parsed_data <- .parse_arxiv_response(response, verbose)
```

#### Этап 5: Возврат результатов

```
if (verbose && nrow(parsed_data) > 0) {
  message("Сбор данных завершен успешно")
  message("Получено записей: ", nrow(parsed_data))
}

return(parsed_data)
```

### Примеры использования

#### Базовый пример

```
# Получить 10 статей по криптографии
data <- fetch_arxiv_data(
  categories = "cs.CR",
  max_results = 10,
  verbose = TRUE
)

# Просмотр результатов
print(data)
head(data)
```

#### Множественные категории

```
# Получить статьи по нескольким категориям
data <- fetch_arxiv_data(
  categories = c("cs.CR", "cs.NI", "cs.AI"),
  max_results = 50,
  verbose = TRUE
)

# Подсчет по категориям
library(dplyr)
data %>%
  tidyr::unnest(categories) %>%
  count(categories) %>%
  arrange(desc(n))
```

#### Тихий режим

```
# Без вывода отладочной информации
data <- fetch_arxiv_data(
  categories = "cs.CR",
  max_results = 100,
  verbose = FALSE
)
```

#### Обработка ошибок

```
# Безопасный вызов с обработкой ошибок
data <- tryCatch({
  fetch_arxiv_data(
    categories = "cs.CR",
    max_results = 50,
    verbose = TRUE
  )
}, error = function(e) {
  message("Ошибка при получении данных: ", e$message)
  return(tibble::tibble())
})

if (nrow(data) > 0) {
  message("Получено ", nrow(data), " статей")
} else {
  message("Не удалось получить данные")
}
```

Продолжаю документацию для collect_data.R:

```markdown
**Факторы, влияющие на производительность:**
- Скорость интернет-соединения
- Нагрузка на серверы arXiv
- Сложность XML ответа
- Количество авторов и категорий в статьях

---

## Функция filter_cybersecurity()

### Полное описание

Фильтрует полученные публикации по ключевым словам, связанным с кибербезопасностью. Использует регулярные выражения для поиска терминов в заголовках и аннотациях.

### Сигнатура функции

```
filter_cybersecurity(
  data,
  strict_mode = FALSE
)
```

### Параметры

#### data (обязательный)
- **Тип:** `data.frame` или `tibble`
- **Обязательные колонки:**
  - `title` (character)
  - `abstract` (character)
- **Описание:** Датафрейм с публикациями для фильтрации

#### strict_mode
- **Тип:** `logical`
- **По умолчанию:** `FALSE`
- **Описание:**
  - `FALSE` - базовая фильтрация (70+ ключевых слов)
  - `TRUE` - строгая фильтрация (90+ ключевых слов, включая специализированные термины)

### Базовые ключевые слова (strict_mode = FALSE)

**Общая безопасность (15 терминов):**
```
"security", "cybersecurity", "cyber security", "information security",
"network security", "computer security", "data security"
```

**Угрозы и атаки (13 терминов):**
```
"threat", "attack", "malware", "ransomware", "phishing", "botnet",
"exploit", "vulnerability", "zero-day", "zero day", "cve", "cwe"
```

**Криптография (12 терминов):**
```
"cryptography", "encryption", "cipher", "cryptographic",
"aes", "rsa", "elliptic curve", "public key", "private key"
```

**Защитные механизмы (10 терминов):**
```
"firewall", "intrusion", "authentication", "authorization",
"access control", "identity management", "vpn", "ssl", "tls"
```

**Приватность и регуляции (10 терминов):**
```
"privacy", "anonymization", "pseudonymization", "data protection",
"gdpr", "hipaa", "compliance", "regulation"
```

### Расширенные ключевые слова (strict_mode = TRUE)

Включает все базовые + дополнительные 20+ терминов:

**Threat Intelligence:**
```
"threat intelligence", "advanced persistent threat", "apt",
"attack vector", "attack surface", "mitre att&ck", "ttp"
```

**Incident Response:**
```
"incident response", "digital forensics", "security audit",
"penetration testing", "red team", "blue team", "purple team"
```

**Security Operations:**
```
"security operations center", "soc", "siem", "soar",
"endpoint detection and response", "edr", "xdr"
```

### Внутренняя логика работы

#### Шаг 1: Проверка входных данных

```
if (is.null(data) || nrow(data) == 0) {
  warning("Входной набор данных пуст")
  return(data)
}
```

#### Шаг 2: Формирование списка ключевых слов

```
base_keywords <- c(
  "security", "cybersecurity", "threat", "attack", 
  "cryptography", "encryption", # ... и т.д.
)

if (strict_mode) {
  extended_keywords <- c(
    "threat intelligence", "apt", "mitre att&ck",
    "incident response", "soc", "siem", # ... и т.д.
  )
  keywords <- c(base_keywords, extended_keywords)
} else {
  keywords <- base_keywords
}
```

#### Шаг 3: Построение регулярного выражения

```
keyword_pattern <- paste0("\\b(", paste(keywords, collapse = "|"), ")\\b")
# Результат: "\\b(security|cybersecurity|threat|attack|...)\\b"
```

#### Шаг 4: Фильтрация и подсчет совпадений

```
filtered_data <- data %>%
  dplyr::mutate(
    search_text = tolower(paste(title, abstract)),
    keyword_matches = stringr::str_extract_all(search_text, keyword_pattern),
    match_count = purrr::map_int(keyword_matches, length),
    is_relevant = match_count > 0
  ) %>%
  dplyr::filter(is_relevant) %>%
  dplyr::arrange(desc(match_count)) %>%
  dplyr::select(-search_text, -keyword_matches, -match_count, -is_relevant)
```

#### Шаг 5: Вывод статистики

```
if (nrow(filtered_data) > 0) {
  message("Выделено публикаций по кибербезопасности: ", 
          nrow(filtered_data), " из ", nrow(data), 
          " (", round(nrow(filtered_data) / nrow(data) * 100, 1), "%)")
}
```

### Примеры использования

#### Базовая фильтрация

```
# Получить данные
raw_data <- fetch_arxiv_data(
  categories = c("cs.CR", "cs.AI"),
  max_results = 100
)

# Базовая фильтрация
filtered <- filter_cybersecurity(raw_data, strict_mode = FALSE)

# Результат
# Выделено публикаций по кибербезопасности: 45 из 100 (45.0%)
```

#### Строгая фильтрация

```
# Строгий режим для более точной выборки
strict_filtered <- filter_cybersecurity(raw_data, strict_mode = TRUE)

# Результат
# Выделено публикаций по кибербезопасности: 28 из 100 (28.0%)
```

### Рекомендации по выбору режима

**Используйте strict_mode = FALSE когда:**
- Нужен широкий охват публикаций
- Анализируется общая тематика безопасности
- Важно не пропустить релевантные статьи

**Используйте strict_mode = TRUE когда:**
- Нужны только специализированные публикации
- Фокус на практических аспектах (threat intelligence, SOC)
- Требуется высокая точность отбора

---

## Функция save_collected_data()

### Полное описание

Сохраняет собранные данные в RDS файл с возможностью сжатия. Автоматически создает необходимые директории.

### Сигнатура функции

```
save_collected_data(
  data,
  file_path,
  compress = TRUE
)
```

### .construct_arxiv_query()

Строит поисковый запрос для arXiv API из списка категорий.

**Логика:**
```
# Одна категория
.construct_arxiv_query("cs.CR")
# Результат: "cat:cs.CR"

# Несколько категорий
.construct_arxiv_query(c("cs.CR", "cs.AI", "cs.NI"))
# Результат: "(cat:cs.CR OR cat:cs.AI OR cat:cs.NI)"
```

**Код:**
```
.construct_arxiv_query <- function(categories) {
  if (length(categories) == 1) {
    query <- paste0("cat:", categories)
  } else {
    category_queries <- sapply(categories, function(cat) paste0("cat:", cat))
    query <- paste0("(", paste(category_queries, collapse = " OR "), ")")
  }
  return(query)
}
```

### .execute_arxiv_api_request()

Выполняет HTTP GET запрос к arXiv API.

**Параметры запроса:**
- `search_query` - поисковый запрос
- `start` - начальный индекс (для пагинации)
- `max_results` - количество результатов
- `sortBy` - сортировка (submittedDate)
- `sortOrder` - порядок (descending)

**Обработка ошибок:**
```
response <- tryCatch({
  httr::GET(
    url = "http://export.arxiv.org/api/query",
    query = query_params,
    httr::user_agent("arXiv-Cybersecurity-Collector/1.0"),
    httr::timeout(30)
  )
}, error = function(e) {
  if (verbose) message("Сетевая ошибка: ", e$message)
  return(NULL)
})
```

### .parse_arxiv_response()

Парсит XML ответ от arXiv API и извлекает все entry элементы.

**Этапы парсинга:**
1. Чтение XML контента
2. Извлечение всех `<entry>` элементов
3. Парсинг каждого

Продолжаю документацию для collect_data.R:

```markdown
entry отдельно
4. Объединение результатов в tibble

**Код:**
```
.parse_arxiv_response <- function(response, verbose) {
  response_content <- httr::content(response, as = "text", encoding = "UTF-8")
  
  if (nchar(trimws(response_content)) == 0) {
    if (verbose) message("Получен пустой ответ от API")
    return(tibble::tibble())
  }
  
  xml_doc <- tryCatch({
    xml2::read_xml(response_content)
  }, error = function(e) {
    if (verbose) message("Невалидный XML: ", e$message)
    return(NULL)
  })
  
  if (is.null(xml_doc)) {
    return(tibble::tibble())
  }
  
  xml_namespaces <- xml2::xml_ns(xml_doc)
  entries <- xml2::xml_find_all(xml_doc, "//d1:entry", ns = xml_namespaces)
  
  if (length(entries) == 0) {
    return(tibble::tibble())
  }
  
  parsed_entries <- purrr::map(entries, .parse_single_entry, 
                               ns = xml_namespaces, verbose = verbose)
  valid_entries <- purrr::discard(parsed_entries, is.null)
  
  if (length(valid_entries) == 0) {
    return(tibble::tibble())
  }
  
  result <- dplyr::bind_rows(valid_entries)
  return(result)
}
```

### .parse_single_entry()

Извлекает метаданные из одного XML entry элемента.

**Извлекаемые поля:**

1. **ID статьи:**
```
id <- safe_extract("./d1:id")
arxiv_id <- stringr::str_extract(id, "\\d{4}\\.\\d{4,5}(v\\d+)?")
# Пример: "2401.12345" или "2401.12345v2"
```

2. **Заголовок:**
```
title <- safe_extract("./d1:title")
title <- stringr::str_trim(title)  # Удаление пробелов
```

3. **Аннотация:**
```
abstract <- safe_extract("./d1:summary")
abstract <- stringr::str_trim(abstract)
```

4. **Авторы:**
```
author_nodes <- xml2::xml_find_all(entry, "./d1:author/d1:name", ns = ns)
authors <- if (length(author_nodes) > 0) {
  list(purrr::map_chr(author_nodes, xml2::xml_text))
} else {
  list(character(0))
}
# Результат: list(c("Smith J.", "Doe A.", "Johnson K."))
```

5. **Категории:**
```
category_nodes <- xml2::xml_find_all(entry, "./d1:category", ns = ns)
categories <- if (length(category_nodes) > 0) {
  list(purrr::map_chr(category_nodes, ~xml2::xml_attr(., "term")))
} else {
  list(character(0))
}
# Результат: list(c("cs.CR", "cs.AI", "cs.LG"))
```

6. **Дата публикации:**
```
published <- safe_extract("./d1:published")
published_date <- .parse_datetime(published)
# Результат: POSIXct объект
```

7. **DOI:**
```
doi <- .extract_doi_from_entry(entry, ns, id)
# Результат: "10.1234/arxiv.2401.12345" или NA
```

8. **Дата сбора:**
```
collection_date <- Sys.time()
```

**Формирование tibble:**
```
publication_record <- tibble::tibble(
  arxiv_id = arxiv_id,
  title = stringr::str_trim(title),
  authors = authors,
  abstract = stringr::str_trim(abstract),
  categories = categories,
  published_date = .parse_datetime(published),
  doi = doi,
  collection_date = Sys.time()
)
```

### .extract_doi_from_entry()

Извлекает DOI (Digital Object Identifier) из entry.

**Стратегия извлечения:**

1. Поиск в ссылках:
```
link_nodes <- xml2::xml_find_all(entry, "./d1:link", ns = ns)

for (link in link_nodes) {
  href <- xml2::xml_attr(link, "href")
  if (!is.na(href) && stringr::str_detect(href, "doi\\.org")) {
    return(href)
  }
}
```

2. Поиск в ID через regex:
```
if (!is.na(id)) {
  doi_match <- stringr::str_extract(id, "10\\.\\d{4,9}/[-._;()/:A-Z0-9]+")
  if (!is.na(doi_match)) {
    return(doi_match)
  }
}
```

3. Возврат NA если не найден:
```
return(NA_character_)
```

### .parse_datetime()

Парсит строку даты в POSIXct объект.

**Поддерживаемые форматы:**
- ISO 8601: "2024-01-15T10:30:45Z"
- Без временной зоны: "2024-01-15 10:30:45"

**Код:**
```
.parse_datetime <- function(datetime_str) {
  tryCatch({
    lubridate::as_datetime(datetime_str)
  }, error = function(e) {
    NA
  })
}
```

---

## Полные рабочие примеры

### Пример 1: Минимальный рабочий скрипт

```
# Загрузить библиотеки
library(dplyr)
library(httr)
library(xml2)
library(stringr)
library(tibble)
library(lubridate)
library(purrr)

# Загрузить модуль
source("R/collect_data.R")

# Получить данные
data <- fetch_arxiv_data(
  categories = "cs.CR",
  max_results = 20,
  verbose = TRUE
)

# Посмотреть результаты
print(data)
head(data, 5)
```

### Пример 2: Полный ETL пайплайн

```
# Загрузить модуль
source("R/collect_data.R")

# Шаг 1: Извлечение (Extract)
message("=== Шаг 1: Извлечение данных из arXiv ===")
raw_data <- fetch_arxiv_data(
  categories = c("cs.CR", "cs.NI", "cs.AI"),
  max_results = 200,
  verbose = TRUE
)

message("Получено статей: ", nrow(raw_data))

# Шаг 2: Трансформация (Transform)
message("\n=== Шаг 2: Фильтрация по кибербезопасности ===")
filtered_data <- filter_cybersecurity(
  data = raw_data,
  strict_mode = FALSE
)

message("После фильтрации: ", nrow(filtered_data))

# Шаг 3: Загрузка (Load)
message("\n=== Шаг 3: Сохранение данных ===")
timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
file_path <- paste0("data-raw/arxiv_", timestamp, ".rds")

save_result <- save_collected_data(
  data = filtered_data,
  file_path = file_path,
  compress = TRUE
)

if (save_result) {
  message("Данные успешно сохранены в: ", file_path)
  message("Размер файла: ", 
          format(file.size(file_path) / 1024, digits = 2), " KB")
}

# Шаг 4: Валидация
message("\n=== Шаг 4: Валидация ===")
loaded_data <- readRDS(file_path)
message("Проверка целостности: ", identical(filtered_data, loaded_data))
message("Строк в файле: ", nrow(loaded_data))
```

### Пример 3: Анализ собранных данных

```
# Загрузить данные
source("R/collect_data.R")

data <- fetch_arxiv_data(
  categories = c("cs.CR", "cs.AI"),
  max_results = 100,
  verbose = FALSE
)

filtered <- filter_cybersecurity(data, strict_mode = FALSE)

# Анализ 1: Топ авторов
library(dplyr)

top_authors <- filtered %>%
  tidyr::unnest(authors) %>%
  count(authors, sort = TRUE) %>%
  head(10)

print("Топ-10 авторов:")
print(top_authors)

# Анализ 2: Распределение по категориям
categories_dist <- filtered %>%
  tidyr::unnest(categories) %>%
  count(categories, sort = TRUE)

print("\nРаспределение по категориям:")
print(categories_dist)

# Анализ 3: Временная динамика
library(lubridate)

temporal_dist <- filtered %>%
  mutate(
    month = floor_date(published_date, "month")
  ) %>%
  count(month, sort = TRUE)

print("\nПубликации по месяцам:")
print(temporal_dist)

# Анализ 4: Длина аннотаций
filtered <- filtered %>%
  mutate(abstract_length = nchar(abstract))

print("\nСтатистика длины аннотаций:")
summary(filtered$abstract_length)
```

### Пример 4: Обработка больших объемов данных

```
# Для больших объемов используйте батчинг
source("R/collect_data.R")

# Функция для батчинга
collect_in_batches <- function(categories, total_results, batch_size = 100) {
  all_data <- list()
  num_batches <- ceiling(total_results / batch_size)
  
  for (i in 1:num_batches) {
    message("Обработка батча ", i, " из ", num_batches)
    
    batch_data <- fetch_arxiv_data(
      categories = categories,
      max_results = min(batch_size, total_results - (i-1) * batch_size),
      verbose = FALSE
    )
    
    all_data[[i]] <- batch_data
    
    # Задержка между запросами (rate limiting)
    if (i < num_batches) {
      message("Ожидание 3 секунды...")
      Sys.sleep(3)
    }
  }
  
  # Объединение всех батчей
  combined_data <- dplyr::bind_rows(all_data)
  return(combined_data)
}

# Использование
large_dataset <- collect_in_batches(
  categories = c("cs.CR", "cs.NI"),
  total_results = 500,
  batch_size = 100
)

message("Всего собрано: ", nrow(large_dataset), " статей")
```

### Пример 5: Интеграция с другими модулями

```
# Полный пайплайн с категоризацией и визуализацией
source("R/collect_data.R")
source("R/analysis_utils.R")
source("R/visualization.R")

# 1. Сбор данных
raw_data <- fetch_arxiv_data(
  categories = "cs.CR",
  max_results = 150,
  verbose = TRUE
)

# 2. Фильтрация
filtered_data <- filter_cybersecurity(raw_data, strict_mode = FALSE)

# 3. Категоризация
categorized_data <- categorize_articles(
  data = filtered_data,
  mode = "primary",
  verbose = TRUE
)

# 4. Визуализация
plot <- plot_category_distribution(
  data = categorized_data,
  mode = "primary",
  top_n = 10
)

print(plot)

# 5. Сохранение всех результатов
save_collected_data(raw_data, "data-raw/01_raw.rds")
save_collected_data(filtered_data, "data-raw/02_filtered.rds")
save_collected_data(categorized_data, "data-raw/03_categorized.rds")
ggsave("output/category_distribution.png", plot, width = 12, height = 8)
```
### Rate Limiting

arXiv рекомендует:
- **Максимум 1 запрос в 3 секунды**
- Использовать User-Agent заголовок
- Не превышать 1000 результатов за запрос

**Реализация в модуле:**
```
httr::GET(
  url = "http://export.arxiv.org/api/query",
  query = query_params,
  httr::user_agent("arXiv-Cybersecurity-Collector/1.0"),  # Идентификация
  httr::timeout(30)  # Таймаут 30 секунд
)
```