# ==============================================================================
# ФАЙЛ: collect_data.R
# МОДУЛЬ СБОРА ДАННЫХ ИЗ ARXIV ДЛЯ КИБЕРБЕЗОПАСНОСТИ
# Участник 1: Сбор данных (ETL-процесс)
# ==============================================================================

# Зависимости
library(httr)
library(xml2)
library(dplyr)
library(stringr)
library(tibble)
library(lubridate)
library(purrr)
library(glue)

# ==============================================================================
# ОСНОВНЫЕ ФУНКЦИИ СБОРА ДАННЫХ
# ==============================================================================

#' Сбор метаданных публикаций из arXiv
#'
#' Основная функция для извлечения метаинформации научных статей через arXiv API.
#' Реализует ETL-процесс: Extract (извлечение), Transform (преобразование), 
#' Load (структурирование) данных.
#'
#' @param categories Вектор категорий arXiv. По умолчанию "cs.CR" (криптография и безопасность).
#'                  Допустимые значения: "cs.CR", "cs.AI", "cs.NI", "cs.SE", "cs.DC", 
#'                  "cs.LG", "cs.CY", "cs.DB", "cs.IR", "stat.ML", "math.OC"
#' @param max_results Максимальное количество возвращаемых записей (1-1000)
#' @param verbose Логический параметр, контролирующий вывод прогресс-сообщений
#'
#' @return Объект класса `tbl_df` (tibble) со следующими полями:
#'   \item{arxiv_id}{Уникальный идентификатор arXiv (формат: ГГГГ.ННННН)}
#'   \item{title}{Название публикации}
#'   \item{authors}{Список авторов}
#'   \item{abstract}{Аннотация статьи}
#'   \item{categories}{Категории arXiv, к которым относится публикация}
#'   \item{published_date}{Дата и время публикации (тип POSIXct)}
#'   \item{doi}{Digital Object Identifier (если доступен)}
#'   \item{collection_date}{Дата и время сбора данных}
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Получение 10 последних публикаций по криптографии и безопасности
#' publications <- fetch_arxiv_data(categories = "cs.CR", max_results = 10)
#'
#' # Сбор данных по нескольким категориям
#' multi_cat_data <- fetch_arxiv_data(
#'   categories = c("cs.CR", "cs.AI", "cs.NI"),
#'   max_results = 50,
#'   verbose = TRUE
#' )
#' }
fetch_arxiv_data <- function(categories = "cs.CR", 
                             max_results = 10, 
                             verbose = TRUE) {
  
  # Валидация входных параметров
  if (max_results < 1 || max_results > 1000) {
    stop("Параметр max_results должен быть в диапазоне от 1 до 1000")
  }
  
  # Проверка допустимости категорий
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
  
  # Формирование поискового запроса
  search_query <- .construct_arxiv_query(categories)
  
  if (verbose) {
    message("[ETL] Инициализация сбора данных из arXiv API")
    message("[ETL] Категории поиска: ", paste(categories, collapse = ", "))
    message("[ETL] Ожидаемое количество записей: ", max_results)
  }
  
  # Выполнение HTTP-запроса к arXiv API
  response <- .execute_arxiv_api_request(search_query, max_results, verbose)
  
  if (httr::http_error(response)) {
    if (verbose) message("[ОШИБКА] Не удалось подключиться к arXiv API")
    return(tibble::tibble())
  }
  
  # Обработка XML-ответа
  parsed_data <- .parse_arxiv_response(response, verbose)
  
  if (verbose) {
    if (nrow(parsed_data) > 0) {
      message("[УСПЕХ] Сбор данных завершен успешно")
      message("[СТАТИСТИКА] Получено записей: ", nrow(parsed_data))
      date_range <- range(parsed_data$published_date, na.rm = TRUE)
      if (!any(is.na(date_range))) {
        message("[ПЕРИОД] С ", format(date_range[1], "%Y-%m-%d"), 
                " по ", format(date_range[2], "%Y-%m-%d"))
      }
    } else {
      message("[ПРЕДУПРЕЖДЕНИЕ] По указанным критериям публикации не найдены")
    }
  }
  
  return(parsed_data)
}

