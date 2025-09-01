#!/bin/bash

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    Zsh + Oh My Zsh 自动配置脚本${NC}"
echo -e "${GREEN}========================================${NC}"

# 全局变量
FAILED_PLUGINS=()
SUCCESS_PLUGINS=()
PROXY_CONFIGURED=false

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

# 清理git代理配置
cleanup_git_proxy() {
    if [ "$PROXY_CONFIGURED" = true ]; then
        echo -e "${YELLOW}清理Git代理配置...${NC}"
        git config --global --unset http.proxy 2>/dev/null
        git config --global --unset https.proxy 2>/dev/null
        git config --global --unset http.sslVerify 2>/dev/null
    fi
}

# 退出时的清理函数
cleanup_on_exit() {
    cleanup_temp_files
    cleanup_git_proxy
}

# 错误处理
trap cleanup_on_exit EXIT

# 配置Git代理（只在有代理环境变量时执行）
setup_git_proxy() {
    if [ -n "$http_proxy" ] || [ -n "$https_proxy" ]; then
        echo -e "${GREEN}检测到代理，配置Git...${NC}"
        
        # 保存原始配置状态
        git config --global --get http.proxy &>/dev/null && OLD_HTTP_PROXY=true || OLD_HTTP_PROXY=false
        git config --global --get https.proxy &>/dev/null && OLD_HTTPS_PROXY=true || OLD_HTTPS_PROXY=false
        
        # 设置git代理
        if [ -n "$http_proxy" ]; then
            git config --global http.proxy "$http_proxy"
            echo -e "${BLUE}  HTTP代理: $http_proxy${NC}"
        fi
        
        if [ -n "$https_proxy" ]; then
            git config --global https.proxy "$https_proxy"
            echo -e "${BLUE}  HTTPS代理: $https_proxy${NC}"
        fi
        
        # 标记已配置代理
        PROXY_CONFIGURED=true
        
        # 测试连接
        echo -e "${YELLOW}测试GitHub连接...${NC}"
        if timeout 10 git ls-remote https://github.com/ohmyzsh/ohmyzsh.git HEAD &>/dev/null; then
            echo -e "${GREEN}✓ GitHub连接成功${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ GitHub连接较慢，继续尝试...${NC}"
            return 0
        fi
    else
        echo -e "${GREEN}直接连接GitHub（无代理）${NC}"
    fi
}

# 安装 ncurses (zsh 的依赖)
install_ncurses() {
    if [ -f "$HOME/.local/lib/libncursesw.so" ] || [ -f "$HOME/.local/lib/libncursesw.a" ]; then
        echo -e "${GREEN}ncurses 已安装，跳过${NC}"
        return 0
    fi
    
    echo -e "${GREEN}安装 ncurses 库...${NC}"
    cd /tmp
    
    wget https://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.3.tar.gz || \
    curl -O https://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.3.tar.gz
    
    if [ ! -f ncurses-6.3.tar.gz ]; then
        echo -e "${RED}ncurses 下载失败${NC}"
        return 1
    fi
    
    tar -xf ncurses-6.3.tar.gz
    cd ncurses-6.3
    
    ./configure --prefix=$HOME/.local --with-shared --enable-widec
    make -j$(nproc)
    make install
    
    export CPPFLAGS="-I$HOME/.local/include"
    export LDFLAGS="-L$HOME/.local/lib"
    export LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH"
    
    cd /tmp
    rm -rf ncurses*
    
    echo -e "${GREEN}ncurses 安装完成${NC}"
}

