效果：

![](鸿蒙地图效果.gif)

```markdown
# WeiMap - 鸿蒙地图应用

## 项目概述

**WeiMap** 是一款基于 HarmonyOS 6.1.0 平台开发的智能地图导航应用，采用 ArkTS 语言和 Stage 应用模型构建。该应用集成了华为 Map Kit、Location Kit 等核心系统能力，提供地图展示、地点搜索、路线规划、位置服务等综合功能。

- **包名**: com.wei.WeiMap
- **版本**: 1.0.0 (versionCode: 1000000)
- **开发时间**: 2026年5月
- **目标平台**: HarmonyOS 6.1.0 (API Level 23)
- **支持设备**: 手机、平板、二合一设备、车机、可穿戴设备、电视

---

## 技术栈

### 核心技术
- **开发语言**: ArkTS (TypeScript 扩展)
- **UI 框架**: ArkUI (声明式 UI)
- **应用模型**: Stage 模型
- **构建工具**: Hvigor

### 华为 Kit 集成
- **@kit.MapKit**: 地图服务（地图渲染、Marker 标注、路线规划、地点搜索）
- **@kit.LocationKit**: 定位服务（获取当前位置）
- **@kit.AbilityKit**: 应用能力管理（权限请求、UIAbility 生命周期）
- **@kit.BasicServicesKit**: 基础服务（错误处理、异步回调）
- **@kit.PerformanceAnalysisKit**: 性能分析日志
- **@kit.ArkUI**: UI 组件库（窗口管理、路由跳转）

### 依赖管理
- **ohpm**: OpenHarmony Package Manager
- 测试依赖: @ohos/hypium@1.0.25, @ohos/hamock@1.0.0

---

## 项目架构

### 整体设计模式
采用 **MVVM (Model-View-ViewModel)** 架构模式，结合 **Service Layer** 和 **Renderer** 分层设计：

```



┌─────────────────────────────────────┐
│         View Layer (UI)             │
│  MapPage, Components, Dialogs       │
└──────────────┬──────────────────────┘
│
┌──────────────▼──────────────────────┐
│      ViewModel Layer                │
│      MapViewModel (@Observed)       │
└──────────────┬──────────────────────┘
│
┌──────────────▼──────────────────────┐
│      Service Layer                  │
│ LocationService, MarkerService,     │
│ SiteSearchService, RoutePlanning... │
└──────────────┬──────────────────────┘
│
┌──────────────▼──────────────────────┐
│      Renderer Layer                 │
│      RouteRenderer                  │
└──────────────┬──────────────────────┘
│
┌──────────────▼──────────────────────┐
│      Model Layer                    │
│  RouteModels, SiteModel             │
└─────────────────────────────────────┘
```
### 目录结构

```

entry/src/main/ets/
├── components/              # UI 组件层
│   ├── MapTypeSwitcher.ets          # 地图类型切换器
│   ├── RoutePanel.ets               # 路线方案面板
│   ├── SearchResultList.ets         # 搜索结果列表
│   └── SiteDetailDialog.ets         # 地点详情对话框
├── entryability/            # 入口 Ability
│   └── EntryAbility.ets             # 应用主入口
├── entrybackupability/      # 备份 Ability
│   └── EntryBackupAbility.ets       # 数据备份支持
├── models/                  # 数据模型层
│   ├── RouteModels.ets              # 路线规划数据模型
│   └── SiteModel.ets                # 地点数据模型
├── pages/                   # 页面层
│   ├── Index.ets                    # 启动页
│   ├── MapPage.ets                  # 旧版主地图页面（保留）
│   ├── MapPage1.ets                 # 新版重构主地图页面
│   └── tsFunction/
│       └── setPointAnnotationOptions.ets  # 辅助函数
├── renderers/               # 渲染器层
│   └── RouteRanderer.ets            # 路线绘制引擎
├── services/                # 服务层
│   ├── LocationService.ets          # 定位服务
│   ├── MapCameraService.ets         # 地图相机控制
│   ├── MarkerService.ets            # Marker 标注管理
│   ├── RoutePlanningService.ets     # 路线规划服务
│   └── SiteSearchService.ets        # 地点搜索服务
└── viewmodel/               # ViewModel 层
└── MapViewModel.ets             # 地图状态管理
```
---

## 核心模块详解

### 1. 地图页面 (MapPage1.ets)

**职责**: 主界面控制器，协调所有地图功能

**核心功能**:
- 地图初始化与生命周期管理
- 搜索框交互（关键字搜索、自动补全）
- 地图类型切换（标准、地形、卫星、混合）
- 出行方式选择（驾车、公交、步行、骑行）
- 周边搜索功能
- 路线规划面板展示
- 地点详情对话框管理

**关键技术点**:
```
typescript
// 使用 @Provide/@Consume 实现跨组件状态共享
@Provide('selectedSite') selectedSiteForDialog: site.Site | null = null;
@Provide('sitesList') sitesList: site.Site[] = [];

