import { map, mapCommon, navi } from '@kit.MapKit';
import { RoutePlanData, TravelMode } from '../models/RouteModels';

export class RouteRenderer {
  private mapController?: map.MapComponentController;
  private routePolylines: Map<string, map.MapPolyline[]> = new Map();
  private startMarker?: map.Marker;
  private endMarker?: map.Marker;

  setMapController(controller: map.MapComponentController): void {
    this.mapController = controller;
  }

  async drawRoute(plan: RoutePlanData): Promise<void> {
    if (!this.mapController) {
      console.error('=[路线绘制] 地图控制器未初始化');
      return;
    }

    console.info(`=[路线绘制] 开始绘制路线: ${plan.id}, 模式: ${plan.modeName}`);

    this.clearAllRoutes();

    let coordinates: mapCommon.LatLng[] = [];

    if (plan.drivingRoute) {
      console.info('=[路线绘制] 提取驾车路线坐标');
      coordinates = this.extractCoordinatesFromRoute(plan.drivingRoute);
    } else if (plan.walkingRoute) {
      console.info('=[路线绘制] 提取步行路线坐标');
      coordinates = this.extractCoordinatesFromRoute(plan.walkingRoute);
    } else if (plan.cyclingRoute) {
      console.info('=[路线绘制] 提取骑行路线坐标');
      coordinates = this.extractCoordinatesFromRoute(plan.cyclingRoute);
    } else if (plan.transitRoute) {
      console.info('=[路线绘制] 提取公交路线坐标');
      coordinates = this.extractCoordinatesFromTransitRoute(plan.transitRoute);
    } else {
      console.warn('=[路线绘制] 路线数据为空，无法提取坐标');
    }

    if (coordinates.length === 0) {
      console.warn('=[路线绘制] 路线坐标为空，无法绘制');
      console.info(`=[路线绘制] plan对象: drivingRoute=${!!plan.drivingRoute}, walkingRoute=${!!plan.walkingRoute}, cyclingRoute=${!!plan.cyclingRoute}, transitRoute=${!!plan.transitRoute}`);
      return;
    }

    console.info(`=[路线绘制] 提取到 ${coordinates.length} 个坐标点，颜色: ${plan.color.toString(16)}`);

    try {
      const polylineOptions: mapCommon.MapPolylineOptions = {
        points: coordinates,
        width: 10,
        color: plan.color,
        startCap: mapCommon.CapStyle.ROUND,
        jointType: mapCommon.JointType.ROUND,
        visible: true,
        zIndex: 100
      };

      const polyline = await this.mapController.addPolyline(polylineOptions);
      if (polyline) {
        this.routePolylines.set(plan.id, [polyline]);
        console.info(`=[路线绘制] Polyline 添加成功`);
      } else {
        console.error('=[路线绘制] Polyline 添加失败，返回值为 null');
      }

      // 注释掉原来的 fitMapToRoute，改用 fitMapToStartEndPoints
      // await this.fitMapToRoute(coordinates);
      console.info(`=[路线绘制] 路线绘制完成，等待视野调整`);
    } catch (error) {
      console.error(`=[路线绘制] 绘制失败: ${JSON.stringify(error)}`);
    }
  }

  async drawStartEndMarkers(origin: mapCommon.LatLng, destination: mapCommon.LatLng): Promise<void> {
    if (!this.mapController) return;

    this.clearMarkers();

    try {
      const startMarkerOptions: mapCommon.MarkerOptions = {
        position: origin,
        title: '起点',
        clickable: false,
        draggable: false,
        visible: true
      };
      this.startMarker = await this.mapController.addMarker(startMarkerOptions);

      const endMarkerOptions: mapCommon.MarkerOptions = {
        position: destination,
        title: '终点',
        clickable: false,
        draggable: false,
        visible: true
      };
      this.endMarker = await this.mapController.addMarker(endMarkerOptions);
    } catch (error) {
      console.error(`=添加起终点标记失败: ${JSON.stringify(error)}`);
    }
  }

  async fitMapToStartEndPoints(origin: mapCommon.LatLng, destination: mapCommon.LatLng): Promise<void> {
    if (!this.mapController) {
      console.error('=[路线绘制] 地图控制器未初始化，无法调整视野');
      return;
    }

    try {
      // 计算包含起点和终点的边界框
      const minLat = Math.min(origin.latitude, destination.latitude);
      const maxLat = Math.max(origin.latitude, destination.latitude);
      const minLng = Math.min(origin.longitude, destination.longitude);
      const maxLng = Math.max(origin.longitude, destination.longitude);

      const bounds: mapCommon.LatLngBounds = {
        southwest: { latitude: minLat, longitude: minLng },
        northeast: { latitude: maxLat, longitude: maxLng }
      };

      console.info(`=[路线绘制] 调整视野到起终点边界 - 西南: (${minLat}, ${minLng}), 东北: (${maxLat}, ${maxLng})`);

      // 使用 newLatLngBounds 创建 CameraUpdate，padding 设置为 100px
      const cameraUpdate = map.newLatLngBounds(bounds, 100);

      // 动画移动相机
      await this.mapController.animateCamera(cameraUpdate, 1000);
      console.info('=[路线绘制] 视野调整完成');
    } catch (error) {
      console.error(`=[路线绘制] 调整视野失败: ${JSON.stringify(error)}`);
    }
  }

