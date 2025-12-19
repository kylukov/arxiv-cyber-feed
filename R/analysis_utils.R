library(dplyr)
library(stringr)
library(purrr)
library(tibble)
library(tidyr)

#' Categorize cybersecurity articles into thematic subcategories
#'
#' This function analyzes article titles and abstracts to assign one or more
#' thematic categories from predefined cybersecurity domains.
#'
#' @param data A data frame containing article records with at least
#'   `title` and `abstract` columns (typically output from `fetch_arxiv_data`)
#' @param mode Character, either "primary" (assign single best category) or
#'   "multi" (assign all matching categories). Default: "primary"
#' @param min_score Numeric, minimum score threshold for category assignment
#'   when mode="multi". Default: 1 (at least one keyword match)
#' @param verbose Logical, whether to print progress messages. Default: TRUE
#'
#' @return A data frame with added `security_category` column (character for
#'   mode="primary") or `security_categories` column (list of character vectors
#'   for mode="multi"). Also includes `category_confidence` score.
#'
#' @export
#' @examples
#' \dontrun{
#' data <- fetch_arxiv_data(categories = "cs.CR", max_results = 50)
#' categorized <- categorize_articles(data, mode = "primary")
#' categorized_multi <- categorize_articles(data, mode = "multi")
#' }
categorize_articles <- function(data, mode = c("primary", "multi"), 
                                min_score = 1, verbose = TRUE) {
  
  if (is.null(data) || nrow(data) == 0) {
    warning("Входной набор данных пуст")
    return(data)
  }
  
  required_cols <- c("title", "abstract")
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    stop("Отсутствуют обязательные колонки: ", paste(missing_cols, collapse = ", "))
  }
  
  mode <- match.arg(mode)
  
  if (verbose) {
    message("Начало категоризации статей...")
    message("Режим: ", mode)
  }
  
  # Define category keyword patterns
  category_patterns <- .get_category_patterns()
  
  # Prepare text for analysis
  data_with_text <- data %>%
    dplyr::mutate(
      search_text = tolower(paste(title, abstract, sep = " "))
    )
  
  # Score each article against each category
  category_scores <- purrr::map_dfc(
    names(category_patterns),
    ~ {
      pattern <- category_patterns[[.x]]
      scores <- stringr::str_count(
        data_with_text$search_text,
        pattern
      )
      tibble::tibble(!!.x := scores)
    }
  )
  
  # Assign categories based on mode
  if (mode == "primary") {
    result <- data_with_text %>%
      dplyr::bind_cols(category_scores) %>%
      dplyr::rowwise() %>%
      dplyr::mutate(
        category_scores_list = list(c(
          cryptography = cryptography,
          network_security = network_security,
          malware_threats = malware_threats,
          access_control = access_control,
          privacy_compliance = privacy_compliance,
          threat_intelligence = threat_intelligence,
          web_security = web_security,
          iot_embedded = iot_embedded,
          ai_security = ai_security,
          blockchain_crypto = blockchain_crypto,
          incident_response = incident_response,
          secure_development = secure_development
        )),
        max_score = max(unlist(category_scores_list)),
        primary_category = ifelse(
          max_score > 0,
          names(category_scores_list)[which.max(unlist(category_scores_list))],
          "other"
        ),
        category_confidence = max_score
      ) %>%
      dplyr::ungroup() %>%
      dplyr::mutate(
        security_category = primary_category,
        security_category = dplyr::case_when(
          security_category == "cryptography" ~ "Криптография",
          security_category == "network_security" ~ "Сетевая безопасность",
          security_category == "malware_threats" ~ "Вредоносное ПО и угрозы",
          security_category == "access_control" ~ "Контроль доступа",
          security_category == "privacy_compliance" ~ "Конфиденциальность и соответствие",
          security_category == "threat_intelligence" ~ "Киберразведка",
          security_category == "web_security" ~ "Веб-безопасность",
          security_category == "iot_embedded" ~ "IoT и встроенные системы",
          security_category == "ai_security" ~ "Безопасность ИИ",
          security_category == "blockchain_crypto" ~ "Блокчейн и криптовалюты",
          security_category == "incident_response" ~ "Реагирование на инциденты",
          security_category == "secure_development" ~ "Безопасная разработка",
          TRUE ~ "Прочее"
        )
      ) %>%
      dplyr::select(-dplyr::any_of(c(
        "cryptography", "network_security", "malware_threats",
        "access_control", "privacy_compliance", "threat_intelligence",
        "web_security", "iot_embedded", "ai_security", "blockchain_crypto",
        "incident_response", "secure_development", "category_scores_list",
        "max_score", "primary_category", "search_text"
      )))
  } else {
    # Multi-category mode
    result <- data_with_text %>%
      dplyr::bind_cols(category_scores) %>%
      dplyr::rowwise() %>%
      dplyr::mutate(
        security_categories = list({
          scores <- c(
            "Криптография" = cryptography,
            "Сетевая безопасность" = network_security,
            "Вредоносное ПО и угрозы" = malware_threats,
            "Контроль доступа" = access_control,
            "Конфиденциальность и соответствие" = privacy_compliance,
            "Киберразведка" = threat_intelligence,
            "Веб-безопасность" = web_security,
            "IoT и встроенные системы" = iot_embedded,
            "Безопасность ИИ" = ai_security,
            "Блокчейн и криптовалюты" = blockchain_crypto,
            "Реагирование на инциденты" = incident_response,
            "Безопасная разработка" = secure_development
          )
          names(scores)[scores >= min_score]
        }),
        category_confidence = max(c(
          cryptography, network_security, malware_threats,
          access_control, privacy_compliance, threat_intelligence,
          web_security, iot_embedded, ai_security, blockchain_crypto,
          incident_response, secure_development
        ))
      ) %>%
      dplyr::ungroup() %>%
      dplyr::mutate(
        security_categories = ifelse(
          purrr::map_int(security_categories, length) == 0,
          list("Прочее"),
          security_categories
        )
      ) %>%
      dplyr::select(-dplyr::any_of(c(
        "cryptography", "network_security", "malware_threats",
        "access_control", "privacy_compliance", "threat_intelligence",
        "web_security", "iot_embedded", "ai_security", "blockchain_crypto",
        "incident_response", "secure_development", "search_text"
      )))
  }
  
  if (verbose) {
    if (mode == "primary") {
      cat_table <- result %>%
        dplyr::count(security_category, sort = TRUE)
      message("\nРаспределение по категориям:")
      print(cat_table)
    } else {
      cat_table <- result %>%
        tidyr::unnest_longer(security_categories, values_to = "category") %>%
        dplyr::count(category, sort = TRUE)
      message("\nРаспределение по категориям:")
      print(cat_table)
    }
    message("\nКатегоризация завершена. Обработано статей: ", nrow(result))
  }
  
  return(result)
}