// MVVM 模式：通过 ViewModel 管理业务逻辑
private viewModel: MapViewModel = new MapViewModel();

// 地图回调初始化
this.callback = async (err, mapController) => {
this.viewModel.setMapController(mapController);
// 权限检查、事件监听、数据初始化
};
```
### 2. MapViewModel (MapViewModel.ets)

**职责**: 集中管理地图相关的所有状态和业务逻辑

**状态管理** (使用 @Observed 装饰器):
```
typescript
@Observed
export class MapViewModel {
currentLocation: mapCommon.LatLng           // 当前位置
searchKeyword: string                        // 搜索关键字
siteList: site.Site[]                        // 搜索结果列表
showLocationList: boolean                    // 是否显示列表
selectedMapType: mapCommon.MapType           // 地图类型

// 路线规划状态
routePlans: RoutePlanData[]                  // 路线方案列表
selectedRouteId: string                      // 选中路线 ID
showRoutePanel: boolean                      // 是否显示路线面板
routeOrigin?: mapCommon.LatLng               // 起点
routeDestination?: mapCommon.LatLng          // 终点
}
```
**核心方法**:
- `initMap()`: 初始化地图，加载默认地点
- `searchAndMarkById(siteId)`: 通过 ID 搜索并标注地点
- `searchNearby()`: 周边 POI 搜索
- `searchByKeyword(keyword)`: 关键字搜索
- `autoComplete(keyword)`: 搜索自动补全
- `getMyLocation()`: 获取当前位置
- `planRoute(origin, destination, mode)`: 路线规划
- `selectRoute(plan)`: 选择并绘制路线
- `clearRoute()`: 清除路线

### 3. 服务层 (Services)

#### LocationService.ets
**职责**: 定位权限管理与位置获取

```
typescript
static async checkPermissions(): Promise<boolean>
static async requestPermissions(context): Promise<boolean>
static async getCurrentLocation(): Promise<Location | null>
```
**特性**:
- 双重权限检查（精确位置 + 模糊位置）
- 静态方法设计，无需实例化
- 统一的错误日志格式（`===...===`）

#### MarkerService.ets
**职责**: Marker 标注的增删改查管理

```
typescript
async addMarker(siteId, position, title): Promise<Marker | null>
removeMarker(siteId): void
clearAllMarkers(): void
getMarker(siteId): Marker | undefined
showInfoWindow(siteId): void
```
**设计亮点**:
- 使用 `Map<string, Marker>` 缓存所有 Marker
- 支持延迟初始化（setMapController）
- 完善的异常捕获与日志记录

#### SiteSearchService.ets
**职责**: 地点搜索功能封装

```
typescript
async searchNearby(location, poiTypes): Promise<Site[]>
async searchByKeyword(keyword): Promise<Site[]>
async autoComplete(keyword, location): Promise<Site[]>
async searchById(siteId): Promise<Site | null>
async openLocationDetail(context, siteId): Promise<void>
```
**优化策略**:
- 内置缓存机制 (`siteCache: Map<string, Site>`)
- 避免重复 API 调用
- 统一的错误处理

#### RoutePlanningService.ets
**职责**: 多模式路线规划

**支持的出行方式**:
- 🚗 驾车 (DRIVING): 支持多种策略（最快、避开收费、避开高速等）
- 🚶 步行 (WALKING)
- 🚴 骑行 (CYCLING)
- 🚌 公交 (TRANSIT): 包含地铁、公交换乘

**核心方法**:
```
typescript
async planRoute(request: RouteRequest): Promise<RouteResult>
```
**数据处理**:
- 统一提取路线时长、距离
- 格式化显示文本（"15分钟"、"3.5公里"）
- 提取路线概要（主要道路名称）
- 为不同出行方式分配颜色标识

#### MapCameraService.ets
**职责**: 地图相机控制（移动、缩放、定位）

```
typescript
async moveTo(location, zoom, duration): Promise<void>
async zoomTo(amount): Promise<void>
setMyLocation(location): void
setMapType(mapType): void
```
### 4. 渲染器层 (Renderers)

#### RouteRanderer.ets
**职责**: 路线可视化绘制

**核心功能**:
```
typescript
async drawRoute(plan: RoutePlanData): Promise<void>
async drawStartEndMarkers(origin, destination): Promise<void>
async fitMapToStartEndPoints(origin, destination): Promise<void>
highlightRoute(plan): Promise<void>
clear(): void
```
**技术实现**:
- 从不同路线类型提取坐标点（overviewPolyline、steps、sections）
- 使用 Polyline 绘制路线轨迹
- 添加起终点 Marker 标记
- 自动调整地图视野到合适范围
- 支持多条路线管理与高亮切换

**坐标提取策略**:
```
typescript
// 驾车/步行/骑行：优先使用 overviewPolyline
if (route.overviewPolyline) return route.overviewPolyline;

