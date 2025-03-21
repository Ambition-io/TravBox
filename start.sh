#!/data/data/com.termux/files/usr/bin/bash

# Traverse Termux集成脚本框架
VERSION="1.0.5"

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
RESET="\033[0m"

# 配置变量
SCRIPT_DIR="$HOME/travbox"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
CONFIG_FILE="$SCRIPT_DIR/config.sh"
REPO_URL="https://github.com/Ambition-io/TravBox.git"
BASHRC_FILE="$HOME/.bashrc"

# 确保目录存在
mkdir -p "$SCRIPTS_DIR"

# 创建配置文件（如果不存在）
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" << EOF
#!/data/data/com.termux/files/usr/bin/bash
# 配置文件
REPO_URL="$REPO_URL"
DEFAULT_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/termux"
FRAMEWORK_ALIAS="travbox"
EOF
    chmod +x "$CONFIG_FILE"
fi

# 加载配置
source "$CONFIG_FILE"

# 打印标题
print_title() {
    clear
    echo -e "${CYAN}============================================${RESET}"
    echo -e "${CYAN}          Traverse Termux v$VERSION${RESET}"
    echo -e "${CYAN}============================================${RESET}"
    echo ""
}

# 打印信息、成功、警告和错误消息
print_info() { echo -e "${BLUE}[信息]${RESET} $1"; }
print_success() { echo -e "${GREEN}[成功]${RESET} $1"; }
print_warning() { echo -e "${YELLOW}[警告]${RESET} $1"; }
print_error() { echo -e "${RED}[错误]${RESET} $1"; }

# 按键继续
press_enter() {
    echo ""
    read -p "按 Enter 键继续..."
}

# 初始化框架
init_framework() {
    # 确保必要的目录存在
    mkdir -p "$SCRIPTS_DIR"
    
    # 确保存在 alias 指令可以访问 travbox
    ensure_framework_alias
}

# 确保框架别名存在
ensure_framework_alias() {
    local current_script="$(realpath "$0")"
    local alias_name="${FRAMEWORK_ALIAS:-travbox}"
    
    # 检查别名是否已经存在或需要更新
    if grep -q "alias $alias_name=" "$BASHRC_FILE" 2>/dev/null; then
        # 检查是否指向当前脚本，如果不是则更新
        if ! grep -q "alias $alias_name='$current_script'" "$BASHRC_FILE" 2>/dev/null; then
            sed -i "s|alias $alias_name=.*|alias $alias_name='$current_script'|" "$BASHRC_FILE"
            print_info "框架别名已更新: $alias_name"
            print_warning "请运行 'source ~/.bashrc' 或重启终端以应用更改"
        fi
    else
        # 别名不存在，创建新别名
        echo "alias $alias_name='$current_script'" >> "$BASHRC_FILE"
        print_info "框架别名已添加: $alias_name"
        print_warning "请运行 'source ~/.bashrc' 或重启终端以应用更改"
    fi
}

# 检查必要的命令是否安装
check_dependencies() {
    local deps=("git" "curl" "wget")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_warning "缺少必要的依赖：${missing[*]}"
        read -p "是否立即安装这些依赖？(y/n): " install
        if [[ "$install" =~ ^[Yy]$ ]]; then
            pkg update -y
            pkg install -y "${missing[@]}"
            print_success "依赖安装完成"
        else
            print_warning "部分功能可能无法正常使用"
        fi
    fi
}

# 配置Git以使用HTTPS
configure_git() {
    if command -v git &> /dev/null; then
        git config --global core.askPass ""
        git config --global credential.helper ""
        
        if [[ "$REPO_URL" == git@* ]]; then
            REPO_URL=$(echo "$REPO_URL" | sed -e 's|git@github.com:|https://github.com/|')
            sed -i "s|REPO_URL=.*|REPO_URL=\"$REPO_URL\"|" "$CONFIG_FILE"
            print_info "已将仓库URL从SSH格式转换为HTTPS格式"
        fi
    fi
}

# 扫描已安装脚本
scan_installed_scripts() {
    local scripts=()
    
    if [ -d "$SCRIPTS_DIR" ]; then
        while IFS= read -r script; do
            if [ -x "$script" ]; then
                local name=$(basename "$script")
                local desc=$(grep -m 1 "# Description:" "$script" | cut -d ':' -f 2- | sed 's/^[[:space:]]*//')
                
                if [ -z "$desc" ]; then
                    desc="$name"
                fi
                
                scripts+=("$script:$desc")
            fi
        done < <(find "$SCRIPTS_DIR" -type f -name "*.sh")
    fi
    
    echo "${scripts[@]}"
}

