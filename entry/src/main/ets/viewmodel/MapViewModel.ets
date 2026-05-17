// viewmodel/MapViewModel.ts
import { map,mapCommon } from '@kit.MapKit';
import { LocationService } from '../services/LocationService';
import { SiteSearchService } from '../services/SiteSearchService';
import { MapMarkerService } from '../services/MarkerService';
import { MapCameraService } from '../services/MapCameraService';
import { site } from '@kit.MapKit';
import { RoutePlanningService } from '../services/RoutePlanningService';
import { RouteRenderer } from '../renderers/RouteRanderer';
import { common } from '@kit.AbilityKit';
import { RouteRequest, RouteResult, RoutePlanData, TravelMode, DrivingStrategy } from '../models/RouteModels';

const DEFAULT_LOCATION: mapCommon.LatLng = { latitude: 39.9, longitude: 116.4 };

@Observed
export class MapViewModel {
  // UI 状态
  currentLocation: mapCommon.LatLng = DEFAULT_LOCATION;
  searchKeyword: string = '';
  siteList: site.Site[] = [];
  showLocationList: boolean = false;
  selectedMapType: mapCommon.MapType = mapCommon.MapType.STANDARD;
  isLoading: boolean = false;
  selectedSite: site.Site | null=null;

  // 路径规划相关状态
  routePlans: RoutePlanData[] = [];
  selectedRouteId: string = '';
  showRoutePanel: boolean = false;
  routeOrigin?: mapCommon.LatLng;
  routeDestination?: mapCommon.LatLng;
  isRoutePlanning: boolean = false;
  private hasFitMapBounds: boolean = false;

  // 服务层实例
  private searchService = new SiteSearchService();
  private markerService = new MapMarkerService();
  private cameraService = new MapCameraService();
  private routePlanningService?: RoutePlanningService;
  private routeRenderer = new RouteRenderer();
  private mapController?: map.MapComponentController;

  setContext(context: common.UIAbilityContext): void {
    this.routePlanningService = new RoutePlanningService(context);
  }

  setMapController(controller: map.MapComponentController): void {
    this.mapController = controller;
    this.markerService.setMapController(controller);
    this.cameraService.setMapController(controller);
    this.routeRenderer.setMapController(controller);
  }

  setMapEventManager(manager: map.MapEventManager): void {
    // 注册 infoWindow 点击事件
    manager.on("infoWindowClick", (marker: map.Marker) => {
      const siteId = marker.getTag() as string;
      if (siteId) {
        this.openSiteDetail(siteId);
      }
    });
  }

  async initMap(): Promise<void> {
    await this.searchAndMarkById("922204635355451392");
  }

  async searchAndMarkById(siteId: string): Promise<void> {
    const siteData = await this.searchService.searchById(siteId);
    if (siteData?.location) {
      this.selectedSite = siteData;
      this.currentLocation = siteData.location;
      await this.cameraService.moveTo(siteData.location);
      await this.markerService.addMarker(siteId, siteData.location, siteData.name || "");
      this.markerService.showInfoWindow(siteId);
    }
  }

  async searchNearby(): Promise<void> {
    this.isLoading = true;
    const poiTypes = ["Watch_Store", "SUBWAY", "PRIMARY_SCHOOL", "GENERAL_AUTO_REPAIR_SERVICE_CENTER", "SHOP"];
    const sites = await this.searchService.searchNearby(this.currentLocation, poiTypes);
    this.siteList = sites;
    await this.batchAddMarkers(sites);
    this.showLocationList = true;
    this.isLoading = false;
  }

  async searchByKeyword(keyword: string): Promise<void> {
    if (!keyword.trim()) {
      this.siteList = [];
      this.showLocationList = true;
      return;
    }
    this.isLoading = true;
    const sites = await this.searchService.searchByKeyword(keyword);
    this.siteList = sites;
    await this.batchAddMarkers(sites);
    this.showLocationList = true;
    this.isLoading = false;
  }

  async autoComplete(keyword: string): Promise<void> {
    if (!keyword.trim()) {
      this.siteList = [];
      this.showLocationList = true;
      return;
    }
    const sites = await this.searchService.autoComplete(keyword, this.currentLocation);
    this.siteList = sites;
    this.showLocationList = true;
  }

  async getMyLocation(): Promise<void> {
    try {
      console.info('===[位置服务] 开始获取当前位置===');
      const location = await LocationService.getCurrentLocation();
      if (location) {
        this.currentLocation = location;
        await this.cameraService.moveTo(location);
        this.cameraService.setMyLocation(location);
        console.info(`===[位置服务] 获取真实位置成功: (${location.latitude}, ${location.longitude})===`);
      } else {
        console.warn('===[位置服务] 无法获取位置信息，使用默认位置（天安门 39.9, 116.4）===');
      }
    } catch (error) {
      const err = error as BusinessError;
      console.error(`===[位置服务] 获取位置失败: code=${err.code}, message=${err.message}，使用默认位置（天安门）===`);
      // 保持默认的 currentLocation 不变（39.9, 116.4）
    }
  }