#' Фильтрация публикаций по тематике кибербезопасности
#'
#' Применяет алгоритм текстового анализа для идентификации публикаций,
#' относящихся к области информационной безопасности и кибербезопасности.
#'
#' @param data Объект `tbl_df`, содержащий метаданные публикаций
#' @param strict_mode Логический параметр. Если TRUE, применяются более строгие 
#'                   критерии фильтрации, ориентированные на профессиональную 
#'                   терминологию кибербезопасности
#'
#' @return Отфильтрованный `tbl_df`, содержащий только релевантные публикации
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Базовая фильтрация
#' raw_data <- fetch_arxiv_data(max_results = 20)
#' security_publications <- filter_cybersecurity(raw_data)
#'
#' # Строгая фильтрация
#' strict_security <- filter_cybersecurity(raw_data, strict_mode = TRUE)
#' }
filter_cybersecurity <- function(data, strict_mode = FALSE) {
  
  # Проверка входных данных
  if (is.null(data) || nrow(data) == 0) {
    warning("Входной набор данных пуст")
    return(data)
  }
  
  # Базовый словарь ключевых терминов кибербезопасности
  base_keywords <- c(
    # Основные понятия
    "security", "cybersecurity", "cyber security", "information security",
    "network security", "computer security", "data security",
    
    # Угрозы и уязвимости
    "threat", "attack", "malware", "ransomware", "phishing", "botnet",
    "exploit", "vulnerability", "zero[-\\.]?day", "cve", "cwe",
    
    # Криптография
    "cryptography", "encryption", "cipher", "cryptographic",
    "aes", "rsa", "elliptic curve", "public key", "private key",
    
    # Протоколы и механизмы защиты
    "firewall", "intrusion", "authentication", "authorization",
    "access control", "identity management", "vpn", "ssl", "tls",
    
    # Конфиденциальность и приватность
    "privacy", "anonymization", "pseudonymization", "data protection",
    "gdpr", "hipaa", "compliance", "regulation"
  )
  
  # Расширенный словарь для строгого режима
  if (strict_mode) {
    extended_keywords <- c(
      "threat intelligence", "advanced persistent threat", "apt",
      "attack vector", "attack surface", "mitre att&ck", "ttp",
      "incident response", "digital forensics", "security audit",
      "penetration testing", "red team", "blue team", "purple team",
      "security operations center", "soc", "siem", "soar",
      "endpoint detection and response", "edr", "xdr"
    )
    keywords <- c(base_keywords, extended_keywords)
  } else {
    keywords <- base_keywords
  }
  
  # Создание регулярного выражения для поиска
  keyword_pattern <- paste0("\\b(", paste(keywords, collapse = "|"), ")\\b")
  
  # Применение фильтрации
  filtered_data <- data %>%
    dplyr::mutate(
      # Приведение текста к нижнему регистру для регистронезависимого поиска
      search_text = tolower(paste(title, abstract)),
      
      # Поиск совпадений с ключевыми словами
      keyword_matches = stringr::str_extract_all(search_text, keyword_pattern),
      
      # Подсчет количества найденных ключевых слов
      match_count = purrr::map_int(keyword_matches, length),
      
      # Флаг релевантности
      is_relevant = match_count > 0
    ) %>%
    dplyr::filter(is_relevant) %>%
    dplyr::arrange(desc(match_count)) %>%
    dplyr::select(-search_text, -keyword_matches, -match_count, -is_relevant)
  
  # Логирование результатов фильтрации
  if (nrow(filtered_data) > 0) {
    message("[ФИЛЬТРАЦИЯ] Выделено публикаций по кибербезопасности: ", 
            nrow(filtered_data), " из ", nrow(data), 
            " (", round(nrow(filtered_data) / nrow(data) * 100, 1), "%)")
  } else {
    message("[ФИЛЬТРАЦИЯ] Публикации по кибербезопасности не обнаружены")
  }
  
  return(filtered_data)
}

