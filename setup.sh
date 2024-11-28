#!/bin/bash
# iptables-firewall by Sean Evans
# https://github.com/sre3219/iptables-firewall

if [[ "$1" =~ ^(\-|\-\-)[hHhelpHELP] ]]; then
  # TODO: getopts
  echo "设置 iptables-firewall 安装所有依赖项 复制到 /etc/iptables-firewall"
  echo "并允许简单和高级安装模式"
  echo "用法：sudo ./setup.sh"
  exit 0
elif [[ $(whoami) != "root" ]]; then
  echo "此脚本需要 root 权限 您必须使用 'sudo $0' 运行它"
  exit 1
fi

DEBIAN_DEPENDS="iptables iptables-persistent host"
RHEL_DEPENDS="iptables bind-utils"

write_msg() {
  MODE="$1"
  MSG="$2"

  case $MODE in
    0)echo "[INFO] $MSG"
      echo "$(date +%s) i[INFO] $MSG" >> /tmp/iptables-firewall-installation.log
      ;;
    1)echo "[WARN] $MSG"
      echo "$(date +%s) [WARN] $MSG" >> /tmp/iptables-firewall-installation.log
      ;;
    2)echo "[ERROR] $MSG"
      echo "$(date +%s) [ERROR] $MSG" >> /tmp/iptables-firewall-installation.log
      ;;
    *)echo "[??] $MSG"
      echo "$(date +%s) [??] $MSG" >> /tmp/iptables-firewall-installation.log
      ;;
  esac
}

install_depends() {
  if [[ $(which yum > /dev/null 2>&1; echo $?) -eq 0 ]]; then
    echo "检测到基于 Red Hat 的发行版 使用 yum 更新和安装（这可能需要几分钟）..."
    yum update > /dev/null 2>&1
    yum install -y $RHEL_DEPENDS > /dev/null 2>&1
    if [[ "$?" -eq 0 ]]; then
      echo "依赖项安装成功"
    else
      echo "安装依赖项时出现问题 正在退出"
      exit 1
    fi
  elif [[ $(which apt > /dev/null 2>&1; echo $?) -eq 0 ]]; then
    echo "检测到基于 Debian 的发行版 使用 apt 更新和安装（这可能需要几分钟）..."
    apt update > /dev/null 2>&1
    apt install -yq $DEBIAN_DEPENDS
    if [[ "$?" -eq 0 ]]; then
      echo "依赖项安装成功"
    else
      echo "安装依赖项时出现问题 退出"
      exit 1
    fi
  elif [[ $(which pacman > /dev/null; echo $?) -eq 0 ]]; then
    echo "抱歉 ARCH 依赖项尚未实现"
    exit 1
    echo "检测到基于 Arch 的发行版 使用 pacman 更新和安装（这可能需要几分钟）..."
    pacman -Su > /dev/null 2>&1
    pacman install -y $DEPENDS > /dev/null 2>&1
    if [[ "$?" -eq 0 ]]; then
      echo "依赖项安装成功"
    else
      echo "安装依赖项时出现问题 退出"
      exit 1
    fi
  else
    echo "无法确定包管理器"
    echo "(Are you doing something naughty, like using Gentoo? (暂不支持)."
    # TODO: 提示继续或失败?
    exit 1
  fi
}

check_depends() {
  if [[ ! -d /etc/iptables-firewall ]]; then
    echo "正在安装到 /etc/iptables-firewall ..."
    mkdir /etc/iptables-firewall > /dev/null 2>&1
    cp -rfu . /etc/iptables-firewall/ > /dev/null 2>&1
  elif [[ "$1" -eq 1 ]]; then
    echo "/etc/iptables-firewall 似乎存在."
    echo "You may:"
    echo "  [R]重新安装覆盖现有安装，保持当前配置不变"
    echo "  [O]覆盖现有安装，删除以前的配置（全新安装）"
    echo "  [C]取消此过程，不进行修改任何内容（默认）"
    read -p"[r/o/C]: " PROMPT

    case "$PROMPT" in
      "R" | "r") # 重新安装 - 保留旧配置
        cp -ru ./bin /etc/iptables-firewall/ > /dev/null 2>&1
        cp -ru * /etc/iptables-firewall/ > /dev/null 2>&1
        ;;
      "O" | "o") # 删除 - 移除所有旧文件，然后安装
        rm -rf /etc/iptables-firewall/ > /dev/null 2>&1
        mkdir /etc/iptables-firewall > /dev/null 2>&1
        cp -rfu . /etc/iptables-firewall/ > /dev/null 2>&1
        ;;
      "C" | "c") # 退出
        echo "退出."
        exit 1
        ;;
      * | ?) # Wut
        echo "选择的选项无效，退出..."
        exit 1
        ;; 
    esac
  else
    echo "备份似乎是旧版本的 iptables-firewall ..."
    mv /etc/iptables-firewall /etc/iptables-firewall.OLD > /dev/null 2>&1
    mkdir /etc/iptables-firewall > /dev/null 2>&1
    cp -rfu . /etc/iptables-firewall/ > /dev/null 2>&1
  fi
}

