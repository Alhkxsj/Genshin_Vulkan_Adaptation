#!/system/bin/sh

# 设备GPU检测与配置文件适配脚本
# 本脚本负责检测设备GPU型号并适配原神Vulkan配置文件
# 支持多种检测方法和GPU类型识别

# GPU检测函数
# 通过多种方法检测设备GPU型号，提高检测准确性
detect_gpu() {
    local gpu_model=""
    
    # 方法1: 通过OpenGL ES渲染器检测
    # 这是最准确的检测方法，直接获取GPU型号
    gpu_model=$(getprop ro.hardware.egl 2>/dev/null)
    
    # 方法2: 通过SurfaceFlinger服务检测
    # 获取图形渲染信息，补充检测
    if [ -z "$gpu_model" ]; then
        gpu_model=$(dumpsys SurfaceFlinger | grep "GLES" | head -1 | awk '{print $3}' 2>/dev/null)
    fi
    
    # 方法3: 通过系统属性推断GPU型号
    # 基于CPU平台和芯片信息推断GPU类型
    if [ -z "$gpu_model" ]; then
        local cpu_hardware=$(getprop ro.hardware)
        local board_platform=$(getprop ro.board.platform)
        local chipname=$(getprop ro.chipname)
        
        # 高通骁龙平台检测
        case "$cpu_hardware$board_platform$chipname" in
            *qcom*|*sm*|*msm*|*sdm*|*lahaina*|*kona*|*taro*)
                # 获取Adreno GPU版本号
                local adreno_ver=$(getprop ro.boot.revision 2>/dev/null)
                if [ -n "$adreno_ver" ]; then
                    gpu_model="Adreno (TM) $adreno_ver"
                else
                    # 根据平台推断Adreno版本
                    case "$board_platform" in
                        *lahaina*) gpu_model="Adreno (TM) 660" ;;
                        *kona*) gpu_model="Adreno (TM) 650" ;;
                        *taro*) gpu_model="TM) 740" ;;
                        *) gpu_model="Adreno (TM) 未知型号" ;;
                    esac
                fi
                ;;
            # 联发科天玑平台检测
            *mt*|*dimensity*)
                # 根据天玑型号推断Mali GPU版本
                case "$chipname" in
                    *dimensity9000*|*dimensity9200*) gpu_model="Mali-G710" ;;
                    *dimensity8000*|*dimensity8200*) gpu_model="Mali-G610" ;;
                    *dimensity7000*|*dimensity7200*) gpu_model="Mali-G57" ;;
                    *) gpu_model="Mali-G710" ;;
                esac
                ;;
            # 三星Exynos平台检测
            *exynos*|*s5e*)
                case "$chipname" in
                    *exynos2200*) gpu_model="Samsung Xclipse 920" ;;
                    *exynos2100*) gpu_model="Mali-G78" ;;
                    *exynos1080*) gpu_model="Mali-G78" ;;
                    *) gpu_model="Samsung Xclipse 920" ;;
                esac
                ;;
            # 海思麒麟平台检测
            *kirin*|*hi*)
                case "$chipname" in
                    *kirin9000*) gpu_model="Mali-G78" ;;
                    *kirin8000*) gpu_model="Mali-G77" ;;
                    *kirin7000*) gpu_model="Mali-G57" ;;
                    *) gpu_model="Mali-G78" ;;
                esac
                ;;
            # 其他平台默认处理
            *)
                gpu_model="未知GPU"
                ;;
        esac
    fi
    
    # 清理GPU型号字符串，移除多余信息
    gpu_model=$(echo "$gpu_model" | sed 's/OpenGL ES.*//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    echo "$gpu_model"
}

# 配置文件适配函数
# 根据检测到的GPU型号适配配置文件内容
adapt_config() {
    local gpu_model=$(detect_gpu)
    local config_content="$1"
    
    # 如果GPU型号未知或为空，则不进行适配
    if [ -z "$gpu_model" ] || [ "$gpu_model" = "未知GPU" ]; then
        echo "$config_content"
        return
    fi
    
    # 检查GPU是否已经在配置列表中
    if echo "$config_content" | grep -q "$gpu_model"; then
        echo "$config_content"
        return
    fi
    
    # 根据GPU类型确定替换位置
    local target_line=0
    
    # Adreno GPU适配
    if echo "$gpu_model" | grep -qi "Adreno"; then
        target_line=$(echo "$config_content" | grep -n "Adreno (TM)" | head -1 | cut -d: -f1)
    # Mali GPU适配
    elif echo "$gpu_model" | grep -qi "Mali"; then
        target_line=$(echo "$config_content" | grep -n "Mali-" | head -1 | cut -d: -f1)
    # 三星Xclipse GPU适配
    elif echo "$gpu_model" | grep -qi "Xclipse"; then
        target_line=$(echo "$config_content" | grep -n "Xclipse" | head -1 | cut -d: -f1)
    fi
    
    # 如果没有找到匹配类型，替换第5行（第一个非三星行）
    if [ -z "$target_line" ] || [ "$target_line" -eq 0 ]; then
        target_line=5
    fi
    
    # 替换目标行，保持配置文件格式
    echo "$config_content" | sed "${target_line}s/.*/$gpu_model/"
}

# 显示系统信息函数
# 显示用于GPU检测的系统属性信息
show_system_info() {
    echo "系统信息:"
    echo "  ro.hardware: $(getprop ro.hardware)"
    echo "  ro.board.platform: $(getprop ro.board.platform)"
    echo "  ro.chipname: $(getprop ro.chipname)"
    echo "  ro.hardware.egl: $(getprop ro.hardware.egl)"
    echo "  ro.product.model: $(getprop ro.product.model)"
    echo "  ro.product.brand: $(getprop ro.product.brand)"
}

# 主逻辑处理
# 根据命令行参数执行相应操作
case "$1" in
    --detect)
        # 仅检测GPU型号
        detect_gpu
        ;;
    --adapt)
        # 适配配置文件内容
        config_content=$(cat)
        adapt_config "$config_content"
        ;;
    --info)
        # 显示详细系统信息
        echo "GPU型号: $(detect_gpu)"
        show_system_info
        ;;
    *)
        # 默认显示检测信息
        echo "GPU型号: $(detect_gpu)"
        show_system_info
        echo ""
        echo "使用方法:"
        echo "  $0 --detect    仅检测GPU型号"
        echo "  $0 --adapt     适配配置文件（从stdin读取）"
        echo "  $0 --info      显示详细系统信息"
        ;;
esac