# SmartFitness 后端接口文档（API）

> 文档版本：V1.0  
> 更新日期：2026-07-14  
> 来源：iOS 客户端调用与 Codable 模型反推  
> 重要说明：当前仓库不含后端实现或 OpenAPI。本文件中的“当前契约”可由客户端代码验证；错误码、鉴权强制性、幂等和服务端校验仍需后端确认。

## 1. 接口概览

### 1.1 当前开发地址

```text
http://10.108.2.95:8001
```

该地址为硬编码局域网 HTTP 地址，不可作为生产地址。生产环境必须使用 HTTPS 和独立域名。

### 1.2 端点清单

| Method | Path | 用途 | 客户端状态 |
|---|---|---|---|
| POST | `/api/auth/apple/login` | Apple 登录并换取业务 Token | 使用中 |
| POST | `/api/plans/generate` | AI 生成训练计划 | 使用中 |
| POST | `/api/training/save` | 保存训练记录 | 使用中 |
| GET | `/api/training/gettraining` | 按日期查询训练记录 | 使用中 |
| POST | `/a2a/v1/message` | A2A 同步或 SSE 消息 | 客户端已实现，主流程未启用 |
| POST | `/a2a/v1/stream/stop/{taskID}` | 停止 A2A 流式任务 | 客户端已实现，主流程未启用 |

另有 DashScope 与 OpenFoodFacts 第三方接口，见第 9 节。

## 2. 通用接口规范

### 2.1 请求格式

- 字符集：UTF-8。
- REST POST：`Content-Type: application/json`。
- 日期时间：训练保存使用 ISO 8601。
- 日期查询：`yyyy-MM-dd`。
- 字段命名：JSON 使用 `snake_case`。
- 未设置的可选字段应省略或传 `null`，不要传类型不匹配的空字符串。

### 2.2 推荐通用请求头

| Header | 必填 | 说明 |
|---|---:|---|
| `Content-Type` | POST 是 | `application/json` |
| `Accept` | 建议 | `application/json` |
| `Authorization` | 受保护接口是 | `Bearer <access_token>` |
| `X-Request-ID` | 规划 | 客户端 UUID，用于链路追踪 |
| `X-App-Version` | 规划 | App 版本 |
| `X-Platform` | 规划 | 固定为 `ios` |
| `Idempotency-Key` | 训练保存规划 | 建议使用训练记录 UUID |

当前代码只稳定设置 `Content-Type` 和可选 `Authorization`。

### 2.3 REST 统一响应

```json
{
  "code": 200,
  "msg": "ok",
  "data": {}
}
```

| 字段 | 类型 | 可空 | 说明 |
|---|---|---:|---|
| `code` | integer | 是 | 业务状态码 |
| `msg` | string | 是 | 用户或调试消息 |
| `data` | object/array/null | 是 | 业务数据 |

当前客户端对多数接口只显式处理 `code=401` 和 `code=500`，成功码是否固定为 200 需后端确认。

### 2.4 建议错误码规范

以下为目标规范，不代表当前后端已实现：

| HTTP | code | 语义 |
|---:|---|---|
| 200 | 200 | 成功 |
| 400 | 40000 | 请求格式错误 |
| 400 | 40001 | 参数校验失败 |
| 401 | 40100 | 未登录或 Token 缺失 |
| 401 | 40101 | Token 过期 |
| 403 | 40300 | 无资源权限 |
| 404 | 40400 | 资源不存在 |
| 409 | 40900 | 幂等冲突或版本冲突 |
| 422 | 42200 | 业务规则不满足 |
| 429 | 42900 | 请求过于频繁 |
| 500 | 50000 | 服务内部错误 |
| 503 | 50300 | 服务暂不可用 |

错误响应示例：

```json
{
  "code": 40001,
  "msg": "frequency must be one of three, four, five, six",
  "data": null
}
```

### 2.5 客户端错误行为

| 条件 | 当前行为 |
|---|---|
| JSON `code == 401` | 发出未授权通知，清除用户与计划 |
| JSON `code == 500` | 返回失败，优先显示 `msg` |
| HTTP 401 | 同上 |
| HTTP 5xx | 返回服务端错误 |
| 查询训练 HTTP 404 | 返回成功但数据为 `nil` |
| 解码失败 | 返回失败 |

