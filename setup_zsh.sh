#!/bin/bash

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    Zsh + Oh My Zsh 自动配置脚本${NC}"
echo -e "${GREEN}========================================${NC}"

# 设置GitHub代理（可选择使用不同的代理）
GITHUB_PROXY="https://mirror.ghproxy.com/"
# 备选代理: "https://ghproxy.com/" "https://github.moeyy.xyz/"

# 清理函数
cleanup_temp_files() {
    echo -e "${YELLOW}清理临时文件...${NC}"
    rm -rf /tmp/zsh-*
    rm -rf /tmp/ncurses-*
    rm -f ~/.p10k.zsh.tmp
    rm -f ~/.zshrc.pre-oh-my-zsh*
    rm -rf ~/zsh-build-temp
    rm -rf ~/.oh-my-zsh.bak.*
}

# 脚本开始时清理
cleanup_temp_files

# 错误处理
trap cleanup_temp_files EXIT

# 安装 ncurses (zsh 的依赖)
install_ncurses() {
    # 检查是否已安装
    if [ -f "$HOME/.local/lib/libncursesw.so" ] || [ -f "$HOME/.local/lib/libncursesw.a" ]; then
        echo -e "${GREEN}ncurses 已安装，跳过${NC}"
        return 0
    fi
    
    echo -e "${GREEN}安装 ncurses 库...${NC}"
    cd /tmp
    
    # 下载 ncurses
    wget https://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.3.tar.gz || \
    curl -O https://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.3.tar.gz
    
    if [ ! -f ncurses-6.3.tar.gz ]; then
        echo -e "${RED}ncurses 下载失败${NC}"
        return 1
    fi
    
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
    # 检查是否已安装
    if [ -f "$HOME/.local/bin/zsh" ]; then
        echo -e "${GREEN}zsh 已安装在 ~/.local/bin/zsh，跳过编译${NC}"
        export PATH="$HOME/.local/bin:$PATH"
        return 0
    fi
    
    echo -e "${GREEN}开始源码编译安装 zsh...${NC}"
    
    # 先安装依赖
    install_ncurses
    
    cd /tmp
    
    # 下载源码
    ZSH_VERSION="5.9"
    echo "下载 zsh 源码..."
    
    curl -L "${GITHUB_PROXY}https://github.com/zsh-users/zsh/archive/refs/tags/zsh-${ZSH_VERSION}.tar.gz" -o zsh.tar.gz || \
    wget "${GITHUB_PROXY}https://github.com/zsh-users/zsh/archive/refs/tags/zsh-${ZSH_VERSION}.tar.gz" -O zsh.tar.gz || \
    curl -L "https://github.com/zsh-users/zsh/archive/refs/tags/zsh-${ZSH_VERSION}.tar.gz" -o zsh.tar.gz
    
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
    
    # 添加到 PATH
    export PATH="$HOME/.local/bin:$PATH"
    
    # 永久添加到 bashrc
    if ! grep -q "$HOME/.local/bin" ~/.bashrc; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi
    if ! grep -q "LD_LIBRARY_PATH.*\.local/lib" ~/.bashrc; then
        echo 'export LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH"' >> ~/.bashrc
    fi
    
    # 清理编译文件
    cd /tmp
    rm -rf zsh*
    
    echo -e "${GREEN}zsh 安装完成${NC}"
    return 0
}