// 降级：从 steps.roads.polyline 提取
for (const step of route.steps) {
if (step.roads) coordinates.push(...road.polyline);
}

// 公交：从 sections 提取
if (section.type === 'transit') {
coordinates.push(...section.transitSection.polyline);
}
```
### 5. 数据模型 (Models)

#### RouteModels.ets
**核心枚举**:
```
typescript
enum TravelMode {
DRIVING = 'driving',
WALKING = 'walking',
CYCLING = 'cycling',
TRANSIT = 'transit'
}

enum DrivingStrategy {
FASTEST = 0,        // 时间最短
AVOID_TOLL = 1,     // 避免收费
AVOID_HIGHWAY = 2,  // 避开高速
SHORT_DIST = 4,     // 距离优先
AVOID_FERRY = 8     // 避免轮渡
}
```
**核心接口**:
```
typescript
interface RoutePlanData {
id: string;
mode: TravelMode;
modeName: string;           // "驾车"、"步行"等
duration: number;           // 秒
durationText: string;       // "15分钟"
distance: number;           // 米
distanceText: string;       // "3.5公里"
summary: string;            // "长安街 → 建国路"
color: number;              // ARGB 颜色值
drivingRoute?: navi.Route;  // 原始路线数据
walkingRoute?: navi.Route;
cyclingRoute?: navi.Route;
transitRoute?: navi.TransitRoute;
}

interface RouteRequest {
origin: mapCommon.LatLng;
destination: mapCommon.LatLng;
mode: TravelMode;
waypoints?: mapCommon.LatLng[];
departureTime?: number;
strategy?: DrivingStrategy;
}
```
### 6. UI 组件 (Components)

#### MapTypeSwitcher.ets
- 四种地图类型切换按钮
- 动态背景色（选中蓝色，未选中橙色）

#### RoutePanel.ets
- 路线方案列表展示
- 显示出行方式图标、距离、时长、路线概要
- 选中状态高亮边框
- 关闭按钮

#### SearchResultList.ets
- 搜索结果列表渲染
- 空状态提示
- 点击回调传递选中的地点对象

#### SiteDetailDialog.ets
- 自定义对话框展示地点详情
- 滚动容器显示完整信息
- POI 详细信息（电话、评分、营业时间、品牌等）
- 跳转系统地图详情页按钮

---

## 关键业务流程

### 1. 应用启动流程
```