#' Экспорт собранных данных в файл
#'
#' Сохраняет структурированные метаданные публикаций в формате RDS
#' с автоматическим созданием необходимых директорий.
#'
#' @param data Объект `tbl_df` для сохранения
#' @param file_path Полный путь к файлу назначения
#' @param compress Использовать ли сжатие при сохранении (рекомендуется TRUE)
#'
#' @return Логическое значение: TRUE при успешном сохранении, FALSE при ошибке
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Сохранение данных
#' data <- fetch_arxiv_data(max_results = 50)
#' success <- save_collected_data(
#'   data = data,
#'   file_path = "data/raw/arxiv_publications.rds",
#'   compress = TRUE
#' )
#'
#' if (success) {
#'   message("Данные успешно сохранены")
#' }
#' }
save_collected_data <- function(data, file_path, compress = TRUE) {
  
  # Проверка входных данных
  if (is.null(data) || nrow(data) == 0) {
    warning("Экспорт не выполнен: входные данные отсутствуют")
    return(FALSE)
  }
  
  if (missing(file_path) || is.null(file_path) || file_path == "") {
    stop("Не указан путь для сохранения файла")
  }
  
  # Создание директорий при необходимости
  target_dir <- dirname(file_path)
  if (!dir.exists(target_dir)) {
    dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)
    message("[СИСТЕМА] Создана директория: ", target_dir)
  }
  
  # Сохранение данных
  tryCatch({
    saveRDS(object = data, file = file_path, compress = compress)
    
    # Проверка успешности сохранения
    if (file.exists(file_path)) {
      file_size <- file.info(file_path)$size
      message("[ЭКСПОРТ] Данные сохранены: ", file_path)
      message("[ЭКСПОРТ] Размер файла: ", 
              format(file_size, big.mark = ",", scientific = FALSE), " байт")
      message("[ЭКСПОРТ] Количество записей: ", nrow(data))
      return(TRUE)
    } else {
      warning("[ОШИБКА] Файл не был создан")
      return(FALSE)
    }
  }, error = function(e) {
    warning("[ОШИБКА] Не удалось сохранить данные: ", e$message)
    return(FALSE)
  })
}

# ==============================================================================
# СЛУЖЕБНЫЕ ФУНКЦИИ (ВНУТРЕННИЕ)
# ==============================================================================

#' Конструктор поискового запроса для arXiv API
#'
#' @param categories Вектор категорий arXiv
#'
#' @return Строка поискового запроса в формате arXiv API
#' @keywords internal
.construct_arxiv_query <- function(categories) {
  
  if (length(categories) == 1) {
    query <- paste0("cat:", categories)
  } else {
    category_queries <- sapply(categories, function(cat) paste0("cat:", cat))
    query <- paste0("(", paste(category_queries, collapse = " OR "), ")")
  }
  
  return(query)
}

#' Исполнитель запросов к arXiv API
#'
#' @param search_query Поисковый запрос
#' @param max_results Максимальное количество результатов
#' @param verbose Флаг вывода отладочной информации
#'
#' @return Объект ответа HTTP
#' @keywords internal
.execute_arxiv_api_request <- function(search_query, max_results, verbose) {
  
  # Параметры запроса согласно документации arXiv API
  query_params <- list(
    search_query = search_query,
    start = 0,
    max_results = max_results,
    sortBy = "submittedDate",
    sortOrder = "descending"
  )
  
  if (verbose) {
    message("[API] Формирование запроса к arXiv API")
    message("[API] URL: http://export.arxiv.org/api/query")
  }
  
  # Выполнение HTTP-GET запроса с обработкой таймаутов
  response <- tryCatch({
    httr::GET(
      url = "http://export.arxiv.org/api/query",
      query = query_params,
      httr::user_agent("arXiv-Cybersecurity-Collector/1.0"),
      httr::timeout(30)  # 30-секундный таймаут
    )
  }, error = function(e) {
    if (verbose) message("[ОШИБКА] Сетевая ошибка: ", e$message)
    return(NULL)
  })
  
  return(response)
}

