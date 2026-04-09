FROM golang:1.22 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /pr-dashboard .

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl apt-transport-https gnupg && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list && \
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
      > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    apt-get update && apt-get install -y --no-install-recommends gh google-cloud-cli && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
COPY --from=build /pr-dashboard /usr/local/bin/pr-dashboard
ENV LISTEN_ALL=1
ENV CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE=/etc/gcs/adc.json
ENTRYPOINT ["sh", "-c", "export GH_TOKEN=\"${GH_TOKEN:-$GITHUB_TOKEN}\"; exec pr-dashboard --no-browse --data /data/pr_tracker.yaml ${GCS_BUCKET:+--gcs-bucket $GCS_BUCKET}"]
