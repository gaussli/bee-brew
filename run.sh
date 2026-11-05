#!/bin/bash

# beebrew启动脚本
# 使用方法: ./run.sh [debug|release]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函数定义
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}       beebrew - macOS Homebrew客户端   ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# 检查环境
check_environment() {
    print_info "检查环境..."
    
    # 检查Swift版本
    if ! command -v swift &> /dev/null; then
        print_error "未找到Swift编译器"
        echo "请安装Xcode命令行工具: xcode-select --install"
        exit 1
    fi
    
    swift_version=$(swift --version | head -n 1)
    print_success "Swift版本: $swift_version"
    
    # 检查Homebrew
    if ! command -v brew &> /dev/null; then
        print_warning "未找到Homebrew"
        echo "beebrew需要Homebrew才能正常工作"
        echo "您可以在应用内安装Homebrew"
    else
        brew_version=$(brew --version | head -n 1)
        print_success "Homebrew版本: $brew_version"
    fi
    
    # 检查项目结构
    if [ ! -f "Package.swift" ]; then
        print_error "未找到Package.swift"
        exit 1
    fi
}

# 清理构建
clean_build() {
    print_info "清理构建文件..."
    swift package clean
    rm -rf .build 2>/dev/null || true
    print_success "清理完成"
}

# 构建项目
build_project() {
    local build_type=$1
    
    print_info "开始构建 ($build_type)..."
    
    if [ "$build_type" = "debug" ]; then
        swift build -c debug
    else
        swift build -c release
    fi
    
    if [ $? -eq 0 ]; then
        print_success "构建成功"
    else
        print_error "构建失败"
        exit 1
    fi
}

# 运行应用
run_application() {
    local build_type=$1
    
    print_info "启动应用 ($build_type)..."
    echo ""
    
    if [ "$build_type" = "debug" ]; then
        swift run -c debug beebrew
    else
        swift run -c release beebrew
    fi
}

# 创建Xcode项目
create_xcode_project() {
    print_info "创建Xcode项目..."
    swift package generate-xcodeproj
    
    if [ $? -eq 0 ]; then
        print_success "Xcode项目创建成功"
        echo "使用以下命令打开项目:"
        echo "  open beebrew.xcodeproj"
    else
        print_error "Xcode项目创建失败"
    fi
}

# 运行测试
run_tests() {
    print_info "运行测试..."
    swift test
    
    if [ $? -eq 0 ]; then
        print_success "所有测试通过"
    else
        print_error "测试失败"
    fi
}

# 显示帮助
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  debug          调试模式运行 (默认)"
    echo "  release        发布模式运行"
    echo "  clean          清理构建文件"
    echo "  build          仅构建不运行"
    echo "  test           运行测试"
    echo "  xcode          创建Xcode项目"
    echo "  help           显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0             调试模式运行"
    echo "  $0 release     发布模式运行"
    echo "  $0 clean       清理构建"
    echo ""
}

# 主函数
main() {
    print_header
    
    # 默认参数
    MODE="debug"
    ACTION="run"
    
    # 解析参数
    case "$1" in
        "debug")
            MODE="debug"
            ;;
        "release")
            MODE="release"
            ;;
        "clean")
            ACTION="clean"
            ;;
        "build")
            ACTION="build"
            ;;
        "test")
            ACTION="test"
            ;;
        "xcode")
            ACTION="xcode"
            ;;
        "help"|"-h"|"--help")
            show_help
            exit 0
            ;;
        "")
            # 使用默认值
            ;;
        *)
            print_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
    
    # 检查环境
    check_environment
    
    # 执行操作
    case "$ACTION" in
        "clean")
            clean_build
            ;;
        "build")
            build_project "$MODE"
            ;;
        "test")
            run_tests
            ;;
        "xcode")
            create_xcode_project
            ;;
        "run")
            clean_build
            build_project "$MODE"
            run_application "$MODE"
            ;;
    esac
}

# 运行主函数
main "$@"