#!/bin/sh

# UA
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36"
# 模拟访问页面延时
DELAY_TIME=5
# 用户名, URLEncode编码
USER_NAME=""
# 密码
PASSWORD=""
# 安全提问和答案
QUESTION_ID="0"
ANSWER=""
# 模拟访问个人空间的UID, 可选
# SPACE_UID=""


EXT_HEADER="Host: www.mydigit.cn"
BASE_URL="https://www.mydigit.cn"
PORTAL="$BASE_URL/"
SIGN_PAGE="$BASE_URL/k_misign-sign.html"
LOGIN_PAGE="$BASE_URL/member.php?mod=logging&action=login&handlekey=login"
CURL_COMMON='curl -A "$USER_AGENT" -H "$EXT_HEADER" -s -D -'

# awk substr param a added length("\"")
get_formhash() {
  FORM_HASH=`grep formhash /tmp/autosign.$$ | grep -v jQuery | grep input \
           | awk -F 'value=' '!(arr[$0]++){print substr($2,2,8)}'`
}

add_cookie() {
  COOKIE=`awk '(tolower($1)=="set-cookie:"){n=split($0,arr," *; *")
              for(i=2;i<=n;i++){if(tolower(arr[i])=="max-age=0"){flag=1}}
              if(flag){split($2,arr,"=");print arr[1]"=,;"}
              else{print $2};flag=0}' << EOF
$*
EOF
`" "$COOKIE
  
  # trim cookie
  COOKIE=`sed 's/ /\n/g' << EOF | awk -F '=' '!arr[$1]++' | grep -v '^[^=]*=,;$'
$COOKIE
EOF
`
}

# request homepage
add_cookie "`$CURL_COMMON -o /dev/null $PORTAL`"

# get time from lastact
LASTACT_TIME=`sed -n '/_lastact/{s/^[^=]*=//;s/[^0-9].*;$//p}' << EOF
$COOKIE
EOF
`

# sendmail?
add_cookie "`$CURL_COMMON -b "$(echo $COOKIE)" -e "$PORTAL" -o /dev/null \
           $BASE_URL/home.php?mod=misc\&ac=sendmail\&rand=$LASTACT_TIME`"

rm -f /tmp/autosign.$$
# request fwin_content_login
add_cookie "`$CURL_COMMON -b "$(echo $COOKIE)" -e "$PORTAL" -o /tmp/autosign.$$ \
           $LOGIN_PAGE\&infloat=yes\&inajax=1\&ajaxtarget=fwin_content_login`"

# get loginhash and formhash
LOGIN_HASH=`awk -F 'loginhash=' '$2{print substr($2,1,5)}' /tmp/autosign.$$`
get_formhash
rm -f /tmp/autosign.$$

# login
add_cookie "`$CURL_COMMON -b "$(echo $COOKIE)" -e "$PORTAL" -X POST -o /dev/null \
           -d formhash=$FORM_HASH\&referer=$PORTAL\&username=$USER_NAME\&password=$PASSWORD\&questionid=$QUESTION_ID\&answer=$ANSWER \
           $LOGIN_PAGE\&loginsubmit=yes\&loginhash=$LOGIN_HASH\&inajax=1`"

sleep $DELAY_TIME
# request sign page
add_cookie "`$CURL_COMMON -b "$(echo $COOKIE)" -e "$PORTAL" -o /tmp/autosign.$$ \
           $SIGN_PAGE`"
# get formhash
get_formhash
rm -f /tmp/autosign.$$

# do sign
add_cookie "`$CURL_COMMON -b "$(echo $COOKIE)" -e "$SIGN_PAGE" -o /dev/null \
           $BASE_URL/plugin.php?id=k_misign:sign\&operation=qiandao\&formhash=$FORM_HASH\&format=empty
           `"

sleep $DELAY_TIME
[ -z $SPACE_UID ] || 
  $CURL_COMMON -b "$(echo $COOKIE)" -e "$SIGN_PAGE" -o /dev/null \
  $BASE_URL/home.php?mod=space\&uid=$SPACE_UID\&do=profile >/dev/null 2>&1

exit 0
