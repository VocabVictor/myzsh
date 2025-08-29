#!/bin/bash

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    Zsh + Oh My Zsh 自动配置脚本${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查 zsh 是否已安装
if ! command -v zsh &> /dev/null; then
    echo -e "${RED}错误: zsh 未安装，请先安装 zsh${NC}"
    echo "Ubuntu/Debian: sudo apt install zsh"
    echo "CentOS/RHEL: sudo yum install zsh"
    exit 1
fi

# 检查 git 是否已安装
if ! command -v git &> /dev/null; then
    echo -e "${RED}错误: git 未安装，请先安装 git${NC}"
    exit 1
fi

# 备份现有配置
if [ -f ~/.zshrc ]; then
    echo -e "${YELLOW}备份现有 .zshrc 到 .zshrc.backup${NC}"
    cp ~/.zshrc ~/.zshrc.backup.$(date +%Y%m%d_%H%M%S)
fi

if [ -f ~/.p10k.zsh ]; then
    echo -e "${YELLOW}备份现有 .p10k.zsh 到 .p10k.zsh.backup${NC}"
    cp ~/.p10k.zsh ~/.p10k.zsh.backup.$(date +%Y%m%d_%H%M%S)
fi

# 安装 Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo -e "${GREEN}安装 Oh My Zsh...${NC}"
    sh -c "$(curl -fsSL https://gh-proxy.com/https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo -e "${YELLOW}Oh My Zsh 已安装，跳过${NC}"
fi

# 安装 Powerlevel10k 主题
echo -e "${GREEN}安装 Powerlevel10k 主题...${NC}"
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
    git clone --depth=1 https://gh-proxy.com/https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
else
    echo -e "${YELLOW}Powerlevel10k 主题已存在${NC}"
fi

# 下载 p10k 配置
echo -e "${GREEN}下载 Powerlevel10k 配置...${NC}"
P10K_URL="https://gh-proxy.com/https://raw.githubusercontent.com/VocabVictor/myzsh/refs/heads/main/p10k.zsh"
echo "从 $P10K_URL 下载..."

# 尝试使用 curl 下载
if command -v curl &> /dev/null; then
    if curl -fsSL "$P10K_URL" -o ~/.p10k.zsh.tmp 2>/dev/null; then
        if [ -s ~/.p10k.zsh.tmp ]; then
            mv ~/.p10k.zsh.tmp ~/.p10k.zsh
            echo -e "${GREEN}✓ Powerlevel10k 配置下载成功 ($(wc -l < ~/.p10k.zsh) 行)${NC}"
        else
            echo -e "${RED}✗ 下载的文件为空${NC}"
            rm -f ~/.p10k.zsh.tmp
        fi
    else
        echo -e "${RED}✗ curl 下载失败${NC}"
    fi
# 如果 curl 失败，尝试 wget
elif command -v wget &> /dev/null; then
    if wget -q "$P10K_URL" -O ~/.p10k.zsh.tmp 2>/dev/null; then
        if [ -s ~/.p10k.zsh.tmp ]; then
            mv ~/.p10k.zsh.tmp ~/.p10k.zsh
            echo -e "${GREEN}✓ Powerlevel10k 配置下载成功 ($(wc -l < ~/.p10k.zsh) 行)${NC}"
        else
            echo -e "${RED}✗ 下载的文件为空${NC}"
            rm -f ~/.p10k.zsh.tmp
        fi
    else
        echo -e "${RED}✗ wget 下载失败${NC}"
    fi
else
    echo -e "${RED}✗ 没有找到 curl 或 wget${NC}"
fi

# 验证 p10k.zsh 是否存在
if [ ! -f ~/.p10k.zsh ]; then
    echo -e "${YELLOW}警告: p10k.zsh 文件不存在${NC}"
    echo -e "${YELLOW}Powerlevel10k 将使用默认配置${NC}"
    echo -e "${YELLOW}你可以稍后手动下载配置：${NC}"
    echo "curl -fsSL $P10K_URL -o ~/.p10k.zsh"
    echo "或运行 'p10k configure' 重新配置"
fi

# 安装插件
echo -e "${GREEN}安装常用插件...${NC}"

# zsh-autosuggestions
if [ ! -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
    echo "安装 zsh-autosuggestions..."
    git clone https://gh-proxy.com/https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
fi

# zsh-syntax-highlighting
if [ ! -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
    echo "安装 zsh-syntax-highlighting..."
    git clone https://gh-proxy.com/https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
fi

# zsh-completions
if [ ! -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions" ]; then
    echo "安装 zsh-completions..."
    git clone https://gh-proxy.com/https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions
fi

# zsh-z (快速跳转)
if [ ! -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-z" ]; then
    echo "安装 zsh-z..."
    git clone https://gh-proxy.com/https://github.com/agkozak/zsh-z ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-z
fi

# 创建自定义配置
echo -e "${GREEN}配置 .zshrc...${NC}"
cat > ~/.zshrc << 'EOF'
# Enable Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"

# 主题设置
ZSH_THEME="powerlevel10k/powerlevel10k"

# 插件配置
plugins=(
    git
    docker
    docker-compose
    kubectl
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
    zsh-z
    extract
    sudo
    colored-man-pages
    command-not-found
    history-substring-search
)

source $ZSH/oh-my-zsh.sh

# 用户配置
export LANG=en_US.UTF-8
export EDITOR='vim'
export PATH=$HOME/bin:$HOME/.local/bin:$PATH

# 历史记录优化
HISTSIZE=100000
SAVEHIST=100000
HISTFILE=~/.zsh_history
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_VERIFY
setopt SHARE_HISTORY
setopt HIST_FIND_NO_DUPS

# 自动建议配置
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=244"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# 别名设置
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Git 别名
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'
alias glog='git log --oneline --graph --decorate'

# 系统别名
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias grep='grep --color=auto'
alias cls='clear'
alias h='history'
alias path='echo -e ${PATH//:/\\n}'
alias ports='netstat -tulanp'

# 实用函数
mkcd() { mkdir -p "$1" && cd "$1"; }
backup() { cp "$1" "$1.bak.$(date +%Y%m%d_%H%M%S)"; }
extract() {
    if [ -f $1 ]; then
        case $1 in
            *.tar.bz2)   tar xjf $1   ;;
            *.tar.gz)    tar xzf $1   ;;
            *.bz2)       bunzip2 $1   ;;
            *.rar)       unrar x $1   ;;
            *.gz)        gunzip $1    ;;
            *.tar)       tar xf $1    ;;
            *.tbz2)      tar xjf $1   ;;
            *.tgz)       tar xzf $1   ;;
            *.zip)       unzip $1     ;;
            *.Z)         uncompress $1;;
            *.7z)        7z x $1      ;;
            *)           echo "'$1' cannot be extracted" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# 查找文件
