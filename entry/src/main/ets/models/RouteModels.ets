// models/RouteModels.ets
import { navi, mapCommon, map } from '@kit.MapKit';

// 出行方式枚举
export enum TravelMode {
  DRIVING = 'driving',
  WALKING = 'walking',
  CYCLING = 'cycling',
  TRANSIT = 'transit'
}

// 驾车偏好策略
export enum DrivingStrategy {
  FASTEST = 0,        // 时间最短
  AVOID_TOLL = 1,     // 避免收费
  AVOID_HIGHWAY = 2,  // 避开高速
  SHORT_DIST = 4,     // 距离优先
  AVOID_FERRY = 8     // 避免轮渡
}

// 统一的路线方案展示模型（不含polyline对象，由渲染器单独管理）
export interface RoutePlanData {
  id: string;
  mode: TravelMode;
  modeName: string;
  duration: number;        // 秒
  durationText: string;
  distance: number;        // 米
  distanceText: string;
  summary: string;         // 路线概要描述
  color: number;
  // 原始路线数据（各类型不共享父类型，分开存储）
  drivingRoute?: navi.Route;
  walkingRoute?: navi.Route;
  cyclingRoute?: navi.Route;
  transitRoute?: navi.TransitRoute;
}

// 路线规划请求参数
export interface RouteRequest {
  origin: mapCommon.LatLng;
  destination: mapCommon.LatLng;
  mode: TravelMode;
  waypoints?: mapCommon.LatLng[];     // 最多5个，仅驾车有效
  departureTime?: number;              // 未来出发时间（秒时间戳）
  strategy?: DrivingStrategy;          // 仅驾车有效
}

// 路线规划结果
export interface RouteResult {
  success: boolean;
  plans: RoutePlanData[];
  errorMsg?: string;
}