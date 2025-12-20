# syntax=docker/dockerfile:1.4
# ============================
# Stage 1 — Build R package
# ============================
FROM rocker/r-ver:4.4.0 AS builder

# Install system dependencies (cached layer)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev libssl-dev libxml2-dev \
    libfontconfig1-dev libharfbuzz-dev libfribidi-dev \
    libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev \
    git libgit2-dev libicu-dev libssh2-1-dev \
    make g++ pkg-config && \
    rm -rf /var/lib/apt/lists/*

# Install remotes (faster than devtools) with cache
RUN --mount=type=cache,target=/root/.cache/R/renv/cache/v5,sharing=locked \
    R -e "install.packages('remotes', repos='https://cloud.r-project.org/', Ncpus=2)"

WORKDIR /build

# Copy DESCRIPTION and NAMESPACE first (cache-friendly)
COPY DESCRIPTION NAMESPACE ./

# Install dependencies with cache mount for R packages
RUN --mount=type=cache,target=/root/.cache/R/renv/cache/v5,sharing=locked \
    R -e "remotes::install_deps('.', dependencies = TRUE, upgrade = 'never', repos='https://cloud.r-project.org/', Ncpus=2)"

# Copy R source files (changes more frequently)
COPY R/ ./R/

# Copy man directory (documentation - will be regenerated but needed for structure)
COPY man/ ./man/

# Copy tests directory (needed for package structure)
COPY tests/ ./tests/

# Remove any old tar.gz or installed package remnants
RUN rm -f /build/*.tar.gz && \
    rm -rf /usr/local/lib/R/site-library/arxivThreatIntel

# Install roxygen2 for documentation (if not already installed)
RUN --mount=type=cache,target=/root/.cache/R/renv/cache/v5,sharing=locked \
    R -e "if (!requireNamespace('roxygen2', quietly=TRUE)) install.packages('roxygen2', repos='https://cloud.r-project.org/', Ncpus=2)"

# Generate documentation
RUN R -e "roxygen2::roxygenise()"

# Build package
RUN R CMD build .

# Install freshly built package
RUN R CMD INSTALL *.tar.gz


# ============================
# Stage 2 — Runtime image
# ============================
FROM rocker/r-ver:4.4.0

# Set working directory
WORKDIR /app

# Copy installed package from builder
COPY --from=builder /usr/local/lib/R/site-library /usr/local/lib/R/site-library

# Default command
CMD ["R"]