ff() { find . -type f -name "*$1*" ; }
fd() { find . -type d -name "*$1*" ; }

# 自动补全
autoload -U compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# 键绑定
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line

# 加载 p10k 配置
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF

# 最终验证
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}安装摘要：${NC}"
[ -d ~/.oh-my-zsh ] && echo -e "${GREEN}✓ Oh My Zsh${NC}" || echo -e "${RED}✗ Oh My Zsh${NC}"
[ -d ~/.oh-my-zsh/custom/themes/powerlevel10k ] && echo -e "${GREEN}✓ Powerlevel10k 主题${NC}" || echo -e "${RED}✗ Powerlevel10k 主题${NC}"
[ -f ~/.p10k.zsh ] && echo -e "${GREEN}✓ P10k 配置文件${NC}" || echo -e "${YELLOW}! P10k 配置文件（将使用默认）${NC}"
[ -d ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions ] && echo -e "${GREEN}✓ 插件已安装${NC}" || echo -e "${YELLOW}! 部分插件未安装${NC}"

echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}配置完成！${NC}"
echo -e "${GREEN}注意：Powerlevel10k 需要特殊字体支持${NC}"
echo -e "${GREEN}推荐在本地安装 MesloLGS NF 字体${NC}"
echo -e "${GREEN}Windows: https://github.com/romkatv/powerlevel10k#fonts${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}请运行以下命令设置 zsh 为默认 shell:${NC}"
echo -e "${GREEN}  chsh -s \$(which zsh)${NC}"
echo -e "${GREEN}然后重新登录或运行: exec zsh${NC}"
echo -e "${GREEN}========================================${NC}"

# 询问是否立即切换到 zsh
read -p "是否现在切换到 zsh? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    exec zsh
fi