#' Get category keyword patterns
#' @keywords internal
.get_category_patterns <- function() {
  
  list(
    # Криптография
    cryptography = "\\b(aes|rsa|ecdsa|elliptic curve|public key|private key|cipher|cryptographic|cryptography|encryption|decryption|symmetric|asymmetric|hash function|digital signature|certificate|pki|tls|ssl|dtls|mac|hmac|sha|md5|block cipher|stream cipher|quantum cryptography|post[\\- ]quantum|homomorphic encryption)\\b",
    
    # Сетевая безопасность
    network_security = "\\b(network security|firewall|ids|ips|intrusion detection|intrusion prevention|ddos|denial of service|network attack|packet inspection|network monitoring|vpn|virtual private network|network segmentation|microsegmentation|sdn security|network function virtualization)\\b",
    
    # Вредоносное ПО и угрозы
    malware_threats = "\\b(malware|ransomware|trojan|virus|worm|botnet|rootkit|spyware|adware|apt|advanced persistent threat|zero[\\- ]day|exploit|vulnerability|cve|cwe|attack vector|attack surface|threat actor|payload|backdoor|command and control|c2|phishing|spear phishing|social engineering)\\b",
    
    # Контроль доступа
    access_control = "\\b(authentication|authorization|access control|identity management|iam|rbac|abac|multi[\\- ]factor|mfa|two[\\- ]factor|2fa|single sign[\\- ]on|sso|oauth|saml|ldap|active directory|privileged access|least privilege|zero trust)\\b",
    
    # Конфиденциальность и соответствие
    privacy_compliance = "\\b(privacy|gdpr|hipaa|pci[\\- ]dss|compliance|regulation|data protection|anonymization|pseudonymization|differential privacy|k[\\- ]anonymity|l[\\- ]diversity|data minimization|consent management|right to be forgotten|data breach notification)\\b",
    
    # Киберразведка
    threat_intelligence = "\\b(threat intelligence|cyber threat|indicators of compromise|ioc|tactics techniques procedures|ttp|mitre att&ck|threat hunting|threat modeling|threat actor|apt group|indicator sharing|stiх|taxii|yara|sigma rules|osint|open source intelligence)\\b",
    
    # Веб-безопасность
    web_security = "\\b(web security|sql injection|xss|cross[\\- ]site scripting|csrf|cross[\\- ]site request forgery|owasp|secure coding|api security|rest api security|graphql security|content security policy|csp|secure headers|session management|csrf token|same[\\- ]origin policy)\\b",
    
    # IoT и встроенные системы
    iot_embedded = "\\b(iot|internet of things|embedded security|industrial control system|ics|scada|iot device|smart device|wearable security|automotive security|vehicle security|cyber[\\- ]physical|critical infrastructure|smart grid|sensor security)\\b",
    
    # Безопасность ИИ
    ai_security = "\\b(ai security|machine learning security|ml security|adversarial attack|adversarial example|model poisoning|backdoor attack|data poisoning|federated learning security|model extraction|membership inference|privacy preserving ml|differential privacy ml|secure ml)\\b",
    
    # Блокчейн и криптовалюты
    blockchain_crypto = "\\b(blockchain security|smart contract security|consensus mechanism|proof of work|proof of stake|cryptocurrency security|bitcoin security|ethereum security|defi security|nft security|distributed ledger security|byzantine fault tolerance)\\b",
    
    # Реагирование на инциденты
    incident_response = "\\b(incident response|digital forensics|computer forensics|network forensics|memory forensics|malware analysis|static analysis|dynamic analysis|sandbox|threat hunting|soar|security orchestration|playbook|siem|security information and event management|security operations|soc|security operations center)\\b",
    
    # Безопасная разработка
    secure_development = "\\b(secure development|secure coding|secure software development|ssdlc|security by design|devsecops|application security|code review|static application security testing|sast|dynamic application security testing|dast|penetration testing|vulnerability assessment|bug bounty|secure architecture|threat modeling)\\b"
  )
}