simple_install() {
  # 可选地提示用户输入 IP/主机名
  echo "简单安装" #
  check_depends "0"
  install_depends

  echo "iptables-firewall 和依赖项安装成功"
  read -p"是否继续将 IP 和主机名添加到配置中? [Y/n]: " PROMPT

  if [[ "$PROMPT" =~ [nN] ]]; then
    echo "Okay, 这是手动配置."
    return
  fi

  # Setup IPs - TODO: 检查有效 IP
  echo "请输入允许连接到此系统的所有 IP，以英文逗号、tab或空格分隔（非 EOL）: "
  read RIP
  for IP in `grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" <<< $RIP`; do
    echo $IP >> /etc/iptables-firewall/config/whitelist.conf
  done

  # 域名
  echo "请输入您希望解析和允许的任何主机名，以英文逗号、tab或空格分隔（非 EOL）: "
  read RHOST
  for HOST in `grep -oP "\w*\.*\w*\.\w*\.*\w*\.*\w*\.*" <<< $RHOST`; do
    echo $HOST >> /etc/iptables-firewall/config/hostname.list
  done 

  # 设置 TCP 端口
  echo "请输入所有允许的 TCP 端口（22、80、443 等）.请记住,这些端口将向全世界开放: "
  read TPORTS
  for PORT in `grep -oE "[0-9]{1,5}" <<< $TPORTS`; do
    if [[ "$PORT" -gt 0 ]] && [[ "$PORT" -lt 65536 ]]; then
      echo $PORT >> /etc/iptables-firewall/config/tcp-ports.conf
    fi
  done

  # 设置 UDP 端口
  echo "请输入所有允许的 UDP 端口.请记住,这些端口将向全世界开放: "
  read UPORTS
  for PORT in `grep -oE "[0-9]{1,5}" <<< $UPORTS`; do 
    if [[ "$PORT" -gt 0 ]] && [[ "$PORT" -lt 65536 ]]; then
      echo $PORT >> /etc/iptables-firewall/config/tcp-ports.conf 
    fi
  done

  # 启用 ICMP?
  read -p"允许来自互联网的 ICMP? [y/N]: " ICMP
  if [[ "$ICMP" =~ [yY] ]]; then
    sed -i 's/allow\_icmp\=6/allow\_icmp\=1/g' /etc/iptables-firewall/config/icmp.conf
    echo "ICMP 已设置为 ALLOW；ICMP 已启用."
  fi

  # 设置 cron 任务
  echo ""
  echo "您可以选择自动执行解析域名到 IP。脚本会将域名名解析为 IP"
  echo "每隔一段时间，并更新 iptables 规则以更新最新更改."
  echo "这意味着，如果您使用 DDNS，您的 IP 将始终位于规则集中."
  echo "这也意味着任何白名单配置更改都将自动应用于您的防火墙规则."
  echo "(注意：域名名将每 5 分钟解析一次，防火墙更新将每 8 分钟进行一次.)"
  echo ""
  read -p"是否要启用此自动脚本? [Y/n]: " PROMPT

  if [[ "$PROMPT" =~ [nN] ]]; then
    echo "好的，不会启用自动脚本。您需要自行手动运行所有脚本,"
    echo "或设置你自己的 cron 任务."
    return
  fi

  cp -f ./config/cron-file/iptables_firewall.cron /etc/cron.d/iptables_firewall
  echo "cron 任务已放置在 /etc/cron.d (iptables_firewall) 中”"

  echo "正在运行 iptables-firewall.sh ..."
  /bin/bash /etc/iptables-firewall/bin/iptables-firewall.sh
  echo ""
  echo "安装完成！尝试运行‘sudo iptables -nvL’ 来验证您的配置"
  echo ""
  echo "Done."
}

advanced_install() {
  # 要求用户自己更新所有配置，包括 cron 任务
  echo "正在执行高级安装."
  check_depends "1"
  install_depends

  echo "Advanced setup is complete."
  echo ""
  echo "Some useful information:"
  echo ""
  echo "Main folder: /etc/iptables-firewall"
  echo "Script folder: /etc/iptables-firewall/bin"
  echo "Config folder: /etc/iptables-firewall/config"
  echo ""
  echo "You should look under /etc/iptables-firewall/config to get started."
  echo "To apply your config changes, run /etc/iptables-firewall/bin/iptables-firewall.sh."
  echo "(Note: a cron script is located under /etc/iptables-firewall/config/cron-file)"
  echo ""
}

while true; do
  echo "This script will setup iptables-firewall for you."
  echo ""
  echo "您可以选择运行: "
  echo "  [S]简单设置和安装，系统将提示您进行所有配置（推荐）"
  echo "  [A]高级设置和安装（将安装基本系统，您必须手动配置/启用）"
  echo "  [Q]退出设置，不修改系统"
  echo ""
  read -p"Please choose: [s/a/Q]: " PROMPT
    if [[ "$PROMPT" =~ [Aa] ]]; then
      advanced_install
      break
    elif [[ "$PROMPT" =~ [Ss] ]]; then
      simple_install
      break
    else
      echo "No changes have been made, exiting."
      echo ""
      exit 0
    fi
done
