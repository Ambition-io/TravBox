#!/data/data/com.termux/files/usr/bin/bash

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
RESET="\033[0m"

# 打印信息、成功、警告和错误消息
print_info() { echo -e "${BLUE}[信息]${RESET} $1"; }
print_success() { echo -e "${GREEN}[成功]${RESET} $1"; }
print_warning() { echo -e "${YELLOW}[警告]${RESET} $1"; }
print_error() { echo -e "${RED}[错误]${RESET} $1"; }

# 打印标题
print_title() {
    clear
    echo -e "${CYAN}============================================${RESET}"
    echo -e "${CYAN}          TravBox 安装程序${RESET}"
    echo -e "${CYAN}============================================${RESET}"
    echo ""
}

# 检查依赖
check_git() {
    if ! command -v git &> /dev/null; then
        print_warning "未安装Git，正在安装..."
        pkg update -y && pkg install -y git
        if [ $? -ne 0 ]; then
            print_error "Git安装失败，请手动安装后重试"
            exit 1
        fi
        print_success "Git安装完成"
    fi
}

# 主函数
main() {
    print_title
    
    # 检查git是否安装
    check_git
    
    # 仓库地址
    REPO_URL="https://github.com/Ambition-io/TravBox.git"
    
    print_info "选择安装位置"
    echo "1) 隐藏文件夹 ($HOME/.travbox) [默认，保持主目录整洁]"
    echo "2) 可见文件夹 ($HOME/TravBox) [更直观，便于查看]"
    echo ""
    read -p "请选择 [1-2，默认1]: " location_choice
    
    if [[ "$location_choice" == "2" ]]; then
        INSTALL_DIR="$HOME/TravBox"
    else
        INSTALL_DIR="$HOME/.travbox"
    fi
    
    # 检查目标目录是否已存在
    if [ -d "$INSTALL_DIR" ]; then
        print_warning "目标目录已存在: $INSTALL_DIR"
        read -p "是否覆盖现有安装? (y/n): " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            print_warning "安装已取消"
            exit 0
        fi
        rm -rf "$INSTALL_DIR"
    fi
    
    # 克隆仓库
    print_info "正在从GitHub克隆TravBox..."
    git clone "$REPO_URL" "$INSTALL_DIR"
    
    if [ $? -ne 0 ]; then
        print_error "克隆失败，请检查网络连接后重试"
        exit 1
    fi
    
    # 如果选择非隐藏文件夹，需要修改主脚本中的SCRIPT_DIR变量
    if [ "$INSTALL_DIR" == "$HOME/TravBox" ]; then
        print_info "配置为非隐藏安装..."
        sed -i "s|SCRIPT_DIR=\"\$HOME/.travbox\"|SCRIPT_DIR=\"\$HOME/TravBox\"|g" "$INSTALL_DIR/start.sh"
    fi
    
    # 设置执行权限
    chmod +x "$INSTALL_DIR/start.sh"
    
    # 创建.initialized标记文件
    touch "$INSTALL_DIR/.initialized"
    
    print_success "TravBox已成功安装到: $INSTALL_DIR"
    echo ""
    
    # 询问是否创建快捷方式
    read -p "是否创建命令行快捷方式'travbox'? (y/n): " create_shortcut
    if [[ "$create_shortcut" =~ ^[Yy]$ ]]; then
        # 创建快捷方式
        cat > "$PREFIX/bin/travbox" << EOF
#!/data/data/com.termux/files/usr/bin/bash
exec "$INSTALL_DIR/start.sh" "\$@"
EOF
        chmod +x "$PREFIX/bin/travbox"
        print_success "快捷方式已创建，现在可以直接使用'travbox'命令启动"
    fi
    
    # 询问是否立即运行
    read -p "立即运行TravBox? (y/n): " run_now
    if [[ "$run_now" =~ ^[Yy]$ ]]; then
        exec "$INSTALL_DIR/start.sh"
    else
        echo -e "${GREEN}安装完成，感谢使用!${RESET}"
    fi
    
    # 脚本执行完成后自删除
    rm -f "$0"
}

# 运行主函数
main