# 切换Termux软件源
switch_mirror() {
    print_title
    echo -e "${CYAN}选择Termux软件源:${RESET}\n"
    echo "1) 清华大学镜像源 (国内推荐)"
    echo "2) 阿里云镜像源"
    echo "3) 中科大镜像源"
    echo "4) 官方源 (国际)"
    echo "5) 自定义源"
    echo "0) 返回主菜单"
    
    read -p "请选择 [0-5]: " choice
    
    local mirror=""
    case $choice in
        1) mirror="https://mirrors.tuna.tsinghua.edu.cn/termux" ;;
        2) mirror="https://mirrors.aliyun.com/termux" ;;
        3) mirror="https://mirrors.ustc.edu.cn/termux" ;;
        4) mirror="https://packages.termux.dev/apt/termux-main" ;;
        5) read -p "请输入自定义镜像源URL: " mirror ;;
        0) return ;;
        *) 
            print_error "无效选项"
            press_enter
            switch_mirror
            return
            ;;
    esac
    
    if [ -n "$mirror" ]; then
        mkdir -p $PREFIX/etc/apt/sources.list.d/
        echo "deb $mirror stable main" > $PREFIX/etc/apt/sources.list.d/termux-main.list
        apt update -y
        
        sed -i "s|DEFAULT_MIRROR=.*|DEFAULT_MIRROR=\"$mirror\"|" "$CONFIG_FILE"
        
        print_success "软件源已切换至: $mirror"
    fi
    
    press_enter
}

# 更新Termux环境
update_termux() {
    print_title
    print_info "正在更新Termux环境..."
    
    apt update -y && apt upgrade -y
    
    print_success "Termux环境更新完成"
    press_enter
}

# 基本环境安装菜单
install_basic_environment() {
    while true; do
        print_title
        echo -e "${YELLOW}基本环境安装:${RESET}"
        echo "1) 安装所有基本工具 (git, curl, wget, python, openssh, vim, nano)"
        echo "2) 安装 Git"
        echo "3) 安装 Curl"
        echo "4) 安装 Wget"
        echo "5) 安装 Python"
        echo "6) 安装 OpenSSH"
        echo "7) 安装 Vim"
        echo "8) 安装 Nano"
        echo "0) 返回主菜单"
        echo ""
        
        read -p "请选择 [0-8]: " choice
        
        case $choice in
            1) 
                print_info "安装所有基本工具..."
                pkg update -y
                pkg install -y git curl wget python openssh vim nano
                print_success "所有基本工具安装完成"
                ;;
            2)
                print_info "安装 Git..."
                pkg update -y
                pkg install -y git
                print_success "Git 安装完成"
                ;;
            3)
                print_info "安装 Curl..."
                pkg update -y
                pkg install -y curl
                print_success "Curl 安装完成"
                ;;
            4)
                print_info "安装 Wget..."
                pkg update -y
                pkg install -y wget
                print_success "Wget 安装完成"
                ;;
            5)
                print_info "安装 Python..."
                pkg update -y
                pkg install -y python
                print_success "Python 安装完成"
                ;;
            6)
                print_info "安装 OpenSSH..."
                pkg update -y
                pkg install -y openssh
                print_success "OpenSSH 安装完成"
                ;;
            7)
                print_info "安装 Vim..."
                pkg update -y
                pkg install -y vim
                print_success "Vim 安装完成"
                ;;
            8)
                print_info "安装 Nano..."
                pkg update -y
                pkg install -y nano
                print_success "Nano 安装完成"
                ;;
            0)
                return
                ;;
            *)
                print_error "无效选项"
                ;;
        esac
        
        press_enter
    done
}

# 卸载菜单
uninstall_menu() {
    print_title
    echo -e "${YELLOW}卸载选项:${RESET}"
    echo "1) 卸载软件包"
    echo "2) 卸载整个框架"
    echo "0) 返回上一级菜单"
    echo ""
    
    read -p "请选择 [0-2]: " choice
    
    case $choice in
        1) uninstall_package ;;
        2) uninstall_framework ;;
        0) return ;;
        *) 
            print_error "无效选项"
            press_enter
            uninstall_menu
            ;;
    esac
}