Index.ets (启动页)
↓ 点击"初始化地图"
MapPage1.ets (主地图页)
↓ aboutToAppear()
初始化 MapViewModel
↓
配置 MapOptions（中心点、缩放级别、手势等）
↓
创建地图回调 callback
↓
MapComponent 加载地图
↓
callback 被调用
↓
检查定位权限 → 请求权限（如需要）
↓
启用我的位置图层
↓
注册事件监听（myLocationButtonClick, infoWindowClick）
↓
viewModel.initMap() → 加载默认地点（天安门）
```
### 2. 地点搜索流程
```

用户输入关键字
↓ Search.onChange()
viewModel.autoComplete(keyword)
↓
SiteSearchService.autoComplete()
↓
调用 site.queryAutoComplete(params)
↓
返回候选地点列表
↓
更新 siteList 状态
↓
SearchResultList 渲染列表

用户点击"搜索"按钮
↓ Search.onSubmit()
viewModel.searchByKeyword(keyword)
↓
SiteSearchService.searchByKeyword()
↓
调用 site.geocode(params)
↓
批量添加 Marker 到地图
↓
显示搜索结果列表
```
### 3. 路线规划流程
```

用户点击搜索结果项
↓ handleSearchResultClick(item)
startRoutePlanning(destination)
↓
viewModel.planRoute(origin, destination, mode)
↓
RoutePlanningService.planRoute(request)
↓
根据 mode 调用对应 API:
- navi.getDrivingRoutes()
- navi.getWalkingRoutes()
- navi.getCyclingRoutes()
- navi.getTransitRoutes()
  ↓
  解析返回数据，提取:
- 路线坐标点
- 时长、距离
- 路线概要描述
  ↓
  返回 RouteResult
  ↓
  更新 routePlans 状态
  ↓
  显示 RoutePanel 面板
  ↓
  默认选中第一条路线
  ↓
  RouteRenderer.drawRoute(plan)
  ↓
  提取坐标点 → 添加 Polyline
  ↓
  RouteRenderer.drawStartEndMarkers()
  ↓
  添加起终点 Marker
  ↓
  RouteRenderer.fitMapToStartEndPoints()
  ↓
  调整地图视野到起终点边界
```
### 4. 地点详情查看流程
```

用户点击 Marker 的信息窗口
↓ infoWindowClick 事件触发
eventManager.on("infoWindowClick", marker)
↓
获取 marker.getTag() → siteId
↓
viewModel.openSiteDetail(siteId)
↓
SiteSearchService.searchById(siteId)
↓
检查缓存 → 命中则直接返回
↓
未命中则调用 site.searchById(params)
↓
缓存结果到 siteCache
↓
更新 selectedSite 状态
↓
打开 SiteDetailDialog
↓
展示地点详细信息
```
---

## 权限管理

### 申请的权限
```
json5
{
"name": "ohos.permission.LOCATION",
"reason": "$string:location_permission",
"usedScene": {
"abilities": ["EntryAbility"],
"when": "inuse"
}
},
{
"name": "ohos.permission.APPROXIMATELY_LOCATION",
"reason": "$string:approximately_location_permission",
"usedScene": {
"abilities": ["EntryAbility"],
"when": "inuse"
}
}
```
### 权限检查流程
```
typescript
// 静态方法检查权限
LocationService.checkPermissions()
↓
遍历 REQUIRED_PERMISSIONS
↓
调用 checkAccessToken(tokenId, permission)
↓
获取 bundleInfo.appInfo.accessTokenId
↓
atManager.checkAccessToken()
↓
返回 GrantStatus

// 动态请求权限
LocationService.requestPermissions(context)
↓
atManager.requestPermissionsFromUser(context, permissions)
↓
返回 authResults
↓
检查是否全部授权成功
```
---

## 日志规范

项目遵循统一的日志格式规范（InfoConsoleRule.md）：

```
typescript
// 正确示例
console.error(`===[路线规划] 路线规划服务未初始化===`);
console.info(`===[位置服务] 获取真实位置成功: (${lat}, ${lng})===`);
console.warn(`===[地点搜索] 关键字搜索失败: code=${code}===`);

