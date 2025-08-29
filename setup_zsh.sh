#!/bin/bash

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    Zsh + Oh My Zsh 自动配置脚本${NC}"
echo -e "${GREEN}========================================${NC}"

# 清理函数
cleanup_old_files() {
    echo -e "${YELLOW}清理旧文件...${NC}"
    rm -rf /tmp/zsh-*
    rm -rf /tmp/ncurses-*
    rm -rf ~/.oh-my-zsh.bak.*
    rm -rf ~/.zshrc.pre-oh-my-zsh*
    rm -f ~/.p10k.zsh.tmp
}

# 安装 ncurses (zsh 的依赖)
install_ncurses() {
    echo -e "${GREEN}安装 ncurses 库...${NC}"
    cd /tmp
    
    # 下载 ncurses
    wget https://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.3.tar.gz || \
    curl -O https://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.3.tar.gz
    
    tar -xf ncurses-6.3.tar.gz
    cd ncurses-6.3
    
    # 配置和编译
    ./configure --prefix=$HOME/.local --with-shared --enable-widec
    make -j$(nproc)
    make install
    
    # 设置环境变量
    export CPPFLAGS="-I$HOME/.local/include"
    export LDFLAGS="-L$HOME/.local/lib"
    export LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH"
    
    cd /tmp
    rm -rf ncurses*
    
    echo -e "${GREEN}ncurses 安装完成${NC}"
}

# 源码编译安装 zsh
install_zsh_from_source() {
    echo -e "${GREEN}开始源码编译安装 zsh...${NC}"
    
    # 先安装依赖
    install_ncurses
    
    cd /tmp
    
    # 使用 GitHub 代理下载源码
    ZSH_VERSION="5.9"
    echo "下载 zsh 源码..."
    
    curl -L "https://ghfast.top/https://github.com/zsh-users/zsh/archive/refs/tags/zsh-${ZSH_VERSION}.tar.gz" -o zsh.tar.gz || \
    wget "https://gh-proxy.com/https://github.com/zsh-users/zsh/archive/refs/tags/zsh-${ZSH_VERSION}.tar.gz" -O zsh.tar.gz
    
    if [ ! -f zsh.tar.gz ]; then
        echo -e "${RED}下载失败${NC}"
        return 1
    fi
    
    # 解压编译
    tar -xf zsh.tar.gz
    cd zsh-zsh-${ZSH_VERSION}
    
    # 设置编译环境变量
    export CPPFLAGS="-I$HOME/.local/include"
    export LDFLAGS="-L$HOME/.local/lib"
    export LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH"
    
    # 配置
    ./Util/preconfig
    ./configure --prefix=$HOME/.local \
                --enable-cap \
                --enable-pcre \
                --enable-multibyte \
                --with-tcsetpgrp
    
    make -j$(nproc)
    make install
    
    # 添加到 PATH 和 LD_LIBRARY_PATH
    export PATH="$HOME/.local/bin:$PATH"
    
    # 永久添加到 bashrc
    if ! grep -q "$HOME/.local/bin" ~/.bashrc; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi
    if ! grep -q "LD_LIBRARY_PATH.*\.local/lib" ~/.bashrc; then
        echo 'export LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH"' >> ~/.bashrc
    fi
    
    # 清理
    cd /tmp
    rm -rf zsh*
    
    echo -e "${GREEN}zsh 安装完成${NC}"
    return 0
}

# 清理旧文件
cleanup_old_files

# 检查 zsh 是否已安装
if ! command -v zsh &> /dev/null; then
    echo -e "${YELLOW}zsh 未安装，尝试从源码编译安装...${NC}"
    if ! install_zsh_from_source; then
        echo -e "${RED}zsh 安装失败，请手动安装${NC}"
        exit 1
    fi
fi

# 检查 git 是否已安装
if ! command -v git &> /dev/null; then
    echo -e "${RED}错误: git 未安装，请先安装 git${NC}"
    exit 1
fi

