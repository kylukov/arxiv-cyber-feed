#' @importFrom dplyr %>%

library(httr)
library(xml2)
library(dplyr)
library(stringr)
library(tibble)
library(lubridate)
library(purrr)

#' Fetch data from arXiv API 
#' @export
fetch_arxiv_data <- function(categories = "cs.CR", 
                             max_results = 10, 
                             verbose = TRUE) {
  
  if (max_results < 1 || max_results > 1000) {
    stop("Параметр max_results должен быть в диапазоне от 1 до 1000")
  }
  
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
  
  search_query <- .construct_arxiv_query(categories)
  
  if (verbose) {
    message("Инициализация сбора данных из arXiv API")
    message("Категории поиска: ", paste(categories, collapse = ", "))
    message("Ожидаемое количество записей: ", max_results)
  }
  
  response <- .execute_arxiv_api_request(search_query, max_results, verbose)
  
  # Защита от сетевых ошибок: если запрос вернул NULL или HTTP‑ошибку,
  # возвращаем пустой tibble вместо падения с ошибкой http_error(NULL)
  if (is.null(response) || httr::http_error(response)) {
    if (verbose) message("Не удалось подключиться к arXiv API (сетевой сбой или ошибка ответа)")
    return(tibble::tibble())
  }
  
  parsed_data <- .parse_arxiv_response(response, verbose)
  
  if (verbose && nrow(parsed_data) > 0) {
    message("Сбор данных завершен успешно")
    message("Получено записей: ", nrow(parsed_data))
  }
  
  return(parsed_data)
}

#' Filter cybersecurity publications 
#' @export
filter_cybersecurity <- function(data, strict_mode = FALSE) {
  
  if (is.null(data) || nrow(data) == 0) {
    warning("Входной набор данных пуст")
    return(data)
  }
  
  base_keywords <- c(
    "security", "cybersecurity", "cyber security", "information security",
    "network security", "computer security", "data security",
    "threat", "attack", "malware", "ransomware", "phishing", "botnet",
    "exploit", "vulnerability", "zero[-\\.]?day", "cve", "cwe",
    "cryptography", "encryption", "cipher", "cryptographic",
    "aes", "rsa", "elliptic curve", "public key", "private key",
    "firewall", "intrusion", "authentication", "authorization",
    "access control", "identity management", "vpn", "ssl", "tls",
    "privacy", "anonymization", "pseudonymization", "data protection",
    "gdpr", "hipaa", "compliance", "regulation"
  )
  
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
  
  keyword_pattern <- paste0("\\b(", paste(keywords, collapse = "|"), ")\\b")
  
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
  
  if (nrow(filtered_data) > 0) {
    message("Выделено публикаций по кибербезопасности: ", 
            nrow(filtered_data), " из ", nrow(data), 
            " (", round(nrow(filtered_data) / nrow(data) * 100, 1), "%)")
  }
  
  return(filtered_data)
}

#' Save collected data to a file
#' @export
save_collected_data <- function(data, file_path, compress = TRUE) {
  
  if (is.null(data) || nrow(data) == 0) {
    warning("Экспорт не выполнен: входные данные отсутствуют")
    return(FALSE)
  }
  
  if (missing(file_path) || is.null(file_path) || file_path == "") {
    stop("Не указан путь для сохранения файла")
  }
  
  target_dir <- dirname(file_path)
  if (!dir.exists(target_dir)) {
    dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)
    message("Создана директория: ", target_dir)
  }
  
  tryCatch({
    saveRDS(object = data, file = file_path, compress = compress)
    
    if (file.exists(file_path)) {
      message("Данные сохранены: ", file_path)
      return(TRUE)
    } else {
      warning("Файл не был создан")
      return(FALSE)
    }
  }, error = function(e) {
    warning("Не удалось сохранить данные: ", e$message)
    return(FALSE)
  })
}

.construct_arxiv_query <- function(categories) {
  if (length(categories) == 1) {
    query <- paste0("cat:", categories)
  } else {
    category_queries <- sapply(categories, function(cat) paste0("cat:", cat))
    query <- paste0("(", paste(category_queries, collapse = " OR "), ")")
  }
  return(query)
}

.execute_arxiv_api_request <- function(search_query, max_results, verbose) {
  
  query_params <- list(
    search_query = search_query,
    start = 0,
    max_results = max_results,
    sortBy = "submittedDate",
    sortOrder = "descending"
  )
  
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
  
  return(response)
}

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

.parse_single_entry <- function(entry, ns, verbose = FALSE) {
  
  tryCatch({
    safe_extract <- function(xpath, attribute = NULL) {
      node <- xml2::xml_find_first(entry, xpath, ns = ns)
      if (is.null(node)) return(NA_character_)
      
      if (!is.null(attribute)) {
        xml2::xml_attr(node, attribute)
      } else {
        xml2::xml_text(node)
      }
    }
    
    id <- safe_extract("./d1:id")
    title <- safe_extract("./d1:title")
    abstract <- safe_extract("./d1:summary")
    published <- safe_extract("./d1:published")
    
    if (any(is.na(c(id, title, abstract, published)))) {
      return(NULL)
    }
    
    author_nodes <- xml2::xml_find_all(entry, "./d1:author/d1:name", ns = ns)
    authors <- if (length(author_nodes) > 0) {
      list(purrr::map_chr(author_nodes, xml2::xml_text))
    } else {
      list(character(0))
    }
    
    category_nodes <- xml2::xml_find_all(entry, "./d1:category", ns = ns)
    categories <- if (length(category_nodes) > 0) {
      list(purrr::map_chr(category_nodes, ~xml2::xml_attr(., "term")))
    } else {
      list(character(0))
    }
    
    arxiv_id <- stringr::str_extract(id, "\\d{4}\\.\\d{4,5}(v\\d+)?")
    doi <- .extract_doi_from_entry(entry, ns, id)
    
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
    return(NULL)
  })
}

.extract_doi_from_entry <- function(entry, ns, id) {
  
  link_nodes <- xml2::xml_find_all(entry, "./d1:link", ns = ns)
  
  for (link in link_nodes) {
    href <- xml2::xml_attr(link, "href")
    if (!is.na(href) && stringr::str_detect(href, "doi\\.org")) {
      return(href)
    }
  }
  
  if (!is.na(id)) {
    doi_match <- stringr::str_extract(id, "10\\.\\d{4,9}/[-._;()/:A-Z0-9]+")
    if (!is.na(doi_match)) {
      return(doi_match)
    }
  }
  
  return(NA_character_)
}

.parse_datetime <- function(datetime_str) {
  tryCatch({
    lubridate::as_datetime(datetime_str)
  }, error = function(e) {
    NA
  })
}

.onAttach <- function(libname, pkgname) {
  packageStartupMessage("Модуль сбора данных из arXiv загружен")
}

fetch_arxiv_data
filter_cybersecurity
save_collected_data