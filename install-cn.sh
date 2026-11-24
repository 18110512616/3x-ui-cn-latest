#!/usr/bin/env bash
# ============================================================
#  3x-ui 官方安装脚本「中文汉化版」包装器
#  - 默认拉取官方 3x-ui v3.11.0 的 install.sh
#  - 只把交互提示、菜单、关键流程文案替换成中文
#  - 核心逻辑（依赖安装、下载、校验、服务配置）完全不动
#  - 汉化后先用 bash -n 做语法检查，通过后才执行
#
#  用法：
#    bash install-cn.sh                 # 安装/升级官方 v3.11.0（中文提示）
#    bash install-cn.sh -v latest       # 跟随官方最新版（master 分支脚本）
#    bash install-cn.sh -v v3.11.0      # 指定版本
#    CN_ONLY=1 bash install-cn.sh       # 只生成汉化脚本，不执行（输出路径见提示）
#
#  非交互安装（云端/脚本化）时直接透传官方环境变量：
#    XUI_NONINTERACTIVE=1 XUI_PANEL_PORT=2053 XUI_DB_TYPE=sqlite bash install-cn.sh
# ============================================================

set -uo pipefail

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
plain='\033[0m'

XUI_VERSION="${XUI_VERSION:-v3.11.0}"
CN_ONLY="${CN_ONLY:-0}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -v | --version)
            XUI_VERSION="${2:-}"
            shift 2
            ;;
        -h | --help)
            sed -n '3,20p' "$0" | sed 's/^#\{1,\}\s*//'
            exit 0
            ;;
        *)
            echo -e "${yellow}未知参数：$1（可用 -v/--version 指定版本）${plain}"
            exit 1
            ;;
    esac
done

if [[ "${CN_ONLY}" != "1" && ${EUID} -ne 0 ]]; then
    echo -e "${red}错误：${plain} 请使用 root 权限运行本脚本（sudo -i 后重试）"
    exit 1
fi

if [[ "${XUI_VERSION}" == "latest" || "${XUI_VERSION}" == "master" ]]; then
    SCRIPT_URL="https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh"
    VERSION_LABEL="最新版(master)"
else
    SCRIPT_URL="https://raw.githubusercontent.com/mhsanaei/3x-ui/${XUI_VERSION}/install.sh"
    VERSION_LABEL="${XUI_VERSION}"
fi

TMP_ORIG="$(mktemp -t xui-install-orig-XXXXXX.sh)"
TMP_CN="$(mktemp -t xui-install-cn-XXXXXX.sh)"
TMP_MAP="$(mktemp -t xui-cn-map-XXXXXX.txt)"
cleanup() { rm -f "${TMP_ORIG}" "${TMP_CN}" "${TMP_MAP}"; }
trap cleanup EXIT

echo -e "${green}== 3x-ui 中文安装脚本 ==${plain}"
echo -e "目标版本：${yellow}${VERSION_LABEL}${plain}"
echo -e "正在下载官方安装脚本..."

if ! curl -fsSL --connect-timeout 20 "${SCRIPT_URL}" -o "${TMP_ORIG}" || [[ ! -s "${TMP_ORIG}" ]]; then
    echo -e "${red}下载官方安装脚本失败${plain}"
    echo -e "${yellow}请确认服务器能访问 GitHub（raw.githubusercontent.com），必要时给 curl 配置代理后重试。${plain}"
    exit 1
fi

echo -e "${green}下载完成，正在汉化交互提示...${plain}"

content="$(cat "${TMP_ORIG}")"
hit=0
miss=0
miss_list=""