# 备份现有配置
if [ -f ~/.zshrc ]; then
    echo -e "${YELLOW}备份现有 .zshrc${NC}"
    cp ~/.zshrc ~/.zshrc.backup.$(date +%Y%m%d_%H%M%S)
fi

if [ -f ~/.p10k.zsh ]; then
    echo -e "${YELLOW}备份现有 .p10k.zsh${NC}"
    cp ~/.p10k.zsh ~/.p10k.zsh.backup.$(date +%Y%m%d_%H%M%S)
fi

# 安装 Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo -e "${GREEN}安装 Oh My Zsh...${NC}"
    sh -c "$(curl -fsSL https://ghfast.top/https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo -e "${YELLOW}Oh My Zsh 已安装，跳过${NC}"
fi

# 安装 Powerlevel10k 主题
echo -e "${GREEN}检查 Powerlevel10k 主题...${NC}"
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
    echo "安装 Powerlevel10k..."
    git clone --depth=1 https://ghfast.top/https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
else
    echo -e "${YELLOW}Powerlevel10k 主题已存在${NC}"
fi

# 下载 p10k 配置
echo -e "${GREEN}下载 Powerlevel10k 配置...${NC}"
P10K_URL="https://ghfast.top/https://raw.githubusercontent.com/VocabVictor/myzsh/main/p10k.zsh"
echo "从 $P10K_URL 下载..."

curl -fsSL "$P10K_URL" -o ~/.p10k.zsh.tmp 2>/dev/null
if [ $? -eq 0 ] && [ -s ~/.p10k.zsh.tmp ]; then
    mv ~/.p10k.zsh.tmp ~/.p10k.zsh
    echo -e "${GREEN}✓ Powerlevel10k 配置下载成功${NC}"
else
    echo -e "${YELLOW}P10k 配置下载失败，将使用默认配置${NC}"
    rm -f ~/.p10k.zsh.tmp
fi

# 安装插件
echo -e "${GREEN}安装常用插件...${NC}"

# zsh-autosuggestions
if [ ! -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
    echo "安装 zsh-autosuggestions..."
    git clone https://ghfast.top/https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
else
    echo -e "${YELLOW}zsh-autosuggestions 已存在${NC}"
fi

# zsh-syntax-highlighting
if [ ! -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
    echo "安装 zsh-syntax-highlighting..."
    git clone https://ghfast.top/https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
else
    echo -e "${YELLOW}zsh-syntax-highlighting 已存在${NC}"
fi

# zsh-completions
if [ ! -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions" ]; then
    echo "安装 zsh-completions..."
    git clone https://ghfast.top/https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions
else
    echo -e "${YELLOW}zsh-completions 已存在${NC}"
fi

# zsh-z
if [ ! -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-z" ]; then
    echo "安装 zsh-z..."
    git clone https://ghfast.top/https://github.com/agkozak/zsh-z ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-z
else
    echo -e "${YELLOW}zsh-z 已存在${NC}"
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

# 添加本地安装的程序到 PATH
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
export LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH"

# 主题设置
ZSH_THEME="powerlevel10k/powerlevel10k"

# 插件配置
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
    zsh-z
    extract
    sudo
    colored-man-pages
    history-substring-search
)

source $ZSH/oh-my-zsh.sh

# 用户配置
export LANG=en_US.UTF-8
export EDITOR='vim'

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
echo -e "${GREEN}zsh 路径: $(which zsh)${NC}"
echo -e "${YELLOW}========================================${NC}"

# 设置默认 shell（无需 sudo）
echo -e "${GREEN}将 zsh 添加到 ~/.bashrc 以自动启动${NC}"
if ! grep -q "exec zsh" ~/.bashrc; then
    echo '[ -x "$(command -v zsh)" ] && exec zsh' >> ~/.bashrc
fi

echo -e "${GREEN}下次登录时将自动进入 zsh${NC}"
echo -e "${GREEN}或现在运行: exec zsh${NC}"

# 询问是否立即切换
read -p "是否现在切换到 zsh? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    exec zsh
fi
