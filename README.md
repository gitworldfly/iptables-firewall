基于白名单的简单防火墙，使用 iptables 执行规则。  

功能：  
基于 IP 的白名单--白名单中的 IP 可以完全访问盒子上的所有端口  
基于端口的白名单 - TCP/UDP 端口可向全世界开放  
主机名解析功能--自动解析主机名背后的 IP，并将其添加到 IP 白名单中  

安装：
1.运行 "git clone https://github.com/sevsec/iptables-firewall ”   
2.使用 “cd iptables-firewall ”进入该文件夹  
3.使用 sudo 运行附带的 setup.sh 脚本："sudo ./setup.sh  
4.默认安装模式为简单安装，它会提示你输入所有必要的配置信息。  
4a. 如果坚持使用简单安装模式，请按照屏幕上的说明进行操作。  
4b. 如果决定使用高级模式，则必须自行修改位于 /etc/iptables-firewall/config 中的配置文件。  

安装脚本会自动下载并安装任何依赖项。  
如果您在第 4 步中选择了简单安装模式，那么一切都已设置完毕，可以开始使用了。  
现在，您的机器将只接受来自您指定的 IP 的连接，以及来自 ALL IPS 在您指定的协议和端口上的连接。  

注：如果选择高级安装模式，将安装必要的依赖项，并创建所有必要的目录/文件。但不会对 iptables 进行任何更改，您需要自行运行 iptables-firewall.sh。此外，还应考虑将 config/cron-file 中的 cron 文件复制到 /etc/cron.d/。  

使用 iptables 的基于白名单的简单防火墙。还可通过主机名解析 IP 地址（DDNS 等）并添加到白名单中。