# 源码编译安装 zsh
install_zsh_from_source() {
    if [ -f "$HOME/.local/bin/zsh" ]; then
        echo -e "${GREEN}zsh 已安装在 ~/.local/bin/zsh，跳过编译${NC}"
        export PATH="$HOME/.local/bin:$PATH"
        return 0
    fi
    
    echo -e "${GREEN}开始源码编译安装 zsh...${NC}"
    
    install_ncurses
    
    cd /tmp
    
    ZSH_VERSION="5.9"
    echo "下载 zsh 源码..."
    
    curl -L "https://github.com/zsh-users/zsh/archive/refs/tags/zsh-${ZSH_VERSION}.tar.gz" -o zsh.tar.gz || \
    wget "https://github.com/zsh-users/zsh/archive/refs/tags/zsh-${ZSH_VERSION}.tar.gz" -O zsh.tar.gz
    
    if [ ! -f zsh.tar.gz ] || [ ! -s zsh.tar.gz ]; then
        echo -e "${RED}下载失败${NC}"
        return 1
    fi
    
    tar -xf zsh.tar.gz
    cd zsh-zsh-${ZSH_VERSION}
    
    export CPPFLAGS="-I$HOME/.local/include"
    export LDFLAGS="-L$HOME/.local/lib"
    export LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH"
    
    ./Util/preconfig
    ./configure --prefix=$HOME/.local \
                --enable-cap \
                --enable-pcre \
                --enable-multibyte \
                --with-tcsetpgrp
    
    make -j$(nproc)
    make install
    
    export PATH="$HOME/.local/bin:$PATH"
    
    if ! grep -q "$HOME/.local/bin" ~/.bashrc; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi
    if ! grep -q "LD_LIBRARY_PATH.*\.local/lib" ~/.bashrc; then
        echo 'export LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH"' >> ~/.bashrc
    fi
    
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

# 配置Git代理（如果需要）
setup_git_proxy

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
    
    if git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh 2>&1 | grep -v "Cloning into"; then
        echo -e "${GREEN}✓ Oh My Zsh 安装成功${NC}"
    else
        echo -e "${RED}✗ Oh My Zsh 安装失败${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Oh My Zsh 已安装${NC}"
fi

# 创建必要目录
mkdir -p ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins
mkdir -p ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes

# 插件验证函数
validate_plugin() {
    local plugin_dir=$1
    local plugin_name=$(basename "$plugin_dir")
    
    if [ ! -d "$plugin_dir" ]; then
        return 1
    fi
    
    case "$plugin_name" in
        zsh-autosuggestions)
            [ -f "$plugin_dir/zsh-autosuggestions.plugin.zsh" ] || [ -f "$plugin_dir/zsh-autosuggestions.zsh" ]
            ;;
        zsh-syntax-highlighting)
            [ -f "$plugin_dir/zsh-syntax-highlighting.plugin.zsh" ] || [ -f "$plugin_dir/zsh-syntax-highlighting.zsh" ]
            ;;
        zsh-completions)
            [ -d "$plugin_dir/src" ]
            ;;
        zsh-z)
            [ -f "$plugin_dir/zsh-z.plugin.zsh" ] || [ -f "$plugin_dir/z.sh" ]
            ;;
        *)
            ls "$plugin_dir"/*.zsh >/dev/null 2>&1 || ls "$plugin_dir"/*.plugin.zsh >/dev/null 2>&1
            ;;
    esac
}

# 安装插件函数
install_plugin() {
    local plugin_name=$1
    local plugin_url=$2
    local plugin_dir=$3
    
    echo -e "${YELLOW}安装 $plugin_name...${NC}"
    
    # 清理旧目录
    rm -rf "$plugin_dir"
    
    # 克隆插件
    echo -e "${BLUE}  正在克隆...${NC}"
    if git clone --depth=1 "$plugin_url" "$plugin_dir" 2>&1 | grep -v "Cloning into"; then
        if validate_plugin "$plugin_dir"; then
            echo -e "${GREEN}  ✓ $plugin_name 安装成功${NC}"
            SUCCESS_PLUGINS+=("$plugin_name")
            return 0
        else
            # 特殊处理 zsh-z
            if [ "$plugin_name" = "zsh-z" ] && [ -f "$plugin_dir/z.sh" ]; then
                echo 'source ${0:A:h}/z.sh' > "$plugin_dir/zsh-z.plugin.zsh"
                echo -e "${GREEN}  ✓ $plugin_name 修复成功${NC}"
                SUCCESS_PLUGINS+=("$plugin_name")
                return 0
            fi
            echo -e "${YELLOW}  ⚠ $plugin_name 文件不完整${NC}"
        fi
    else
        echo -e "${RED}  ✗ $plugin_name 克隆失败${NC}"
    fi
    
    FAILED_PLUGINS+=("$plugin_name")
    return 1
}

# 安装 Powerlevel10k 主题
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}安装 Powerlevel10k 主题...${NC}"
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

if [ ! -f "$P10K_DIR/powerlevel10k.zsh-theme" ]; then
    rm -rf "$P10K_DIR"
    echo -e "${BLUE}  正在克隆...${NC}"
    if git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR" 2>&1 | grep -v "Cloning into"; then
        if [ -f "$P10K_DIR/powerlevel10k.zsh-theme" ]; then
            echo -e "${GREEN}✓ Powerlevel10k 安装成功${NC}"
        else
            echo -e "${RED}✗ Powerlevel10k 文件不完整${NC}"
        fi
    else
        echo -e "${RED}✗ Powerlevel10k 安装失败${NC}"
    fi
else
    echo -e "${GREEN}✓ Powerlevel10k 已安装${NC}"
fi

# 安装插件
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}安装插件...${NC}"
echo -e "${GREEN}========================================${NC}"

# 定义插件列表
declare -a PLUGINS=(
    "zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions.git"
    "zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting.git"
    "zsh-completions|https://github.com/zsh-users/zsh-completions.git"
    "zsh-z|https://github.com/agkozak/zsh-z.git"
)

# 安装每个插件
for plugin_info in "${PLUGINS[@]}"; do
    IFS='|' read -r plugin_name plugin_url <<< "$plugin_info"
    plugin_dir="${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/$plugin_name"
    install_plugin "$plugin_name" "$plugin_url" "$plugin_dir"
done

# 下载 p10k 配置
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}配置 Powerlevel10k...${NC}"
if [ ! -f ~/.p10k.zsh ]; then
    if curl -fsSL --connect-timeout 10 --max-time 30 \
        "https://raw.githubusercontent.com/VocabVictor/myzsh/main/p10k.zsh" \
        -o ~/.p10k.zsh.tmp 2>/dev/null && [ -s ~/.p10k.zsh.tmp ]; then
        mv ~/.p10k.zsh.tmp ~/.p10k.zsh
        echo -e "${GREEN}✓ P10k 配置下载成功${NC}"
    else
        echo -e "${YELLOW}! P10k 配置下载失败，使用默认配置${NC}"
        rm -f ~/.p10k.zsh.tmp
    fi
else
    echo -e "${GREEN}✓ P10k 配置已存在${NC}"
fi

# 创建 .zshrc
echo -e "${GREEN}生成 .zshrc 配置...${NC}"
cat > ~/.zshrc << 'EOF'
# Enable Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path configuration
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
export LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH"

# Oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(
    git
    extract
    sudo
    colored-man-pages
    history-substring-search
)

# Add custom plugins if they exist
for plugin in zsh-autosuggestions zsh-syntax-highlighting zsh-completions zsh-z; do
    plugin_dir="$ZSH/custom/plugins/$plugin"
    if [ -d "$plugin_dir" ]; then
        case "$plugin" in
            zsh-completions)
                [ -d "$plugin_dir/src" ] && plugins+=($plugin)
                ;;
            *)
                if ls "$plugin_dir"/*.plugin.zsh >/dev/null 2>&1 || ls "$plugin_dir"/*.zsh >/dev/null 2>&1; then
                    plugins+=($plugin)
                fi
                ;;
        esac
    fi
done

# Load oh-my-zsh
source $ZSH/oh-my-zsh.sh

# User configuration
export LANG=en_US.UTF-8
export EDITOR='vim'
export TZ='Asia/Shanghai'

# History
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

# Autosuggestions settings
if [[ -d "$ZSH/custom/plugins/zsh-autosuggestions" ]]; then
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

# Functions
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

# Load zsh-completions
if [[ -d "$ZSH/custom/plugins/zsh-completions/src" ]]; then
  fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src
fi
EOF

# 创建缓存目录
mkdir -p ~/.cache

# 最终报告
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}安装报告${NC}"
echo -e "${GREEN}========================================${NC}"

# 基础组件
echo -e "${BLUE}基础组件：${NC}"
[ -d ~/.oh-my-zsh ] && echo -e "  ${GREEN}✓ Oh My Zsh${NC}" || echo -e "  ${RED}✗ Oh My Zsh${NC}"
[ -f ~/.oh-my-zsh/custom/themes/powerlevel10k/powerlevel10k.zsh-theme ] && echo -e "  ${GREEN}✓ Powerlevel10k${NC}" || echo -e "  ${RED}✗ Powerlevel10k${NC}"
[ -f ~/.p10k.zsh ] && echo -e "  ${GREEN}✓ P10k 配置${NC}" || echo -e "  ${YELLOW}⚠ P10k 配置（默认）${NC}"

# 插件状态
echo -e "\n${BLUE}插件状态：${NC}"
for plugin in zsh-autosuggestions zsh-syntax-highlighting zsh-completions zsh-z; do
    plugin_dir="${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/$plugin"
    if validate_plugin "$plugin_dir"; then
        echo -e "  ${GREEN}✓ $plugin${NC}"
    else
        echo -e "  ${RED}✗ $plugin${NC}"
    fi
done

# Zsh 信息
echo -e "\n${BLUE}Zsh 信息：${NC}"
if [ -f "$HOME/.local/bin/zsh" ]; then
    echo -e "  路径: $HOME/.local/bin/zsh"
    $HOME/.local/bin/zsh --version 2>/dev/null | head -1 | sed 's/^/  /'
elif command -v zsh &> /dev/null; then
    echo -e "  路径: $(which zsh)"
    zsh --version 2>/dev/null | head -1 | sed 's/^/  /'
fi

echo -e "${GREEN}========================================${NC}"

# 设置自动启动
if [ -f "$HOME/.local/bin/zsh" ]; then
    if ! grep -q "exec.*zsh" ~/.bashrc; then
        echo -e "\n# Auto-start zsh" >> ~/.bashrc
        echo '[ -z "$ZSH_VERSION" ] && [ -f "$HOME/.local/bin/zsh" ] && exec $HOME/.local/bin/zsh' >> ~/.bashrc
    fi
fi

echo -e "${GREEN}配置完成！${NC}"
echo -e "\n${YELLOW}使用说明：${NC}"
echo -e "  1. 启动 Zsh: ${GREEN}exec \$HOME/.local/bin/zsh${NC}"
echo -e "  2. 配置主题: ${GREEN}p10k configure${NC}"

# 询问是否立即切换
echo ""
read -p "是否现在切换到 zsh? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -f "$HOME/.local/bin/zsh" ]; then
        exec $HOME/.local/bin/zsh
    else
        exec zsh
    fi
fi
