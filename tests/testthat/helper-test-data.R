get_sample_arxiv_xml <- function() {
  '<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title type="html">ArXiv Query: search_query=cat:cs.CR&amp;id_list=&amp;start=0&amp;max_results=2</title>
  <id>http://arxiv.org/api/cHxbiOdZaP56ODnBPIenZhzg5f8</id>
  <updated>2024-01-15T00:00:00-05:00</updated>
  <opensearch:totalResults xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1/">2</opensearch:totalResults>
  <opensearch:startIndex xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1/">0</opensearch:startIndex>
  <opensearch:itemsPerPage xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1/">2</opensearch:itemsPerPage>
  <entry>
    <id>http://arxiv.org/abs/2412.12345v1</id>
    <updated>2024-12-15T12:00:00Z</updated>
    <published>2024-12-15T12:00:00Z</published>
    <title>Advanced Encryption Techniques for Secure Communication</title>
    <summary>This paper presents novel cryptographic methods for ensuring secure communication in distributed systems. We explore zero-knowledge proofs and homomorphic encryption.</summary>
    <author>
      <name>Alice Johnson</name>
    </author>
    <author>
      <name>Bob Smith</name>
    </author>
    <category term="cs.CR" scheme="http://arxiv.org/schemas/atom"/>
    <category term="cs.NI" scheme="http://arxiv.org/schemas/atom"/>
    <link href="http://arxiv.org/abs/2412.12345v1" rel="alternate" type="text/html"/>
    <link title="pdf" href="http://arxiv.org/pdf/2412.12345v1" rel="related" type="application/pdf"/>
  </entry>
  <entry>
    <id>http://arxiv.org/abs/2412.54321v2</id>
    <updated>2024-12-10T08:30:00Z</updated>
    <published>2024-12-10T08:30:00Z</published>
    <title>Machine Learning for Malware Detection</title>
    <summary>We propose a deep learning approach for detecting ransomware and other malware threats using behavioral analysis and static code features.</summary>
    <author>
      <name>Charlie Davis</name>
    </author>
    <category term="cs.CR" scheme="http://arxiv.org/schemas/atom"/>
    <category term="cs.AI" scheme="http://arxiv.org/schemas/atom"/>
    <link href="http://arxiv.org/abs/2412.54321v2" rel="alternate" type="text/html"/>
    <link href="https://doi.org/10.1234/example.doi" title="doi" rel="related"/>
  </entry>
</feed>'
}

get_empty_arxiv_xml <- function() {
  '<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title type="html">ArXiv Query: search_query=cat:cs.CR&amp;id_list=&amp;start=0&amp;max_results=0</title>
  <id>http://arxiv.org/api/empty</id>
  <updated>2024-01-15T00:00:00-05:00</updated>
  <opensearch:totalResults xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1/">0</opensearch:totalResults>
  <opensearch:startIndex xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1/">0</opensearch:startIndex>
  <opensearch:itemsPerPage xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1/">0</opensearch:itemsPerPage>
</feed>'
}

get_sample_arxiv_data <- function() {
  tibble::tibble(
    arxiv_id = c("2412.12345", "2412.54321", "2412.98765"),
    title = c(
      "Advanced Encryption Techniques for Secure Communication",
      "Machine Learning for Malware Detection",
      "Network Security in IoT Devices"
    ),
    authors = list(
      c("Alice Johnson", "Bob Smith"),
      c("Charlie Davis"),
      c("Eve Wilson", "Frank Miller", "Grace Lee")
    ),
    abstract = c(
      "This paper presents novel cryptographic methods for ensuring secure communication in distributed systems. We explore zero-knowledge proofs and homomorphic encryption.",
      "We propose a deep learning approach for detecting ransomware and other malware threats using behavioral analysis and static code features.",
      "This work addresses network security challenges in IoT embedded systems, focusing on lightweight encryption and intrusion detection."
    ),
    categories = list(
      c("cs.CR", "cs.NI"),
      c("cs.CR", "cs.AI"),
      c("cs.CR", "cs.NI", "cs.CY")
    ),
    published_date = as.POSIXct(c(
      "2024-12-15 12:00:00",
      "2024-12-10 08:30:00",
      "2024-12-05 14:20:00"
    ), tz = "UTC"),
    doi = c(NA_character_, "https://doi.org/10.1234/example.doi", NA_character_),
    collection_date = as.POSIXct(rep("2024-12-20 10:00:00", 3), tz = "UTC")
  )
}

get_categorized_data_primary <- function() {
  data <- get_sample_arxiv_data()
  data$security_category <- c(
    "Криптография",
    "Вредоносное ПО и угрозы",
    "IoT и встроенные системы"
  )
  data$category_confidence <- c(5, 3, 4)
  data
}