  async selectSiteAndNavigate(siteItem: site.Site): Promise<void> {
    this.isLoading = true;
    const detailedSite = await this.searchService.searchById(siteItem.siteId);
    if (detailedSite?.location) {
      // 只更新标记标题和显示信息窗口，不再移动相机（由 planRoute 统一处理）
      const marker = this.markerService.getMarker(siteItem.siteId);
      if (marker) {
        marker.setTitle(detailedSite.name || siteItem.name);
        marker.setInfoWindowVisible(true);
      }
    } else if (siteItem.location) {
      // 只显示信息窗口，不再移动相机
      this.markerService.showInfoWindow(siteItem.siteId);
    }
    this.showLocationList = false;
    this.isLoading = false;
  }

  async openSiteDetail(siteId: string): Promise<void> {
    const siteData = await this.searchService.searchById(siteId);
    if (siteData) {
      this.selectedSite = siteData;
    }
  }

  switchMapType(type: mapCommon.MapType): void {
    this.selectedMapType = type;
    if (this.mapController) {
      this.mapController.setMapType(type);
    }
  }

  clearAllMarkers(): void {
    this.markerService.clearAllMarkers();
  }

  async planRoute(origin: mapCommon.LatLng, destination: mapCommon.LatLng, mode: TravelMode = TravelMode.DRIVING): Promise<void> {
    if (!this.routePlanningService) {
      console.error('===[路线规划] 路线规划服务未初始化===');
      return;
    }

    console.info(`===[路线规划] 开始规划 - 起点: (${origin.latitude}, ${origin.longitude}), ` +
      `终点: (${destination.latitude}, ${destination.longitude}), 模式: ${mode}===`);

    this.isRoutePlanning = true;
    this.routeOrigin = origin;
    this.routeDestination = destination;

    // 🆕 优化：每次规划新路线时都调整视野（通过比较起终点是否变化）
    const isSameRoute = this.routeOrigin && this.routeDestination &&
      Math.abs(this.routeOrigin.latitude - origin.latitude) < 0.000001 &&
      Math.abs(this.routeOrigin.longitude - origin.longitude) < 0.000001 &&
      Math.abs(this.routeDestination.latitude - destination.latitude) < 0.000001 &&
      Math.abs(this.routeDestination.longitude - destination.longitude) < 0.000001;

    // 如果是新路线或尚未调整过视野，则调整
    if (!isSameRoute || !this.hasFitMapBounds) {
      await this.fitMapToRouteBounds(origin, destination);
      this.hasFitMapBounds = true;
    }

    const request: RouteRequest = {
      origin: origin,
      destination: destination,
      mode: mode,
      strategy: DrivingStrategy.FASTEST
    };

    try {
      const result: RouteResult = await this.routePlanningService.planRoute(request);

      console.info(`===[路线规划] API返回 - success: ${result.success}, plans数量: ${result.plans.length}===`);
      if (result.errorMsg) {
        console.warn(`===[路线规划] 错误信息: ${result.errorMsg}===`);
      }

      if (result.success && result.plans.length > 0) {
        this.routePlans = result.plans;
        this.showRoutePanel = true;
        console.info(`===[路线规划] 规划成功，显示路线面板===`);

        // 默认选中第一条路线并绘制
        if (result.plans.length > 0) {
          console.info(`===[路线规划] 绘制第一条路线: ${result.plans[0].id}===`);
          await this.selectRoute(result.plans[0]);
        }
      } else {
        console.warn(`===[路线规划] 失败: ${result.errorMsg || '未找到路线'}===`);
        this.routePlans = [];
        this.showRoutePanel = false;
      }
    } catch (error) {
      console.error(`===[路线规划] 异常: ${JSON.stringify(error)}===`);
      this.routePlans = [];
      this.showRoutePanel = false;
    } finally {
      this.isRoutePlanning = false;
    }
  }

  async selectRoute(plan: RoutePlanData): Promise<void> {
    this.selectedRouteId = plan.id;
    await this.routeRenderer.drawRoute(plan);

    // 添加起终点标记
    if (this.routeOrigin && this.routeDestination) {
      await this.routeRenderer.drawStartEndMarkers(this.routeOrigin, this.routeDestination);
    }
  }

  async fitMapToRouteBounds(origin: mapCommon.LatLng, destination: mapCommon.LatLng): Promise<void> {
    await this.routeRenderer.fitMapToStartEndPoints(origin, destination);
  }

  switchTravelMode(mode: TravelMode): Promise<void> {
    if (this.routeOrigin && this.routeDestination) {
      return this.planRoute(this.routeOrigin, this.routeDestination, mode);
    }
    return Promise.resolve();
  }

  clearRoute(): void {
    this.routeRenderer.clear();
    this.routePlans = [];
    this.selectedRouteId = '';
    this.showRoutePanel = false;
    this.routeOrigin = undefined;
    this.routeDestination = undefined;
    this.hasFitMapBounds = false;
  }

  closeRoutePanel(): void {
    // ✅ 只关闭路线规划结果面板显示状态，不清除其他数据
    this.showRoutePanel = false;
  }

  private async batchAddMarkers(sites: site.Site[]): Promise<void> {
    this.markerService.clearAllMarkers();
    for (const item of sites) {
      if (item.location && item.siteId) {
        await this.markerService.addMarker(item.siteId, item.location, item.name || "");
      }
    }
  }
}