#' Get category statistics from categorized data
#'
#' @param data Categorized data frame (output from `categorize_articles`)
#' @param mode Character, either "primary" or "multi" matching the mode
#'   used in categorization. Default: "primary"
#'
#' @return A summary data frame with category counts and percentages
#' @export
get_category_stats <- function(data, mode = c("primary", "multi")) {
  
  mode <- match.arg(mode)
  
  if (mode == "primary") {
    if (!"security_category" %in% names(data)) {
      stop("Колонка security_category не найдена. Используйте categorize_articles с mode='primary'")
    }
    
    stats <- data %>%
      dplyr::count(security_category, sort = TRUE) %>%
      dplyr::mutate(
        percentage = round(n / sum(n) * 100, 2),
        cumulative_pct = round(cumsum(percentage), 2)
      )
  } else {
    if (!"security_categories" %in% names(data)) {
      stop("Колонка security_categories не найдена. Используйте categorize_articles с mode='multi'")
    }
    
    stats <- data %>%
      tidyr::unnest_longer(security_categories, values_to = "category") %>%
      dplyr::count(category, sort = TRUE) %>%
      dplyr::mutate(
        percentage = round(n / sum(n) * 100, 2),
        cumulative_pct = round(cumsum(percentage), 2)
      )
  }
  
  return(stats)
}