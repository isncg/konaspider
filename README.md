# Konachan.net 网站爬虫测试

konachan.net 是一个壁纸网站，通过 https://konachan.net/post.json 可以访问最新一批壁纸的json数据，实例数据可以参考本目录的 post.json

由于该网站托管于cloudflare，使用简单的http请求是无法通过bot检测的。经过试验，想要得到json response，需要在http请求header的cookie中加入正确的 `cf_clearance` 参数。

## 爬虫策略

1. 首次发送 http 请求，request header 模拟浏览器参数，首次请求用来观测cloudflare的下发消息
2. 根据下发消息，设法获取并记录 `cf_clearance`
3. 用取得的 `cf_clearance` 再次发送http请求

## 技术要求
1. 使用lua实现
2. http请求、响应完整记录到日志文件，用于反复调整lua代码实现

## 预期过程和结果
1. 理论上http请求应该很容易得到403响应代码，随着多次迭代调整，应该可以逐步逼近浏览器的访问流程
2. 最终得到一个lua程序，能够完全模拟用户访问该网站时的请求响应过程