# 卸载软件包
uninstall_package() {
    print_title
    echo -e "${YELLOW}可卸载的软件包:${RESET}"
    
    # 初始化目录变量
    init_pinned_directory
    
    local scripts=($(scan_installed_scripts))
    if [ ${#scripts[@]} -eq 0 ]; then
        print_warning "没有找到可卸载的软件包"
        press_enter
        return
    fi
    
    local i=1
    declare -A script_map
    
    for script_info in "${scripts[@]}"; do
        IFS=':' read -r script_path script_desc <<< "$script_info"
        echo "$i) $script_desc ($(basename "$script_path"))"
        script_map[$i]="$script_path"
        ((i++))
    done
    
    echo "0) 返回上一级菜单"
    echo ""
    
    read -p "请选择要卸载的软件包 [0-$((i-1))]: " choice
    
    if [[ $choice -eq 0 ]]; then
        uninstall_menu
        return
    elif [[ $choice -ge 1 && $choice -lt $i ]]; then
        local script_path="${script_map[$choice]}"
        local script_name=$(basename "$script_path")
        
        read -p "确定要卸载软件包 '$script_name'? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            # 移除固定列表中的项目
            if [ -f "$PINNED_FILE" ]; then
                grep -v "$script_path:" "$PINNED_FILE" > "$PINNED_FILE.tmp"
                mv "$PINNED_FILE.tmp" "$PINNED_FILE"
            fi
            
            # 移除别名
            local script_basename=$(basename "$script_path" .sh)
            remove_script_alias "$script_basename"
            
            # 删除脚本文件
            rm -f "$script_path"
            print_success "软件包 '$script_name' 已成功卸载"
        else
            print_warning "卸载已取消"
        fi
    else
        print_error "无效选项"
    fi
    
    press_enter
    uninstall_menu
}

# 卸载整个框架
uninstall_framework() {
    print_title
    echo -e "${RED}警告: 此操作将卸载整个Termux集成脚本框架${RESET}"
    echo "包括所有软件包和配置。"
    echo ""
    
    read -p "确定要卸载整个框架? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_warning "卸载已取消"
        press_enter
        uninstall_menu
        return
    fi
    
    # 确定框架别名
    local framework_alias="${FRAMEWORK_ALIAS:-travbox}"
    local bashrc="$HOME/.bashrc"
    
    # 清理别名
    if [ -f "$bashrc" ]; then
        # 移除框架别名
        sed -i "/alias $framework_alias=/d" "$bashrc"
        
        # 移除所有软件包别名行（以"# Traverse script alias:"标记的行）
        sed -i '/# Traverse script alias:/d' "$bashrc"
    fi
    
    # 删除框架目录
    rm -rf "$SCRIPT_DIR"
    
    print_success "Traverse Termux框架已成功卸载"
    echo ""
    echo "感谢您使用本框架！"
    
    exit 0
}

# 执行选定的脚本
execute_script() {
    local script="$1"
    
    if [ -f "$script" ] && [ -x "$script" ]; then
        print_info "执行软件包: $(basename "$script")"
        "$script"
    else
        print_error "软件包不存在或没有执行权限"
    fi
    
    press_enter
}

# 设置菜单
settings_menu() {
    while true; do
        print_title
        echo -e "${YELLOW}设置:${RESET}"
        echo "1) 查看版本信息"
        echo "2) 卸载功能"
        echo "3) 配置管理"
        echo "0) 返回主菜单"
        echo ""
        
        read -p "请选择 [0-3]: " choice
        
        case $choice in
            1) show_version_info ;;
            2) uninstall_menu ;;
            3) config_management ;;
            0) return ;;
            *) 
                print_error "无效选项"
                press_enter
                ;;
        esac
    done
}

# 显示详细的版本信息
show_version_info() {
    print_title
    echo -e "${YELLOW}版本信息:${RESET}"
    echo "框架版本: $VERSION"
    echo "安装路径: $SCRIPT_DIR"
    
    local script_count=$(find "$SCRIPTS_DIR" -type f -name "*.sh" | wc -l)
    echo "已安装软件包: $script_count"
    
    # 初始化固定软件包目录
    init_pinned_directory
    
    if [ -f "$PINNED_FILE" ]; then
        local pinned_count=$(wc -l < "$PINNED_FILE")
        echo "已固定软件包: $pinned_count"
    else
        echo "已固定软件包: 0"
    fi
    
    local init_file="$SCRIPT_DIR/.initialized"
    if [ -f "$init_file" ]; then
        local install_date=$(stat -c %y "$init_file" 2>/dev/null || stat -f "%Sm" "$init_file" 2>/dev/null)
        echo "安装日期: $install_date"
    fi
    
    echo ""
    press_enter
}

