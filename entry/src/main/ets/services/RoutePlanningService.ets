import { navi, mapCommon } from '@kit.MapKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { RouteRequest, RouteResult, RoutePlanData, TravelMode, DrivingStrategy } from '../models/RouteModels';
import { common } from '@kit.AbilityKit';

export class RoutePlanningService {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async planRoute(request: RouteRequest): Promise<RouteResult> {
    try {
      switch (request.mode) {
        case TravelMode.DRIVING:
          return await this.planDrivingRoute(request);
        case TravelMode.WALKING:
          return await this.planWalkingRoute(request);
        case TravelMode.CYCLING:
          return await this.planCyclingRoute(request);
        case TravelMode.TRANSIT:
          return await this.planTransitRoute(request);
        default:
          return { success: false, plans: [], errorMsg: '不支持的出行方式' };
      }
    } catch (error) {
      const err = error as BusinessError;
      console.error(`===[路线规划] 路线规划失败: code=${err.code}, message=${err.message}===`);
      return { success: false, plans: [], errorMsg: err.message };
    }
  }

  private async planDrivingRoute(request: RouteRequest): Promise<RouteResult> {
    const drivingParams: navi.DrivingRouteParams = {
      origins: [{ latitude: request.origin.latitude, longitude: request.origin.longitude }],
      destination: {
        latitude: request.destination.latitude,
        longitude: request.destination.longitude
      },
      language: "zh-CN",
      avoids: [request.strategy || DrivingStrategy.FASTEST],
      waypoints: request.waypoints || [],
      isViaType: true,
      optimize: true,
      alternatives: true,
      departAt: request.departureTime || 0,
      trafficMode: 0
    };

    const result = await navi.getDrivingRoutes(drivingParams);

    if (!result.routes || result.routes.length === 0) {
      return { success: false, plans: [], errorMsg: '未找到驾车路线' };
    }

    const plans: RoutePlanData[] = [];
    for (let i = 0; i < result.routes.length; i++) {
      const route = result.routes[i];
      const duration = this.calculateRouteDuration(route);
      const distance = this.calculateRouteDistance(route);
      const plan: RoutePlanData = {
        id: `driving_${i}`,
        mode: TravelMode.DRIVING,
        modeName: '驾车',
        duration: duration,
        durationText: this.formatDuration(duration),
        distance: distance,
        distanceText: this.formatDistance(distance),
        summary: this.extractRouteSummary(route),
        color: this.getRouteColor(TravelMode.DRIVING),
        drivingRoute: route
      };
      plans.push(plan);
    }

    return { success: true, plans };
  }

  private async planWalkingRoute(request: RouteRequest): Promise<RouteResult> {
    const walkingParams: navi.RouteParams = {
      origins: [request.origin],
      destination: {
        latitude: request.destination.latitude,
        longitude: request.destination.longitude
      },
      language: "zh-CN"
    };

    const result = await navi.getWalkingRoutes(walkingParams);

    if (!result.routes || result.routes.length === 0) {
      return { success: false, plans: [], errorMsg: '未找到步行路线' };
    }

    const plans: RoutePlanData[] = [];
    for (let i = 0; i < result.routes.length; i++) {
      const route = result.routes[i];
      const duration = this.calculateRouteDuration(route);
      const distance = this.calculateRouteDistance(route);
      const plan: RoutePlanData = {
        id: `walking_${i}`,
        mode: TravelMode.WALKING,
        modeName: '步行',
        duration: duration,
        durationText: this.formatDuration(duration),
        distance: distance,
        distanceText: this.formatDistance(distance),
        summary: this.extractRouteSummary(route),
        color: this.getRouteColor(TravelMode.WALKING),
        walkingRoute: route
      };
      plans.push(plan);
    }

    return { success: true, plans };
  }

  private async planCyclingRoute(request: RouteRequest): Promise<RouteResult> {
    const cyclingParams: navi.RouteParams = {
      origins: [request.origin],
      destination: {
        latitude: request.destination.latitude,
        longitude: request.destination.longitude
      },
      language: "zh-CN"
    };

    const result = await navi.getCyclingRoutes(cyclingParams);

    if (!result.routes || result.routes.length === 0) {
      return { success: false, plans: [], errorMsg: '未找到骑行路线' };
    }

    const plans: RoutePlanData[] = [];
    for (let i = 0; i < result.routes.length; i++) {
      const route = result.routes[i];
      const duration = this.calculateRouteDuration(route);
      const distance = this.calculateRouteDistance(route);
      const plan: RoutePlanData = {
        id: `cycling_${i}`,
        mode: TravelMode.CYCLING,
        modeName: '骑行',
        duration: duration,
        durationText: this.formatDuration(duration),
        distance: distance,
        distanceText: this.formatDistance(distance),
        summary: this.extractRouteSummary(route),
        color: this.getRouteColor(TravelMode.CYCLING),
        cyclingRoute: route
      };
      plans.push(plan);
    }

    return { success: true, plans };
  }