# 检查 zsh 是否已安装
if ! command -v zsh &> /dev/null && [ ! -f "$HOME/.local/bin/zsh" ]; then
    echo -e "${YELLOW}zsh 未安装，尝试从源码编译安装...${NC}"
    if ! install_zsh_from_source; then
        echo -e "${RED}zsh 安装失败，请手动安装${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}zsh 已安装${NC}"
    if [ -f "$HOME/.local/bin/zsh" ]; then
        export PATH="$HOME/.local/bin:$PATH"
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
if [ ! -d "$HOME/.oh-my-zsh" ] || [ ! -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
    echo -e "${GREEN}安装 Oh My Zsh...${NC}"
    rm -rf ~/.oh-my-zsh
    
    # 尝试多个方式克隆
    git clone --depth=1 "${GITHUB_PROXY}https://github.com/ohmyzsh/ohmyzsh.git" ~/.oh-my-zsh || \
    git clone --depth=1 "https://github.com/ohmyzsh/ohmyzsh.git" ~/.oh-my-zsh
    
    if [ $? -eq 0 ] && [ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
        echo -e "${GREEN}Oh My Zsh 安装成功${NC}"
    else
        echo -e "${RED}Oh My Zsh 安装失败${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}Oh My Zsh 已安装，跳过${NC}"
fi

# 创建插件目录
mkdir -p ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins

# 改进的插件安装函数
install_plugin() {
    local plugin_name=$1
    local plugin_repo=$2
    local plugin_dir=$3
    
    # 检查插件是否存在且有效
    if [ -d "$plugin_dir" ]; then
        # 检查是否有 .git 目录和插件文件
        if [ -d "$plugin_dir/.git" ] && ls "$plugin_dir"/*.zsh* >/dev/null 2>&1; then
            echo -e "${GREEN}$plugin_name 已安装且完整，跳过${NC}"
            return 0
        else
            echo -e "${YELLOW}$plugin_name 目录存在但不完整，重新安装...${NC}"
            rm -rf "$plugin_dir"
        fi
    fi
    
    echo "安装 $plugin_name..."
    
    # 尝试使用代理克隆
    if git clone --depth=1 "${GITHUB_PROXY}${plugin_repo}" "$plugin_dir" 2>/dev/null; then
        echo -e "${GREEN}$plugin_name 通过代理安装成功${NC}"
        return 0
    fi
    
    # 如果代理失败，尝试直接克隆
    if git clone --depth=1 "$plugin_repo" "$plugin_dir" 2>/dev/null; then
        echo -e "${GREEN}$plugin_name 直接安装成功${NC}"
        return 0
    fi
    
    echo -e "${RED}$plugin_name 安装失败${NC}"
    return 1
}

# 安装 Powerlevel10k 主题
echo -e "${GREEN}安装 Powerlevel10k 主题...${NC}"
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ] || [ ! -f "$P10K_DIR/powerlevel10k.zsh-theme" ]; then
    rm -rf "$P10K_DIR"
    git clone --depth=1 "${GITHUB_PROXY}https://github.com/romkatv/powerlevel10k.git" "$P10K_DIR" || \
    git clone --depth=1 "https://github.com/romkatv/powerlevel10k.git" "$P10K_DIR"
else
    echo -e "${GREEN}Powerlevel10k 主题已存在，跳过${NC}"
fi

echo -e "${GREEN}安装插件...${NC}"

# 安装各个插件
install_plugin "zsh-autosuggestions" \
    "https://github.com/zsh-users/zsh-autosuggestions" \
    "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"

install_plugin "zsh-syntax-highlighting" \
    "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
    "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"

install_plugin "zsh-completions" \
    "https://github.com/zsh-users/zsh-completions" \
    "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions"

install_plugin "zsh-z" \
    "https://github.com/agkozak/zsh-z" \
    "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-z"

# 下载 p10k 配置
echo -e "${GREEN}配置 Powerlevel10k...${NC}"
if [ ! -f ~/.p10k.zsh ]; then
    # 尝试下载预配置的 p10k 配置
    P10K_URL="${GITHUB_PROXY}https://raw.githubusercontent.com/VocabVictor/myzsh/main/p10k.zsh"
    
    if curl -fsSL "$P10K_URL" -o ~/.p10k.zsh.tmp 2>/dev/null && [ -s ~/.p10k.zsh.tmp ]; then
        mv ~/.p10k.zsh.tmp ~/.p10k.zsh
        echo -e "${GREEN}✓ Powerlevel10k 配置下载成功${NC}"
    else
        echo -e "${YELLOW}使用默认 P10k 配置${NC}"
        rm -f ~/.p10k.zsh.tmp
    fi
fi

# 创建优化的 .zshrc 配置
echo -e "${GREEN}配置 .zshrc...${NC}"
cat > ~/.zshrc << 'EOF'
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path configuration (必须在 instant prompt 之后，oh-my-zsh 之前)
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
export LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH"

# Path to oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Set theme
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins configuration (only use available plugins)
plugins=(
    git
    extract
    sudo
    colored-man-pages
    history-substring-search
)

# Add custom plugins if they exist
[[ -d "$ZSH/custom/plugins/zsh-autosuggestions" ]] && plugins+=(zsh-autosuggestions)
[[ -d "$ZSH/custom/plugins/zsh-syntax-highlighting" ]] && plugins+=(zsh-syntax-highlighting)
[[ -d "$ZSH/custom/plugins/zsh-completions" ]] && plugins+=(zsh-completions)
[[ -d "$ZSH/custom/plugins/zsh-z" ]] && plugins+=(zsh-z)

# Load oh-my-zsh
source $ZSH/oh-my-zsh.sh

# User configuration
export LANG=en_US.UTF-8
export EDITOR='vim'
export TZ='Asia/Shanghai'

# History configuration
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

# Autosuggestions configuration
if [[ -n "$ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE" ]]; then
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=244"
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
  ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
fi

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'
alias glog='git log --oneline --graph --decorate'

# System aliases
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias grep='grep --color=auto'
alias cls='clear'
alias h='history'
alias path='echo -e ${PATH//:/\\n}'

# Useful functions
mkcd() { mkdir -p "$1" && cd "$1"; }
backup() { cp "$1" "$1.bak.$(date +%Y%m%d_%H%M%S)"; }

# Completions
autoload -U compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# Key bindings
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# Load p10k configuration
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Load zsh-completions if installed
if [[ -d "$ZSH/custom/plugins/zsh-completions" ]]; then
  fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src
fi
EOF

# 创建缓存目录
mkdir -p ~/.cache

# 最终清理
echo -e "${GREEN}执行最终清理...${NC}"
cleanup_temp_files

# 验证安装
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}安装验证：${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查主要组件
[ -d ~/.oh-my-zsh ] && echo -e "${GREEN}✓ Oh My Zsh${NC}" || echo -e "${RED}✗ Oh My Zsh${NC}"
[ -d ~/.oh-my-zsh/custom/themes/powerlevel10k ] && echo -e "${GREEN}✓ Powerlevel10k${NC}" || echo -e "${RED}✗ Powerlevel10k${NC}"
[ -f ~/.p10k.zsh ] && echo -e "${GREEN}✓ P10k 配置${NC}" || echo -e "${YELLOW}! P10k 配置（使用默认）${NC}"

# 检查插件
echo -e "\n${GREEN}插件状态：${NC}"
for plugin in zsh-autosuggestions zsh-syntax-highlighting zsh-completions zsh-z; do
    if [ -d ~/.oh-my-zsh/custom/plugins/$plugin ]; then
        echo -e "  ${GREEN}✓ $plugin${NC}"
    else
        echo -e "  ${YELLOW}○ $plugin (未安装)${NC}"
    fi
done

# 显示 zsh 路径
echo -e "\n${GREEN}Zsh 信息：${NC}"
if [ -f "$HOME/.local/bin/zsh" ]; then
    echo -e "  路径: $HOME/.local/bin/zsh"
elif command -v zsh &> /dev/null; then
    echo -e "  路径: $(which zsh)"
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}配置完成！${NC}"
echo -e "${GREEN}========================================${NC}"

# 设置自动启动
if [ -f "$HOME/.local/bin/zsh" ]; then
    if ! grep -q "exec.*zsh" ~/.bashrc; then
        echo -e "\n# Auto-start zsh" >> ~/.bashrc
        echo '[ -z "$ZSH_VERSION" ] && [ -f "$HOME/.local/bin/zsh" ] && exec $HOME/.local/bin/zsh' >> ~/.bashrc
    fi
fi

echo -e "${YELLOW}提示：${NC}"
echo -e "1. 重新登录或运行: ${GREEN}exec \$HOME/.local/bin/zsh${NC}"
echo -e "2. 如需重新配置主题，运行: ${GREEN}p10k configure${NC}"
echo -e "3. 如有插件未安装，可手动运行相应的 git clone 命令"

# 询问是否立即切换
read -p "是否现在切换到 zsh? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -f "$HOME/.local/bin/zsh" ]; then
        exec $HOME/.local/bin/zsh
    else
        exec zsh
    fi
fi