# 配置管理
config_management() {
    print_title
    echo -e "${YELLOW}配置管理:${RESET}"
    echo "1) 修改仓库URL"
    echo "2) 修改框架别名"
    echo "3) 恢复默认配置"
    echo "0) 返回上一级菜单"
    echo ""
    
    read -p "请选择 [0-3]: " choice
    
    case $choice in
        1)
            read -p "请输入新的仓库URL: " new_repo
            if [ -n "$new_repo" ]; then
                if [[ "$new_repo" == git@* ]]; then
                    new_repo=$(echo "$new_repo" | sed -e 's|git@github.com:|https://github.com/|')
                    print_info "已将仓库URL从SSH格式转换为HTTPS格式"
                fi
                sed -i "s|REPO_URL=.*|REPO_URL=\"$new_repo\"|" "$CONFIG_FILE"
                print_success "仓库URL已更新"
            fi
            ;;
        2)
            current_alias="${FRAMEWORK_ALIAS:-travbox}"
            read -p "请输入新的框架别名 (当前: $current_alias, 留空使用默认'travbox'): " new_alias
            
            # 如果新别名为空，则使用默认值
            if [ -z "$new_alias" ]; then
                new_alias="travbox"
            fi
            
            # 如果新别名与当前别名不同
            if [ "$new_alias" != "$current_alias" ]; then
                # 移除旧的别名
                if grep -q "alias $current_alias=" "$BASHRC_FILE" 2>/dev/null; then
                    sed -i "/alias $current_alias=/d" "$BASHRC_FILE" 2>/dev/null
                fi
                
                # 更新配置文件中的别名
                if grep -q "FRAMEWORK_ALIAS=" "$CONFIG_FILE" 2>/dev/null; then
                    sed -i "s|FRAMEWORK_ALIAS=.*|FRAMEWORK_ALIAS=\"$new_alias\"|" "$CONFIG_FILE"
                else
                    echo "FRAMEWORK_ALIAS=\"$new_alias\"" >> "$CONFIG_FILE"
                fi
                
                # 更新FRAMEWORK_ALIAS变量
                FRAMEWORK_ALIAS="$new_alias"
                
                # 更新别名
                ensure_framework_alias
                
                print_success "框架别名已更新为: $new_alias"
                print_warning "请运行 'source ~/.bashrc' 或重启终端以使别名生效"
            else
                print_info "别名未更改"
            fi
            ;;
        3)
            read -p "确定要恢复默认配置? (y/n): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                # 存储当前别名以便移除
                current_alias="${FRAMEWORK_ALIAS:-travbox}"
                
                cat > "$CONFIG_FILE" << EOF
#!/data/data/com.termux/files/usr/bin/bash
# 配置文件
REPO_URL="$REPO_URL"
DEFAULT_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/termux"
FRAMEWORK_ALIAS="travbox"
EOF
                chmod +x "$CONFIG_FILE"
                
                # 如果当前别名不是"travbox"，需要更新
                if [ "$current_alias" != "travbox" ]; then
                    # 移除旧的别名
                    if grep -q "alias $current_alias=" "$BASHRC_FILE" 2>/dev/null; then
                        sed -i "/alias $current_alias=/d" "$BASHRC_FILE" 2>/dev/null
                    fi
                    
                    # 更新FRAMEWORK_ALIAS变量
                    FRAMEWORK_ALIAS="travbox"
                    
                    # 更新别名
                    ensure_framework_alias
                fi
                
                print_success "配置已重置为默认值"
            fi
            ;;
        0)
            return
            ;;
        *)
            print_error "无效选项"
            press_enter
            ;;
    esac
    
    press_enter
}

# ==================== 软件包管理功能 ====================

# 初始化固定软件包目录
init_pinned_directory() {
    PINNED_DIR="$SCRIPT_DIR/pinned"
    PINNED_FILE="$PINNED_DIR/scripts.list"
    
    # 创建必要的目录
    mkdir -p "$PINNED_DIR"
}

# 软件包管理菜单
package_management() {
    # 初始化固定软件包目录
    init_pinned_directory
    
    while true; do
        print_title
        echo -e "${YELLOW}软件包管理:${RESET}"
        echo "1) 已安装软件包列表"
        echo "2) 安装新软件包"
        echo "3) 管理别名"
        echo "4) 管理主页固定软件包" 
        echo "0) 返回主菜单"
        echo ""
        
        read -p "请选择 [0-4]: " choice
        
        case $choice in
            1) show_installed_packages ;;
            2) install_new_packages ;;
            3) manage_aliases ;;
            4) manage_pinned_packages ;;
            0) return ;;
            *) 
                print_error "无效选项"
                press_enter
                ;;
        esac
    done
}

