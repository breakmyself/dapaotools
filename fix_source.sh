#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

BLUE="\033[1;34m"
PLAIN="\033[0m"
SUCCESS="\033[1;32mOK软件源修复已完成\033[0m"
ERROR="\033[1;31mERROR\033[0m"
start=$(date +%s)

##定义目录
Dir_YumRepos=/etc/yum.repos.d
Dir_YumReposBackup=/etc/yum.repos.d_$(date '+%Y%m%d').bak

File_DebianSourceList=/etc/apt/sources.list
File_DebianSourceList_Backup=/etc/apt/sources.list_$(date '+%Y%m%d').bak
File_sources_list=/etc/apt/sources.list.d
File_sources_list_Backup=/etc/apt/sources.list.d_$(date '+%Y%m%d').bak

#定义可直接下载的repo文件
# Tencent_EL7="http://mirrors.cloud.tencent.com/repo/centos7_base.repo"
# Tencent_EL7_EPEL="http://mirrors.cloud.tencent.com/repo/epel-7.repo"
# Aliyun_EL7="https://mirrors.aliyun.com/repo/Centos-7.repo"
# Aliyun_EL7_EPEL="https://mirrors.aliyun.com/repo/epel-7.repo"
# Huawei_EL7="http://mirrors.aliyun.com/repository/conf/CentOS-7-reg.repo"
# WANGYI163_EL7="http://mirrors.163.com/.help/CentOS7-Base-163.repo"
# Tencent_EL8="http://mirrors.cloud.tencent.com/repo/centos8_base.repo"
# Aliyun_EL8="https://mirrors.aliyun.com/repo/Centos-vault-8.5.2111.repo"
# Huawei_EL8="https://repo.huaweicloud.com/repository/conf/CentOS-8-reg.repo"

# 判断自身是否有root权限
if [ "$(whoami)" != "root" ]; then
    echo "请使用root权限执行此脚本！"
    exit 1
fi

echo "开始检查网络是否正常！"
ping -c 2 www.baidu.com >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "检查网络正常。"
else
    echo "Ping 失败，您的服务器网络无法正常连接外网，请检查您的服务器网络。"
    exit 1
fi

clear

# 输出title
Title() {
    local date="$(date "+%Y-%m-%d %H:%M:%S")"
    local timezone="$(timedatectl status 2>/dev/null | grep "Time zone" | awk -F ':' '{print$2}' | awk -F ' ' '{print$1}')"

    # StartTitle
    echo -e "\e[1;36m### \e[1;32m 欢迎使用 GNU/Linux 一键更换软件源脚本 \e[36m### \e[0m"
    echo -e "\e[1;32m ______     _________            _______         _        ____  _____   ________    _____     
|_   _ \   |  _   _  |          |_   __ \       / \      |_   \|_   _| |_   __  |  |_   _|    
  | |_) |  |_/ | | \_|  ______    | |__) |     / _ \       |   \ | |     | |_ \_|    | |      
  |  __'.      | |     |______|   |  ___/     / ___ \      | |\ \| |     |  _| _     | |   _  
 _| |__) |    _| |_              _| |_      _/ /   \ \_   _| |_\   |_   _| |__/ |   _| |__/ | 
|_______/    |_____|            |_____|    |____| |____| |_____|\____| |________|  |________| 
                                                                                              \e[0m "
    echo -e "当前运行环境: ${BLUE}${SYS_OS} ${SYS_VERSION}${PLAIN}"
    echo -e "当前系统时间: ${BLUE}${date} ${timezone}${PLAIN}"
}

# 判断是否有curl，没有就安装。
Get_Pack_Manager() {

    if [ ! -f /bin/curl ]; then
        $PM install curl -y
        if ! [ -x "$(command -v curl)" ]; then
            echo '开始尝试更换临时源进行安装Curl组件....' 2>&1
            backup_source
            case "${SYS_OS}${SYS_VERSION}" in
            "CentOS7")
                CentOS_7
                ;;
            "CentOS8")
                CentOS_8
                ;;
            "CentOSStream 8")
                CentOS_8stream
                ;;
            "CentOSStream 9")
                CentOS_9stream
                ;;
            "Debian10")
                Debian_10
                ;;
            "Debian11")
                Debian_11
                ;;
            "Debian12")
                Debian_12
                ;;
            "Ubuntu20.04")
                Ubuntu_20
                ;;
            "Ubuntu22.04")
                Ubuntu_22
                ;;
            *)
                echo 'Error: failed to install curl.' 2>&1
                exit 1
                ;;
            esac

            if [ "$PM" = "apt-get" ]; then
                $PM update
                $PM reinstall -y libcurl4 curl
            else
                $PM install -y curl
            fi

            if [ "$?" -ne 0 ]; then
                recover_backup
                echo 'Error: failed to install curl.' 2>&1
                exit 1
            else
                recover_backup
            fi

        fi
    fi
}