# 说明：$1 = 官方原文（必须逐字匹配），$2 = 中文替换
#       TAB 分隔，可用 # 开头写注释行
# 长句优先替换（按长度降序），避免短句先命中把长句拆成半中半英
cat >"${TMP_MAP}" <<'MAP'
Please run this script with root privilege	请使用 root 权限运行本脚本
Failed to check the system OS, please contact the author!	无法检测操作系统版本，请联系脚本作者！
The OS release is: $release	当前系统版本：$release
Arch: $(arch)	CPU 架构：$(arch)
Unsupported CPU architecture!	不支持的 CPU 架构！
Port to use for ACME HTTP-01 listener (default 80): 	请输入 ACME HTTP-01 证书校验使用的端口（直接回车使用默认 80）：
Please choose which port to use (default is 80): 	请选择证书校验使用的端口（直接回车使用默认 80）：
Do you have an IPv6 address to include? (leave empty to skip): 	是否要一并申请 IPv6 地址的证书？（留空则跳过）：
Enter another port for acme.sh standalone listener (leave empty to abort): 	请另指定一个 acme.sh 独立监听端口（留空则放弃）：
Please enter your domain name: 	请输入域名：
Would you like to modify --reloadcmd for ACME? (y/n): 	是否要自定义 ACME 的 --reloadcmd（证书续期后自动执行的命令）？(y/n)：
Choose an option: 	请选择操作：
Please enter your custom reloadcmd: 	请输入自定义的 reloadcmd 命令：
Would you like to set this certificate for the panel? (y/n): 	是否将此证书应用于面板？(y/n)：
Choose an option (default 2 for IP): 	请选择（默认 2，即使用 IP 证书）：
Is ${server_ip} the correct incoming public IPv4 address for this server? [Default y]: 	本机对外的公网 IPv4 地址是 ${server_ip} 吗？[默认 y]：
Please enter your server's public IPv4 address: 	请输入服务器的公网 IPv4 地址：
Please enter domain name certificate issued for: 	请输入该证书签发的域名：
Input certificate path (keywords: .crt / fullchain): 	请输入证书文件路径（文件名通常含 .crt 或 fullchain）：
Input private key path (keywords: .key / privatekey): 	请输入私钥文件路径（文件名通常含 .key 或 privatekey）：
Bind the panel to 127.0.0.1 only? (recommended — forces SSH tunnel / reverse-proxy access) [y/N]: 	是否只让面板监听 127.0.0.1？（推荐——之后只能通过 SSH 隧道或反向代理访问）[y/N]：
Choose [1]: 	请选择 [1]：
Enter PostgreSQL DSN (postgres://user:pass@host:port/dbname?sslmode=disable): 	请输入 PostgreSQL 连接串 DSN（格式 postgres://用户:密码@主机:端口/库名?sslmode=disable）：
Would you like to customize the Panel Port settings? (If not, a random port will be applied) [y/n]: 	是否自定义面板端口？（选 n 则自动生成随机端口）[y/n]：
Please set up the panel port: 	请设置面板端口：
Choose SSL certificate setup method:	请选择 SSL 证书配置方式：
Let's Encrypt for Domain (90-day validity, auto-renews)	Let's Encrypt 域名证书（有效期 90 天，自动续期）
Let's Encrypt for IP Address (6-day validity, auto-renews)	Let's Encrypt IP 地址证书（有效期约 6 天，自动续期）
Custom SSL Certificate (Path to existing files)	使用已有的自定义证书（手动填写文件路径）
Skip SSL (advanced — behind reverse proxy / SSH tunnel only)	跳过 SSL（高级用法——仅在反向代理或 SSH 隧道后面才建议）
Options 1 & 2 require port 80 open. Option 3 requires manual paths.	选项 1、2 需要 80 端口对外开放且可达；选项 3 需要手动填写证书路径。
Option 4 serves the panel over plain HTTP — only safe behind nginx/Caddy or an SSH tunnel.	选项 4 面板使用明文 HTTP——只有在 nginx/Caddy 反向代理或 SSH 隧道后面才安全。
Unknown XUI_SSL_MODE=	未知的 XUI_SSL_MODE 取值
defaulting to none (HTTP).	将按「不使用 SSL（HTTP）」处理。
Database Selection	数据库选择
SQLite     (default — recommended for < 500 clients)	SQLite     （默认——客户端少于 500 个时推荐）
PostgreSQL (recommended for high client counts / many nodes)	PostgreSQL （客户端很多、节点较多时推荐）
Install PostgreSQL locally and create a dedicated user/db (recommended)	本机安装 PostgreSQL，并创建专用的用户和数据库（推荐）
Use an existing PostgreSQL server (enter DSN)	使用已有的 PostgreSQL 服务器（手动输入 DSN）
Retry local install	重试本机安装
Enter an external DSN instead	改为输入外部 DSN
Abort install	中止安装
Fall back to SQLite	回退改用 SQLite
Preset: systemctl reload nginx ; systemctl restart x-ui	预设命令：systemctl reload nginx ; systemctl restart x-ui
Input your own command	自己输入一条命令
Keep default reloadcmd	保持默认 reloadcmd
It's recommended to put x-ui restart at the end	建议把 x-ui 的重启放在命令末尾
Setting up SSL certificate...	正在配置 SSL 证书...
Installing acme.sh for SSL certificate management...	正在安装 acme.sh（用于 SSL 证书管理）...
acme.sh installed successfully	acme.sh 安装成功
Failed to install acme.sh	acme.sh 安装失败
Failed to install acme.sh, skipping SSL setup	acme.sh 安装失败，跳过 SSL 配置
acme.sh could not be found. Installing now...	找不到 acme.sh，正在安装...
Issuing SSL certificate for ${domain}...	正在为 ${domain} 申请 SSL 证书...
Note: Port 80 must be open and accessible from the internet	提示：80 端口必须对外开放且可从公网访问
Failed to issue certificate for ${domain}	为 ${domain} 申请证书失败
Please ensure port 80 is open and try again later with: x-ui	请确认 80 端口已放通，稍后可执行 x-ui 菜单重新尝试
Failed to install certificate	证书安装失败
SSL certificate installed and configured successfully!	SSL 证书已安装并配置完成！
Certificate files not found	未找到证书文件
Setting up Let's Encrypt IP certificate (shortlived profile)...	正在申请 Let's Encrypt IP 地址证书（短有效期模式）...
Note: IP certificates are valid for ~6 days and will auto-renew.	提示：IP 证书有效期约 6 天，到期会自动续期。
Default listener is port 80. If you choose another port, ensure external port 80 forwards to it.	默认监听 80 端口；若改用其他端口，请确保外部 80 端口转发到该端口。
IPv4 address is required	必须提供 IPv4 地址
Invalid IPv4 address	IPv4 地址无效
Including IPv6 address:	同时加入 IPv6 地址：
Invalid port provided. Falling back to 80.	端口填写无效，回退使用 80。
Invalid port provided.	端口填写无效。
Using port ${WebPort} for standalone validation.	将使用 ${WebPort} 端口进行独立校验。
Reminder: Let's Encrypt still connects on port 80; forward external port 80 to ${WebPort}.	提醒：Let's Encrypt 仍会访问 80 端口，请把外部 80 端口转发到 ${WebPort}。
Port ${WebPort} is busy; cannot proceed in non-interactive mode.	端口 ${WebPort} 被占用，非交互模式下无法继续。
Port ${WebPort} is busy; cannot proceed.	端口 ${WebPort} 被占用，无法继续。
Port ${WebPort} is free and ready for standalone validation.	端口 ${WebPort} 空闲，可用于独立校验。
Issuing IP certificate for ${ipv4}...	正在为 ${ipv4} 申请 IP 证书...
Failed to issue IP certificate	IP 证书申请失败
Please ensure port ${WebPort} is reachable (or forwarded from external port 80)	请确认 ${WebPort} 端口可达（或已从外部 80 端口转发过来）
Certificate issued successfully, installing...	证书申请成功，正在安装...
Certificate files not found after installation	安装后未找到证书文件
Certificate files installed successfully	证书文件安装成功
Setting certificate paths for the panel...	正在为面板写入证书路径...
Warning: Could not set certificate paths automatically	警告：无法自动写入证书路径
Certificate files are at:	证书文件位置：
Certificate paths configured successfully	证书路径配置成功
IP certificate installed and configured successfully!	IP 证书已安装并配置完成！
Certificate valid for ~6 days, auto-renews via acme.sh cron job.	证书有效期约 6 天，由 acme.sh 定时任务自动续期。
acme.sh will automatically renew and reload x-ui before expiry.	acme.sh 会在到期前自动续期并重载 x-ui。
Domain name cannot be empty. Please try again.	域名不能为空，请重新输入。
Invalid domain format	域名格式无效
Your domain is:	你的域名是：
Existing certificate found for ${domain}, will reuse it.	检测到 ${domain} 已有可用证书，将直接复用。
Your domain is ready for issuing certificates now...	域名检查通过，可以开始申请证书...
Your input ${WebPort} is invalid, will use default port 80.	你输入的 ${WebPort} 无效，将使用默认 80 端口。
Will use port: ${WebPort} to issue certificates. Please make sure this port is open.	将使用 ${WebPort} 端口申请证书，请确保该端口已放通。
Stopping panel temporarily...	正在临时停止面板...
Issuing certificate failed, please check logs.	证书申请失败，请查看日志。
Issuing certificate succeeded, installing certificates...	证书申请成功，正在安装证书...
Using existing certificate, installing certificates...	使用已有证书，正在安装...
Default --reloadcmd for ACME is:	ACME 默认的 --reloadcmd 是：
This command will run on every certificate issue and renew.	该命令会在每次签发、续期证书后执行。
Reloadcmd is:	当前 reloadcmd 为：
Keeping default reloadcmd	保持默认 reloadcmd
Installing certificate succeeded, enabling auto renew...	证书安装成功，正在开启自动续期...
Installing certificate failed, exiting.	证书安装失败，退出。
Auto renew setup had issues, certificate details:	自动续期配置有问题，证书信息如下：
Auto renew succeeded, certificate details:	自动续期配置成功，证书信息如下：
Certificate paths set for the panel	面板证书路径已设置
Certificate File:	证书文件：
Private Key File:	私钥文件：
Panel will restart to apply SSL certificate...	面板将重启以应用 SSL 证书...
Error: Certificate or private key file not found for domain	错误：未找到该域名的证书或私钥文件
Skipping panel path setting.	已跳过面板证书路径设置。
Using Let's Encrypt for domain certificate...	使用 Let's Encrypt 域名证书...
SSL certificate configured successfully with domain:	SSL 证书配置成功，域名：
SSL setup may have completed, but domain extraction failed	SSL 可能已配置完成，但未能解析出域名
SSL certificate setup failed for domain mode.	域名证书模式配置失败。
Using Let's Encrypt for IP certificate (shortlived profile)...	使用 Let's Encrypt IP 证书（短有效期模式）...
Invalid IPv4 address. Please try again.	IPv4 地址无效，请重新输入。
Let's Encrypt IP certificate configured successfully	Let's Encrypt IP 证书配置成功
IP certificate setup failed. Please check port 80 is open.	IP 证书配置失败，请检查 80 端口是否放通。
Using custom existing certificate...	使用已有的自定义证书...
Error: File does not exist! Try again.	错误：文件不存在，请重新输入。
Error: File exists but is not readable (check permissions)!	错误：文件存在但不可读（请检查权限）。
Error: File is empty!	错误：文件为空。
Custom certificate paths applied.	自定义证书路径已应用。
Note: You are responsible for renewing these files externally.	提示：这些证书文件需要你自己负责续期。
Panel will be installed WITHOUT SSL/TLS.	面板将在「无 SSL/TLS」的情况下安装。
Login credentials and cookies will travel as plain HTTP.	登录凭据与 Cookie 会以明文 HTTP 传输。
Only safe when:	仅在以下情况才算安全：
A reverse proxy (nginx, Caddy, Traefik) terminates TLS for you, or	由反向代理（nginx、Caddy、Traefik）替你终结 TLS；或者
You access the panel exclusively via SSH tunnel	你只通过 SSH 隧道访问面板
Panel bound to 127.0.0.1 only. It is now unreachable from the public internet.	面板已只监听 127.0.0.1，公网无法直接访问。
SSH Port Forwarding — open the panel from your local machine via:	SSH 端口转发——在你本机用下面的命令打开面板：
Standard SSH command:	标准 SSH 命令：
If using an SSH key:	如果使用密钥登录：
Then open in your browser:	然后在浏览器打开：
Alternative: point a reverse proxy (nginx/Caddy) at 127.0.0.1:	另一种方式：让反向代理（nginx/Caddy）指向 127.0.0.1：
Panel will listen on all interfaces over plain HTTP. Make sure something else is terminating TLS in front of it.	面板将在所有网卡上以明文 HTTP 监听，请务必在它前面有别的组件负责 TLS。
SSL setup skipped.	已跳过 SSL 配置。
Invalid option. Skipping SSL setup.	选项无效，跳过 SSL 配置。
Could not auto-detect server IP from any provider.	无法从任何接口自动探测服务器 IP。
Installing PostgreSQL locally (non-interactive)...	正在本机安装 PostgreSQL（非交互模式）...
PostgreSQL installation failed in non-interactive mode; aborting.	非交互模式下 PostgreSQL 安装失败，已中止。
Set XUI_DB_DSN to use an existing server, or XUI_DB_TYPE=sqlite.	可设置 XUI_DB_DSN 使用已有服务器，或设置 XUI_DB_TYPE=sqlite。
Installing PostgreSQL — this may take a moment...	正在安装 PostgreSQL——可能需要一点时间...
Failed to create temporary credentials file.	创建临时凭据文件失败。
PostgreSQL installation failed.	PostgreSQL 安装失败。
Install aborted.	安装已中止。
Your Panel Port is:	面板端口：
Generated random port:	已随机生成端口：
SSL Certificate Setup (RECOMMENDED)	SSL 证书配置（强烈推荐）
SSL is strongly recommended. Skip only if a reverse proxy	强烈建议配置 SSL；只有当你已有反向代理
or SSH tunnel handles TLS for you.	或 SSH 隧道负责 TLS 时才跳过。
Let's Encrypt now supports both domains and IP addresses!	Let's Encrypt 现已支持域名和 IP 地址两种证书！
Panel Installation Complete!	面板安装完成！
Username:	用户名：
Password:	密码：
WebBasePath:	访问路径：
Database:	数据库：
Access URL:	访问地址：
API Token:	API 令牌：
IMPORTANT: Save these credentials securely!	重要：请务必妥善保存以上登录信息！
SSL Certificate: Enabled and configured	SSL 证书：已启用并配置完成
SSL Certificate: Skipped — panel is HTTP-only. Use a reverse proxy or SSH tunnel.	SSL 证书：已跳过——面板为 HTTP，请使用反向代理或 SSH 隧道。
PostgreSQL backup & restore is built into the panel:	面板已内置 PostgreSQL 备份与恢复：
Backup & Restore	备份与恢复
Back Up downloads a pg_dump .dump file; Restore reloads it via pg_restore.	备份会下载 pg_dump 导出的 .dump 文件；恢复会通过 pg_restore 重新导入。
PostgreSQL Credentials	PostgreSQL 连接信息
DB Name:	数据库名：
Host:	主机：
DSN:	连接串：
Env file:	环境文件：
Connect from this server:	在本机连接数据库：
(as the postgres superuser)	（以 postgres 超级用户身份）
The panel reads these credentials from	面板会从这个文件读取凭据：
Save the password — it is not stored anywhere else in plain text.	请保存好密码——其他位置不会明文存储它。
WebBasePath is missing or too short. Generating a new one...	访问路径缺失或过短，正在重新生成...
New WebBasePath:	新的访问路径：
Default credentials detected. Security update required...	检测到默认账号密码，正在强制更新安全设置...
Generated new random login credentials:	已生成新的随机登录凭据：
Username, Password, and WebBasePath are properly set.	用户名、密码、访问路径均已正确设置。
SSL certificate already configured. No action needed.	SSL 证书已配置，无需操作。
skipping Fail2ban auto-setup.	已跳过 Fail2ban 自动配置。
x-ui CLI not found; skipping Fail2ban auto-setup.	未找到 x-ui 命令，跳过 Fail2ban 自动配置。
Setting up Fail2ban for the IP Limit feature...	正在为「IP 限制」功能配置 Fail2ban...
Fail2ban setup complete.	Fail2ban 配置完成。
Note: systemd 	提示：systemd 
Not applied, needs a newer systemd:	以下加固项未生效，需要更新的 systemd：
Warning: could not refresh	警告：无法刷新
No checksum published for this release, skipping verification	该版本未发布校验值，跳过校验
Checksum mismatch for	校验值不匹配
Checksum verified:	校验值校验通过：
Install a release that ships it, or 'dev' for the rolling build. Your existing installation has not been touched.	请改用包含该文件的正式版本（或用 dev 安装滚动构建版）。你现有的安装未被改动。
Failed to fetch x-ui version, it may be due to GitHub API restrictions, please try it later	获取 3x-ui 版本信息失败，可能是 GitHub API 受限，请稍后重试
Got x-ui latest version:	获取到的 3x-ui 最新版本：
Downloading x-ui failed, please be sure that your server can access GitHub 	下载 3x-ui 失败，请确认服务器能访问 GitHub 
Downloaded x-ui release archive is empty	下载的 3x-ui 安装包为空
Installing the rolling dev build (tag: dev-latest). This is a per-commit pre-release, not a stable version.	正在安装滚动 dev 构建（tag: dev-latest）。这是逐提交的预发布版本，不是稳定版。
Please use a newer version (at least v2.3.5). Exiting installation.	请使用更新的版本（至少 v2.3.5），退出安装。
Beginning to install x-ui 	开始安装 x-ui 
Download x-ui ${tag_version} failed, please check if the version exists 	下载 x-ui ${tag_version} 失败，请确认该版本是否存在
Failed to download x-ui.sh	下载 x-ui.sh 失败
Downloaded x-ui.sh is empty	下载的 x-ui.sh 为空
Could not back up bin/ -- custom files there will not be preserved across this update	无法备份 bin/ 目录——本次升级不会保留你放在里面的自定义文件
Failed to extract the x-ui release archive	解压 3x-ui 安装包失败
Extracted x-ui archive is missing the x-ui binary	解压后的安装包中缺少 x-ui 主程序
Restored custom file(s) in bin/ not shipped by this release:	已恢复 bin/ 中本版本未包含的自定义文件：
Failed to install x-ui.sh	安装 x-ui.sh 失败
Added x-ui.db to /etc/.gitignore for etckeeper	已将 x-ui.db 加入 /etc/.gitignore（供 etckeeper 使用）
Created /etc/.gitignore and added x-ui.db for etckeeper	已创建 /etc/.gitignore 并加入 x-ui.db（供 etckeeper 使用）
Failed to download x-ui.rc	下载 x-ui.rc 失败
Downloaded x-ui.rc is empty	下载的 x-ui.rc 为空
Failed to install x-ui.rc	安装 x-ui.rc 失败
Found x-ui.service in extracted files, installing...	在安装包中发现 x-ui.service，正在安装...
Found x-ui.service.debian in extracted files, installing...	在安装包中发现 x-ui.service.debian，正在安装...
Found x-ui.service.arch in extracted files, installing...	在安装包中发现 x-ui.service.arch，正在安装...
Found x-ui.service.rhel in extracted files, installing...	在安装包中发现 x-ui.service.rhel，正在安装...
Service files not found in tar.gz, downloading from GitHub...	安装包中未找到服务文件，正从 GitHub 下载...
Setting up systemd unit...	正在配置 systemd 服务...
Failed to install x-ui.service file	安装 x-ui.service 服务文件失败
installation finished, it is running now...	安装完成，服务已启动...
Running...	运行中...
Port ${WebPort} is in use.	端口 ${WebPort} 已被占用。
. Please enter a valid domain name.	，请输入正确的域名。
, checking it...	，正在检查...
${blue}Note:${plain}	${blue}提示：${plain}
and let it terminate TLS.	并让它负责 TLS 终结。
This x-ui.sh predates 'x-ui setup-fail2ban';	当前 x-ui.sh 不支持 'x-ui setup-fail2ban'；
ignores part of the hardening in x-ui.service; the panel still starts.	不支持 x-ui.service 中的部分加固项；面板仍能正常启动。
: expected ${expected:-<none>}, got ${actual}	：期望 ${expected:-<none>}，实际为 ${actual}
, beginning the installation...	，开始安装...
Fatal error:	致命错误：
-- the previous installation has already been removed, so the panel will not start until this is fixed; try running the installer again	-- 旧版本已被移除，若不修复面板将无法启动；请重新运行安装脚本
MAP

# 按长度降序应用替换：长句先处理，避免短句先命中把长句拆坏
while IFS=$'\t' read -r old new; do
    [[ -z "${old:-}" ]] && continue
    [[ "${old}" == \#* ]] && continue
    before="${content}"
    content="${content//"${old}"/"${new}"}"
    if [[ "${content}" != "${before}" ]]; then
        hit=$((hit + 1))
    else
        miss=$((miss + 1))
        miss_list="${miss_list}
  - ${old}"
    fi
done < <(awk -F'\t' 'NF>1 {print length($0) "\t" $0}' "${TMP_MAP}" | sort -rn | cut -f2-)

printf '%s\n' "${content}" >"${TMP_CN}"

echo -e "${green}汉化替换：成功 ${hit} 条，未命中 ${miss} 条${plain}"
if [[ "${miss}" -gt 0 ]]; then
    echo -e "${yellow}以下原文未在脚本中找到（官方改版后可能出现，不影响安装）：${miss_list}${plain}"
fi

if ! bash -n "${TMP_CN}"; then
    echo -e "${red}汉化后的脚本语法检查未通过，已停止。${plain}"
    echo -e "${yellow}为了安全，请改用官方原版脚本安装。${plain}"
    exit 1
fi

echo -e "${green}语法检查通过${plain}"

if [[ "${CN_ONLY}" == "1" ]]; then
    OUT="${XUI_CN_OUT:-./install-cn-localized.sh}"
    cp "${TMP_CN}" "${OUT}"
    chmod 755 "${OUT}"
    echo -e "${green}已生成汉化脚本：${OUT}${plain}"
    exit 0
fi

echo -e "${green}开始安装（以下交互提示均为中文）...${plain}"
echo ""

bash "${TMP_CN}"