# 显示已安装软件包
show_installed_packages() {
    print_title
    echo -e "${YELLOW}已安装软件包列表:${RESET}"
    
    local scripts=($(scan_installed_scripts))
    if [ ${#scripts[@]} -eq 0 ]; then
        print_warning "没有找到已安装的软件包"
        press_enter
        return
    fi
    
    local i=1
    declare -A script_map
    
    for script_info in "${scripts[@]}"; do
        IFS=':' read -r script_path script_desc <<< "$script_info"
        echo "$i) $script_desc ($(basename "$script_path"))"
        script_map[$i]="$script_path"
        ((i++))
    done
    
    echo "0) 返回上一级菜单"
    echo ""
    
    read -p "请选择要执行的软件包 [0-$((i-1))]: " choice
    
    if [[ $choice -eq 0 ]]; then
        return
    elif [[ $choice -ge 1 && $choice -lt $i ]]; then
        execute_script "${script_map[$choice]}"
    else
        print_error "无效选项"
        press_enter
    fi
}

# 从仓库安装新软件包
install_new_packages() {
    print_title
    echo -e "${YELLOW}安装新软件包:${RESET}"
    
    # 检查依赖
    check_dependencies
    
    # 首先确保仓库已克隆，以便查看可用软件包
    if [ ! -d "$SCRIPTS_DIR/.git" ]; then
        print_info "正在获取可用软件包列表..."
        
        local temp_dir="/data/data/com.termux/files/usr/tmp/scripts_temp_$$"
        mkdir -p "$temp_dir"
        
        # 克隆仓库以获取最新软件包
        GIT_TERMINAL_PROMPT=0 git clone "$REPO_URL" "$temp_dir" 2>/dev/null
        
        if [ $? -ne 0 ]; then
            print_error "无法连接到软件包仓库，请检查网络或仓库地址"
            rm -rf "$temp_dir"
            press_enter
            return
        fi
        
        # 如果存在scripts目录，则使用它
        if [ -d "$temp_dir/scripts" ]; then
            temp_dir="$temp_dir/scripts"
        fi
    else
        print_info "正在更新可用软件包列表..."
        # 仓库已存在，执行pull操作
        cd "$SCRIPTS_DIR"
        GIT_TERMINAL_PROMPT=0 git pull 2>/dev/null
        temp_dir="$SCRIPTS_DIR"
    fi
    
    # 扫描可用软件包
    local available_packages=()
    local i=1
    declare -A package_map
    
    while IFS= read -r script; do
        if [ -f "$script" ]; then
            local name=$(basename "$script")
            local desc=$(grep -m 1 "# Description:" "$script" | cut -d ':' -f 2- | sed 's/^[[:space:]]*//')
            
            if [ -z "$desc" ]; then
                desc="$name"
            fi
            
            echo "$i) $desc ($(basename "$script"))"
            package_map[$i]="$script"
            ((i++))
        fi
    done < <(find "$temp_dir" -type f -name "*.sh")
    
    if [ $i -eq 1 ]; then
        print_warning "仓库中没有找到可用的软件包"
        # 如果是临时目录，则清理
        if [ "$temp_dir" != "$SCRIPTS_DIR" ]; then
            rm -rf "$(dirname "$temp_dir")"
        fi
        press_enter
        return
    fi
    
    echo "0) 返回上一级菜单"
    echo ""
    
    read -p "请选择要安装的软件包 [0-$((i-1))]: " choice
    
    if [[ $choice -eq 0 ]]; then
        # 如果是临时目录，则清理
        if [ "$temp_dir" != "$SCRIPTS_DIR" ]; then
            rm -rf "$(dirname "$temp_dir")"
        fi
        return
    elif [[ $choice -ge 1 && $choice -lt $i ]]; then
        local package_path="${package_map[$choice]}"
        local package_name=$(basename "$package_path")
        
        # 安装软件包
        print_info "正在安装软件包 '$package_name'..."
        
        # 确保脚本目录存在
        mkdir -p "$SCRIPTS_DIR"
        
        # 复制软件包到脚本目录
        cp "$package_path" "$SCRIPTS_DIR/"
        chmod +x "$SCRIPTS_DIR/$package_name"
        
        print_success "软件包 '$package_name' 已成功安装"
        
        # 询问是否创建别名
        read -p "是否为此软件包创建命令别名? (y/n): " create_alias
        if [[ "$create_alias" =~ ^[Yy]$ ]]; then
            local script_name=$(basename "$package_name" .sh)
            read -p "请输入别名 (默认: $script_name): " alias_name
            if [ -z "$alias_name" ]; then
                alias_name="$script_name"
            fi
            
            # 检查别名是否已存在于bashrc中
            if grep -q "alias $alias_name=" "$BASHRC_FILE" 2>/dev/null; then
                print_warning "别名 '$alias_name' 已存在，可能会导致冲突。"
                read -p "是否覆盖? (y/n): " continue_anyway
                if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
                    print_warning "别名创建已取消"
                else
                    create_script_alias_internal "$SCRIPTS_DIR/$package_name" "$alias_name"
                fi
            else
                create_script_alias_internal "$SCRIPTS_DIR/$package_name" "$alias_name"
            fi
        fi
        
        # 询问是否固定到主菜单
        read -p "是否将此软件包固定到主菜单? (y/n): " pin_to_menu
        if [[ "$pin_to_menu" =~ ^[Yy]$ ]]; then
            read -p "请输入显示在菜单中的名称 (默认: $package_name): " display_name
            if [ -z "$display_name" ]; then
                display_name="$package_name"
            fi
            
            # 初始化固定软件包目录
            init_pinned_directory
            
            echo "$SCRIPTS_DIR/$package_name:$display_name" >> "$PINNED_FILE"
            
            print_success "软件包 '$package_name' 已固定到主菜单"
        fi
    else
        print_error "无效选项"
    fi
    
    # 如果是临时目录，则清理
    if [ "$temp_dir" != "$SCRIPTS_DIR" ]; then
        rm -rf "$(dirname "$temp_dir")"
    fi
    
    press_enter
}

# 创建脚本别名的内部函数
create_script_alias_internal() {
    local script_path="$1"
    local alias_name="$2"
    
    local abs_script_path=$(readlink -f "$script_path" 2>/dev/null || realpath "$script_path" 2>/dev/null || echo "$script_path")
    
    # 如果已存在同名别名，先移除
    sed -i "/alias $alias_name=/d" "$BASHRC_FILE" 2>/dev/null
    
    # 在bashrc中添加别名
    echo "alias $alias_name='$abs_script_path' # Traverse script alias:" >> "$BASHRC_FILE"
    
    print_success "别名 '$alias_name' 已创建，可通过 '$alias_name' 命令执行软件包"
    print_warning "请运行 'source ~/.bashrc' 或重启终端以使别名生效"
}

# 移除脚本别名
remove_script_alias() {
    local alias_name="$1"
    
    # 从bashrc中移除别名
    sed -i "/alias $alias_name=/d" "$BASHRC_FILE" 2>/dev/null
}

# 管理别名
manage_aliases() {
    while true; do
        print_title
        echo -e "${YELLOW}别名管理:${RESET}"
        echo "1) 查看现有别名"
        echo "2) 创建新别名"
        echo "3) 删除别名"
        echo "0) 返回上一级菜单"
        echo ""
        
        read -p "请选择 [0-3]: " choice
        
        case $choice in
            1) view_aliases ;;
            2) create_alias ;;
            3) remove_alias ;;
            0) return ;;
            *) 
                print_error "无效选项"
                press_enter
                ;;
        esac
    done
}

