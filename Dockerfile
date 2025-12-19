# ============================
# Stage 1 — Build R package
# ============================
FROM rocker/r-ver:4.4.0 AS builder

RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev libssl-dev libxml2-dev \
    libfontconfig1-dev libharfbuzz-dev libfribidi-dev \
    libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev \
    git libgit2-dev libicu-dev libssh2-1-dev \
    make g++ pkg-config && \
    rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('remotes'), repos='https://cloud.r-project.org/')"
RUN R -e "remotes::install_cran('devtools')"

WORKDIR /build

COPY DESCRIPTION .
RUN R -e "devtools::install_deps('.', dependencies = TRUE, upgrade = 'never')"

COPY . .

# Build tar.gz
RUN R CMD build .

# Install package into builder image
RUN R CMD INSTALL *.tar.gz


# ============================
# Stage 2 — Runtime image
# ============================
FROM rocker/r-ver:4.4.0

# Copy installed package
COPY --from=builder /usr/local/lib/R/site-library /usr/local/lib/R/site-library

CMD ["R"]