# 备份软件源
backup_source() {
    if [ "$PM" = "yum" ] || [ "$PM" = "dnf" ]; then
        \cp -rp $Dir_YumRepos $Dir_YumReposBackup && rm -rf $Dir_YumRepos/*
    elif [ "$PM" = "apt-get" ]; then
        \cp -rp $File_DebianSourceList $File_DebianSourceList_Backup
        \cp -rp $File_sources_list $File_sources_list_Backup
        rm -rf $File_sources_list/*.list
    fi
}
# 恢复软件源
recover_backup() {
    if [ "$PM" = "yum" ] || [ "$PM" = "dnf" ]; then
        rm -rf $Dir_YumRepos
        mv $Dir_YumReposBackup $Dir_YumRepos

    elif [ "$PM" = "apt-get" ]; then
        rm -rf $File_DebianSourceList $File_sources_list
        mv $File_DebianSourceList_Backup $File_DebianSourceList
        mv $File_sources_list_Backup $File_sources_list
    fi

}

SYS_OS=""
SYS_VERSION=""
#判断系统和版本号
GetSysInfo() {
    if [ -f "/usr/bin/hostnamectl" ]; then
        SYS_OS=$(hostnamectl | awk '/Operating System:/{print $3}')
        case "$SYS_OS" in
        Ubuntu)
            SYS_VERSION=$(hostnamectl | grep 'Operating System:' | grep -Eow '[0-9]+\.[0-9]+' | head -n 1)
            ;;
        CentOS)
            CentosStreamCheck=$(hostnamectl | awk '/Operating System:/{print $3, $4, $5}' | grep -iE "CentOS Stream")
            if [ -n "$CentosStreamCheck" ]; then
                SYS_VERSION=$(echo "$CentosStreamCheck" | awk '{print $2,$3}')
            else
                SYS_VERSION=$(hostnamectl | grep 'Operating System:' | grep -Eow '[0-9]+' | head -n 1)
            fi
            ;;
        *)
            SYS_VERSION=$(hostnamectl | grep 'Operating System:' | grep -Eow '[0-9]+' | head -n 1)
            ;;
        esac
    fi

    if [ -z "$SYS_VERSION" ] || [ -z "$SYS_OS" ]; then
        if [ -s "/etc/lsb-release" ]; then
            SYS_OS=$(cat /etc/lsb-release | awk -F= '/DISTRIB_ID/{print $2}')
            SYS_VERSION=$(cat /etc/lsb-release | awk -F= '/DISTRIB_RELEASE/{print $2}' | head -n 1)

        elif [ "$(cat /etc/issue | grep -Eow 'Debian')" == "Debian" ]; then
            SYS_OS=$(cat /etc/issue | grep -Eow 'Debian')
            SYS_VERSION=$(cat /etc/issue | grep 'Debian' | grep -Eow '[0-9]+')

        elif [ -s "/etc/redhat-release" ]; then
            SYS_OS=$(cat /etc/redhat-release | awk '/CentOS/{print $1}')
            SYS_VERSION=$(cat /etc/redhat-release | awk '{print substr($4,1,1)}')
            if [ "$SYS_VERSION" = "8" ]; then
                if grep -qE "CentOS Stream" "/etc/redhat-release"; then
                    SYS_VERSION="Stream 8"
                fi
            elif [ "$SYS_VERSION" = "9" ]; then
                SYS_VERSION="Stream 9"
            fi
        else
            echo "获取系统信息失败，请联系服务器厂商协助您更换软件源！"
            exit 1
        fi
    fi

    if [[ ! "${SYS_OS,,}" =~ ^(centos|debian|ubuntu)$ ]]; then
        echo "很抱歉，当前暂未兼容您当前的系统，如需更换软件源，请联系服务器商协助处理！"
        exit 1
    fi

    if [[ "${SYS_OS,,}" =~ ^(centos) ]]; then
        if [ ! -d "$Dir_YumRepos" ]; then
            mkdir -p "$Dir_YumRepos"
        fi

        if [ -f "/usr/bin/yum" ] && [ -d "$Dir_YumRepos" ]; then
            PM="yum"
        elif [ -f "/usr/bin/dnf" ] && [ -d "$Dir_YumRepos" ]; then
            PM="dnf"
        fi

    elif [ -f "/usr/bin/apt-get" ] && [ -f "/usr/bin/dpkg" ]; then
        if [ ! -f "$File_DebianSourceList" ]; then
            mkdir -p /etc/apt
        fi
        PM="apt-get"
    fi

    Title

    case $(uname -m) in
    x86_64)
        SYSTEM_ARCH="x86_64"
        ;;
    aarch64)
        SYSTEM_ARCH="ARM64"
        ;;
    armv7l)
        SYSTEM_ARCH="ARMv7"
        ;;
    armv6l)
        SYSTEM_ARCH="ARMv6"
        ;;
    i686)
        SYSTEM_ARCH="x86_32"
        ;;
    *)
        SYSTEM_ARCH=$(uname -m)
        ;;
    esac

    case "${SYS_OS}" in
    "Debian")
        case "${SYS_VERSION}" in
        "9") SYS_CODE="stretch" ;;
        "10") SYS_CODE="buster" ;;
        "11") SYS_CODE="bullseye" ;;
        "12") SYS_CODE="bookworm" ;;
        esac
        if [ "${SYS_VERSION}" == "12" ]; then
            source_suffix="main contrib non-free non-free-firmware"
        else
            source_suffix="main contrib non-free"
        fi
        ;;
    "Ubuntu")
        case "${SYS_VERSION}" in
        "20.04") SYS_CODE="focal" ;;
        "21.04") SYS_CODE="hirsute" ;;
        "22.04") SYS_CODE="jammy" ;;
        "22.10") SYS_CODE="kinetic" ;;
        esac
        source_suffix="main restricted universe multiverse"
        ;;
    "CentOS")
        case "${SYS_VERSION}" in
        "7") SYS_CODE="el7" ;;
        "8") SYS_CODE="el8" ;;
        "Stream 8") SYS_CODE="stream_el8" ;;
        "Stream 9") SYS_CODE="stream_el9" ;;
        esac
        ;;
    esac

    ## 定义软件源分支名称
    if [[ -z "${SOURCE_BRANCH}" ]]; then
        if [ "$SYS_OS" = "Ubuntu" ]; then
            if [ ${SYSTEM_ARCH} = "x86_64" ] || [ $(uname -m) = "*i?86*" ]; then
                SOURCE_BRANCH="ubuntu"
            else
                SOURCE_BRANCH=ubuntu-ports
            fi
        fi
    fi

}

##服务器厂商判断
IDC_CHECK() {
    #通过motd文件来检查
    if grep -iq "Huawei Cloud" /etc/motd; then
        IDC_Service="Huawei"
    elif grep -iq "Alibaba Cloud" /etc/motd; then
        IDC_Service="Alibaba"
    fi

    if [ -d "/usr/local/qcloud" ]; then
        IDC_Service="Tencent"
    fi

    #尝试通过第三方接口获取IDC厂商
    if [[ -z "$IDC_Service" ]]; then
        IDC_Service=$(curl --connect-timeout 5 -m 5 -s https://ipinfo.io/json | grep -Eow 'Tencent|Alibaba|Huawei')
        if [[ -z "$IDC_Service" ]]; then
            IDC_Service=$(curl --connect-timeout 5 -m 5 -s https://ifconfig.co/json | grep -Eow 'Tencent|Alibaba|Huawei')
        fi
    fi

    #判断服务器厂商，验证是否可用内网源
    case "$IDC_Service" in
    Tencent)
        echo -e "当前服务器供应商: ${BLUE}腾讯云${PLAIN}"
        if timeout 5 ping -c 2 mirrors.tencentyun.com >/dev/null 2>&1; then
            echo "检测到您当前的网络可以使用腾讯云的内网源，将设置腾讯云的内网源"
            Mirrors_URL="mirrors.tencentyun.com"
        elif timeout 5 ping -c 2 mirrors.cloud.tencent.com >/dev/null 2>&1; then
            echo "您当前服务器的网络无法连接腾讯云的内网源，将设置腾讯云的公网源"
            Mirrors_URL="mirrors.cloud.tencent.com"
        else
            echo "检测到您当前的网络内、外网源无法使用，将开始使用第三方源"
            IDC_Service=""
        fi
        ;;
    Alibaba)
        echo -e "当前服务器供应商: ${BLUE}阿里云${PLAIN}"
        if timeout 5 ping -c 2 mirrors.cloud.aliyuncs.com >/dev/null 2>&1; then
            echo "检测到您当前的网络可以使用阿里云的内网源，将设置阿里云的内网源"
            Mirrors_URL="mirrors.cloud.aliyuncs.com"
        elif timeout 5 ping -c 2 mirrors.aliyun.com >/dev/null 2>&1; then
            echo "您当前服务器的网络无法连接阿里云的内网源，将设置阿里云的公网源"
            Mirrors_URL="mirrors.aliyun.com"
        else
            echo "检测到您当前的网络内、外网源无法使用，将开始使用第三方源"
            IDC_Service=""
        fi
        ;;
    Huawei)
        echo -e "当前服务器供应商: ${BLUE}华为云${PLAIN}"
        if timeout 5 ping -c 2 mirrors.myhuaweicloud.com >/dev/null 2>&1; then
            echo "检测到您当前的网络可以使用华为云的内网源，将设置华为云的内网源"
            Mirrors_URL="mirrors.myhuaweicloud.com"
        elif timeout 5 ping -c 2 repo.huaweicloud.com >/dev/null 2>&1; then
            echo "您当前服务器的网络无法连接华为云的内网源，将设置华为云的公网源"
            Mirrors_URL="repo.huaweicloud.com"
        else
            echo "检测到您当前的网络内、外网源无法使用，将开始使用第三方源"
            IDC_Service=""
        fi
        ;;
    esac
}

Check_mirrors() {
    if [ -n "$IDC_Service" ]; then
        return
    fi
    tmp_file1="/dev/shm/net_test1.pl"
    [ -f "${tmp_file1}" ] && rm -f "${tmp_file1}"
    touch "${tmp_file1}"

    declare -a mirrors=(
        "mirrors.cloud.tencent.com"
        "mirrors.aliyun.com"
        "repo.huaweicloud.com"
        "mirrors.sustech.edu.cn"
        "mirrors.zju.edu.cn"
        "mirrors.hit.edu.cn"
        "mirrors.tuna.tsinghua.edu.cn"
        "mirrors.ustc.edu.cn"
        "mirrors.cernet.edu.cn"
        "chinanet.mirrors.ustc.edu.cn"
        "unicom.mirrors.ustc.edu.cn"
        "cmcc.mirrors.ustc.edu.cn"
        "mirror.iscas.ac.cn"
    )

    for mirror in "${mirrors[@]}"; do
        MIRROR_CHECK=$(curl --connect-timeout 5 -m 5 -w "%{http_code} %{time_total}" "${mirror}" -o /dev/null 2>/dev/null | xargs)
        MIRROR_STATUS=$(echo "${MIRROR_CHECK}" | awk '{print $1}')
        TIME_TOTAL=$(echo "${MIRROR_CHECK}" | awk '{print $2 * 1000 - 500}' | cut -d '.' -f 1)

        if [[ "${MIRROR_STATUS}" =~ ("200"|"301"|"302"|"308")$ ]]; then
            echo "${TIME_TOTAL} ${mirror}" >>"${tmp_file1}"
        fi
    done

    if [ -s "${tmp_file1}" ]; then
        Mirrors_URL=$(sort -n "${tmp_file1}" | awk '{print $2}' | head -n 1)

    else
        echo -e "\e[1;31mNo mirrors available.$PNAIN"
        recover_backup
        exit 1
    fi
    rm -f "${tmp_file1}"
}

yum_check() {
    echo "开始检查软件源是否可用..."
    echo "可能耗时较久，请耐心等待..."
    yum clean all >/dev/null 2>&1
    timeout 15 yum makecache >/dev/null
    if [[ "$?" =~ ^(0|124)$ ]]; then
        echo -e "$SUCCESS"
        #rm -rf $Dir_YumRepos__$(date '+%Y%m%d').bak
    else
        echo -e "\n$ERROR 软件源修复失败\n"
        echo -e "请尝试再次执行脚本修复软件源，若仍然修复失败那么可能由以下原因导致"
        echo -e "1. 网络问题：例如连接异常、网络间歇式中断、由地区影响的网络因素等"
        echo -e "2. 软件源问题：例如正在维护，或者出现罕见的文件同步出错导致软件源修复命令执行后返回错误状态，请前往镜像站对应路径验证"
        echo -e "\n软件源地址："http://${Mirrors_URL}/"\n"
        recover_backup
    fi
}

apt_check() {
    echo "开始检查软件源是否可用..."
    echo "正在更新软件源，如等待时间过久，可使用CTRL+C键结束脚本，手动执行命令：apt-get update"
    apt-get update -y >/dev/null 2>&1
    if [ $? == 0 ]; then
        echo -e "$SUCCESS"
        #rm -rf /etc/apt/sources.list_$(date '+%Y%m%d').bak
    else
        echo -e "\n$ERROR 软件源修复失败\n"
        echo -e "请再次执行脚本并更换相同软件源后进行尝试，若仍然修复失败那么可能由以下原因导致"
        echo -e "1. 网络问题：例如连接异常、网络间歇式中断、由地区影响的网络因素等"
        echo -e "2. 软件源问题：例如正在维护，或者出现罕见的文件同步出错导致软件源修复命令执行后返回错误状态，请前往镜像站对应路径验证"
        echo -e "\n软件源地址："http://${Mirrors_URL}/"\n"
        recover_backup
    fi
}

#修改软件源
Re_Mirrors() {
    echo "正在选择软件源..."
    debian_basic_url="http://${Mirrors_URL}/debian"
    ubuntu_basic_url="http://${Mirrors_URL}/${SOURCE_BRANCH}"
    case "${SYS_CODE}" in
    stretch)
        echo "您的系统为Debian 9，此脚本不提供Debian 9 软件源！"
        exit 1
        ;;
    bullseye)
        echo "Debian源开始修复..."
        cat <<EOF >$File_DebianSourceList
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb ${debian_basic_url}/ ${SYS_CODE} ${source_suffix}
##deb-src ${debian_basic_url}/ ${SYS_CODE} ${source_suffix}

deb ${debian_basic_url}/ ${SYS_CODE}-updates ${source_suffix}
##deb-src ${debian_basic_url}/ ${SYS_CODE}-updates ${source_suffix}

deb ${debian_basic_url}/ ${SYS_CODE}-backports ${source_suffix}
##deb-src ${debian_basic_url}/ ${SYS_CODE}-backports ${source_suffix}

deb ${debian_basic_url}-security ${SYS_CODE}-security ${source_suffix}
##deb-src ${debian_basic_url}-security ${SYS_CODE}-security ${source_suffix}
EOF
        apt_check
        ;;
    buster)
        echo "Debian源开始修复..."
        cat <<EOF >$File_DebianSourceList
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb ${debian_basic_url}/ ${SYS_CODE} ${source_suffix}
##deb-src ${debian_basic_url}/ ${SYS_CODE} ${source_suffix}

deb ${debian_basic_url}-security ${SYS_CODE}/updates main
##deb-src ${debian_basic_url}-security ${SYS_CODE}/updates main

deb ${debian_basic_url}/ ${SYS_CODE}-updates ${source_suffix}
##deb-src ${debian_basic_url}/ ${SYS_CODE}-updates ${source_suffix}

deb ${debian_basic_url}/ ${SYS_CODE}-backports ${source_suffix}
##deb-src ${debian_basic_url}/ ${SYS_CODE}-backports ${source_suffix}
EOF
        apt_check
        ;;
    bookworm)
        echo "Debian源开始修复..."
        cat <<EOF >$File_DebianSourceList
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb ${debian_basic_url}/ ${SYS_CODE} ${source_suffix}
##deb-src ${debian_basic_url}/ ${SYS_CODE} ${source_suffix}

deb ${debian_basic_url}/ ${SYS_CODE}-updates ${source_suffix}
##deb-src ${debian_basic_url}/ ${SYS_CODE}-updates ${source_suffix}

deb ${debian_basic_url}/ ${SYS_CODE}-backports ${source_suffix}
##deb-src ${debian_basic_url}/ ${SYS_CODE}-backports ${source_suffix}

deb ${debian_basic_url}-security ${SYS_CODE}-security ${source_suffix}
##deb-src ${debian_basic_url}-security ${SYS_CODE}-security ${source_suffix}
EOF
        apt_check
        ;;
    focal | jammy | kinetic)
        echo "Ubuntu源开始修复..."
        cat <<EOF >$File_DebianSourceList
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb ${ubuntu_basic_url} ${SYS_CODE} ${source_suffix}
##deb-src ${ubuntu_basic_url} ${SYS_CODE} ${source_suffix}

deb ${ubuntu_basic_url} ${SYS_CODE}-security ${source_suffix}
##deb-src ${ubuntu_basic_url} ${SYS_CODE}-security ${source_suffix}

deb ${ubuntu_basic_url} ${SYS_CODE}-updates ${source_suffix}
##deb-src ${ubuntu_basic_url} ${SYS_CODE}-updates ${source_suffix}

# deb ${ubuntu_basic_url} ${SYS_CODE}-proposed ${source_suffix}
# ##deb-src http://${Mirrors_URL}/ ${SYS_CODE}-proposed ${source_suffix}

deb ${ubuntu_basic_url} ${SYS_CODE}-backports ${source_suffix}
##deb-src ${ubuntu_basic_url} ${SYS_CODE}-backports ${source_suffix}
EOF
        apt_check
        ;;
    el7)
        echo "CentOS-7源开始修复..."
        if [ -n "$Mirrors_URL" ]; then
            CentOS_7
            CentOS_7_EPEL
            sed -e "s#http://mirrors.aliyun.com#http://$Mirrors_URL#g" -i.bak $Dir_YumRepos/*.repo
        else
            echo "修复软件源异常"
        fi
        yum_check
        ;;
    el8)
        echo "CentOS-8源开始修复..."
        if [ -n "$Mirrors_URL" ]; then
            CentOS_8
            CentOS_8_EPEL
            sed -e "s#http://mirrors.aliyun.com#http://$Mirrors_URL#g" -i.bak $Dir_YumRepos/*.repo
        else
            echo "修复软件源异常"
        fi
        yum_check
        ;;
    stream_el8)
        echo "CentOS-8-stream源开始修复..."
        if [ -n "$Mirrors_URL" ]; then
            CentOS_8stream
            CentOS_8stream_EPEL
            sed -e "s#http://mirrors.aliyun.com#http://$Mirrors_URL#g" -i.bak $Dir_YumRepos/*.repo
        else
            echo "修复软件源异常"
        fi
        yum_check
        ;;
    stream_el9)
        #源较少。
        echo "CentOS-9-stream源开始修复..."
        if [ -n "$Mirrors_URL" ]; then
            if [[ "$Mirrors_URL" =~ ("mirrors.sustech.edu.cn"|"mirrors.zju.edu.cn"|"mirrors.hit.edu.cn")$ ]]; then
                Mirrors_URL="mirrors.cernet.edu.cn"
            fi
            CentOS_9stream
            CentOS_9stream_EPEL
            sed -e "s#http://mirrors.aliyun.com#http://$Mirrors_URL#g" -i.bak $Dir_YumRepos/*.repo
        else
            echo "修复软件源异常"
        fi
        yum_check
        ;;
    esac

}

CentOS_8() {
    ## 生成 CentOS 官方 repo 源文件
    cat >$Dir_YumRepos/CentOS-Linux-BaseOS.repo <<\EOF

# CentOS-Base.repo
#
# The mirror system uses the connecting IP address of the client and the
# update status of each mirror to pick mirrors that are updated to and
# geographically close to the client.  You should use this for CentOS updates
# unless you are manually picking other mirrors.
#
# If the mirrorlist= does not work for you, as a fall back you can try the 
# remarked out baseurl= line instead.
#
#

[BaseOS]
name=CentOS-$releasever - Base - 
baseurl=http://mirrors.aliyun.com/centos-vault/8.5.2111/BaseOS/$basearch/os/
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=BaseOS&infra=$infra
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF

    cat >$Dir_YumRepos/CentOS-Linux-AppStream.repo <<\EOF
#released updates 
[AppStream]
name=CentOS-$releasever - AppStream - 
baseurl=http://mirrors.aliyun.com/centos-vault/8.5.2111/AppStream/$basearch/os/
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=AppStream&infra=$infra
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF
    cat >$Dir_YumRepos/CentOS-Linux-PowerTools.repo <<\EOF
[PowerTools]
name=CentOS-$releasever - PowerTools - 
baseurl=http://mirrors.aliyun.com/centos-vault/8.5.2111/PowerTools/$basearch/os/
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=PowerTools&infra=$infra
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF

    cat >$Dir_YumRepos/CentOS-Linux-Extras.repo <<\EOF
# CentOS-Linux-Extras.repo
#
# The mirrorlist system uses the connecting IP address of the client and the
# update status of each mirror to pick current mirrors that are geographically
# close to the client.  You should use this for CentOS updates unless you are
# manually picking other mirrors.
#
# If the mirrorlist does not work for you, you can try the commented out
# baseurl line instead.

[extras]
name=CentOS Linux $releasever - Extras
baseurl=http://mirrors.aliyun.com/centos-vault/8.5.2111/extras/$basearch/os/
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=extras&infra=$infra
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

EOF

    cat >$Dir_YumRepos/CentOS-Linux-Plus.repo.repo <<\EOF
#additional packages that extend functionality of existing packages
[centosplus]
name=CentOS-$releasever - Plus -
baseurl=http://mirrors.aliyun.com/centos-vault/8.5.2111/centosplus/$basearch/os/
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=centosplus
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF

    cat >$Dir_YumRepos/CentOS-Linux-FastTrack.repo <<\EOF
# CentOS-Linux-FastTrack.repo
#
# The mirrorlist system uses the connecting IP address of the client and the
# update status of each mirror to pick current mirrors that are geographically
# close to the client.  You should use this for CentOS updates unless you are
# manually picking other mirrors.
#
# If the mirrorlist does not work for you, you can try the commented out
# baseurl line instead.

[fasttrack]
name=CentOS Linux $releasever - FastTrack
baseurl=http://mirrors.aliyun.com/centos-vault/8.5.2111/fasttrack/$basearch/os/
# mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=fasttrack&infra=$infra
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

EOF
    cat >$Dir_YumRepos/CentOS-Linux-HighAvailability.repo <<\EOF
# CentOS-Linux-HighAvailability.repo
#
# The mirrorlist system uses the connecting IP address of the client and the
# update status of each mirror to pick current mirrors that are geographically
# close to the client.  You should use this for CentOS updates unless you are
# manually picking other mirrors.
#
# If the mirrorlist does not work for you, you can try the commented out
# baseurl line instead.

[ha]
name=CentOS Linux $releasever - HighAvailability
baseurl=http://mirrors.aliyun.com/centos-vault/8.5.2111/HighAvailability/$basearch/os/
# mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=HighAvailability&infra=$infra
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

EOF

    cat >$Dir_YumRepos/CentOS-Linux-Media.repo <<\EOF
# CentOS-Linux-Media.repo
#
# You can use this repo to install items directly off the installation media.
# Verify your mount point matches one of the below file:// paths.

[media-baseos]
name=CentOS Linux $releasever - Media - BaseOS
baseurl=file:///media/CentOS/BaseOS
        file:///media/cdrom/BaseOS
        file:///media/cdrecorder/BaseOS
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

[media-appstream]
name=CentOS Linux $releasever - Media - AppStream
baseurl=file:///media/CentOS/AppStream
        file:///media/cdrom/AppStream
        file:///media/cdrecorder/AppStream
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

EOF

    cat >$Dir_YumRepos/CentOS-Linux-Sources.repo <<\EOF
[baseos-source]
name=CentOS Linux $releasever - BaseOS - Source
baseurl=http://vault.centos.org/$contentdir/$releasever/BaseOS/Source/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

[appstream-source]
name=CentOS Linux $releasever - AppStream - Source
baseurl=http://vault.centos.org/$contentdir/$releasever/AppStream/Source/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

[powertools-source]
name=CentOS Linux $releasever - PowerTools - Source
baseurl=http://vault.centos.org/$contentdir/$releasever/PowerTools/Source/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

[extras-source]
name=CentOS Linux $releasever - Extras - Source
baseurl=http://vault.centos.org/$contentdir/$releasever/extras/Source/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

[plus-source]
name=CentOS Linux $releasever - Plus - Source
baseurl=http://vault.centos.org/$contentdir/$releasever/centosplus/Source/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

EOF
    cat >$Dir_YumRepos/CentOS-Linux-ContinuousRelease.repo <<\EOF
# CentOS-Linux-ContinuousRelease.repo
#
# The mirrorlist system uses the connecting IP address of the client and the
# update status of each mirror to pick current mirrors that are geographically
# close to the client.  You should use this for CentOS updates unless you are
# manually picking other mirrors.
#
# If the mirrorlist does not work for you, you can try the commented out
# baseurl line instead.
#
# The Continuous Release (CR) repository contains packages for the next minor
# release of CentOS Linux.  This repository only has content in the time period
# between an upstream release and the official CentOS Linux release.  These
# packages have not been fully tested yet and should be considered beta
# quality.  They are made available for people willing to test and provide
# feedback for the next release.

[cr]
name=CentOS Linux $releasever - ContinuousRelease
baseurl=http://mirrors.aliyun.com/centos-vault/8.5.2111/cr/$basearch/os/
# mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=cr&infra=$infra
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF

    cat >$Dir_YumRepos/CentOS-Linux-Debuginfo.repo <<\EOF
# CentOS-Linux-Debuginfo.repo
#
# All debug packages are merged into a single repo, split by basearch, and are
# not signed.

[debuginfo]
name=CentOS Linux $releasever - Debuginfo
baseurl=http://debuginfo.centos.org/$releasever/$basearch/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF

    cat >$Dir_YumRepos/CentOS-Linux-Devel.repo <<\EOF
# CentOS-Linux-Devel.repo
#
# The mirrorlist system uses the connecting IP address of the client and the
# update status of each mirror to pick current mirrors that are geographically
# close to the client.  You should use this for CentOS updates unless you are
# manually picking other mirrors.
#
# If the mirrorlist does not work for you, you can try the commented out
# baseurl line instead.

[devel]
name=CentOS Linux $releasever - Devel WARNING! FOR BUILDROOT USE ONLY!
baseurl=http://mirrors.aliyun.com/centos-vault/8.5.2111/Devel/$basearch/os/
# mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=Devel&infra=$infra
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

EOF
}

CentOS_8_EPEL() {
    cat >$Dir_YumRepos/epel.repo <<\EOF
[epel]
name=Extra Packages for Enterprise Linux $releasever - $basearch
baseurl=http://mirrors.aliyun.com/epel/8/Everything/$basearch
# metalink=https://mirrors.fedoraproject.org/metalink?repo=epel-$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=1
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8

[epel-debuginfo]
name=Extra Packages for Enterprise Linux $releasever - $basearch - Debug
baseurl=http://mirrors.aliyun.com/epel/8/Everything/$basearch/debug
# metalink=https://mirrors.fedoraproject.org/metalink?repo=epel-debug-$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8
gpgcheck=1

[epel-source]
name=Extra Packages for Enterprise Linux $releasever - $basearch - Source
baseurl=http://mirrors.aliyun.com/epel/8/Everything/SRPMS
# metalink=https://mirrors.fedoraproject.org/metalink?repo=epel-source-$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8
gpgcheck=1
EOF
    cat >$Dir_YumRepos/epel-modular.repo <<\EOF
[epel-modular]
name=Extra Packages for Enterprise Linux Modular $releasever - $basearch
baseurl=http://mirrors.aliyun.com/epel/8/Modular/$basearch
# metalink=https://mirrors.fedoraproject.org/metalink?repo=epel-modular-$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=1
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8

[epel-modular-debuginfo]
name=Extra Packages for Enterprise Linux Modular $releasever - $basearch - Debug
baseurl=http://mirrors.aliyun.com/epel/8/Modular/$basearch/debug
# metalink=https://mirrors.fedoraproject.org/metalink?repo=epel-modular-debug-$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8
gpgcheck=1

[epel-modular-source]
name=Extra Packages for Enterprise Linux Modular $releasever - $basearch - Source
baseurl=http://mirrors.aliyun.com/epel/8/Modular/SRPMS
# metalink=https://mirrors.fedoraproject.org/metalink?repo=epel-modular-source-$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8
gpgcheck=1
EOF
    cat >$Dir_YumRepos/epel-playground.repo <<\EOF
[epel-playground]
name=Extra Packages for Enterprise Linux $releasever - Playground - $basearch
baseurl=http://mirrors.aliyun.com/epel/playground/$releasever/Everything/$basearch/os
# metalink=https://mirrors.fedoraproject.org/metalink?repo=playground-epel$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8

[epel-playground-debuginfo]
name=Extra Packages for Enterprise Linux $releasever - Playground - $basearch - Debug
baseurl=http://mirrors.aliyun.com/epel/playground/$releasever/Everything/$basearch/debug
# metalink=https://mirrors.fedoraproject.org/metalink?repo=playground-debug-epel$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8
gpgcheck=1

[epel-playground-source]
name=Extra Packages for Enterprise Linux $releasever - Playground - $basearch - Source
baseurl=http://mirrors.aliyun.com/epel/playground/$releasever/Everything/source/tree/
# metalink=https://mirrors.fedoraproject.org/metalink?repo=playground-source-epel$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8
gpgcheck=1
EOF
    cat >$Dir_YumRepos/epel-testing.repo <<\EOF
[epel-testing]
name=Extra Packages for Enterprise Linux $releasever - Testing - $basearch
baseurl=http://mirrors.aliyun.com/epel/testing/$releasever/Everything/$basearch
# metalink=https://mirrors.fedoraproject.org/metalink?repo=testing-epel$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8

[epel-testing-debuginfo]
name=Extra Packages for Enterprise Linux $releasever - Testing - $basearch - Debug
baseurl=http://mirrors.aliyun.com/epel/testing/$releasever/Everything/$basearch/debug
# metalink=https://mirrors.fedoraproject.org/metalink?repo=testing-debug-epel$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8
gpgcheck=1

[epel-testing-source]
name=Extra Packages for Enterprise Linux $releasever - Testing - $basearch - Source
baseurl=http://mirrors.aliyun.com/epel/testing/$releasever/Everything/SRPMS
# metalink=https://mirrors.fedoraproject.org/metalink?repo=testing-source-epel$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8
gpgcheck=1
EOF
    cat >$Dir_YumRepos/epel-testing-modular.repo <<\EOF
[epel-testing-modular]
name=Extra Packages for Enterprise Linux Modular $releasever - Testing - $basearch
baseurl=http://mirrors.aliyun.com/epel/testing/$releasever/Modular/$basearch
# metalink=https://mirrors.fedoraproject.org/metalink?repo=testing-modular-epel$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8

[epel-testing-modular-debuginfo]
name=Extra Packages for Enterprise Linux Modular $releasever - Testing - $basearch - Debug
baseurl=http://mirrors.aliyun.com/epel/testing/$releasever/Modular/$basearch/debug
# metalink=https://mirrors.fedoraproject.org/metalink?repo=testing-modular-debug-epel$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8
gpgcheck=1

[epel-testing-modular-source]
name=Extra Packages for Enterprise Linux Modular $releasever - Testing - $basearch - Source
baseurl=http://mirrors.aliyun.com/epel/testing/$releasever/Modular/SRPMS
# metalink=https://mirrors.fedoraproject.org/metalink?repo=testing-modular-source-epel$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8
gpgcheck=1
EOF

}

CentOS_7() {
    ## 生成 CentOS 官方 repo 源文件
    cat >$Dir_YumRepos/CentOS-Base.repo <<\EOF
# CentOS-Base.repo
#
# The mirror system uses the connecting IP address of the client and the
# update status of each mirror to pick mirrors that are updated to and
# geographically close to the client.  You should use this for CentOS updates
# unless you are manually picking other mirrors.
#
# If the mirrorlist= does not work for you, as a fall back you can try the 
# remarked out baseurl= line instead.
#
#

[base]
name=CentOS-$releasever - Base
# mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=os&infra=$infra
baseurl=http://mirrors.aliyun.com/centos/$releasever/os/$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7

#released updates 
[updates]
name=CentOS-$releasever - Updates
# mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=updates&infra=$infra
baseurl=http://mirrors.aliyun.com/centos/$releasever/updates/$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7

#additional packages that may be useful
[extras]
name=CentOS-$releasever - Extras
# mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=extras&infra=$infra
baseurl=http://mirrors.aliyun.com/centos/$releasever/extras/$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7

#additional packages that extend functionality of existing packages
[centosplus]
name=CentOS-$releasever - Plus
# mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=centosplus&infra=$infra
baseurl=http://mirrors.aliyun.com/centos/$releasever/centosplus/$basearch/
gpgcheck=1
enabled=0
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7
EOF

    cat >$Dir_YumRepos/CentOS-CR.repo <<\EOF
# CentOS-CR.repo
#
# The Continuous Release ( CR )  repository contains rpms that are due in the next
# release for a specific CentOS Version ( eg. next release in CentOS-7 ); these rpms
# are far less tested, with no integration checking or update path testing having
# taken place. They are still built from the upstream sources, but might not map 
# to an exact upstream distro release.
#
# These packages are made available soon after they are built, for people willing 
# to test their environments, provide feedback on content for the next release, and
# for people looking for early-access to next release content.
#
# The CR repo is shipped in a disabled state by default; its important that users 
# understand the implications of turning this on. 
#
# NOTE: We do not use a mirrorlist for the CR repos, to ensure content is available
#       to everyone as soon as possible, and not need to wait for the external
#       mirror network to seed first. However, many local mirrors will carry CR repos
#       and if desired you can use one of these local mirrors by editing the baseurl
#       line in the repo config below.
#

[cr]
name=CentOS-$releasever - cr
baseurl=http://mirrors.aliyun.com/centos/$releasever/cr/$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/RPM-GPG-KEY-CentOS-7
enabled=0
EOF
    cat >$Dir_YumRepos/CentOS-Debuginfo.repo <<\EOF
# CentOS-Debug.repo
#
# The mirror system uses the connecting IP address of the client and the
# update status of each mirror to pick mirrors that are updated to and
# geographically close to the client.  You should use this for CentOS updates
# unless you are manually picking other mirrors.
#

# All debug packages from all the various CentOS-7 releases
# are merged into a single repo, split by BaseArch
#
# Note: packages in the debuginfo repo are currently not signed
#

[base-debuginfo]
name=CentOS-7 - Debuginfo
baseurl=http://debuginfo.centos.org/7/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-Debug-7
enabled=0
#
EOF

    cat >$Dir_YumRepos/CentOS-Debuginfo.repo <<\EOF
# CentOS-Debug.repo
#
# The mirror system uses the connecting IP address of the client and the
# update status of each mirror to pick mirrors that are updated to and
# geographically close to the client.  You should use this for CentOS updates
# unless you are manually picking other mirrors.
#

# All debug packages from all the various CentOS-7 releases
# are merged into a single repo, split by BaseArch
#
# Note: packages in the debuginfo repo are currently not signed
#

[base-debuginfo]
name=CentOS-7 - Debuginfo
baseurl=http://debuginfo.centos.org/7/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-Debug-7
enabled=0
#
EOF
    cat >$Dir_YumRepos/CentOS-fasttrack.repo <<\EOF
[fasttrack]
name=CentOS-7 - fasttrack
# mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=fasttrack&infra=$infra
baseurl=http://mirrors.aliyun.com/centos/$releasever/fasttrack/$basearch/
gpgcheck=1
enabled=0
gpgkey=http://mirrors.aliyun.com/RPM-GPG-KEY-CentOS-7
EOF
    cat >$Dir_YumRepos/CentOS-Media.repo <<\EOF
# CentOS-Media.repo
#
#  This repo can be used with mounted DVD media, verify the mount point for
#  CentOS-7.  You can use this repo and yum to install items directly off the
#  DVD ISO that we release.
#
# To use this repo, put in your DVD and use it with the other repos too:
#  yum --enablerepo=c7-media [command]
#  
# or for ONLY the media repo, do this:
#
#  yum --disablerepo=\* --enablerepo=c7-media [command]

[c7-media]
name=CentOS-$releasever - Media
baseurl=file:///media/CentOS/
        file:///media/cdrom/
        file:///media/cdrecorder/
gpgcheck=1
enabled=0
gpgkey=http://mirrors.aliyun.com/RPM-GPG-KEY-CentOS-7
EOF
    cat >$Dir_YumRepos/CentOS-Sources.repo <<\EOF
# CentOS-Sources.repo
#
# The mirror system uses the connecting IP address of the client and the
# update status of each mirror to pick mirrors that are updated to and
# geographically close to the client.  You should use this for CentOS updates
# unless you are manually picking other mirrors.
#
# If the mirrorlist= does not work for you, as a fall back you can try the 
# remarked out baseurl= line instead.
#
#

[base-source]
name=CentOS-$releasever - Base Sources
baseurl=http://vault.centos.org/centos/$releasever/os/Source/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#released updates 
[updates-source]
name=CentOS-$releasever - Updates Sources
baseurl=http://vault.centos.org/centos/$releasever/updates/Source/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#additional packages that may be useful
[extras-source]
name=CentOS-$releasever - Extras Sources
baseurl=http://vault.centos.org/centos/$releasever/extras/Source/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

#additional packages that extend functionality of existing packages
[centosplus-source]
name=CentOS-$releasever - Plus Sources
baseurl=http://vault.centos.org/centos/$releasever/centosplus/Source/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
EOF
}

CentOS_7_EPEL() {
    cat >$Dir_YumRepos/epel.repo <<\EOF
[epel]
name=Extra Packages for Enterprise Linux 7 - $basearch
baseurl=http://mirrors.aliyun.com/epel/7/$basearch
failovermethod=priority
enabled=1
gpgcheck=0
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-7 
 
[epel-source]
name=Extra Packages for Enterprise Linux 7 - $basearch - Source
baseurl=http://mirrors.aliyun.com/epel/7/SRPMS
failovermethod=priority
enabled=0
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-7
gpgcheck=0

EOF
}

CentOS_8stream() {
    ## 生成 CentOS Stream 官方 repo 源文件
    cat >$Dir_YumRepos/CentOS-Stream-AppStream.repo <<\EOF
[appstream]
name=CentOS Stream $releasever - AppStream
#mirrorlist=http://mirrorlist.centos.org/?release=$stream&arch=$basearch&repo=AppStream&infra=$infra
baseurl=http://mirrors.aliyun.com/$contentdir/$stream/AppStream/$basearch/os/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
exclude=cloud-init
EOF

    cat >$Dir_YumRepos/CentOS-Stream-BaseOS.repo <<\EOF
[baseos]
name=CentOS Stream $releasever - BaseOS
#mirrorlist=http://mirrorlist.centos.org/?release=$stream&arch=$basearch&repo=BaseOS&infra=$infra
baseurl=http://mirrors.aliyun.com/$contentdir/$stream/BaseOS/$basearch/os/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF

    cat >$Dir_YumRepos/CentOS-Stream-Debuginfo.repo <<\EOF

[debuginfo]
name=CentOS Stream $releasever - Debuginfo
baseurl=http://debuginfo.centos.org/$stream/$basearch/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF

    cat >$Dir_YumRepos/CentOS-Stream-Extras-common.repo <<\EOF

[extras-common]
name=CentOS Stream $releasever - Extras common packages
#mirrorlist=http://mirrorlist.centos.org/?release=$stream&arch=$basearch&repo=extras-extras-common
baseurl=http://mirrors.aliyun.com/$contentdir/$stream/extras/$basearch/extras-common/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-SIG-Extras
EOF

    cat >$Dir_YumRepos/CentOS-Stream-Extras.repo <<\EOF

[extras]
name=CentOS Stream $releasever - Extras
#mirrorlist=http://mirrorlist.centos.org/?release=$stream&arch=$basearch&repo=extras&infra=$infra
baseurl=http://mirrors.aliyun.com/$contentdir/$stream/extras/$basearch/os/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF

    cat >$Dir_YumRepos/CentOS-Stream-HighAvailability.repo <<\EOF
[ha]
name=CentOS Stream $releasever - HighAvailability
#mirrorlist=http://mirrorlist.centos.org/?release=$stream&arch=$basearch&repo=HighAvailability&infra=$infra
baseurl=http://mirrors.aliyun.com/$contentdir/$stream/HighAvailability/$basearch/os/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF

    cat >$Dir_YumRepos/CentOS-Stream-Media.repo <<\EOF

[media-baseos]
name=CentOS Stream $releasever - Media - BaseOS
baseurl=file:///media/CentOS/BaseOS
        file:///media/cdrom/BaseOS
        file:///media/cdrecorder/BaseOS
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

[media-appstream]
name=CentOS Stream $releasever - Media - AppStream
baseurl=file:///media/CentOS/AppStream
        file:///media/cdrom/AppStream
        file:///media/cdrecorder/AppStream
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF

    cat >$Dir_YumRepos/CentOS-Stream-NFV.repo <<\EOF

[nfv]
name=CentOS Stream $releasever - NFV
#mirrorlist=http://mirrorlist.centos.org/?release=$stream&arch=$basearch&repo=NFV&infra=$infra
baseurl=http://mirrors.aliyun.com/$contentdir/$stream/NFV/$basearch/os/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF

    cat >$Dir_YumRepos/CentOS-Stream-PowerTools.repo <<\EOF

[powertools]
name=CentOS Stream $releasever - PowerTools
#mirrorlist=http://mirrorlist.centos.org/?release=$stream&arch=$basearch&repo=PowerTools&infra=$infra
baseurl=http://mirrors.aliyun.com/$contentdir/$stream/PowerTools/$basearch/os/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF

    cat >$Dir_YumRepos/CentOS-Stream-RealTime.repo <<\EOF

[rt]
name=CentOS Stream $releasever - RealTime
#mirrorlist=http://mirrorlist.centos.org/?release=$stream&arch=$basearch&repo=RT&infra=$infra
baseurl=http://mirrors.aliyun.com/$contentdir/$stream/RT/$basearch/os/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF

    cat >$Dir_YumRepos/CentOS-Stream-ResilientStorage.repo <<\EOF

[resilientstorage]
name=CentOS Stream $releasever - ResilientStorage
#mirrorlist=http://mirrorlist.centos.org/?release=$stream&arch=$basearch&repo=ResilientStorage&infra=$infra
baseurl=http://mirrors.aliyun.com/$contentdir/$stream/ResilientStorage/$basearch/os/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

EOF
    cat >$Dir_YumRepos/CentOS-Stream-Sources.repo <<\EOF

[baseos-source]
name=CentOS Stream $releasever - BaseOS - Source
baseurl=http://mirrors.aliyun.com/$contentdir/$stream/BaseOS/Source/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

[appstream-source]
name=CentOS Stream $releasever - AppStream - Source
baseurl=http://mirrors.aliyun.com/$contentdir/$stream/AppStream/Source/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

[powertools-source]
name=CentOS Stream $releasever - PowerTools - Source
baseurl=http://mirrors.aliyun.com/$contentdir/$stream/PowerTools/Source/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

[extras-source]
name=CentOS Stream $releasever - Extras - Source
baseurl=http://mirrors.aliyun.com/$contentdir/$stream/extras/Source/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

[ha-source]
name=CentOS Stream $releasever - HighAvailability - Source
baseurl=http://mirrors.aliyun.com/$contentdir/$stream/HighAvailability/Source/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

[rt-source]
name=CentOS Stream $releasever - RT - Source
baseurl=http://mirrors.aliyun.com/$contentdir/$stream/RT/Source/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

[resilientstorage-source]
name=CentOS Stream $releasever - ResilientStorage - Source
baseurl=http://mirrors.aliyun.com/$contentdir/$stream/ResilientStorage/Source/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

[nfv-source]
name=CentOS Stream $releasever - NFV - Source
baseurl=http://mirrors.aliyun.com/$contentdir/$stream/NFV/Source/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF

}

CentOS_8stream_EPEL() {
    cat >$Dir_YumRepos/epel.repo <<\EOF
[epel]
name=Extra Packages for Enterprise Linux $releasever - $basearch
baseurl=http://mirrors.aliyun.com/epel/8/Everything/$basearch
# metalink=https://mirrors.fedoraproject.org/metalink?repo=epel-$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=1
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8

[epel-debuginfo]
name=Extra Packages for Enterprise Linux $releasever - $basearch - Debug
baseurl=http://mirrors.aliyun.com/epel/8/Everything/$basearch/debug
# metalink=https://mirrors.fedoraproject.org/metalink?repo=epel-debug-$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8
gpgcheck=1

[epel-source]
name=Extra Packages for Enterprise Linux $releasever - $basearch - Source
baseurl=http://mirrors.aliyun.com/epel/8/Everything/SRPMS
# metalink=https://mirrors.fedoraproject.org/metalink?repo=epel-source-$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8
gpgcheck=1
EOF
    cat >$Dir_YumRepos/epel-modular.repo <<\EOF
[epel-modular]
name=Extra Packages for Enterprise Linux Modular $releasever - $basearch
baseurl=http://mirrors.aliyun.com/epel/8/Modular/$basearch
# metalink=https://mirrors.fedoraproject.org/metalink?repo=epel-modular-$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=1
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8

[epel-modular-debuginfo]
name=Extra Packages for Enterprise Linux Modular $releasever - $basearch - Debug
baseurl=http://mirrors.aliyun.com/epel/8/Modular/$basearch/debug
# metalink=https://mirrors.fedoraproject.org/metalink?repo=epel-modular-debug-$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8
gpgcheck=1

[epel-modular-source]
name=Extra Packages for Enterprise Linux Modular $releasever - $basearch - Source
baseurl=http://mirrors.aliyun.com/epel/8/Modular/SRPMS
# metalink=https://mirrors.fedoraproject.org/metalink?repo=epel-modular-source-$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8
gpgcheck=1
EOF
    cat >$Dir_YumRepos/epel-playground.repo <<\EOF
[epel-playground]
name=Extra Packages for Enterprise Linux $releasever - Playground - $basearch
baseurl=http://mirrors.aliyun.com/epel/playground/$releasever/Everything/$basearch/os
# metalink=https://mirrors.fedoraproject.org/metalink?repo=playground-epel$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8

[epel-playground-debuginfo]
name=Extra Packages for Enterprise Linux $releasever - Playground - $basearch - Debug
baseurl=http://mirrors.aliyun.com/epel/playground/$releasever/Everything/$basearch/debug
# metalink=https://mirrors.fedoraproject.org/metalink?repo=playground-debug-epel$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8
gpgcheck=1

[epel-playground-source]
name=Extra Packages for Enterprise Linux $releasever - Playground - $basearch - Source
baseurl=http://mirrors.aliyun.com/epel/playground/$releasever/Everything/source/tree/
# metalink=https://mirrors.fedoraproject.org/metalink?repo=playground-source-epel$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8
gpgcheck=1
EOF
    cat >$Dir_YumRepos/epel-testing.repo <<\EOF
[epel-testing]
name=Extra Packages for Enterprise Linux $releasever - Testing - $basearch
baseurl=http://mirrors.aliyun.com/epel/testing/$releasever/Everything/$basearch
# metalink=https://mirrors.fedoraproject.org/metalink?repo=testing-epel$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8

[epel-testing-debuginfo]
name=Extra Packages for Enterprise Linux $releasever - Testing - $basearch - Debug
baseurl=http://mirrors.aliyun.com/epel/testing/$releasever/Everything/$basearch/debug
# metalink=https://mirrors.fedoraproject.org/metalink?repo=testing-debug-epel$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8
gpgcheck=1

[epel-testing-source]
name=Extra Packages for Enterprise Linux $releasever - Testing - $basearch - Source
baseurl=http://mirrors.aliyun.com/epel/testing/$releasever/Everything/SRPMS
# metalink=https://mirrors.fedoraproject.org/metalink?repo=testing-source-epel$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8
gpgcheck=1
EOF
    cat >$Dir_YumRepos/epel-testing-modular.repo <<\EOF
[epel-testing-modular]
name=Extra Packages for Enterprise Linux Modular $releasever - Testing - $basearch
baseurl=http://mirrors.aliyun.com/epel/testing/$releasever/Modular/$basearch
# metalink=https://mirrors.fedoraproject.org/metalink?repo=testing-modular-epel$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8

[epel-testing-modular-debuginfo]
name=Extra Packages for Enterprise Linux Modular $releasever - Testing - $basearch - Debug
baseurl=http://mirrors.aliyun.com/epel/testing/$releasever/Modular/$basearch/debug
# metalink=https://mirrors.fedoraproject.org/metalink?repo=testing-modular-debug-epel$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8
gpgcheck=1

[epel-testing-modular-source]
name=Extra Packages for Enterprise Linux Modular $releasever - Testing - $basearch - Source
baseurl=http://mirrors.aliyun.com/epel/testing/$releasever/Modular/SRPMS
# metalink=https://mirrors.fedoraproject.org/metalink?repo=testing-modular-source-epel$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-8
gpgcheck=1
EOF

}

CentOS_9stream() {
    ## 生成 CentOS Stream 官方 repo 源文件
    cat >$Dir_YumRepos/centos.repo <<\EOF
[baseos]
name=CentOS Stream $releasever - BaseOS
baseurl=http://mirrors.aliyun.com/centos-stream/$stream/BaseOS/$basearch/os/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
countme=1
enabled=1

[baseos-debug]
name=CentOS Stream $releasever - BaseOS - Debug
baseurl=http://mirrors.aliyun.com/centos-stream/$stream/BaseOS/$basearch/debug/tree/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
enabled=0

[baseos-source]
name=CentOS Stream $releasever - BaseOS - Source
baseurl=http://mirrors.aliyun.com/centos-stream/$stream/BaseOS/source/tree/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
enabled=0

[appstream]
name=CentOS Stream $releasever - AppStream
baseurl=http://mirrors.aliyun.com/centos-stream/$stream/AppStream/$basearch/os/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
countme=1
enabled=1

[appstream-debug]
name=CentOS Stream $releasever - AppStream - Debug
baseurl=http://mirrors.aliyun.com/centos-stream/$stream/AppStream/$basearch/debug/tree/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
enabled=0

[appstream-source]
name=CentOS Stream $releasever - AppStream - Source
baseurl=http://mirrors.aliyun.com/centos-stream/$stream/AppStream/$basearch/debug/tree/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
enabled=0

[crb]
name=CentOS Stream $releasever - CRB
baseurl=http://mirrors.aliyun.com/centos-stream/$stream/CRB/$basearch/os/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
countme=1
enabled=0

[crb-debug]
name=CentOS Stream $releasever - CRB - Debug
baseurl=http://mirrors.aliyun.com/centos-stream/$stream/CRB/$basearch/debug/tree/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
enabled=0

[crb-source]
name=CentOS Stream $releasever - CRB - Source
baseurl=http://mirrors.aliyun.com/centos-stream/$stream/CRB/source/tree/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
enabled=0

EOF
    cat >$Dir_YumRepos/centos-addons.repo <<\EOF
[highavailability]
name=CentOS Stream $releasever - HighAvailability
baseurl=http://mirrors.aliyun.com/centos-stream/$stream/HighAvailability/$basearch/os/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
countme=1
enabled=0

[highavailability-debug]
name=CentOS Stream $releasever - HighAvailability - Debug
baseurl=http://mirrors.aliyun.com/centos-stream/$stream/HighAvailability/$basearch/debug/tree/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
enabled=0

[highavailability-source]
name=CentOS Stream $releasever - HighAvailability - Source
baseurl=http://mirrors.aliyun.com/centos-stream/$stream/HighAvailability/source/tree/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
enabled=0

[nfv]
name=CentOS Stream $releasever - NFV
baseurl=http://mirrors.aliyun.com/centos-stream/$stream/NFV/$basearch/os/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
countme=1
enabled=0

[nfv-debug]
name=CentOS Stream $releasever - NFV - Debug
baseurl=http://mirrors.aliyun.com/centos-stream/$stream/NFV/$basearch/debug/tree/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
enabled=0

[nfv-source]
name=CentOS Stream $releasever - NFV - Source
baseurl=http://mirrors.aliyun.com/centos-stream/$stream/NFV/source/tree/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
enabled=0

[rt]
name=CentOS Stream $releasever - RT
baseurl=http://mirrors.aliyun.com/centos-stream/$stream/RT/$basearch/os/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
countme=1
enabled=0

[rt-debug]
name=CentOS Stream $releasever - RT - Debug
baseurl=http://mirrors.aliyun.com/centos-stream/$stream/RT/$basearch/debug/tree/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
enabled=0

[rt-source]
name=CentOS Stream $releasever - RT - Source
baseurl=http://mirrors.aliyun.com/centos-stream/$stream/RT/source/tree/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
enabled=0

[resilientstorage]
name=CentOS Stream $releasever - ResilientStorage
baseurl=http://mirrors.aliyun.com/centos-stream/$stream/ResilientStorage/$basearch/os/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
countme=1
enabled=0

[resilientstorage-debug]
name=CentOS Stream $releasever - ResilientStorage - Debug
baseurl=http://mirrors.aliyun.com/centos-stream/$stream/ResilientStorage/$basearch/debug/tree/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
enabled=0

[resilientstorage-source]
name=CentOS Stream $releasever - ResilientStorage - Source
baseurl=http://mirrors.aliyun.com/centos-stream/$stream/ResilientStorage/source/tree/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
enabled=0

[extras-common]
name=CentOS Stream $releasever - Extras packages
baseurl=http://mirrors.aliyun.com/centos-stream/SIGs/$stream/extras/$basearch/extras-common/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-SIG-Extras-SHA512
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
countme=1
enabled=1

[extras-common-source]
name=CentOS Stream $releasever - Extras packages - Source
baseurl=http://mirrors.aliyun.com/centos-stream/SIGs/$stream/extras/source/extras-common/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-SIG-Extras-SHA512
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
enabled=0
EOF

}

CentOS_9stream_EPEL() {
    cat >$Dir_YumRepos/epel.repo <<\EOF
[epel]
name=Extra Packages for Enterprise Linux $releasever - $basearch
# It is much more secure to use the metalink, but if you wish to use a local mirror
# place its address here.
baseurl=http://mirrors.aliyun.com/epel/$releasever/Everything/$basearch/
# metalink=https://mirrors.fedoraproject.org/metalink?repo=epel-$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=1
gpgcheck=1
countme=1
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-$releasever

[epel-debuginfo]
name=Extra Packages for Enterprise Linux $releasever - $basearch - Debug
# It is much more secure to use the metalink, but if you wish to use a local mirror
# place its address here.
baseurl=http://mirrors.aliyun.com/epel/$releasever/Everything/$basearch/debug/
# metalink=https://mirrors.fedoraproject.org/metalink?repo=epel-debug-$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-$releasever
gpgcheck=1

[epel-source]
name=Extra Packages for Enterprise Linux $releasever - $basearch - Source
# It is much more secure to use the metalink, but if you wish to use a local mirror
# place its address here.
baseurl=http://mirrors.aliyun.com/epel/$releasever/Everything/source/tree/
# metalink=https://mirrors.fedoraproject.org/metalink?repo=epel-source-$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-$releasever
gpgcheck=1
EOF
    cat >$Dir_YumRepos/epel-testing.repo <<\EOF
[epel-testing]
name=Extra Packages for Enterprise Linux $releasever - Testing - $basearch
# It is much more secure to use the metalink, but if you wish to use a local mirror
# place its address here.
baseurl=http://mirrors.aliyun.com/epel/testing/$releasever/Everything/$basearch/
# metalink=https://mirrors.fedoraproject.org/metalink?repo=testing-epel$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgcheck=1
countme=1
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-$releasever

[epel-testing-debuginfo]
name=Extra Packages for Enterprise Linux $releasever - Testing - $basearch - Debug
# It is much more secure to use the metalink, but if you wish to use a local mirror
# place its address here.
baseurl=http://mirrors.aliyun.com/epel/testing/$releasever/Everything/$basearch/debug/
# metalink=https://mirrors.fedoraproject.org/metalink?repo=testing-debug-epel$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-$releasever
gpgcheck=1

[epel-testing-source]
name=Extra Packages for Enterprise Linux $releasever - Testing - $basearch - Source
# It is much more secure to use the metalink, but if you wish to use a local mirror
# place its address here.
baseurl=http://mirrors.aliyun.com/epel/testing/$releasever/Everything/source/tree/
# metalink=https://mirrors.fedoraproject.org/metalink?repo=testing-source-epel$releasever&arch=$basearch&infra=$infra&content=$contentdir
enabled=0
gpgkey=http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-$releasever
gpgcheck=1
EOF

}
Debian_10() {
    cat >$File_DebianSourceList <<\EOF
    # 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb http://mirrors.aliyun.com/debian/ buster main contrib non-free
# deb-src http://mirrors.aliyun.com/debian/ buster main contrib non-free

deb http://mirrors.aliyun.com/debian/ buster-updates main contrib non-free
# deb-src http://mirrors.aliyun.com/debian/ buster-updates main contrib non-free

deb http://mirrors.aliyun.com/debian/ buster-backports main contrib non-free
# deb-src http://mirrors.aliyun.com/debian/ buster-backports main contrib non-free

 deb http://mirrors.aliyun.com/debian-security buster/updates main contrib non-free
# # deb-src http://mirrors.aliyun.com/debian-security buster/updates main contrib non-free

# deb http://security.debian.org/debian-security buster/updates main contrib non-free
# deb-src https://security.debian.org/debian-security buster/updates main contrib non-free
EOF

}

Debian_11() {
    cat >$File_DebianSourceList <<\EOF
    # 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb http://mirrors.aliyun.com/debian/ bullseye main contrib non-free
# deb-src http://mirrors.aliyun.com/debian/ bullseye main contrib non-free

deb http://mirrors.aliyun.com/debian/ bullseye-updates main contrib non-free
# deb-src http://mirrors.aliyun.com/debian/ bullseye-updates main contrib non-free

deb http://mirrors.aliyun.com/debian/ bullseye-backports main contrib non-free
# deb-src http://mirrors.aliyun.com/debian/ bullseye-backports main contrib non-free

 deb http://mirrors.aliyun.com/debian-security bullseye-security main contrib non-free
# # deb-src http://mirrors.aliyun.com/debian-security bullseye-security main contrib non-free

# deb http://security.debian.org/debian-security bullseye-security main contrib non-free
# deb-src http://security.debian.org/debian-security bullseye-security main contrib non-free
EOF
}

Debian_12() {
    cat >$File_DebianSourceList <<\EOF
    # 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb http://mirrors.aliyun.com/debian/ bookworm main contrib non-free non-free-firmware
##deb-src http://mirrors.aliyun.com/debian/ bookworm main contrib non-free non-free-firmware

deb http://mirrors.aliyun.com/debian/ bookworm-updates main contrib non-free non-free-firmware
##deb-src http://mirrors.aliyun.com/debian/ bookworm-updates main contrib non-free non-free-firmware

deb http://mirrors.aliyun.com/debian/ bookworm-backports main contrib non-free non-free-firmware
##deb-src http://mirrors.aliyun.com/debian/ bookworm-backports main contrib non-free non-free-firmware

deb http://mirrors.aliyun.com/debian-security bookworm-security main contrib non-free non-free-firmware
##deb-src http://mirrors.aliyun.com/debian-security bookworm-security main contrib non-free non-free-firmware
EOF
}

Ubuntu_20() {
    cat >$File_DebianSourceList <<\EOF
    # 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
# deb-src http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
# deb-src http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
# deb-src http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse

 deb http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
# # deb-src http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse

# deb http://security.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse
# deb-src http://security.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse
EOF
}

Ubuntu_22() {
    cat >$File_DebianSourceList <<\EOF
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb http://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse
# deb-src http://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse
# deb-src http://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse
# deb-src http://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse

 deb http://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse
# # deb-src http://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse

# deb http://security.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse
# deb-src http://security.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse
EOF
}

GetSysInfo
Get_Pack_Manager
backup_source
IDC_CHECK
Check_mirrors
Re_Mirrors
end=$(date +%s)
runtime=$((end - start))
echo "脚本执行时间为：$runtime 秒"
