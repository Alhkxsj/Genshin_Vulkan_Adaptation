#!/system/bin/sh

# post-mount阶段启动检查脚本
# 本脚本在系统挂载阶段运行，执行启动时的配置文件检查和修复
# 遵循KernelSU模块生命周期规范

# 获取模块目录路径
MODDIR=${0%/*}

# 系统稳定等待
# 等待系统启动稳定，避免过早访问文件系统
sleep 5

# 日期检查函数
# 检查今天是否已经执行过检查，避免重复执行
check_daily_run() {
    # 获取当前日期
    TODAY=$(date +%Y%m%d)
    
    # 从模块配置中获取上次检查日期
    LAST_CHECK=$(ksud module config get last_check_date 2>/dev/null || echo "")
    
    # 如果今天已经检查过，则跳过
    if [ "$LAST_CHECK" = "$TODAY" ]; then
        return 1
    fi
    
    return 0
}

# 延迟检查
# 额外延迟确保系统完全启动
sleep 30

# 检查是否需要运行
if ! check_daily_run; then
    exit 0
fi

# 配置内容加载
# 读取模块保存的适配后配置内容
load_config_content() {
    if [ -f "$MODDIR/adapted_config.txt" ]; then
        ORIGINAL_CONTENT=$(cat "$MODDIR/adapted_config.txt")
    else
        # 如果适配文件不存在，使用默认配置
        ORIGINAL_CONTENT="4
Samsung Xclipse 950
Samsung Xclipse 940
Samsung Xclipse 920
Adreno (TM) 840
Adreno (TM) 830
Adreno (TM) 825
Adreno (TM) 750
Adreno (TM) 740
Adreno (TM) 640
Adreno (TM) 730
Mali-G710
Mali-G715
Mali-G720
Mali-G925
Mali-G1-Ultra MC12"
    fi
}

# 文件检查和修复函数
# 检查配置文件是否存在和内容是否正确，必要时进行修复
check_and_repair() {
    local file="$1"
    local file_path="$GAME_DIR/$file"
    
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

# 主检查逻辑
main_check() {
    # 加载配置内容
    load_config_content
    
    # 设置游戏目录路径
    GAME_DIR="/storage/emulated/0/Android/data/com.miHoYo.Yuanshen/files"
    
    # 检查游戏目录是否存在
    if [ ! -d "$GAME_DIR" ]; then
        # 游戏目录不存在，更新检查日期并退出
        TODAY=$(date +%Y%m%d)
        ksud module config set last_check_date "$TODAY"
        return
    fi
    
    # 执行文件检查
    local files_repaired=0
    local files=("vulkan_gpu_list_config.txt" "vulkan_gpu_list_config_engine.txt")
    
    for file in "${files[@]}"; do
        if ! check_and_repair "$file"; then
            files_repaired=$((files_repaired + 1))
        fi
    done
    
    # 更新检查日期
    TODAY=$(date +%Y%m%d)
    ksud module config set last_check_date "$TODAY"
    
    # 记录修复日志
    if [ $files_repaired -gt 0 ]; then
        local repair_time=$(date '+%Y-%m-%d %H:%M:%S')
        ksud module config set --temp last_repair "$repair_time"
        
        # 可选：添加系统日志记录
        if command -v log >/dev/null 2>&1; then
            log -t "YuanShenVulkan" "修复了 $files_repaired 个配置文件于 $repair_time"
        fi
    fi
}

# 执行主检查逻辑
main_check

# 脚本执行完成
exit 0