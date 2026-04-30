FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_VERSION=22

# System packages: git, sshd, shellcheck, curl, awscli deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    openssh-server \
    shellcheck \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Node.js via nodesource
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# opencode
RUN npm install -g opencode-ai

# AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/aws /tmp/awscliv2.zip

# SSH configuration — key-only auth, no root, non-standard port
RUN mkdir -p /var/run/sshd \
    && sed -i 's/^#*Port .*/Port 2222/' /etc/ssh/sshd_config \
    && sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/^#*PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#*AuthorizedKeysFile .*/AuthorizedKeysFile .ssh\/authorized_keys/' /etc/ssh/sshd_config \
    && echo "ClientAliveInterval 30" >> /etc/ssh/sshd_config \
    && echo "ClientAliveCountMax 2" >> /etc/ssh/sshd_config

# Non-root user for SSH sessions
RUN useradd -m -s /bin/bash phonecoder \
    && mkdir -p /home/phonecoder/.ssh \
    && chmod 700 /home/phonecoder/.ssh

# Workspace directory
RUN mkdir -p /workspace && chown phonecoder:phonecoder /workspace

# opencode config
RUN mkdir -p /home/phonecoder/.opencode \
    && chown -R phonecoder:phonecoder /home/phonecoder/.opencode

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 2222

ENTRYPOINT ["/entrypoint.sh"]
