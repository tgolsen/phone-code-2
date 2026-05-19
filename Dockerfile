FROM node:22-alpine

# System packages: git, sshd, shellcheck, jq
RUN apk add --no-cache \
    bash \
    curl \
    git \
    jq \
    openssh-server \
    openssh-keygen \
    shellcheck

# opencode
RUN npm install -g opencode-ai

# Pre-install opencode AI provider packages (avoids slow first launch)
RUN npm install -g @ai-sdk/openai-compatible

# SSH configuration — key-only auth, no root, non-standard port
RUN ssh-keygen -A \
    && mkdir -p /var/run/sshd \
    && sed -i 's/^#*Port .*/Port 2222/' /etc/ssh/sshd_config \
    && sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/^#*PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's|^#*AuthorizedKeysFile[[:space:]].*|AuthorizedKeysFile .ssh/authorized_keys|' /etc/ssh/sshd_config \
    && echo "ClientAliveInterval 30" >> /etc/ssh/sshd_config \
    && echo "ClientAliveCountMax 6" >> /etc/ssh/sshd_config

# Non-root user for SSH sessions
RUN adduser -D -s /bin/bash phonecoder \
    && mkdir -p /home/phonecoder/.ssh \
    && chmod 700 /home/phonecoder/.ssh \
    && chown -R phonecoder:phonecoder /home/phonecoder/.ssh

# Workspace directory
RUN mkdir -p /workspace && chown phonecoder:phonecoder /workspace

# Pre-seed opencode config so first launch skips resolution
RUN mkdir -p /home/phonecoder/.opencode
COPY opencode.json /home/phonecoder/.opencode/config.json
RUN chown -R phonecoder:phonecoder /home/phonecoder/.opencode

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 2222

ENTRYPOINT ["/entrypoint.sh"]
