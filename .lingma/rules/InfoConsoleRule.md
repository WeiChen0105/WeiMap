---
trigger: always_on
---
- name: log-rule
- 在辅助编写调试代码时，请使用此规则
- 描述: 在辅助编写调试代码时，日志开头以===开始，结尾为===结束，确保日志便于过滤
- 规则: 在打印任何日志（console.log, console.error, console.warn, logger.info 等）时，将完整的日志文本用 `===` 包裹。例如：
    - 原写法：`console.error('[路线规划] 路线规划服务未初始化');`
    - 应改为：`console.error('===[路线规划] 路线规划服务未初始化===');`
    - 其他语言类似：`print("=== 数据加载完成 ===")`、`logger.info("=== 服务启动 ===")`