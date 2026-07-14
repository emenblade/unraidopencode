FROM node:22-bookworm-slim

# git/ssh: opencode shells out to git; ripgrep: used by opencode's search tool;
# tini: reaps zombie processes / forwards signals correctly as PID 1
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        ca-certificates \
        curl \
        openssh-client \
        ripgrep \
        tini \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g opencode-ai@latest && npm cache clean --force

RUN useradd --create-home --shell /bin/bash opencode \
    && mkdir -p /workspace \
    && chown -R opencode:opencode /workspace /home/opencode

USER opencode
WORKDIR /workspace

ENV HOME=/home/opencode \
    XDG_CONFIG_HOME=/home/opencode/.config \
    XDG_DATA_HOME=/home/opencode/.local/share

EXPOSE 4096

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["opencode", "serve", "--hostname", "0.0.0.0", "--port", "4096"]
