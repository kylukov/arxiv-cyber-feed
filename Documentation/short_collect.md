---
title: "short_collect"
output: html_document
---



```markdown
# Краткая документация: collect_data.R

## Введение

Модуль `collect_data.R` отвечает за сбор научных публикаций из arXiv API, их фильтрацию по кибербезопасности и сохранение на диск.

## Основные функции

### 1. fetch_arxiv_data()

Получает публикации из arXiv API.

**Синтаксис:**
```
fetch_arxiv_data(categories = "cs.CR", max_results = 10, verbose = TRUE)
```

**Параметры:**
- `categories` - вектор категорий arXiv (cs.CR, cs.AI, cs.NI и др.)
- `max_results` - количество результатов (1-1000)
- `verbose` - выводить отладочную информацию (TRUE/FALSE)

**Возвращает:** tibble с колонками: arxiv_id, title, authors, abstract, categories, published_date, doi, collection_date

**Пример:**
```
data <- fetch_arxiv_data(
  categories = c("cs.CR", "cs.NI"),
  max_results = 50,
  verbose = TRUE
)
```

### 2. filter_cybersecurity()

Фильтрует публикации по ключевым словам кибербезопасности.

**Синтаксис:**
```
filter_cybersecurity(data, strict_mode = FALSE)
```

**Параметры:**
- `data` - датафрейм с публикациями
- `strict_mode` - строгий режим фильтрации (FALSE = 70+ слов, TRUE = 90+ слов)

**Базовые ключевые слова:**
security, cybersecurity, threat, attack, malware, cryptography, encryption, firewall, authentication, privacy

**Расширенные ключевые слова (strict_mode = TRUE):**
threat intelligence, apt, mitre att&ck, incident response, soc, siem, edr, xdr

**Пример:**
```
filtered <- filter_cybersecurity(data, strict_mode = FALSE)
# Выделено публикаций по кибербезопасности: 45 из 100 (45.0%)
```

### 3. save_collected_data()

Сохраняет данные в RDS файл.

**Синтаксис:**
```
save_collected_data(data, file_path, compress = TRUE)
```

**Параметры:**
- `data` - датафрейм для сохранения
- `file_path` - путь к файлу (с расширением .rds)
- `compress` - сжимать данные (TRUE/FALSE)

**Пример:**
```
save_collected_data(filtered, "data-raw/arxiv_2024.rds", compress = TRUE)
# Данные сохранены: data-raw/arxiv_2024.rds
```

## Полный рабочий пример

```
# Шаг 1: Загрузить модуль
source("R/collect_data.R")

# Шаг 2: Получить данные
raw_data <- fetch_arxiv_data(
  categories = c("cs.CR", "cs.NI", "cs.AI"),
  max_results = 100,
  verbose = TRUE
)

# Шаг 3: Отфильтровать
filtered_data <- filter_cybersecurity(
  data = raw_data,
  strict_mode = FALSE
)

# Шаг 4: Сохранить
save_collected_data(
  data = filtered_data,
  file_path = "data-raw/cyber_articles.rds",
  compress = TRUE
)

# Шаг 5: Проверить
message("Собрано: ", nrow(raw_data), " статей")
message("После фильтрации: ", nrow(filtered_data), " статей")
```

## Допустимые категории arXiv

- cs.CR - Cryptography and Security
- cs.AI - Artificial Intelligence
- cs.NI - Networking and Internet Architecture
- cs.SE - Software Engineering
- cs.DC - Distributed Computing
- cs.LG - Machine Learning
- cs.CY - Computers and Society
- cs.DB - Databases
- cs.IR - Information Retrieval
- stat.ML - Machine Learning (Statistics)
- math.OC - Optimization and Control

## Обработка ошибок

**Неверный диапазон max_results:**
```
fetch_arxiv_data(max_results = 0)
# Error: Параметр max_results должен быть в диапазоне от 1 до 1000
```

**Невалидная категория:**
```
fetch_arxiv_data(categories = "invalid.cat")
# Warning: Обнаружены недопустимые категории: invalid.cat
```