#' Парсер XML-ответа arXiv API
#'
#' @param response Объект HTTP-ответа
#' @param verbose Флаг вывода отладочной информации
#'
#' @return Структурированные данные в формате tibble
#' @keywords internal
.parse_arxiv_response <- function(response, verbose) {
  
  # Извлечение содержимого ответа
  response_content <- httr::content(response, as = "text", encoding = "UTF-8")
  
  if (nchar(trimws(response_content)) == 0) {
    if (verbose) message("[ПАРСИНГ] Получен пустой ответ от API")
    return(tibble::tibble())
  }
  
  # Парсинг XML с обработкой ошибок
  xml_doc <- tryCatch({
    xml2::read_xml(response_content)
  }, error = function(e) {
    if (verbose) message("[ОШИБКА] Невалидный XML: ", e$message)
    return(NULL)
  })
  
  if (is.null(xml_doc)) {
    return(tibble::tibble())
  }
  
  # Извлечение пространств имен XML
  xml_namespaces <- xml2::xml_ns(xml_doc)
  
  # Поиск записей (статей) в XML
  entries <- xml2::xml_find_all(xml_doc, "//d1:entry", ns = xml_namespaces)
  
  if (length(entries) == 0) {
    if (verbose) message("[ПАРСИНГ] В ответе не найдено записей о публикациях")
    return(tibble::tibble())
  }
  
  if (verbose) {
    message("[ПАРСИНГ] Обнаружено записей: ", length(entries))
  }
  
  # Парсинг каждой записи
  parsed_entries <- purrr::map(entries, .parse_single_entry, 
                              ns = xml_namespaces, verbose = verbose)
  
  # Фильтрация NULL-результатов и объединение
  valid_entries <- purrr::discard(parsed_entries, is.null)
  
  if (length(valid_entries) == 0) {
    return(tibble::tibble())
  }
  
  # Создание итоговой таблицы
  result <- dplyr::bind_rows(valid_entries)
  
  return(result)
}

#' Парсер отдельной записи (публикации)
#'
#' @param entry XML-элемент записи
#' @param ns Пространство имен XML
#' @param verbose Флаг вывода отладочной информации
#'
#' @return tibble с данными одной публикации
#' @keywords internal
.parse_single_entry <- function(entry, ns, verbose = FALSE) {
  
  tryCatch({
    # Функция для безопасного извлечения XML-данных
    safe_extract <- function(xpath, attribute = NULL) {
      node <- xml2::xml_find_first(entry, xpath, ns = ns)
      if (is.null(node)) return(NA_character_)
      
      if (!is.null(attribute)) {
        xml2::xml_attr(node, attribute)
      } else {
        xml2::xml_text(node)
      }
    }
    
    # Извлечение обязательных полей
    id <- safe_extract("./d1:id")
    title <- safe_extract("./d1:title")
    abstract <- safe_extract("./d1:summary")
    published <- safe_extract("./d1:published")
    
    # Проверка наличия обязательных полей
    if (any(is.na(c(id, title, abstract, published)))) {
      if (verbose) message("[ПАРСИНГ] Пропущена запись с отсутствующими обязательными полями")
      return(NULL)
    }
    
    # Извлечение списка авторов
    author_nodes <- xml2::xml_find_all(entry, "./d1:author/d1:name", ns = ns)
    authors <- if (length(author_nodes) > 0) {
      list(purrr::map_chr(author_nodes, xml2::xml_text))
    } else {
      list(character(0))
    }
    
    # Извлечение категорий
    category_nodes <- xml2::xml_find_all(entry, "./d1:category", ns = ns)
    categories <- if (length(category_nodes) > 0) {
      list(purrr::map_chr(category_nodes, ~xml2::xml_attr(., "term")))
    } else {
      list(character(0))
    }
    
    # Извлечение идентификатора arXiv
    arxiv_id <- stringr::str_extract(id, "\\d{4}\\.\\d{4,5}(v\\d+)?")
    
    # Извлечение DOI (если доступен)
    doi <- .extract_doi_from_entry(entry, ns, id)
    
    # Создание структурированной записи
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
    
    return(publication_record)
    
  }, error = function(e) {
    if (verbose) message("[ОШИБКА] Ошибка парсинга записи: ", e$message)
    return(NULL)
  })
}

#' Извлечение DOI из записи
#'
#' @param entry XML-элемент записи
#' @param ns Пространство имен XML
#' @param id Идентификатор записи
#'
#' @return DOI или NA
#' @keywords internal
.extract_doi_from_entry <- function(entry, ns, id) {
  
  # Поиск DOI в ссылках
  link_nodes <- xml2::xml_find_all(entry, "./d1:link", ns = ns)
  
  for (link in link_nodes) {
    href <- xml2::xml_attr(link, "href")
    if (!is.na(href) && stringr::str_detect(href, "doi\\.org")) {
      return(href)
    }
  }
  
  # Поиск DOI в идентификаторе arXiv
  if (!is.na(id)) {
    doi_match <- stringr::str_extract(id, "10\\.\\d{4,9}/[-._;()/:A-Z0-9]+")
    if (!is.na(doi_match)) {
      return(doi_match)
    }
  }
  
  return(NA_character_)
}

