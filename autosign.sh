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
PORTAL="https://www.mydigit.cn/"
SIGN_PAGE="https://www.mydigit.cn/k_misign-sign.html"
LOGIN_PAGE="https://www.mydigit.cn/member.php?mod=logging&action=login&handlekey=login"
CURL_COMMON='curl -A "$USER_AGENT" -H "$EXT_HEADER" -s -D -'
CUT_COOKIE='(tolower($1)=="set-cookie:"){n=split($0,arr," *; *")
              for(i=2;i<=n;i++){if(tolower(arr[i])=="max-age=0"){flag=1}}
              if(flag){split($2,arr,"=");print arr[1]"=deleted;"}
              else{print $2};flag=false}'

trim_cookie() {
  COOKIE=`sed 's/ /\n/g' << EOF | awk -F '=' '!arr[$1]++' | grep -v '^[^=]*=deleted;$'
$COOKIE
EOF
`
}

# awk substr param a added length("\"")
get_formhash() {
  FORM_HASH=`grep formhash /tmp/autosign.tmp | grep -v jQuery | grep input \
           | awk -F 'value=' '!(arr[$0]++){print substr($2,2,8)}'`
}

# request homepage
COOKIE=`$CURL_COMMON -o /dev/null $PORTAL | awk "$CUT_COOKIE"`

# get time from lastact
LASTACT_TIME=`sed -n '/_lastact/{s/^[^=]*=//;s/%.*;$//p}' << EOF
$COOKIE
EOF
`

# sendmail?
COOKIE=`$CURL_COMMON -b "$(echo $COOKIE)" -e "$PORTAL" -o /dev/null \
        https://www.mydigit.cn/home.php?mod=misc\&ac=sendmail\&rand=$LASTACT_TIME \
      | awk "$CUT_COOKIE"`" "$COOKIE
trim_cookie

rm -f /tmp/autosign.tmp
# request fwin_content_login
COOKIE=`$CURL_COMMON -b "$(echo $COOKIE)" -e "$PORTAL" -o /tmp/autosign.tmp \
        $LOGIN_PAGE\&infloat=yes\&inajax=1\&ajaxtarget=fwin_content_login \
      | awk "$CUT_COOKIE"`" "$COOKIE
trim_cookie
# get loginhash and formhash
LOGIN_HASH=`awk -F 'loginhash=' '$2{print substr($2,1,5)}' /tmp/autosign.tmp`
get_formhash
rm -f /tmp/autosign.tmp

# login
COOKIE=`$CURL_COMMON -b "$(echo $COOKIE)" -e "$PORTAL" -X POST -o /dev/null \
        -d formhash=$FORM_HASH\&referer=$PORTAL\&username=$USER_NAME\&password=$PASSWORD\&questionid=$QUESTION_ID\&answer=$ANSWER \
        $LOGIN_PAGE\&loginsubmit=yes\&loginhash=$LOGIN_HASH\&inajax=1 \
      | awk "$CUT_COOKIE"`" "$COOKIE
trim_cookie

sleep $DELAY_TIME
# request sign page
COOKIE=`$CURL_COMMON -b "$(echo $COOKIE)" -e "$PORTAL" -o /tmp/autosign.tmp $SIGN_PAGE \
      | awk "$CUT_COOKIE"`" "$COOKIE
trim_cookie
# get formhash
get_formhash
rm -f /tmp/autosign.tmp

# do sign
COOKIE=`$CURL_COMMON -b "$(echo $COOKIE)" -e "$SIGN_PAGE" -o /dev/null \
        https://www.mydigit.cn/plugin.php?id=k_misign:sign\&operation=qiandao\&formhash=$FORM_HASH\&format=empty \
      | awk "$CUT_COOKIE"`" "$COOKIE
trim_cookie
sleep $DELAY_TIME
[ -z $SPACE_UID ] || 
  $CURL_COMMON -b "$(echo $COOKIE)" -e "$SIGN_PAGE" -o /dev/null \
  https://www.mydigit.cn/home.php?mod=space\&uid=$SPACE_UID\&do=profile >/dev/null 2>&1

exit 0