### 2.6 鉴权

```http
Authorization: Bearer <token>
```

- Token 来自 Apple 登录接口的 `data.token`。
- 当前 iOS 将 Token 保存于 UserDefaults；应迁移至 Keychain。
- 生成计划、保存训练和查询训练的客户端方法允许 Token 为空，但 UI 只对 AI 生成强制登录。
- 服务端是否接受匿名训练接口必须确认。目标规范应将用户云数据接口设为强制鉴权。
- 当前无 Refresh Token 接口。

### 2.7 分页

当前接口没有分页参数。按日期查询训练返回数组但客户端只使用第一项。

未来列表接口建议使用游标分页：

```text
GET /api/training/sessions?cursor=<opaque>&limit=20
```

```json
{
  "code": 200,
  "msg": "ok",
  "data": {
    "items": [],
    "next_cursor": null,
    "has_more": false
  }
}
```

### 2.8 幂等

当前实现无法确认。建议：

- `POST /api/training/save` 使用 `TrainingRecord.id` 或 `Idempotency-Key` 幂等。
- Apple 登录按 Apple `sub` 幂等创建/更新用户。
- AI 生成不自动重试；如需重试，使用请求 ID 避免重复计费。

## 3. 数据类型

### 3.1 User

```json
{
  "user_id": 10001,
  "apple_sub": "001234.abcd",
  "email": "user@example.com",
  "name": "User",
  "token": "<access_token>"
}
```

| 字段 | 类型 | 可空 | 说明 |
|---|---|---:|---|
| `user_id` | integer | 否 | 业务用户 ID |
| `apple_sub` | string | 是 | Apple 用户唯一标识 |
| `email` | string | 是 | Apple 可能仅首次授权返回 |
| `name` | string | 是 | 用户名称 |
| `token` | string | 是 | Bearer Token |

### 3.2 ExerciseSet

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | UUID string | 客户端组 ID |
| `weight` | number | 重量，单位 kg |
| `reps` | integer | 实际次数 |
| `is_completed` | boolean | 是否完成 |

### 3.3 Exercise

| 字段 | 类型 | 可空 | 说明 |
|---|---|---:|---|
| `id` | UUID string | 否 | 训练中的动作实例 ID |
| `backend_id` | string | 是 | AI/动作库的后端或参考 ID |
| `order` | integer | 否 | 动作顺序 |
| `exercise_name` | string | 否 | 动作名称 |
| `sets` | integer | 否 | 目标组数 |
| `reps` | string | 否 | 目标次数，可为范围 |
| `equipment` | string | 否 | 器械 |
| `difficulty` | string | 否 | 难度 |
| `images` | string[] | 否 | 图片引用 |
| `instructions` | string | 否 | 动作说明 |
| `focus_area` | string | 否 | 训练部位 |
| `primary_muscles` | string[] | 否 | 主肌群 |
| `rest_time` | integer | 否 | 休息秒数 |
| `exercise_sets` | ExerciseSet[] | 否 | 组明细 |

### 3.4 TrainingRecord

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | UUID string | 客户端记录 ID |
| `date` | ISO 8601 string | 训练时间 |
| `focus_area` | string | 训练部位 |
| `exercises` | Exercise[] | 动作明细 |
| `duration` | number | 秒 |
| `is_completed` | boolean | 是否完成 |

## 4. Apple 登录

### `POST /api/auth/apple/login`

用途：验证 Apple 凭证，创建或查找业务用户并返回访问 Token。

鉴权：无。

#### 请求

```json
{
  "id_token": "<apple_identity_token>",
  "code": "<apple_authorization_code>",
  "name": "Jeremy"
}
```

| 字段 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| `id_token` | string | 是 | Apple Identity Token |
| `code` | string | 客户端可传空 | Apple Authorization Code |
| `name` | string | 客户端可传空 | Apple 仅首次授权可能返回 |

#### 成功响应

