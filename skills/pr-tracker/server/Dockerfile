FROM golang:1.22 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /pr-dashboard .

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && apt-get install -y --no-install-recommends gh && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
COPY --from=build /pr-dashboard /usr/local/bin/pr-dashboard
ENV LISTEN_ALL=1
# gh CLI uses GH_TOKEN; if only GITHUB_TOKEN is provided, alias it.
ENTRYPOINT ["sh", "-c", "export GH_TOKEN=\"${GH_TOKEN:-$GITHUB_TOKEN}\"; exec pr-dashboard --no-browse --data /data/pr_tracker.yaml"]
