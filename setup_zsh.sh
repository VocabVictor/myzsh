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

# 检测代理设置
GITHUB_URLS=()
if [ -n "$http_proxy" ] || [ -n "$https_proxy" ]; then
    echo -e "${GREEN}检测到代理设置，将使用代理下载${NC}"
    GITHUB_URLS+=("https://github.com")
else
    echo -e "${YELLOW}未检测到代理，将尝试多个镜像源${NC}"
    # 添加多个GitHub镜像
    GITHUB_URLS+=(
        "https://mirror.ghproxy.com/https://github.com"
        "https://ghproxy.com/https://github.com"
        "https://github.moeyy.xyz/https://github.com"
        "https://github.com"
    )
fi

# Git克隆函数，支持多个镜像重试
git_clone_with_retry() {
    local repo_path=$1
    local target_dir=$2
    local max_attempts=${3:-${#GITHUB_URLS[@]}}
    
    for url_base in "${GITHUB_URLS[@]}"; do
        echo -e "${BLUE}  尝试: ${url_base}${NC}"
        # 构建完整URL
        if [[ $url_base == *"github.com" ]] && [[ $url_base != "https://github.com" ]]; then
            # 镜像URL
            full_url="$url_base/$repo_path"
        else
            # 直接URL
            full_url="$url_base/$repo_path"
        fi
        
        # 尝试克隆
        if timeout 30 git clone --depth=1 "$full_url" "$target_dir" 2>/dev/null; then
            echo -e "${GREEN}    成功！${NC}"
            return 0
        else
            echo -e "${YELLOW}    失败，尝试下一个源...${NC}"
        fi
    done
    
    return 1
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
    
    # 尝试多个源下载
    for mirror in "" "https://mirror.ghproxy.com/" "https://ghproxy.com/"; do
        if curl -L "${mirror}https://github.com/zsh-users/zsh/archive/refs/tags/zsh-${ZSH_VERSION}.tar.gz" -o zsh.tar.gz 2>/dev/null && [ -s zsh.tar.gz ]; then
            break
        fi
    done
    
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
    
    if git_clone_with_retry "ohmyzsh/ohmyzsh.git" ~/.oh-my-zsh; then
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

# 插件验证函数 - 更宽松的验证
validate_plugin() {
    local plugin_dir=$1
    local plugin_name=$(basename "$plugin_dir")
    
    if [ ! -d "$plugin_dir" ]; then
        return 1
    fi
    
    # 特定插件的验证
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
            # 检查是否有任何 .zsh 或 .plugin.zsh 文件
            ls "$plugin_dir"/*.zsh >/dev/null 2>&1 || ls "$plugin_dir"/*.plugin.zsh >/dev/null 2>&1
            ;;
    esac
}

# 强制安装插件函数
force_install_plugin() {
    local plugin_name=$1
    local plugin_repo=$2
    local plugin_dir=$3
    
    echo -e "${YELLOW}安装 $plugin_name...${NC}"
    
    # 先删除可能存在的目录
    rm -rf "$plugin_dir"
    
    # 使用重试函数安装
    if git_clone_with_retry "$plugin_repo" "$plugin_dir"; then
        # 验证安装
        if validate_plugin "$plugin_dir"; then
            echo -e "${GREEN}✓ $plugin_name 安装成功${NC}"
            SUCCESS_PLUGINS+=("$plugin_name")
            return 0
        else
            echo -e "${YELLOW}⚠ $plugin_name 安装了但验证失败，尝试修复...${NC}"
            # 对于某些插件可能需要特殊处理
            if [ "$plugin_name" = "zsh-z" ] && [ -f "$plugin_dir/z.sh" ]; then
                # 创建一个 plugin 文件
                echo 'source ${0:A:h}/z.sh' > "$plugin_dir/zsh-z.plugin.zsh"
                SUCCESS_PLUGINS+=("$plugin_name")
                return 0
            fi
        fi
    fi
    
    echo -e "${RED}✗ $plugin_name 安装失败${NC}"
    FAILED_PLUGINS+=("$plugin_name")
    return 1
}

# 安装 Powerlevel10k 主题
echo -e "${GREEN}检查 Powerlevel10k 主题...${NC}"
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ] || [ ! -f "$P10K_DIR/powerlevel10k.zsh-theme" ]; then
    echo -e "${YELLOW}安装 Powerlevel10k...${NC}"
    rm -rf "$P10K_DIR"
    
    if git_clone_with_retry "romkatv/powerlevel10k.git" "$P10K_DIR"; then
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

# 安装所有插件
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}开始安装插件...${NC}"
echo -e "${GREEN}========================================${NC}"

# 强制安装所有插件
force_install_plugin "zsh-autosuggestions" \
    "zsh-users/zsh-autosuggestions.git" \
    "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"

force_install_plugin "zsh-syntax-highlighting" \
    "zsh-users/zsh-syntax-highlighting.git" \
    "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"

force_install_plugin "zsh-completions" \
    "zsh-users/zsh-completions.git" \
    "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions"

force_install_plugin "zsh-z" \
    "agkozak/zsh-z.git" \
    "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-z"

# 下载 p10k 配置
echo -e "${GREEN}配置 Powerlevel10k...${NC}"
if [ ! -f ~/.p10k.zsh ]; then
    P10K_URLS=(
        "https://raw.githubusercontent.com/VocabVictor/myzsh/main/p10k.zsh"
        "https://mirror.ghproxy.com/https://raw.githubusercontent.com/VocabVictor/myzsh/main/p10k.zsh"
        "https://ghproxy.com/https://raw.githubusercontent.com/VocabVictor/myzsh/main/p10k.zsh"
    )
    
    for url in "${P10K_URLS[@]}"; do
        if curl -fsSL "$url" -o ~/.p10k.zsh.tmp 2>/dev/null && [ -s ~/.p10k.zsh.tmp ]; then
            mv ~/.p10k.zsh.tmp ~/.p10k.zsh
            echo -e "${GREEN}✓ P10k 配置下载成功${NC}"
            break
        fi
    done
    
    if [ ! -f ~/.p10k.zsh ]; then
        echo -e "${YELLOW}! P10k 配置下载失败，将使用默认配置${NC}"
        rm -f ~/.p10k.zsh.tmp
    fi
else
    echo -e "${GREEN}✓ P10k 配置已存在${NC}"
fi

# 创建 .zshrc - 只加载成功安装的插件
echo -e "${GREEN}生成 .zshrc 配置...${NC}"
cat > ~/.zshrc << 'ZSHRC_HEAD'
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path configuration
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
export LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH"

# Path to oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Set theme
ZSH_THEME="powerlevel10k/powerlevel10k"

# Base plugins
plugins=(
    git
    extract
    sudo
    colored-man-pages
    history-substring-search
)

ZSHRC_HEAD

# 动态添加成功安装的插件
for plugin in "${SUCCESS_PLUGINS[@]}"; do
    echo "plugins+=($plugin)" >> ~/.zshrc
done

# 继续配置文件
cat >> ~/.zshrc << 'ZSHRC_TAIL'

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

# Autosuggestions configuration (if installed)
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
ZSHRC_TAIL

# 创建缓存目录
mkdir -p ~/.cache

# 最终验证
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}安装报告：${NC}"
echo -e "${GREEN}========================================${NC}"

# 基础组件
echo -e "${BLUE}基础组件：${NC}"
[ -d ~/.oh-my-zsh ] && echo -e "  ${GREEN}✓ Oh My Zsh${NC}" || echo -e "  ${RED}✗ Oh My Zsh${NC}"
[ -d ~/.oh-my-zsh/custom/themes/powerlevel10k ] && echo -e "  ${GREEN}✓ Powerlevel10k${NC}" || echo -e "  ${RED}✗ Powerlevel10k${NC}"
[ -f ~/.p10k.zsh ] && echo -e "  ${GREEN}✓ P10k 配置${NC}" || echo -e "  ${YELLOW}⚠ P10k 配置（使用默认）${NC}"

# 插件状态
echo -e "\n${BLUE}插件状态：${NC}"
if [ ${#SUCCESS_PLUGINS[@]} -gt 0 ]; then
    echo -e "${GREEN}成功安装的插件：${NC}"
    for plugin in "${SUCCESS_PLUGINS[@]}"; do
        echo -e "  ${GREEN}✓ $plugin${NC}"
    done
fi

if [ ${#FAILED_PLUGINS[@]} -gt 0 ]; then
    echo -e "${RED}安装失败的插件：${NC}"
    for plugin in "${FAILED_PLUGINS[@]}"; do
        echo -e "  ${RED}✗ $plugin${NC}"
    done
fi

# 实际检查插件目录
echo -e "\n${BLUE}插件目录内容：${NC}"
ls -la ~/.oh-my-zsh/custom/plugins/ 2>/dev/null | tail -n +4 | while read -r line; do
    echo "  $line"
done

# Zsh 信息
echo -e "\n${BLUE}Zsh 信息：${NC}"
if [ -f "$HOME/.local/bin/zsh" ]; then
    echo -e "  路径: $HOME/.local/bin/zsh"
elif command -v zsh &> /dev/null; then
    echo -e "  路径: $(which zsh)"
fi

echo -e "${GREEN}========================================${NC}"

# 设置自动启动
if [ -f "$HOME/.local/bin/zsh" ]; then
    if ! grep -q "exec.*zsh" ~/.bashrc; then
        echo -e "\n# Auto-start zsh" >> ~/.bashrc
        echo '[ -z "$ZSH_VERSION" ] && [ -f "$HOME/.local/bin/zsh" ] && exec $HOME/.local/bin/zsh' >> ~/.bashrc
    fi
fi

# 清理
cleanup_temp_files

echo -e "${GREEN}配置完成！${NC}"
echo -e "${YELLOW}提示：${NC}"
echo -e "1. 重新登录或运行: ${GREEN}exec \$HOME/.local/bin/zsh${NC}"
echo -e "2. 如需重新配置主题，运行: ${GREEN}p10k configure${NC}"

if [ ${#FAILED_PLUGINS[@]} -gt 0 ]; then
    echo -e "3. 部分插件安装失败，但不影响基本使用"
fi

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