```json
{
  "code": 200,
  "msg": "ok",
  "data": {
    "user_id": 10001,
    "apple_sub": "001234.abcd",
    "email": "user@example.com",
    "name": "Jeremy",
    "token": "<access_token>"
  }
}
```

#### 失败响应示例

```json
{
  "code": 40100,
  "msg": "invalid apple identity token",
  "data": null
}
```

#### 权限与业务逻辑

1. 服务端必须验证 Token 的签名、issuer、audience、expiry 和 nonce（若客户端提供）。
2. 以 Apple `sub` 唯一识别用户，不以邮箱作为主身份。
3. 首次登录创建用户，后续登录更新可变资料。
4. 不在日志中记录原始 `id_token` 和 `code`。

#### 待确认

- Token 是 JWT 还是服务端 Session。
- Token 有效期、刷新和吊销方式。
- 客户端传空 `code` 是否允许。

## 5. AI 训练计划

### `POST /api/plans/generate`

用途：根据用户训练条件生成训练计划。

鉴权：客户端可选 Bearer；产品流程要求登录。目标规范建议强制鉴权。

超时：客户端设置 300 秒。

#### 请求

```json
{
  "user_input": "novice，three，gym，无"
}
```

`user_input` 当前拼接格式：

```text
{level}，{frequency}，{scene}，{injuries}
```

枚举：

| 参数 | 值 |
|---|---|
| level | `novice`、`intermediate`、`advanced` |
| frequency | `three`、`four`、`five`、`six` |
| scene | `gym`、`home`、`outdoor` |
| injuries | `无`，或 `shoulder + waist + knee + wrist + elbow` 的组合 |

当前字符串协议脆弱。建议后端新增结构化请求：

```json
{
  "level": "novice",
  "frequency_per_week": 3,
  "scene": "gym",
  "injuries": []
}
```

#### 成功响应

```json
{
  "code": 200,
  "msg": "ok",
  "data": {
    "training_split": "Push Pull Legs",
    "daily_plans": [
      {
        "training_day": "Monday - Chest",
        "exercise_list": [
          {
            "id": "Barbell_Bench_Press",
            "exercise_name": "Barbell Bench Press",
            "sets": 4,
            "reps": "8-10",
            "order": 1,
            "equipment": "barbell",
            "difficulty": "intermediate",
            "images": ["Barbell_Bench_Press/0.jpg"],
            "primary_muscles": ["chest"]
          }
        ]
      }
    ]
  }
}
```

#### 响应字段

| 字段 | 类型 | 可空 | 说明 |
|---|---|---:|---|
| `training_split` | string | 否 | 计划名称/分化 |
| `daily_plans` | array | 否 | 每日计划 |
| `training_day` | string | 否 | 日期/标签/部位文本 |
| `exercise_list` | array | 否 | 空数组会被客户端视为休息日 |
| `id` | string | 是 | 后端动作 ID |
| `exercise_name` | string | 否 | 动作名称 |
| `sets` | integer | 否 | 组数 |
| `reps` | string | 否 | 次数或范围 |
| `order` | integer | 否 | 顺序 |
| `equipment` | string | 否 | 器械 |
| `difficulty` | string | 否 | 难度 |
| `images` | string[] | 是 | 客户端还会拆分元素内的逗号 |
| `primary_muscles` | string[] | 是 | 主肌群 |

#### 业务规则

- 空动作列表代表休息日。
- 服务端应保证每个训练日动作顺序唯一、组数大于 0。
- 伤病条件应限制不适合动作，并在响应中提供可解释提示（当前模型无字段）。
- 客户端成功后只保存本地计划，当前没有云端计划 CRUD。

#### 失败场景

- 参数无效。
- 用户未登录。
- AI 服务超时或限流。
- 返回结构无法解码。

## 6. 保存训练记录

### `POST /api/training/save`

用途：将本地训练记录同步至服务端。

鉴权：客户端可选 Bearer；目标规范建议强制鉴权。

#### 请求