  private async planTransitRoute(request: RouteRequest): Promise<RouteResult> {
    const transitParams: navi.TransitRouteParams = {
      origin: {
        latitude: request.origin.latitude,
        longitude: request.origin.longitude
      },
      destination: {
        latitude: request.destination.latitude,
        longitude: request.destination.longitude
      },
      departureTime: request.departureTime || Math.floor(Date.now() / 1000),
      preference: 0
    };

    const result = await navi.getTransitRoutes(this.context, transitParams);

    if (!result.routes || result.routes.length === 0) {
      return { success: false, plans: [], errorMsg: '未找到公交路线' };
    }

    const plans: RoutePlanData[] = [];
    for (let i = 0; i < result.routes.length; i++) {
      const route = result.routes[i];
      const duration = this.calculateTransitDuration(route);
      const distance = this.calculateTransitDistance(route);
      const plan: RoutePlanData = {
        id: `transit_${i}`,
        mode: TravelMode.TRANSIT,
        modeName: '公交',
        duration: duration,
        durationText: this.formatDuration(duration),
        distance: distance,
        distanceText: this.formatDistance(distance),
        summary: this.extractTransitSummary(route),
        color: this.getRouteColor(TravelMode.TRANSIT),
        transitRoute: route
      };
      plans.push(plan);
    }

    return { success: true, plans };
  }

  private calculateRouteDuration(route: navi.Route): number {
    let totalDuration = 0;
    if (route.steps && route.steps.length > 0) {
      for (const step of route.steps) {
        totalDuration += step.duration || 0;
      }
    }
    return totalDuration;
  }

  private calculateRouteDistance(route: navi.Route): number {
    let totalDistance = 0;
    if (route.steps && route.steps.length > 0) {
      for (const step of route.steps) {
        totalDistance += step.distance || 0;
      }
    }
    return totalDistance;
  }

  private calculateTransitDuration(route: navi.TransitRoute): number {
    // 优先从 busSortInfo 中获取总时长
    if (route.busSortInfo && route.busSortInfo.totalCost) {
      return route.busSortInfo.totalCost as number;
    }

    // 或者从 sections 的 travelSummary 累加
    let totalDuration = 0;
    if (route.sections && route.sections.length > 0) {
      for (const section of route.sections) {
        if (section.transitSection?.travelSummary && section.transitSection.travelSummary.duration) {
          totalDuration += section.transitSection.travelSummary.duration;
        }
      }
    }
    return totalDuration;
  }

  private calculateTransitDistance(route: navi.TransitRoute): number {
    // 从 sections 的 travelSummary 累加距离
    let totalDistance = 0;
    if (route.sections && route.sections.length > 0) {
      for (const section of route.sections) {
        if (section.transitSection?.travelSummary && section.transitSection.travelSummary.length) {
          totalDistance += section.transitSection.travelSummary.length;
        }
      }
    }
    return totalDistance;
  }

  private formatDuration(seconds: number): string {
    if (seconds < 60) {
      return `${seconds}秒`;
    } else if (seconds < 3600) {
      return `${Math.floor(seconds / 60)}分钟`;
    } else {
      const hours = Math.floor(seconds / 3600);
      const minutes = Math.floor((seconds % 3600) / 60);
      return `${hours}小时${minutes > 0 ? `${minutes}分钟` : ''}`;
    }
  }

  private formatDistance(meters: number): string {
    if (meters < 1000) {
      return `${Math.round(meters)}米`;
    } else {
      return `${(meters / 1000).toFixed(1)}公里`;
    }
  }

  private extractRouteSummary(route: navi.Route): string {
    const steps = route.steps || [];
    if (steps.length === 0) return '';

    const mainRoads: string[] = [];
    for (const step of steps) {
      // 从 roads 中提取道路名称
      if (step.roads && step.roads.length > 0) {
        for (const road of step.roads) {
          if (road.roadName && !mainRoads.includes(road.roadName)) {
            mainRoads.push(road.roadName);
            if (mainRoads.length >= 3) break;
          }
        }
      }

      // 如果没有道路名称，使用距离描述
      if (mainRoads.length === 0 && step.distanceDescription) {
        mainRoads.push(step.distanceDescription);
        break;
      }
    }

    return mainRoads.join(' → ');
  }

  private extractTransitSummary(route: navi.TransitRoute): string {
    const sections = route.sections || [];
    const lines: string[] = [];

    for (const section of sections) {
      // 只处理公交路段
      if (section.type === 'transit' && section.transitSection) {
        // 从 transport 中获取交通工具信息
        if (section.transitSection.transport) {
          const transport = section.transitSection.transport;

          // 优先使用 lineName（线路名称）
          if (transport.name && !lines.includes(transport.name)) {
            lines.push(transport.name);
          }
          // 其次使用 vehicleName（交通工具名称）
          else if (transport.mode && !lines.includes(transport.mode)) {
            lines.push(transport.mode);
          }
        }

        // 备用方案：直接从 transitSection 获取 lineName
        if (lines.length === 0 && section.transitSection.type) {
          lines.push(section.transitSection.type);
        }
      }
    }

    return lines.length > 0 ? lines.join(' → ') : '公交路线';
  }

  private getRouteColor(mode: TravelMode): number {
    switch (mode) {
      case TravelMode.DRIVING:
        return 0xFF2196F3;
      case TravelMode.WALKING:
        return 0xFF4CAF50;
      case TravelMode.CYCLING:
        return 0xFFFF9800;
      case TravelMode.TRANSIT:
        return 0xFF9C27B0;
      default:
        return 0xFF2196F3;
    }
  }
}