# 查看现有别名
view_aliases() {
    print_title
    echo -e "${YELLOW}现有别名:${RESET}"
    
    if [ ! -f "$BASHRC_FILE" ]; then
        print_warning "找不到 .bashrc 文件"
        press_enter
        return
    fi
    
    local found=false
    local i=1
    
    while IFS= read -r line; do
        # 找到由本框架创建的别名
        if [[ "$line" == *"# Traverse script alias:"* ]]; then
            local alias_def=$(echo "$line" | cut -d'=' -f1)
            local alias_name="${alias_def#alias }"
            local script_path=$(echo "$line" | cut -d"'" -f2)
            
            echo "$i) $alias_name -> $(basename "$script_path")"
            ((i++))
            found=true
        fi
    done < "$BASHRC_FILE"
    
    if ! $found; then
        print_warning "没有找到由框架创建的别名"
    fi
    
    echo ""
    press_enter
}

# 创建新别名
create_alias() {
    print_title
    echo -e "${YELLOW}为软件包创建别名:${RESET}"
    
    local scripts=($(scan_installed_scripts))
    if [ ${#scripts[@]} -eq 0 ]; then
        print_warning "没有找到可用的软件包"
        press_enter
        return
    fi
    
    local i=1
    declare -A script_map
    
    for script_info in "${scripts[@]}"; do
        IFS=':' read -r script_path script_desc <<< "$script_info"
        echo "$i) $script_desc ($(basename "$script_path"))"
        script_map[$i]="$script_path"
        ((i++))
    done
    
    echo "0) 返回上一级菜单"
    echo ""
    
    read -p "请选择要创建别名的软件包 [0-$((i-1))]: " choice
    
    if [[ $choice -eq 0 ]]; then
        return
    elif [[ $choice -ge 1 && $choice -lt $i ]]; then
        local script_path="${script_map[$choice]}"
        local script_name=$(basename "$script_path" .sh)
        
        read -p "请输入别名 (默认: $script_name): " alias_name
        if [ -z "$alias_name" ]; then
            alias_name="$script_name"
        fi
        
        # 检查别名是否已存在于bashrc中
        if grep -q "alias $alias_name=" "$BASHRC_FILE" 2>/dev/null; then
            print_warning "别名 '$alias_name' 已存在，可能会导致冲突。"
            read -p "是否覆盖? (y/n): " continue_anyway
            if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
                print_warning "别名创建已取消"
                press_enter
                return
            fi
        fi
        
        create_script_alias_internal "$script_path" "$alias_name"
    else
        print_error "无效选项"
    fi
    
    press_enter
}

# 删除别名
remove_alias() {
    print_title
    echo -e "${YELLOW}删除别名:${RESET}"
    
    if [ ! -f "$BASHRC_FILE" ]; then
        print_warning "找不到 .bashrc 文件"
        press_enter
        return
    fi
    
    # 收集所有由框架创建的别名
    local aliases=()
    local i=1
    declare -A alias_map
    
    while IFS= read -r line; do
        # 找到由本框架创建的别名
        if [[ "$line" == *"# Traverse script alias:"* ]]; then
            local alias_def=$(echo "$line" | cut -d'=' -f1)
            local alias_name="${alias_def#alias }"
            local script_path=$(echo "$line" | cut -d"'" -f2)
            
            echo "$i) $alias_name -> $(basename "$script_path")"
            alias_map[$i]="$alias_name"
            ((i++))
        fi
    done < "$BASHRC_FILE"
    
    if [ $i -eq 1 ]; then
        print_warning "没有找到由框架创建的别名"
        press_enter
        return
    fi
    
    echo "0) 返回上一级菜单"
    echo ""
    
    read -p "请选择要删除的别名 [0-$((i-1))]: " choice
    
    if [[ $choice -eq 0 ]]; then
        return
    elif [[ $choice -ge 1 && $choice -lt $i ]]; then
        local alias_name="${alias_map[$choice]}"
        
        read -p "确定要删除别名 '$alias_name'? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            # 删除别名
            sed -i "/alias $alias_name=.*# Traverse script alias:/d" "$BASHRC_FILE"
            
            print_success "别名 '$alias_name' 已成功删除"
            print_warning "请运行 'source ~/.bashrc' 或重启终端以应用更改"
        else
            print_warning "删除已取消"
        fi
    else
        print_error "无效选项"
    fi
    
    press_enter
}

# 管理主页固定软件包
manage_pinned_packages() {
    # 初始化固定软件包目录
    init_pinned_directory
    
    while true; do
        print_title
        echo -e "${YELLOW}主页固定软件包管理:${RESET}"
        echo "1) 查看已固定软件包"
        echo "2) 添加固定软件包"
        echo "3) 移除固定软件包"
        echo "0) 返回上一级菜单"
        echo ""
        
        read -p "请选择 [0-3]: " choice
        
        case $choice in
            1) view_pinned_packages ;;
            2) add_pinned_package ;;
            3) remove_pinned_package ;;
            0) return ;;
            *) 
                print_error "无效选项"
                press_enter
                ;;
        esac
    done
}