// 日志分类标签
[路线规划] - 路线规划相关
[位置服务] - 定位相关
[地点搜索] - 搜索相关
[标记服务] - Marker 管理
[路线绘制] - 路线渲染
```
---

## 代码量统计

| 类别 | 文件数 | 估算行数 |
|------|--------|----------|
| 页面 (pages) | 3 | ~800 |
| 组件 (components) | 4 | ~400 |
| 服务 (services) | 5 | ~700 |
| 视图模型 (viewmodel) | 1 | ~270 |
| 模型 (models) | 2 | ~100 |
| 渲染器 (renderers) | 1 | ~280 |
| Ability | 2 | ~100 |
| 测试文件 | 4 | ~200 |
| **总计** | **22** | **~2850** |

---

## 配置文件说明

### app.json5
- 应用基本信息（包名、版本、图标、标签）

### module.json5
- 模块配置（name、type、deviceTypes）
- Ability 声明（EntryAbility、EntryBackupAbility）
- 权限声明（LOCATION、APPROXIMATELY_LOCATION）

### build-profile.json5
- 签名配置（调试证书路径、密钥）
- 产品配置（targetSdkVersion: 6.1.0(23)）
- 构建模式（debug、release）
- 能力声明（Map Kit）

### oh-package.json5
- 依赖管理（当前无第三方依赖）
- 开发依赖（hypium、hamock 测试框架）

---

## 潜在改进点与风险

### ✅ 优点
1. **架构清晰**: MVVM + Service Layer 分层合理，职责明确
2. **代码复用**: 服务层抽离良好，便于单元测试
3. **状态管理**: 使用 @Observed 实现响应式数据流
4. **错误处理**: 完善的 try-catch 与日志记录
5. **缓存优化**: SiteSearchService 内置缓存减少 API 调用

### ⚠️ 待改进
1. **旧代码清理**: MapPage.ets 仍保留但未使用，建议删除或迁移功能
2. **图标资源**: RoutePanel 中所有出行方式使用相同图标（car_fill），应替换为对应图标
3. **硬编码问题**: 
   - 默认地点 ID ("922204635355451392") 应配置化
   - POI 类型列表应可配置
4. **内存管理**: Marker 和 Polyline 未及时清理可能导致内存泄漏
5. **网络异常处理**: 缺少离线地图或网络重试机制
6. **性能优化**: 
   - 大量 Marker 时建议使用 MarkerCluster
   - 路线坐标点过多时可简化折线
7. **国际化**: 当前仅支持中文，可扩展多语言支持
8. **无障碍**: 缺少 TalkBack/VoiceOver 支持

### 🔒 安全风险
1. **签名文件**: build-profile.json5 中包含明文密码，应使用环境变量或密钥管理服务
2. **敏感日志**: 生产环境应关闭详细日志输出

---

## 快速开始

### 环境要求
- DevEco Studio 4.1+
- HarmonyOS SDK 6.1.0+
- 支持 Map Kit 的设备或模拟器

### 构建运行
```
bash
# 安装依赖
ohpm install

# 构建 Debug 版本
hvigorw assembleHap --mode module -p product=default -p module=entry@default

# 运行到设备
# 在 DevEco Studio 中点击 Run 按钮
```
### 调试技巧
1. 过滤日志：搜索 `===` 关键字查看所有结构化日志
2. 地图调试：开启 `setApproveNumberEnabled(true)` 显示审图号
3. 权限调试：在设置中手动授予/撤销位置权限测试不同场景

---

## 附录：关键 API 参考

### Map Kit 核心 API
- `map.MapComponentController`: 地图控制器（添加 Marker、Polyline、相机控制）
- `map.MapEventManager`: 事件管理器（监听地图加载、点击事件）
- `site.nearbySearch()`: 周边搜索
- `site.geocode()`: 地理编码（关键字搜索）
- `site.queryAutoComplete()`: 自动补全
- `site.searchById()`: 地点详情查询
- `navi.getDrivingRoutes()`: 驾车路线规划
- `navi.getWalkingRoutes()`: 步行路线规划
- `navi.getCyclingRoutes()`: 骑行路线规划
- `navi.getTransitRoutes()`: 公交路线规划

### Location Kit
- `geoLocationManager.getCurrentLocation()`: 获取当前位置
- `geoLocationManager.isLocationEnabled()`: 检查定位服务是否开启
---


```