```json
{
  "id": "E9FDC2F9-46B1-4530-92F4-0D85126B5001",
  "date": "2026-07-14T10:15:30Z",
  "focus_area": "Chest",
  "duration": 2700,
  "is_completed": true,
  "exercises": [
    {
      "id": "B20B92E7-5BE9-4A8C-8C76-16C3A252F001",
      "backend_id": "Barbell_Bench_Press",
      "order": 1,
      "exercise_name": "Barbell Bench Press",
      "sets": 3,
      "reps": "10",
      "equipment": "barbell",
      "difficulty": "intermediate",
      "images": ["Barbell_Bench_Press/0.jpg"],
      "instructions": "",
      "focus_area": "Chest",
      "primary_muscles": ["chest"],
      "rest_time": 90,
      "exercise_sets": [
        {
          "id": "1C5894F3-4030-4FAE-9B2C-E5C3BE178001",
          "weight": 60,
          "reps": 10,
          "is_completed": true
        }
      ]
    }
  ]
}
```

#### 成功响应

客户端只要求可解码为基础响应：

```json
{
  "code": 200,
  "msg": "saved"
}
```

#### 权限与业务逻辑

1. 服务端从 Token 获取用户，不接受客户端指定其他用户。
2. `id` 作为幂等标识；重复请求更新同一记录或返回相同结果。
3. 单次请求应在一个事务中写入会话、动作和组次。
4. 校验 `duration >= 0`、`sets >= 0`、`weight >= 0`、`reps >= 0`。
5. 服务端保存原始会话数据，统计值通过查询聚合或可重建汇总生成。

#### 待确认

- 重复 `id` 是覆盖、忽略还是冲突。
- 同一用户同一天是否允许多条训练会话。
- 服务端是否保留未完成组。
- 成功响应是否返回服务端版本和更新时间。

建议目标响应：

```json
{
  "code": 200,
  "msg": "saved",
  "data": {
    "id": "E9FDC2F9-46B1-4530-92F4-0D85126B5001",
    "version": 1,
    "synced_at": "2026-07-14T10:16:00Z"
  }
}
```

## 7. 查询训练记录

### `GET /api/training/gettraining`

用途：按日期查询当前用户的训练历史。

鉴权：客户端可选 Bearer；目标规范建议强制鉴权。

#### Query 参数

| 参数 | 类型 | 必填 | 格式 |
|---|---|---:|---|
| `date` | string | 客户端可省略 | `yyyy-MM-dd` |

请求示例：

```http
GET /api/training/gettraining?date=2026-07-14
Authorization: Bearer <token>
```

#### 成功响应

```json
{
  "code": 200,
  "msg": "ok",
  "data": [
    {
      "date": "2026-07-14",
      "summary": {
        "total_volume": 5400,
        "total_duration": 2700,
        "focus_areas": ["Chest", "Triceps"]
      },
      "exercises": [
        {
          "exercise_name": "Barbell Bench Press",
          "max_weight": 60,
          "sets": 3,
          "detailed_sets": [
            {
              "id": "1C5894F3-4030-4FAE-9B2C-E5C3BE178001",
              "weight": 60,
              "reps": 10,
              "is_completed": true
            }
          ]
        }
      ]
    }
  ]
}
```

#### 响应字段

| 字段 | 类型 | 说明 |
|---|---|---|
| `date` | string | `yyyy-MM-dd` |
| `summary.total_volume` | number | 完成组的重量 × 次数之和，实际口径待确认 |
| `summary.total_duration` | number | 秒 |
| `summary.focus_areas` | string[] | 训练部位 |
| `exercise_name` | string | 动作名 |
| `max_weight` | number | 最大重量 |
| `sets` | integer | 组数 |
| `detailed_sets` | ExerciseSet[] | 组明细 |

#### 无数据

当前客户端将 HTTP 404 视为无记录：

```json
{
  "code": 40400,
  "msg": "training record not found",
  "data": null
}
```

更推荐返回 HTTP 200 和空数组，减少“无数据”与“错误”混淆。

#### 客户端转换

- 只读取 `data.first`。
- `focusArea` 由 `focus_areas` 拼接。
- 动作目标次数取第一组次数，缺失时默认 10。
- 完整 Exercise 元数据无法从该响应恢复，部分字段使用默认值。

