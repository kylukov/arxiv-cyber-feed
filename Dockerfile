# ============================
# Stage 1 — Build R package
# ============================
FROM rocker/r-ver:4.4.0 AS builder

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev libssl-dev libxml2-dev \
    libfontconfig1-dev libharfbuzz-dev libfribidi-dev \
    libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev \
    git libgit2-dev libicu-dev libssh2-1-dev \
    make g++ pkg-config && \
    rm -rf /var/lib/apt/lists/*

# Install devtools
RUN R -e "install.packages('devtools', repos='https://cloud.r-project.org/')"

WORKDIR /build

# Copy DESCRIPTION first (cache-friendly)
COPY DESCRIPTION .

# Install dependencies
RUN R -e "devtools::install_deps('.', dependencies = TRUE, upgrade = 'never')"

# Copy full package
COPY . .

# ----------------------------
# 🔥 CRITICAL FIX (Solution #3)
# Remove any old tar.gz or installed package remnants
# ----------------------------
RUN rm -f /build/*.tar.gz
RUN rm -rf /usr/local/lib/R/site-library/arxivThreatIntel

# Force documentation regeneration
RUN R -e "devtools::document()"

# Build package
RUN R CMD build .

# Install freshly built package
RUN R CMD INSTALL *.tar.gz


# ============================
# Stage 2 — Runtime image
# ============================
FROM rocker/r-ver:4.4.0

# Copy installed package from builder
COPY --from=builder /usr/local/lib/R/site-library /usr/local/lib/R/site-library

# Default command
CMD ["R"]