# 查看已固定软件包
view_pinned_packages() {
    print_title
    echo -e "${YELLOW}已固定的软件包:${RESET}"
    
    if [ ! -f "$PINNED_FILE" ] || [ ! -s "$PINNED_FILE" ]; then
        print_warning "没有找到已固定的软件包"
        press_enter
        return
    fi
    
    local i=1
    
    while IFS=: read -r script_path display_name; do
        if [ -f "$script_path" ] && [ -x "$script_path" ]; then
            echo "$i) $display_name ($(basename "$script_path"))"
            ((i++))
        fi
    done < "$PINNED_FILE"
    
    if [ $i -eq 1 ]; then
        print_warning "没有找到有效的固定软件包"
    fi
    
    echo ""
    press_enter
}

# 添加固定软件包
add_pinned_package() {
    print_title
    echo -e "${YELLOW}添加固定软件包到主页:${RESET}"
    
    local scripts=($(scan_installed_scripts))
    if [ ${#scripts[@]} -eq 0 ]; then
        print_warning "没有找到可用的软件包"
        press_enter
        return
    fi
    
    local i=1
    declare -A script_map
    
    for script_info in "${scripts[@]}"; do
        IFS=':' read -r script_path script_desc <<< "$script_info"
        echo "$i) $script_desc ($(basename "$script_path"))"
        script_map[$i]="$script_path"
        ((i++))
    done
    
    echo "0) 返回上一级菜单"
    echo ""
    
    read -p "请选择要固定的软件包 [0-$((i-1))]: " choice
    
    if [[ $choice -eq 0 ]]; then
        return
    elif [[ $choice -ge 1 && $choice -lt $i ]]; then
        local script_path="${script_map[$choice]}"
        local script_name=$(basename "$script_path")
        
        # 检查是否已经固定
        if [ -f "$PINNED_FILE" ]; then
            if grep -q "^$script_path:" "$PINNED_FILE"; then
                print_warning "该软件包已经固定在主页"
                press_enter
                return
            fi
        fi
        
        read -p "请输入显示在主页的名称 (默认: $script_name): " display_name
        if [ -z "$display_name" ]; then
            display_name="$script_name"
        fi
        
        echo "$script_path:$display_name" >> "$PINNED_FILE"
        
        print_success "软件包 '$script_name' 已成功固定到主页"
    else
        print_error "无效选项"
    fi
    
    press_enter
}

# 移除固定软件包
remove_pinned_package() {
    print_title
    echo -e "${YELLOW}从主页移除固定软件包:${RESET}"
    
    if [ ! -f "$PINNED_FILE" ] || [ ! -s "$PINNED_FILE" ]; then
        print_warning "没有找到已固定的软件包"
        press_enter
        return
    fi
    
    local i=1
    declare -A pinned_map
    
    while IFS=: read -r script_path display_name; do
        if [ -f "$script_path" ] && [ -x "$script_path" ]; then
            echo "$i) $display_name ($(basename "$script_path"))"
            pinned_map[$i]="$script_path:$display_name"
            ((i++))
        fi
    done < "$PINNED_FILE"
    
    if [ $i -eq 1 ]; then
        print_warning "没有找到有效的固定软件包"
        press_enter
        return
    fi
    
    echo "0) 返回上一级菜单"
    echo ""
    
    read -p "请选择要移除的固定软件包 [0-$((i-1))]: " choice
    
    if [[ $choice -eq 0 ]]; then
        return
    elif [[ $choice -ge 1 && $choice -lt $i ]]; then
        local entry="${pinned_map[$choice]}"
        
        # 从固定列表中删除条目
        grep -v "^$entry$" "$PINNED_FILE" > "$PINNED_FILE.tmp"
        mv "$PINNED_FILE.tmp" "$PINNED_FILE"
        
        # 提取显示名称以用于成功消息
        IFS=':' read -r script_path display_name <<< "$entry"
        
        print_success "软件包 '$display_name' 已成功从主页移除"
    else
        print_error "无效选项"
    fi
    
    press_enter
}

# 主菜单
main_menu() {
    # 初始化固定软件包目录
    init_pinned_directory
    
    while true; do
        print_title
        echo -e "${CYAN}主菜单:${RESET}"
        echo "1) 切换软件源"
        echo "2) 更新Termux环境"
        echo "3) 安装基本环境"
        echo "4) 软件包管理"
        echo "5) 设置"
        echo "0) 退出"
        echo ""
        
        # 显示已固定的软件包
        local pinned_count=0
        
        if [ -f "$PINNED_FILE" ] && [ -s "$PINNED_FILE" ]; then
            echo -e "${YELLOW}快速启动:${RESET}"
            
            while IFS=: read -r script_path display_name; do
                if [ -f "$script_path" ] && [ -x "$script_path" ]; then
                    ((pinned_count++))
                    echo "$((pinned_count+5))) $display_name"
                fi
            done < "$PINNED_FILE"
            
            if [ $pinned_count -gt 0 ]; then
                echo ""
            fi
        fi
        
        echo -n "请选择 [0-5"
        if [ $pinned_count -gt 0 ]; then
            echo -n "-$((pinned_count+5))"
        fi
        echo -n "]: "
        read choice
        
        case $choice in
            1) switch_mirror ;;
            2) update_termux ;;
            3) install_basic_environment ;;
            4) package_management ;;
            5) settings_menu ;;
            0) exit 0 ;;
            *)
                # 检查是否选择了固定软件包
                if [ -f "$PINNED_FILE" ] && [ -s "$PINNED_FILE" ] && [ -n "$pinned_count" ]; then
                    local pinned_index=$((choice-5))
                    if [ $pinned_index -ge 1 ] && [ $pinned_index -le $pinned_count ]; then
                        local j=0
                        while IFS=: read -r script_path display_name; do
                            if [ -f "$script_path" ] && [ -x "$script_path" ]; then
                                ((j++))
                                 if [ $j -eq $pinned_index ]; then
                                       execute_script "$script_path"
                                    break
                                fi
                            fi
                        done < "$PINNED_FILE"
                        continue
                    fi
                fi
                
                print_error "无效选项"
                press_enter
                ;;
        esac
    done
}

# 主程序
init_framework
# 初始化目录变量
init_directories
main_menu