#### 待确认

- 不传 `date` 时的行为。
- 返回数组的原因和排序。
- 多会话是否已经聚合。
- `total_volume` 精确定义。

## 8. A2A 接口

A2A 客户端存在于仓库，但主界面调用被注释，不属于当前正式主流程。其响应不遵循 REST 统一信封。

### 8.1 `POST /a2a/v1/message`

#### 请求

```json
{
  "a2a_version": "1.0",
  "message_id": "16E0E4BF-0371-49E9-A36F-C9F04D850001",
  "session_id": "sess_stream",
  "sender": {
    "agent_id": "ios_app_agent",
    "agent_name": "iOS智能体"
  },
  "recipient": {
    "agent_id": "backend_agent"
  },
  "type": "request",
  "action": "chat_stream",
  "payload": {
    "prompt": "制定今天的训练建议"
  }
}
```

已出现 action：

- `chat_stream`：代码使用。
- `query_weather`：注释示例。
- `generate_article`：注释示例。

同步模式响应被当作任意 JSON 字典解析，完整 schema 待确认。

#### SSE 流式响应

```text
data: {"payload":{"content":"今天"}}

data: {"payload":{"content":"建议训练胸部"}}
```

要求响应头为 `text/event-stream`，按空行分隔事件。当前客户端帧缓冲实现较弱，上线前需联调断包、粘包、心跳、结束和错误事件。

### 8.2 `POST /a2a/v1/stream/stop/{taskID}`

用途：停止流式任务。

| 参数 | 位置 | 类型 | 说明 |
|---|---|---|---|
| `taskID` | Path | string | 客户端当前生成 8 位 UUID 前缀 |

无请求体、无鉴权，客户端不解析响应。

建议目标响应：

```json
{
  "code": 200,
  "msg": "stream stopped",
  "data": {
    "task_id": "A1B2C3D4",
    "status": "cancelled"
  }
}
```

待确认 taskID 与 message/session 的关联、鉴权和幂等行为。

## 9. 第三方接口

### 9.1 DashScope Qwen（实验）

```http
POST https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation
Authorization: Bearer <DASHSCOPE_API_KEY>
Content-Type: application/json
```

```json
{
  "model": "qwen-turbo",
  "input": {
    "messages": [
      {
        "role": "user",
        "content": "<OCR 文本与结构化提示词>"
      }
    ]
  },
  "parameters": {
    "result_format": "text"
  }
}
```

客户端读取 `output.text` 并尝试解析日程 JSON。

安全要求：源码中的 API Key 必须立即轮换；正式功能必须由后端代理调用，客户端不得持有长期第三方密钥。

### 9.2 OpenFoodFacts（实验）

```http
GET https://world.openfoodfacts.org/cgi/search.pl?search_terms=<name>&json=1
```

客户端取第一条产品的 `nutriments["energy-kcal"]`。上线前需增加 URL 编码、超时、空结果、限流和数据准确性说明。

## 10. 未实现接口建议

为支持跨设备和稳定同步，后续可新增：

```text
POST   /api/auth/refresh
POST   /api/auth/logout
GET    /api/plans/current
PUT    /api/plans/current
DELETE /api/plans/current
GET    /api/training/sessions
GET    /api/training/sessions/{id}
PUT    /api/training/sessions/{id}
DELETE /api/training/sessions/{id}
GET    /api/exercises
```

新增前应先提供 OpenAPI 3.1 文档、版本策略、迁移和客户端兼容方案。

## 11. 接口验收清单

- [ ] 所有正式接口使用 HTTPS。
- [ ] 后端确认完整错误码和 HTTP 映射。
- [ ] 明确每个接口是否强制登录。
- [ ] Apple 凭证验证与用户唯一约束已测试。
- [ ] 训练保存具备幂等性和事务性。
- [ ] 日期、时区和同日多会话规则已统一。
- [ ] 401、404、429、5xx 和超时已联调。
- [ ] 请求和日志不泄露 Token。
- [ ] AI 生成具备超时、限流和请求追踪。
- [ ] OpenAPI 与 iOS Codable 契约自动校验。

