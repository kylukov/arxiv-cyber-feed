# Тесты arxiv-cyber-feed

## Структура

```
tests/
├── README.md                       # этот файл
├── TESTING.md                      # подробная документация по тестированию
├── CATEGORIZATION_REPORT.md        # отчёт о тестировании категоризации
├── testthat.R                      # конфигурация testthat
├── testthat/                       # автоматические unit-тесты (testthat)
└── manual/                         # ручные интеграционные тесты
    ├── quick_test_categorization.R           # быстрый тест (1-2 мин)
    ├── test_functionality.R                  # полный функциональный тест
    ├── test_categorization.R                 # детальный тест категоризации
    └── analyze_categorization_quality.R      # анализ качества категоризации
```

## Быстрый старт

### Рекомендуемая последовательность

1. **Быстрая проверка категоризации** (1-2 минуты)
   ```bash
   Rscript tests/manual/quick_test_categorization.R
   ```

2. **Полная проверка функционала** (2-3 минуты)
   ```bash
   Rscript tests/manual/test_functionality.R
   ```

3. **Детальный анализ категоризации** (3-5 минут)
   ```bash
   Rscript tests/manual/test_categorization.R
   ```

4. **Анализ качества** (2-3 минуты)
   ```bash
   Rscript tests/manual/analyze_categorization_quality.R
   ```

## Описание тестов

### Ручные тесты (manual/)

#### `quick_test_categorization.R`
**Назначение:** Быстрая проверка работоспособности категоризации  
**Время:** ~1-2 минуты  
**Проверяет:**
- Сбор данных из arXiv
- Категоризация в primary и multi режимах
- Интеграция с storage_utils
- Нормализация данных

**Запуск:**
```bash
cd /Users/peter/Documents/arxiv-cyber-feed
Rscript tests/manual/quick_test_categorization.R
```

#### `test_functionality.R`
**Назначение:** Комплексное тестирование всех модулей пакета  
**Время:** ~2-3 минуты  
**Проверяет:**
- Сбор данных из arXiv API
- Фильтрация по кибербезопасности
- Категоризация (primary и multi)
- Нормализация данных
- Сохранение в Parquet
- End-to-end pipeline
- Статистика категорий

**Запуск:**
```bash
Rscript tests/manual/test_functionality.R
```

#### `test_categorization.R`
**Назначение:** Детальное тестирование категоризации и интеграции  
**Время:** ~3-5 минут  
**Проверяет:**
- Оба режима категоризации (primary/multi)
- Структуру данных после категоризации
- Интеграцию с storage_utils
- Сохранение в Parquet/DuckDB
- End-to-end pipeline с категоризацией
- Крайние случаи (пустые данные, отсутствие колонок)
- Разные пороги min_score

**Запуск:**
```bash
Rscript tests/manual/test_categorization.R
```

#### `analyze_categorization_quality.R`
**Назначение:** Анализ качества категоризации  
**Время:** ~2-3 минуты  
**Проверяет:**
- Детальный анализ категоризации каждой статьи
- Распределение по категориям
- Уверенность категоризации
- Статьи с низкой/высокой уверенностью

**Запуск:**
```bash
Rscript tests/manual/analyze_categorization_quality.R
```

## Автоматические тесты (testthat/)

### Запуск unit-тестов

```r
# В R консоли
devtools::test()

# Или через testthat
testthat::test_dir("tests/testthat")
```

## Требования

Убедитесь, что установлены все необходимые пакеты:

```r
install.packages(c(
  "dplyr", "tidyr", "tibble", "purrr", "stringr",
  "httr", "xml2", "lubridate",
  "arrow", "DBI", "duckdb",
  "testthat", "devtools"
))
```

## Ожидаемые результаты

### Успешное выполнение

Все тесты должны завершаться с exit code 0 и выводить:
- ✅ или "✓" для успешных проверок
- Статистику по категоризации
- Примеры категоризированных статей

### Типичные проблемы

1. **Отсутствие пакета arrow**
   ```r
   install.packages("arrow")
   ```

2. **Ошибка подключения к arXiv API**
   - Проверьте интернет-соединение
   - arXiv API может быть временно недоступен
   - Уменьшите `max_results`

3. **Пустые результаты фильтрации**
   - Попробуйте `strict_mode = FALSE`
   - Проверьте категорию arXiv

## Дополнительная документация

- **TESTING.md** - подробное руководство по тестированию всех функций
- **CATEGORIZATION_REPORT.md** - отчёт о категоризации и её интеграции

## Очистка тестовых данных

После запуска тестов могут остаться временные директории:

```bash
# Удалить все тестовые выходные данные
rm -rf test-* data-raw/*.parquet inst/data/*.duckdb
```

## Разработка новых тестов

### Добавление unit-теста (testthat)

Создайте файл `tests/testthat/test_module_name.R`:

```r
test_that("описание теста", {
  # ваш тест
  expect_equal(result, expected)
})
```

### Добавление ручного теста

Создайте файл `tests/manual/test_new_feature.R`:

```r
#!/usr/bin/env Rscript
source("R/your_module.R")

cat("=== Тест новой функциональности ===\n")
# ваш код теста
```

Сделайте файл исполняемым:
```bash
chmod +x tests/manual/test_new_feature.R
```
