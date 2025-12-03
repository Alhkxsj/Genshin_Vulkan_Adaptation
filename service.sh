#!/system/bin/sh

# late_start服务模式定时检查脚本
# 本脚本以后台服务方式运行，提供每日定时检查功能
# 确保配置文件不被恶意修改，提供持续保护

# 获取模块目录路径
MODDIR=${0%/*}

# 系统启动等待
# 等待系统完全启动，避免过早执行
sleep 60

# 配置内容加载函数
# 加载模块保存的配置内容，用于后续检查
load_config_content() {
    if [ -f "$MODDIR/adapted_config.txt" ]; then
        ORIGINAL_CONTENT=$(cat "$MODDIR/adapted_config.txt")
        return 0
    else
        # 配置文件不存在，记录错误并退出
        if command -v log >/dev/null 2>&1; then
            log -t "YuanShenVulkan" "错误：适配配置文件不存在"
        fi
        return 1
    fi
}

# 文件检查和修复函数
# 检查指定配置文件的完整性和正确性
check_and_repair_file() {
    local file_name="$1"
    local file_path="$GAME_DIR/$file_name"
    
    # 检查文件是否存在
    if [ ! -f "$file_path" ]; then
        # 文件不存在，创建新文件
        echo "$ORIGINAL_CONTENT" > "$file_path"
        chmod 644 "$file_path"
        return 1
    fi
    
    # 检查文件内容是否正确
    local current_content=$(cat "$file_path" 2>/dev/null)
    if [ "$current_content" != "$ORIGINAL_CONTENT" ]; then
        # 内容不匹配，恢复正确内容
        echo "$ORIGINAL_CONTENT" > "$file_path"
        chmod 644 "$file_path"
        return 1
    fi
    
    return 0
}

# 执行检查和修复
# 执行实际的文件检查和修复操作
perform_check() {
    # 设置游戏目录路径
    GAME_DIR="/storage/emulated/0/Android/data/com.miHoYo.Yuanshen/files"
    
    # 检查游戏目录是否存在
    if [ ! -d "$GAME_DIR" ]; then
        return 0
    fi
    
    # 执行文件检查
    local files_repaired=0
    local files=("vulkan_gpu_list_config.txt" "vulkan_gpu_list_config_engine.txt")
    
    for file in "${files[@]}"; do
        if ! check_and_repair_file "$file"; then
            files_repaired=$((files_repaired + 1))
        fi
    done
    
    # 更新检查日期
    local today=$(date +%Y%m%d)
    ksud module config set last_check_date "$today"
    
    # 记录修复日志
    if [ $files_repaired -gt 0 ]; then
        local repair_time=$(date '+%Y-%m-%d %H:%M:%S')
        ksud module config set --temp last_repair "$repair_time"
        
        # 添加系统日志记录
        if command -v log >/dev/null 2>&1; then
            log -t "YuanShenVulkan" "定时检查修复了 $files_repaired 个配置文件于 $repair_time"
        fi
    fi
    
    return $files_repaired
}

# 时间检查函数
# 检查当前时间是否在执行窗口内（每天凌晨3:00-3:10）
is_check_time() {
    local current_hour=$(date +%H)
    local current_minute=$(date +%M)
    
    # 在凌晨3:00-3:10之间执行检查
    if [ "$current_hour" = "03" ] && [ "$current_minute" -lt 10 ]; then
        return 0
    fi
    
    return 1
}

# 检查是否已执行
# 检查今天是否已经执行过检查
has_checked_today() {
    local today=$(date +%Y%m%d)
    local last_check=$(ksud module config get last_check_date 2>/dev/null || echo "")
    
    if [ "$last_check" = "$today" ]; then
        return 0
    fi
    
    return 1
}

# 主循环逻辑
# 后台持续运行，定时检查执行条件
main_loop() {
    # 加载配置内容
    if ! load_config_content; then
        return 1
    fi
    
    # 主循环
    while true; do
        # 检查是否在执行时间窗口
        if is_check_time; then
            # 检查今天是否已经执行过
            if ! has_checked_today; then
                # 执行检查和修复
                local repaired_count=0
                perform_check
                repaired_count=$?
                
                # 记录检查结果
                if [ $repaired_count -gt 0 ]; then
                    if command -v log >/dev/null 2>&1; then
                        log -t "YuanShenVulkan" "定时检查完成，修复了 $repaired_count 个文件"
                    fi
                else
                    if command -v log >/dev/null 2>&1; then
                        log -t "YuanShenVulkan" "定时检查完成，所有文件正常"
                    fi
                fi
            fi
            
            # 避免在3点内重复执行，睡眠1小时
            sleep 3600
        else
            # 非检查时间，每5分钟检查一次时间
            sleep 300
        fi
    done
}

# 信号处理函数
# 优雅处理系统信号，确保资源正确释放
cleanup() {
    if command -v log >/dev/null 2>&1; then
        log -t "YuanShenVulkan" "服务正在停止"
    fi
    exit 0
}

# 注册信号处理
trap cleanup TERM INT

# 记录服务启动
if command -v log >/dev/null 2>&1; then
    log -t "YuanShenVulkan" "定时检查服务已启动"
fi

# 启动主循环
main_loop