get_categorized_data_multi <- function() {
  data <- get_sample_arxiv_data()
  data$security_categories <- list(
    c("Криптография", "Сетевая безопасность"),
    c("Вредоносное ПО и угрозы", "Безопасность ИИ"),
    c("IoT и встроенные системы", "Сетевая безопасность")
  )
  data$category_confidence <- c(5, 3, 4)
  data
}

get_normalized_tables_primary <- function() {
  list(
    articles = tibble::tibble(
      arxiv_id = c("2412.12345", "2412.54321", "2412.98765"),
      title = c(
        "Advanced Encryption Techniques for Secure Communication",
        "Machine Learning for Malware Detection",
        "Network Security in IoT Devices"
      ),
      abstract = c(
        "This paper presents novel cryptographic methods for ensuring secure communication in distributed systems. We explore zero-knowledge proofs and homomorphic encryption.",
        "We propose a deep learning approach for detecting ransomware and other malware threats using behavioral analysis and static code features.",
        "This work addresses network security challenges in IoT embedded systems, focusing on lightweight encryption and intrusion detection."
      ),
      published_date = as.POSIXct(c(
        "2024-12-15 12:00:00",
        "2024-12-10 08:30:00",
        "2024-12-05 14:20:00"
      ), tz = "UTC"),
      doi = c(NA_character_, "https://doi.org/10.1234/example.doi", NA_character_),
      collection_date = as.POSIXct(rep("2024-12-20 10:00:00", 3), tz = "UTC"),
      security_category = c(
        "Криптография",
        "Вредоносное ПО и угрозы",
        "IoT и встроенные системы"
      ),
      category_confidence = c(5, 3, 4)
    ),
    authors = tibble::tibble(
      arxiv_id = c("2412.12345", "2412.12345", "2412.54321", "2412.98765", "2412.98765", "2412.98765"),
      author_name = c("Alice Johnson", "Bob Smith", "Charlie Davis", "Eve Wilson", "Frank Miller", "Grace Lee"),
      author_order = c(1, 2, 1, 1, 2, 3)
    ),
    categories = tibble::tibble(
      arxiv_id = c("2412.12345", "2412.12345", "2412.54321", "2412.54321", "2412.98765", "2412.98765", "2412.98765"),
      category_term = c("cs.CR", "cs.NI", "cs.CR", "cs.AI", "cs.CR", "cs.NI", "cs.CY")
    )
  )
}

mock_http_response <- function(content, status_code = 200) {
  headers <- structure(
    list("content-type" = "application/xml"),
    class = c("insensitive", "list")
  )
  
  response <- structure(
    list(
      url = "http://export.arxiv.org/api/query",
      status_code = as.integer(status_code),
      headers = headers,
      all_headers = list(
        list(
          status = as.integer(status_code),
          version = "HTTP/1.1",
          headers = headers
        )
      ),
      cookies = structure(
        data.frame(
          domain = character(0),
          flag = logical(0),
          path = character(0),
          secure = logical(0),
          expiration = as.POSIXct(character(0)),
          name = character(0),
          value = character(0),
          stringsAsFactors = FALSE
        ),
        row.names = integer(0)
      ),
      content = charToRaw(content),
      date = Sys.time(),
      times = c(redirect = 0, namelookup = 0, connect = 0, pretransfer = 0, starttransfer = 0, total = 0),
      request = structure(
        list(
          method = "GET",
          url = "http://export.arxiv.org/api/query",
          headers = character(0),
          fields = NULL,
          options = list(useragent = "test", httpget = TRUE),
          auth_token = NULL,
          output = structure(list(), class = c("write_memory", "write_function"))
        ),
        class = "request"
      ),
      handle = NULL
    ),
    class = "response"
  )
  response
}

get_non_security_data <- function() {
  tibble::tibble(
    arxiv_id = c("2412.00001", "2412.00002"),
    title = c(
      "Mathematical Optimization in Linear Programming",
      "Statistical Methods for Data Analysis"
    ),
    authors = list(
      c("John Doe"),
      c("Jane Smith", "Mike Johnson")
    ),
    abstract = c(
      "This paper discusses various optimization techniques for solving linear programming problems efficiently.",
      "We present statistical methods for analyzing large datasets with focus on variance reduction."
    ),
    categories = list(
      c("math.OC"),
      c("stat.ML")
    ),
    published_date = as.POSIXct(c(
      "2024-11-01 10:00:00",
      "2024-11-02 11:00:00"
    ), tz = "UTC"),
    doi = c(NA_character_, NA_character_),
    collection_date = as.POSIXct(rep("2024-12-20 10:00:00", 2), tz = "UTC")
  )
}
