# luci-app-xlnetacc
适用于 OpenWRT/LEDE 纯Shell实现的迅雷快鸟客户端

依赖: wget openssl-util


更新到支持快鸟新协议 300

详情见恩山论坛介绍帖 [依然是改良作品，这次的目标是 -- 迅雷快鸟](http://www.right.com.cn/forum/thread-267641-1-1.html)

## 验证码登录增强

本分支在原版基础上增加了以下功能：

- 迅雷要求图形验证码时，在已登录的 LuCI 设置页面显示验证码和输入框；
- 验证码图片仅通过受 LuCI 登录保护的接口提供，提交接口带 CSRF 校验；
- 验证码登录成功后，以 `600` 权限将 `userID` 和 `loginKey` 缓存在
  `/etc/xlnetacc.auth`，服务或路由器重启时优先复用，减少再次触发验证码；
- 登录凭证失效、账号发生变化或迅雷再次要求验证时，自动清除缓存并回退到页面验证码；
- 修复旧版 LuCI 的 XHR 提交兼容问题以及提交成功后的错误提示。

建议将“保持连接周期”设为 10 分钟，并将“账号重新登录”设为“未启用”，
避免不必要的定时重新登录触发验证码。

## 安装

从 [Releases](https://github.com/leologoli/luci-app-xlnetacc/releases) 下载最新的
`luci-app-xlnetacc_*_all.ipk`，上传到路由器后执行：

```sh
opkg install --force-reinstall /tmp/luci-app-xlnetacc_*_all.ipk
rm -f /tmp/luci-indexcache
rm -rf /tmp/luci-modulecache
/etc/init.d/xlnetacc restart
```

GitHub Actions 会在推送 `v*` 标签或手动运行 “Build and release IPK” 时，
使用 OpenWrt 23.05.5 SDK 构建并发布 IPK 及 SHA-256 校验文件。