#' Парсер даты и времени
#'
#' @param datetime_str Строка с датой и временем
#'
#' @return Объект POSIXct или NA
#' @keywords internal
.parse_datetime <- function(datetime_str) {
  tryCatch({
    lubridate::as_datetime(datetime_str)
  }, error = function(e) {
    NA
  })
}

# ==============================================================================
# ФУНКЦИИ ДЛЯ ТЕСТИРОВАНИЯ И ДЕМОНСТРАЦИИ
# ==============================================================================

#' Демонстрация функциональности модуля сбора данных
#'
#' Предоставляет интерактивную демонстрацию основных возможностей модуля,
#' включая тестирование подключения к API, сбор данных, фильтрацию и экспорт.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Запуск демонстрации
#' demo_collect_module()
#' }
demo_collect_module <- function() {
  
  cat("\n")
  cat("╔══════════════════════════════════════════════════════════════╗\n")
  cat("║               ДЕМОНСТРАЦИЯ МОДУЛЯ СБОРА ДАННЫХ               ║\n")
  cat("║                    Участник 1: ETL-процесс                   ║\n")
  cat("╚══════════════════════════════════════════════════════════════╝\n")
  cat("\n")
  
  cat("1. 📡 ТЕСТИРОВАНИЕ ПОДКЛЮЧЕНИЯ К ARXIV API\n")
  cat("   ──────────────────────────────────────\n")
  
  test_data <- fetch_arxiv_data(
    categories = "cs.CR",
    max_results = 3,
    verbose = TRUE
  )
  
  if (nrow(test_data) > 0) {
    cat("\n   ✅ ПОДКЛЮЧЕНИЕ УСПЕШНО\n")
    cat("   ──────────────────────\n")
    cat("   Получено публикаций: ", nrow(test_data), "\n")
    cat("   Источник данных: arXiv API\n")
    cat("   Категория поиска: cs.CR (Cryptography and Security)\n")
    
    cat("\n2. 🔍 ОБРАЗЕЦ СОБРАННЫХ ДАННЫХ\n")
    cat("   ────────────────────────────\n")
    
    # Отображение образца данных
    sample_display <- test_data %>%
      dplyr::select(arxiv_id, title, published_date) %>%
      dplyr::mutate(
        published_date = format(published_date, "%Y-%m-%d"),
        title_short = ifelse(nchar(title) > 60, 
                            paste0(substr(title, 1, 57), "..."), 
                            title)
      )
    
    for (i in 1:nrow(sample_display)) {
      cat("   ", i, ". ", sample_display$arxiv_id[i], "\n", sep = "")
      cat("      ", sample_display$title_short[i], "\n", sep = "")
      cat("      📅 ", sample_display$published_date[i], "\n\n", sep = "")
    }
    
    cat("3. 🛡️  ФИЛЬТРАЦИЯ ПО КИБЕРБЕЗОПАСНОСТИ\n")
    cat("   ──────────────────────────────────\n")
    
    security_data <- filter_cybersecurity(test_data)
    
    cat("   Исходный набор: ", nrow(test_data), " публикаций\n")
    cat("   После фильтрации: ", nrow(security_data), " публикаций\n")
    cat("   Релевантность: ", 
        round(nrow(security_data) / nrow(test_data) * 100, 1), "%\n")
    
    cat("\n4. 💾 ТЕСТИРОВАНИЕ ЭКСПОРТА ДАННЫХ\n")
    cat("   ────────────────────────────────\n")
    
    # Создание временного файла для демонстрации
    temp_file_path <- tempfile(pattern = "arxiv_demo_", fileext = ".rds")
    
    export_success <- save_collected_data(
      data = test_data,
      file_path = temp_file_path,
      compress = TRUE
    )
    
    if (export_success) {
      cat("   ✅ ЭКСПОРТ УСПЕШЕН\n")
      cat("   ────────────────\n")
      cat("   Файл: ", basename(temp_file_path), "\n")
      cat("   Размер: ", 
          format(file.info(temp_file_path)$size, big.mark = ","), " байт\n")
      cat("   Формат: RDS (R Data Serialization)\n")
      
      # Загрузка для проверки целостности
      loaded_data <- readRDS(temp_file_path)
      cat("   Проверка целостности: ", 
          ifelse(nrow(loaded_data) == nrow(test_data), "✅", "❌"), "\n")
      
      # Очистка временного файла
      file.remove(temp_file_path)
      cat("   Временный файл удален\n")
    }
    
    cat("\n5. 📋 РЕКОМЕНДАЦИИ ПО ИСПОЛЬЗОВАНИЮ В ПРОЕКТЕ\n")
    cat("   ──────────────────────────────────────────\n")
    cat("   Для интеграции в проект используйте следующий подход:\n\n")
    cat("   ```r\n")
    cat("   # 1. Инициализация сбора данных\n")
    cat("   library(your_package_name)\n")
    cat("\n")
    cat("   # 2. Конфигурация параметров сбора\n")
    cat("   categories <- c(\"cs.CR\", \"cs.AI\", \"cs.NI\")\n")
    cat("   max_records <- 500\n")
    cat("   output_dir <- \"data/raw\"\n")
    cat("\n")
    cat("   # 3. Выполнение ETL-процесса\n")
    cat("   raw_publications <- fetch_arxiv_data(\n")
    cat("     categories = categories,\n")
    cat("     max_results = max_records,\n")
    cat("     verbose = TRUE\n")
    cat("   )\n")
    cat("\n")
    cat("   # 4. Применение предметной фильтрации\n")
    cat("   cybersecurity_publications <- filter_cybersecurity(raw_publications)\n")
    cat("\n")
    cat("   # 5. Сохранение результатов\n")
    cat("   save_collected_data(\n")
    cat("     data = cybersecurity_publications,\n")
    cat("     file_path = file.path(output_dir, \"arxiv_cybersecurity.rds\")\n")
    cat("   )\n")
    cat("   ```\n")
    
  } else {
    cat("\n   ❌ ПОДКЛЮЧЕНИЕ НЕ УДАЛОСЬ\n")
    cat("   ────────────────────────\n")
    cat("   Возможные причины:\n")
    cat("   • Отсутствует подключение к интернету\n")
    cat("   • arXiv API временно недоступен\n")
    cat("   • Указаны недопустимые параметры запроса\n")
  }
  
  cat("\n")
  cat("╔══════════════════════════════════════════════════════════════╗\n")
  cat("║          ДЕМОНСТРАЦИЯ ЗАВЕРШЕНА УСПЕШНО                      ║\n")
  cat("╚══════════════════════════════════════════════════════════════╝\n")
  cat("\n")
}