  async highlightRoute(plan: RoutePlanData): Promise<void> {
    this.clearAllRoutes();
    await this.drawRoute(plan);
  }

  clearAllRoutes(): void {
    this.routePolylines.forEach((polylines) => {
      polylines.forEach(polyline => polyline.remove());
    });
    this.routePolylines.clear();
  }

  clearMarkers(): void {
    this.startMarker?.remove();
    this.endMarker?.remove();
    this.startMarker = undefined;
    this.endMarker = undefined;
  }

  clear(): void {
    this.clearAllRoutes();
    this.clearMarkers();
  }

  private extractCoordinatesFromRoute(route: navi.Route): mapCommon.LatLng[] {
    const coordinates: mapCommon.LatLng[] = [];

    // 优先使用 overviewPolyline（整条路线的编码折线）
    if (route.overviewPolyline && route.overviewPolyline.length > 0) {
      console.info(`使用 overviewPolyline，坐标点数: ${route.overviewPolyline.length}`);
      return route.overviewPolyline;
    }

    // 如果没有 overviewPolyline，从 steps 中提取坐标
    if (route.steps && route.steps.length > 0) {
      console.info(`从 steps 提取坐标，steps 数量: ${route.steps.length}`);

      for (const step of route.steps) {
        // 方式1: 从 roads 中提取道路坐标点
        if (step.roads && step.roads.length > 0) {
          for (const road of step.roads) {
            if (road.polyline && road.polyline.length > 0) {
              coordinates.push(...road.polyline);
            }
          }
        }

        // 方式2: 尝试从 viaWaypoints 获取途经点
        if (step.viaWaypoints && step.viaWaypoints.length > 0) {
          for (const waypoint of step.viaWaypoints) {
            if (waypoint.location) {
              coordinates.push(waypoint.location);
            }
          }
        }

        // 方式3: 如果以上都没有，至少添加起点和终点
        if (coordinates.length === 0) {
          if (step.startLocation) {
            coordinates.push(step.startLocation);
          }
          if (step.endLocation &&
              !coordinates.some(c => c.latitude === step.endLocation!.latitude &&
                                     c.longitude === step.endLocation!.longitude)) {
            coordinates.push(step.endLocation);
          }
        }
      }
    }

    console.info(`最终提取的坐标点数: ${coordinates.length}`);
    return coordinates;
  }

  private extractCoordinatesFromTransitRoute(route: navi.TransitRoute): mapCommon.LatLng[] {
    const coordinates: mapCommon.LatLng[] = [];


    // 从 sections 中提取公交和步行路段的坐标
    if (route.sections && route.sections.length > 0) {
      console.info(`从公交 sections 提取坐标，sections 数量: ${route.sections.length}`);

      for (const section of route.sections) {
        // 判断 section 类型并提取坐标
        if (section.type === 'pedestrian' && section.pedestrianSection) {
          // 步行路段：从 pedestrianSection.polyline 获取
          if (section.pedestrianSection.polyline && section.pedestrianSection.polyline.length > 0) {
            console.info(`步行路段坐标点数: ${section.pedestrianSection.polyline.length}`);
            coordinates.push(...section.pedestrianSection.polyline);
          }
        } else if (section.type === 'transit' && section.transitSection) {
          // 公交路段：从 transitSection.polyline 获取
          if (section.transitSection.polyline && section.transitSection.polyline.length > 0) {
            console.info(`公交路段坐标点数: ${section.transitSection.polyline.length}`);
            coordinates.push(...section.transitSection.polyline);
          }
        }
      }
    }

    console.info(`公交路线最终提取的坐标点数: ${coordinates.length}`);
    return coordinates;
  }

  private async fitMapToRoute(coordinates: mapCommon.LatLng[]): Promise<void> {
    if (!this.mapController || coordinates.length === 0) return;

    let minLat = coordinates[0].latitude;
    let maxLat = coordinates[0].latitude;
    let minLng = coordinates[0].longitude;
    let maxLng = coordinates[0].longitude;

    for (const coord of coordinates) {
      minLat = Math.min(minLat, coord.latitude);
      maxLat = Math.max(maxLat, coord.latitude);
      minLng = Math.min(minLng, coord.longitude);
      maxLng = Math.max(maxLng, coord.longitude);
    }

    const centerLat = (minLat + maxLat) / 2;
    const centerLng = (minLng + maxLng) / 2;

    const latDiff = maxLat - minLat;
    const lngDiff = maxLng - minLng;
    const maxDiff = Math.max(latDiff, lngDiff);

    let zoom = 15;
    if (maxDiff > 0) {
      zoom = Math.log2(360 / maxDiff) - 1;
      zoom = Math.max(10, Math.min(18, zoom));
    }

    const targetPosition: mapCommon.LatLng = { latitude: centerLat, longitude: centerLng };
    const cameraPosition: mapCommon.CameraPosition = {
      target: targetPosition,
      zoom: zoom,
      tilt: 0,
      bearing: 0
    };

    const cameraUpdate = map.newCameraPosition(cameraPosition);
    await this.mapController.animateCamera(cameraUpdate, 1000);
  }
}