# ==============================================================================
# ИНИЦИАЛИЗАЦИЯ И ЭКСПОРТ
# ==============================================================================

#' Инициализация модуля при загрузке
#'
#' @param libname Имя библиотеки
#' @param pkgname Имя пакета
#'
#' @keywords internal
.onAttach <- function(libname, pkgname) {
  
  startup_message <- paste(
    "\n",
    "╔══════════════════════════════════════════════════════════════╗\n",
    "║            МОДУЛЬ СБОРА ДАННЫХ ИЗ ARXIV                     ║\n",
    "║            Версия 1.0 | Участник 1: ETL-процесс             ║\n",
    "╚══════════════════════════════════════════════════════════════╝\n",
    "\n",
    "📊 ДОСТУПНЫЕ ФУНКЦИИ:\n",
    "   • fetch_arxiv_data()     – Сбор метаданных публикаций\n",
    "   • filter_cybersecurity() – Фильтрация по кибербезопасности\n",
    "   • save_collected_data()  – Экспорт данных в файл\n",
    "   • demo_collect_module()  – Интерактивная демонстрация\n",
    "\n",
    "📚 ДОКУМЕНТАЦИЯ:\n",
    "   Используйте help(название_функции) для получения справки\n",
    "\n",
    "🧪 ТЕСТИРОВАНИЕ:\n",
    "   Запустите demo_collect_module() для проверки работы модуля\n",
    "\n",
    sep = ""
  )
  
  packageStartupMessage(startup_message)
}

# Экспорт публичных функций
#' @export
fetch_arxiv_data
#' @export
filter_cybersecurity
#' @export
save_collected_data
#' @export
demo_collect_module

# ==============================================================================
# КОНЕЦ ФАЙЛА collect_data.R
# ==============================================================================