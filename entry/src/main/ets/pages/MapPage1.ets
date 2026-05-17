// pages/MapPage1.ets - 自定义路线规划页面
import { MapComponent, map, site, mapCommon } from '@kit.MapKit';
import { common } from '@kit.AbilityKit';
import { AsyncCallback, BusinessError } from '@kit.BasicServicesKit'
import { MapViewModel } from '../viewmodel/MapViewModel';
import { LocationService } from '../services/LocationService';
import { SiteSearchService } from '../services/SiteSearchService';
import { RoutePanel } from '../components/RoutePanel';
import { RoutePlanData, TravelMode } from '../models/RouteModels';
import { SiteDetailDialog } from '../components/SiteDetailDialog';
import { RouteRenderer } from '../renderers/RouteRanderer';
import { window, KeyboardAvoidMode } from '@kit.ArkUI'

const DEFAULT_LOCATION: mapCommon.LatLng = { latitude: 39.9, longitude: 116.4 };

@Entry
@Component
struct MapPage {
  private viewModel: MapViewModel = new MapViewModel();
  private searchService: SiteSearchService = new SiteSearchService();
  private mapOptions?: mapCommon.MapOptions;
  private mapController?: map.MapComponentController;
  private callback?: AsyncCallback<map.MapComponentController>;
  private routeRenderer: RouteRenderer = new RouteRenderer();
  private searchController: SearchController = new SearchController();
  // 状态变量
  @State selectedIndex: number = 0;
  @State selectedTravelMode: TravelMode = TravelMode.DRIVING;
  // 路线规划相关状态
  @State originInput: string = '';
  @State destinationInput: string = '';
  @State isGettingLocation: boolean = false;
  @State isPlanningRoute: boolean = false;
  @State myLocationText: string = '我的位置';
  @State originLocation: mapCommon.LatLng | null = null;
  @State destinationLocation: mapCommon.LatLng | null = null;
  @State showRouteInput: boolean = false;
  @State routeErrorMsg: string = '';
  // ✅ 新增：搜索模式（起点/终点）
  @State searchMode: 'origin' | 'destination' | null = null;
  @State searchKeyword: string = '';
  // 搜索结果相关状态
  @State showSearchResults: boolean = false;
  @State currentSearchResults: site.Site[] = [];
  @State activeSearchField: 'origin' | 'destination' | null = null;
  // ✅ 删除：标记是否正在选择搜索结果（Search 组件不需要）

  // ✅ 新增：保存起点和终点的搜索结果
  @State originSearchResults: site.Site[] = [];
  @State destinationSearchResults: site.Site[] = [];
  // 周边搜索相关
  @State showNearbySearch: boolean = false;
  @State nearbySearchResults: site.Site[] = [];
  @State currentCenterLocation: mapCommon.LatLng = DEFAULT_LOCATION;
  // 地点详情对话框相关
  @Provide('selectedSite') site: site.Site | null = null;
  private siteDetailDialog?: CustomDialogController;
  // Marker 管理（借鉴 MapPage）
  private markers: map.Marker[] = [];
  private markerMap: Map<string, map.Marker> = new Map();
  private siteMap: Map<string, site.Site> = new Map();
  // POI类型列表
  private poiTypeList: Array<string> = [
    "Watch_Store",
    "SUBWAY",
    "PRIMARY_SCHOOL",
    "GENERAL_AUTO_REPAIR_SERVICE_CENTER",
    "SHOP"
  ];
  // 键盘偏移量（单位：vp）
  @State offsetNum: number = 0;

  // ========== Marker 管理（借鉴 MapPage） ==========

  private clearAllMarkers(): void {
    this.markers.forEach(m => m.remove());
    this.markers = [];
    this.markerMap.clear();
    this.siteMap.clear();
  }

  async addMarker(location: mapCommon.LatLng, name: string, siteId: string): Promise<void> {
    if (!this.mapController) return;

    try {
      const markerOptions: mapCommon.MarkerOptions = {
        position: location,
        rotation: 0,
        visible: true,
        zIndex: 0,
        alpha: 1,
        anchorU: 0.5,
        anchorV: 1,
        clickable: true,
        draggable: false,
        flat: false,
      };

      const marker = await this.mapController.addMarker(markerOptions);
      if (marker) {
        marker.setTitle(name);
        marker.setTag(siteId);
        marker.setInfoWindowAnchor(1, 1); // ✅ 新增：设置信息窗锚点
        this.markers.push(marker);
        this.markerMap.set(siteId, marker);
        console.info(`===[标记添加] ${name} (${siteId})===`);
      }
    } catch (error) {
      console.error(`===[标记添加] 失败: ${error}===`);
    }
  }

  async updateMarkersForResults(results: site.Site[]): Promise<void> {
    this.clearAllMarkers();
    for (const item of results) {
      if (item.location && item.siteId) {
        await this.addMarker(item.location, item.name || '', item.siteId);
        this.siteMap.set(item.siteId, item);
      }
    }
  }

  // ========== 搜索结果点击处理（借鉴 MapPage） ==========

  async onSearchResultClick(item: site.Site): Promise<void> {
    const detailedSite = await this.searchService.searchById(item.siteId) as site.Site;
    if (detailedSite) {
      this.siteMap.set(item.siteId, detailedSite);
      const targetMarker = this.markerMap.get(item.siteId);
      if (targetMarker) {
        targetMarker.setTitle(detailedSite.name || item.name);
      }
      const location = detailedSite.location || item.location;
      if (location) {
        this.currentCenterLocation = location;
        await this.moveCameraToLocation(location);
      }
      targetMarker?.setInfoWindowVisible(true);
    } else {
      this.currentCenterLocation = item.location || this.currentCenterLocation;
      await this.moveCameraToLocation(item.location || this.currentCenterLocation);
      const targetMarker = this.markerMap.get(item.siteId);
      targetMarker?.setInfoWindowVisible(true);
    }
    this.closeSearchResults();
  }

  async moveCameraToLocation(location: mapCommon.LatLng): Promise<void> {
    if (!this.mapController) return;
    const cameraPosition: mapCommon.CameraPosition = {
      target: location,
      zoom: 14,
      tilt: 0,
      bearing: 0,
    };
    const cameraUpdate = map.newCameraPosition(cameraPosition);
    await this.mapController.animateCamera(cameraUpdate, 1000);
  }

  // ========== 地点详情对话框 ==========

  async openSiteDetailDialog(siteId: string): Promise<void> {
    try {
      let siteData = this.siteMap.get(siteId);
      if (!siteData) {
        console.info(`===[地点详情] 从API获取: ${siteId}===`);
        siteData = await this.searchService.searchById(siteId) as site.Site;
        if (siteData) {
          this.siteMap.set(siteId, siteData);
        }
      }

      if (siteData) {
        this.site = siteData;
        if (!this.siteDetailDialog) {
          this.siteDetailDialog = new CustomDialogController({
            builder: SiteDetailDialog(),
            alignment: DialogAlignment.Center,
            customStyle: true,
            autoCancel: true
          });
        }
        this.siteDetailDialog.open();
        console.info(`===[地点详情] 对话框已打开: ${siteData.name}===`);
      } else {
        console.warn(`===[地点详情] 未找到地点信息: ${siteId}===`);
      }
    } catch (error) {
      console.error(`===[地点详情] 打开失败: ${error}===`);
    }
  }

  // ========== ✅ 新的搜索逻辑（基于 Search 组件） ==========

  // ✅ 打开搜索：设置搜索模式
  openSearch(mode: 'origin' | 'destination' | null): void {
    this.activeSearchField = mode;
    if (mode === 'origin') {
      this.searchKeyword = this.originInput;
    } else if (mode === 'destination') {
      this.searchKeyword = this.destinationInput;
    } else {
      this.searchKeyword = '';
    }
    this.showSearchResults = false;
    this.currentSearchResults = [];
  }

  // ✅ Search 组件 onChange：实时搜索
  async onSearchChange(value: string): Promise<void> {
    this.searchKeyword = value;

    if (!value.trim()) {
      this.currentSearchResults = [];
      this.showSearchResults = false;
      return;
    }

    try {
      const centerLocation = this.getCurrentCenterLocation();
      const results = await this.searchService.autoComplete(value, centerLocation);
      this.currentSearchResults = results;

      // ✅ 如果有活跃的搜索字段，保存到对应的结果集
      if (this.activeSearchField === 'origin') {
        this.originSearchResults = results;
      } else if (this.activeSearchField === 'destination') {
        this.destinationSearchResults = results;
      }

      this.showSearchResults = results.length > 0;
      await this.updateMarkersForResults(results);
      console.info(`===[搜索] 搜索到 ${results.length} 个结果===`);
    } catch (error) {
      console.error(`===[搜索] 自动补全失败: ${error}===`);
    }
  }

  // ✅ Search 组件 onSubmit：关键字搜索
  async onSearchSubmit(): Promise<void> {
    if (!this.searchKeyword.trim()) return;

    try {
      const results = await this.searchService.searchByKeyword(this.searchKeyword);
      if (results && results.length > 0) {
        this.currentSearchResults = results;

        // ✅ 如果有活跃的搜索字段，保存到对应的结果集
        if (this.activeSearchField === 'origin') {
          this.originSearchResults = results;
        } else if (this.activeSearchField === 'destination') {
          this.destinationSearchResults = results;
        }

        this.showSearchResults = true;
        await this.updateMarkersForResults(results);
        console.info(`===[搜索] 关键字搜索找到 ${results.length} 个结果===`);
      } else {
        this.currentSearchResults = [];
        this.showSearchResults = false;
      }
    } catch (error) {
      console.error(`===[搜索] 关键字搜索失败: ${error}===`);
      this.currentSearchResults = [];
      this.showSearchResults = false;
    }
  }

  // ✅ 选择搜索结果：根据当前模式设置起点或终点
  async selectSiteFromSearch(item: site.Site): Promise<void> {
    if (this.activeSearchField === 'origin') {
      // ✅ 设置为起点
      this.originInput = item.name || '';
      this.originLocation = item.location || null;
      if (item.siteId) {
        this.siteMap.set(item.siteId, item);
      }
      console.info(`===[起点选择] ${item.name}: (${item.location?.latitude}, ${item.location?.longitude})===`);

      // ✅ 移动相机到起点位置
      if (item.location) {
        await this.moveCameraToLocation(item.location);
      }

      // ✅ 显示起点的 Marker 信息窗
      if (item.siteId) {
        const targetMarker = this.markerMap.get(item.siteId);
        if (targetMarker) {
          this.markers.forEach(marker => {
            marker.setInfoWindowVisible(false);
          });
          targetMarker.setInfoWindowVisible(true);
        }
      }
    } else if (this.activeSearchField === 'destination') {
      // ✅ 设置为终点
      this.destinationInput = item.name || '';
      this.destinationLocation = item.location || null;
      if (item.siteId) {
        this.siteMap.set(item.siteId, item);
      }
      console.info(`===[终点选择] ${item.name}: (${item.location?.latitude}, ${item.location?.longitude})===`);

      // ✅ 移动相机到终点位置
      if (item.location) {
        await this.moveCameraToLocation(item.location);
      }

      // ✅ 显示终点的 Marker 信息窗
      if (item.siteId) {
        const targetMarker = this.markerMap.get(item.siteId);
        if (targetMarker) {
          this.markers.forEach(marker => {
            marker.setInfoWindowVisible(false);
          });
          targetMarker.setInfoWindowVisible(true);
        }
      }

      // ✅ 如果已经有起点，自动开始路线规划
      if (this.originLocation || this.originInput.trim()) {
        setTimeout(() => {
          this.startRoutePlanning();
        }, 500);
      }
    } else {
      // ✅ 普通搜索：只显示地点，不设置为起点或终点
      console.info(`===[普通搜索] ${item.name}: (${item.location?.latitude}, ${item.location?.longitude})===`);

      // ✅ 移动相机到该位置
      if (item.location) {
        await this.moveCameraToLocation(item.location);
      }

      // ✅ 显示 Marker 信息窗
      if (item.siteId) {
        const targetMarker = this.markerMap.get(item.siteId);
        if (targetMarker) {
          this.markers.forEach(marker => {
            marker.setInfoWindowVisible(false);
          });
          targetMarker.setInfoWindowVisible(true);
        }
      }
    }

    // ✅ 关闭搜索结果列表，但保持 Search 组件显示
    this.showSearchResults = false;
    this.currentSearchResults = [];
  }

  // ✅ 关闭搜索：清理状态
  closeSearch(): void {
    this.showSearchResults = false;
    this.activeSearchField = null;
    this.searchController.stopEditing();
    this.currentSearchResults = [];
    this.searchKeyword = '';
  }

  // ========== 旧的辅助方法（用于兼容） ==========

  async onOriginInputChange(value: string): Promise<void> {
    this.originInput = value;
    this.originLocation = null;

    if (!value.trim()) {
      this.currentSearchResults = [];
      this.originSearchResults = [];
      this.showSearchResults = false;
      return;
    }

    try {
      const centerLocation = this.getCurrentCenterLocation();
      const results = await this.searchService.autoComplete(value, centerLocation);
      this.currentSearchResults = results;
      this.originSearchResults = results;
      this.activeSearchField = 'origin';
      this.showSearchResults = results.length > 0;

      await this.updateMarkersForResults(results);
      console.info(`===[起点搜索] 自动补全找到 ${results.length} 个结果===`);
    } catch (error) {
      console.error(`===[起点搜索] 自动补全失败: ${error}===`);
    }
  }

  async onDestinationInputChange(value: string): Promise<void> {
    this.destinationInput = value;
    this.destinationLocation = null;

    if (!value.trim()) {
      this.currentSearchResults = [];
      this.destinationSearchResults = [];
      this.showSearchResults = false;
      return;
    }

    try {
      const centerLocation = this.getCurrentCenterLocation();
      const results = await this.searchService.autoComplete(value, centerLocation);
      this.currentSearchResults = results;
      this.destinationSearchResults = results;
      this.activeSearchField = 'destination';
      this.showSearchResults = results.length > 0;

      await this.updateMarkersForResults(results);
      console.info(`===[终点搜索] 自动补全找到 ${results.length} 个结果===`);
    } catch (error) {
      console.error(`===[终点搜索] 自动补全失败: ${error}===`);
    }
  }

  async onOriginSubmit(): Promise<void> {
    if (!this.originInput.trim()) return;

    try {
      const results = await this.searchService.searchByKeyword(this.originInput);
      if (results && results.length > 0) {
        this.currentSearchResults = results;
        this.originSearchResults = results;
        this.activeSearchField = 'origin';
        this.showSearchResults = true;
        await this.updateMarkersForResults(results);
        console.info(`===[起点搜索] 关键字搜索找到 ${results.length} 个结果===`);
      } else {
        this.currentSearchResults = [];
        this.originSearchResults = [];
        this.showSearchResults = false;
      }
    } catch (error) {
      console.error(`===[起点搜索] 关键字搜索失败: ${error}===`);
      this.currentSearchResults = [];
      this.originSearchResults = [];
      this.showSearchResults = false;
    }
  }

  async onDestinationSubmit(): Promise<void> {
    if (!this.destinationInput.trim()) return;

    try {
      const results = await this.searchService.searchByKeyword(this.destinationInput);
      if (results && results.length > 0) {
        this.currentSearchResults = results;
        this.destinationSearchResults = results;
        this.activeSearchField = 'destination';
        this.showSearchResults = true;
        await this.updateMarkersForResults(results);
        console.info(`===[终点搜索] 关键字搜索找到 ${results.length} 个结果===`);
      } else {
        this.currentSearchResults = [];
        this.destinationSearchResults = [];
        this.showSearchResults = false;
      }
    } catch (error) {
      console.error(`===[终点搜索] 关键字搜索失败: ${error}===`);
      this.currentSearchResults = [];
      this.destinationSearchResults = [];
      this.showSearchResults = false;
    }
  }

  async selectOriginSite(item: site.Site): Promise<void> {
    this.originInput = item.name || '';
    this.originLocation = item.location || null;
    this.showSearchResults = false;
    this.activeSearchField = null;
    console.info(`===[起点选择] ${item.name}: (${item.location?.latitude}, ${item.location?.longitude})===`);
  }

  async selectDestinationSite(item: site.Site): Promise<void> {
    this.destinationInput = item.name || '';
    this.destinationLocation = item.location || null;
    this.showSearchResults = false;
    this.activeSearchField = null;
    console.info(`===[终点选择] ${item.name}: (${item.location?.latitude}, ${item.location?.longitude})===`);
  }

  closeSearchResults(): void {
    this.showSearchResults = false;
    this.showNearbySearch = false;
    this.activeSearchField = null;
  }

  // ========== 周边搜索 ==========

  getCurrentCenterLocation(): mapCommon.LatLng {
    if (this.mapController) {
      return this.mapController.getCameraPosition().target;
    }
    return this.currentCenterLocation;
  }

  async performNearbySearch(): Promise<void> {
    try {
      const centerLocation = this.getCurrentCenterLocation();
      this.currentCenterLocation = centerLocation;
      this.showNearbySearch = true;
      const results = await this.searchService.searchNearby(centerLocation, this.poiTypeList);
      this.nearbySearchResults = results;
      await this.updateMarkersForResults(results);
      console.info(`===[周边搜索] 找到 ${results.length} 个地点===`);
    } catch (error) {
      console.error(`===[周边搜索] 失败: ${error}===`);
      this.nearbySearchResults = [];
    }
  }

  async selectNearbySiteAsDestination(item: site.Site): Promise<void> {
    this.destinationInput = item.name || '';
    this.destinationLocation = item.location || null;
    this.showNearbySearch = false;
    if (item.siteId) {
      this.siteMap.set(item.siteId, item);
    }
    console.info(`===[周边选择] 设为终点: ${item.name}===`);
    if (this.originLocation || this.originInput.trim()) {
      await this.startRoutePlanning();
    }
  }

  async selectNearbySiteAsOrigin(item: site.Site): Promise<void> {
    this.originInput = item.name || '';
    this.originLocation = item.location || null;
    this.showNearbySearch = false;
    if (item.siteId) {
      this.siteMap.set(item.siteId, item);
    }
    console.info(`===[周边选择] 设为起点: ${item.name}===`);
    if (this.destinationLocation || this.destinationInput.trim()) {
      await this.startRoutePlanning();
    }
  }

  // ========== 路线规划核心方法 ==========

  async getMyLocation(): Promise<void> {
    this.isGettingLocation = true;
    this.myLocationText = '定位中...';
    try {
      const location = await LocationService.getCurrentLocation();
      if (location) {
        this.originLocation = location;
        this.myLocationText = '已定位';
        this.currentCenterLocation = location;
        console.info(`===[位置] 获取成功===`);
      } else {
        this.originLocation = DEFAULT_LOCATION;
        this.myLocationText = '默认位置';
      }
    } catch (error) {
      this.originLocation = DEFAULT_LOCATION;
      this.myLocationText = '默认位置';
      console.error(`===[位置] 获取失败: ${error}===`);
    } finally {
      this.isGettingLocation = false;
    }
  }

  async startRoutePlanning(): Promise<void> {
    if (!this.destinationInput.trim() && !this.destinationLocation) {
      this.routeErrorMsg = '请输入终点位置';
      return;
    }

    // ✅ 优先级1：使用用户明确设置的起点位置
    let origin = this.originLocation;

    // ✅ 优先级2：如果起点有输入文本但没有位置，尝试从搜索结果获取
    if (!origin && this.originInput.trim()) {
      if (this.originSearchResults.length > 0) {
        this.originLocation = this.originSearchResults[0].location || null;
        origin = this.originLocation;
        console.info(`===[路线规划] 使用起点搜索结果第一条作为起点===`);
      }
    }

    // ✅ 优先级3：如果还是没有起点，尝试获取当前位置
    if (!origin) {
      try {
        const currentLocation = await LocationService.getCurrentLocation();
        if (currentLocation) {
          this.originLocation = currentLocation;
          origin = currentLocation;
          this.myLocationText = '已定位';
          console.info(`===[路线规划] 使用当前位置作为起点===`);
        }
      } catch (error) {
        console.warn(`===[路线规划] 获取当前位置失败: ${error}===`);
      }
    }

    // ✅ 优先级4：使用默认位置（最后手段）
    if (!origin) {
      origin = DEFAULT_LOCATION;
      this.originLocation = DEFAULT_LOCATION;
      console.info(`===[路线规划] 使用默认起点（天安门）===`);
    }

    // ✅ 优先级1：使用用户明确设置的终点位置
    let destination = this.destinationLocation;

    // ✅ 优先级2：如果终点有输入文本但没有位置，尝试从搜索结果获取
    if (!destination && this.destinationInput.trim()) {
      if (this.destinationSearchResults.length > 0) {
        this.destinationLocation = this.destinationSearchResults[0].location || null;
        destination = this.destinationLocation;
        console.info(`===[路线规划] 使用终点搜索结果第一条作为终点===`);
      } else {
        // ✅ 优先级3：如果还没有搜索结果，执行关键字搜索
        await this.onDestinationSubmit();
        if (this.destinationSearchResults.length > 0) {
          this.destinationLocation = this.destinationSearchResults[0].location || null;
          destination = this.destinationLocation;
        }
      }
    }

    // ✅ 如果仍然没有有效终点，报错
    if (!destination) {
      this.routeErrorMsg = '请输入有效的终点';
      return;
    }

    this.isPlanningRoute = true;
    this.routeErrorMsg = '';

    console.info(`===[路线规划] 起点: (${origin.latitude}, ${origin.longitude})===`);
    console.info(`===[路线规划] 终点: (${destination.latitude}, ${destination.longitude})===`);

    try {
      await this.viewModel.planRoute(origin, destination, this.selectedTravelMode);

      this.clearAllMarkers();
      if (this.mapController && this.viewModel.routePlans.length > 0 && this.viewModel.selectedRouteId) {
        const selectedRoute = this.viewModel.routePlans.find(p => p.id === this.viewModel.selectedRouteId);
        if (selectedRoute) {
          this.routeRenderer.setMapController(this.mapController);
          await this.routeRenderer.drawRoute(selectedRoute);
          await this.routeRenderer.drawStartEndMarkers(origin, destination);
          await this.routeRenderer.fitMapToStartEndPoints(origin, destination);
        }
      }
    } catch (error) {
      console.error(`===[路线规划] 失败: ${error}===`);
      this.routeErrorMsg = '路线规划失败，请重试';
    } finally {
      this.isPlanningRoute = false;
    }
  }

  async changeTravelMode(mode: TravelMode): Promise<void> {
    this.selectedTravelMode = mode;
    if (this.destinationLocation || this.destinationInput.trim()) {
      await this.startRoutePlanning();
    }
  }

  clearRoute(): void {
    this.viewModel.clearRoute();
    this.routeRenderer.clear();
    this.originLocation = null;
    this.destinationLocation = null;
    this.originInput = '';
    this.destinationInput = '';
    this.myLocationText = '我的位置';
    this.routeErrorMsg = '';
    this.closeSearchResults();
  }

  // ========== 生命周期 ==========

  onPageShow(): void {
    try {
      window.getLastWindow(this.getUIContext().getHostContext()).then(currentWindow => {
        currentWindow.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.NONE);
        console.info(`===窗口初始化完成===`);
      });
    } catch (exception) {
      console.error(`===窗口初始化失败: ${exception}===`);
    }
    if (this.mapController) {
      this.mapController.show();
    }
  }

  onPageHide(): void {
    if (this.mapController) {
      this.mapController.hide();
    }
  }

  aboutToAppear(): void {
    try {
      window.getLastWindow(this.getUIContext().getHostContext()).then(currentWindow => {
        currentWindow.on('keyboardHeightChange', (height: number) => {
          if (height > 0) {
            this.getUIContext().animateTo({ duration: 200, curve: Curve.Smooth }, () => {
              this.offsetNum = this.getUIContext().px2vp(height);
            });
            console.info(`===键盘已弹起，高度：${this.offsetNum} vp===`);
          } else {
            this.getUIContext().animateTo({ duration: 200, curve: Curve.Smooth }, () => {
              this.offsetNum = 0;
            });
            console.info(`===键盘已收起===`);
          }
        });
      });
    } catch (error) {
      let err = error as BusinessError;
      console.error(`===getLastWindow失败: code=${err.code}===`);
    }

    this.mapOptions = {
      position: { target: DEFAULT_LOCATION, zoom: 14 },
      mapType: mapCommon.MapType.STANDARD,
      scaleControlsEnabled: true,
      rotateGesturesEnabled: true,
      zoomGesturesEnabled: true,
      scrollGesturesEnabled: true,
      alwaysShowScaleEnabled: true,
      compassControlsEnabled: true
    };

    this.initMapCallback();

    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.viewModel.setContext(context);
  }

  private initMapCallback(): void {
    this.callback = async (err: BusinessError, mapController: map.MapComponentController) => {
      if (err) {
        console.error(`===地图初始化失败：${err.code}===`);
        return;
      }

      this.mapController = mapController;
      this.viewModel.setMapController(mapController);
      this.routeRenderer.setMapController(mapController);
      mapController.setApproveNumberEnabled(true);

      const eventManager = mapController.getEventManager();

      const hasPermission = await LocationService.checkPermissions();
      if (!hasPermission) {
        await LocationService.requestPermissions(this.getUIContext().getHostContext() as common.UIAbilityContext);
      }
      mapController.setMyLocationEnabled(true);
      mapController.setMyLocationControlsEnabled(true);

      eventManager.on("myLocationButtonClick", () => this.getMyLocation());

      eventManager.on("infoWindowClick", (marker: map.Marker) => {
        const siteId = marker.getTag() as string;
        if (siteId) {
          console.info(`===[Marker点击] siteId: ${siteId}===`);
          this.openSiteDetailDialog(siteId);
        }
      });

      await this.viewModel.initMap();
    };
  }

  // ========== Build ==========

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 地图组件（占满全屏）
      MapComponent({ mapOptions: this.mapOptions, mapCallback: this.callback })
        .width('100%')
        .height('100%')

      // ✅ 整个内容区域（包含顶部操作栏 + 搜索结果列表）
      Column() {
        // ✅ 顶部控制区域容器（固定在顶部，不随键盘移动）
        Column() {
          // 第一行：路线规划切换按钮 + 周边搜索按钮
          Flex({ direction: FlexDirection.Row, justifyContent: FlexAlign.SpaceEvenly }) {
            Button('🛣️ 路线规划')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .height(42)
              .layoutWeight(1)
              .margin({ right: 8 })
              .borderRadius(21)
              .linearGradient({
                angle: 135,
                colors: this.showRouteInput ? [['#FF5722', 0.0], ['#E64A19', 1.0]] :
                  [['#2196F3', 0.0], ['#1976D2', 1.0]]
              })
              .fontColor(Color.White)
              .onClick(() => {
                this.showRouteInput = !this.showRouteInput;
                if (!this.showRouteInput) {
                  this.closeSearch();
                }
              })

            Button(' 周边')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .height(42)
              .layoutWeight(1)
              .margin({ left: 8 })
              .borderRadius(21)
              .backgroundColor(this.showNearbySearch ? '#FF9800' : '#4CAF50')
              .fontColor(Color.White)
              .onClick(() => {
                this.showNearbySearch = !this.showNearbySearch;
                if (this.showNearbySearch) {
                  this.performNearbySearch();
                  this.showRouteInput = false;
                }
              })
          }
          .width('100%')
          .padding({
            left: 16,
            right: 16,
            top: 8,
            bottom: 4
          })

          // ✅ 路线规划输入面板（使用 Search 组件）
          if (this.showRouteInput) {
            Column({ space: 6 }) {
              // ✅ 起点和终点按钮（点击打开搜索）
              Flex({
                direction: FlexDirection.Row,
                justifyContent: FlexAlign.SpaceBetween,
                alignItems: ItemAlign.Center
              }) {
                // 起点按钮
                Row() {
                  Image($r('sys.media.ohos_ic_public_location'))
                    .width(20)
                    .height(20)
                    .fillColor('#4CAF50')
                  Text(this.originInput || '起点')
                    .fontSize(13)
                    .fontColor(this.originInput ? '#333333' : '#999999')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width('38%')
                .height(40)
                .padding({ left: 10, right: 10 })
                .borderRadius(8)
                .borderWidth(1)
                .borderColor('#E0E0E0')
                .backgroundColor(Color.White)
                .onClick(() => {
                  this.openSearch('origin');
                })

                // 我的位置按钮
                Button(this.myLocationText)
                  .fontSize(11)
                  .height(34)
                  .borderRadius(17)
                  .backgroundColor(this.originLocation ? '#4CAF50' : '#FF9800')
                  .fontColor(Color.White)
                  .enabled(!this.isGettingLocation)
                  .onClick(() => this.getMyLocation())

                // 终点按钮
                Row() {
                  Image($r('sys.media.ohos_ic_public_location'))
                    .width(20)
                    .height(20)
                    .fillColor('#F44336')
                  Text(this.destinationInput || '终点')
                    .fontSize(13)
                    .fontColor(this.destinationInput ? '#333333' : '#999999')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width('38%')
                .height(40)
                .padding({ left: 10, right: 10 })
                .borderRadius(8)
                .borderWidth(1)
                .borderColor('#E0E0E0')
                .backgroundColor(Color.White)
                .onClick(() => {
                  this.openSearch('destination');
                })
              }
              .width('100%')
              .padding({ left: 10, right: 10 })

              // ✅ Search 组件（始终显示）
              Search({
                controller: this.searchController,
                placeholder: this.activeSearchField === 'origin' ? '搜索起点...' :
                  (this.activeSearchField === 'destination' ? '搜索终点...' : '搜索地点...'),
                value: this.searchKeyword
              })
                .width('100%')
                .searchButton('搜索')
                .onChange((value: string) => {
                  this.onSearchChange(value);
                })
                .onSubmit(() => {
                  this.onSearchSubmit();
                })
                .onBlur(()=>{
                  this.closeSearch();
                })

              if (this.routeErrorMsg) {
                Text(this.routeErrorMsg)
                  .fontSize(12)
                  .fontColor('#F44336')
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding({ bottom: 4 })
              }

              // 出行方式选择
              Flex({
                direction: FlexDirection.Row,
                justifyContent: FlexAlign.SpaceEvenly,
                alignItems: ItemAlign.Center
              }) {
                Button('🚗 驾车')
                  .backgroundColor(this.selectedTravelMode === TravelMode.DRIVING ? '#2196F3' : '#9E9E9E')
                  .fontColor(Color.White)
                  .fontSize(12)
                  .height(34)
                  .borderRadius(17)
                  .onClick(() => this.changeTravelMode(TravelMode.DRIVING))

                Button('🚌 公交')
                  .backgroundColor(this.selectedTravelMode === TravelMode.TRANSIT ? '#9C27B0' : '#9E9E9E')
                  .fontColor(Color.White)
                  .fontSize(12)
                  .height(34)
                  .borderRadius(17)
                  .onClick(() => this.changeTravelMode(TravelMode.TRANSIT))

                Button(' 步行')
                  .backgroundColor(this.selectedTravelMode === TravelMode.WALKING ? '#4CAF50' : '#9E9E9E')
                  .fontColor(Color.White)
                  .fontSize(12)
                  .height(34)
                  .borderRadius(17)
                  .onClick(() => this.changeTravelMode(TravelMode.WALKING))

                Button('🚴 骑行')
                  .backgroundColor(this.selectedTravelMode === TravelMode.CYCLING ? '#FF9800' : '#9E9E9E')
                  .fontColor(Color.White)
                  .fontSize(12)
                  .height(34)
                  .borderRadius(17)
                  .onClick(() => this.changeTravelMode(TravelMode.CYCLING))
              }
              .width('100%')
              .padding({ left: 10, right: 10 })

              Flex({
                direction: FlexDirection.Row,
                justifyContent: FlexAlign.SpaceEvenly,
                alignItems: ItemAlign.Center
              }) {
                Button('▶️ 开始规划')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .height(40)
                  .width('58%')
                  .borderRadius(20)
                  .backgroundColor(this.isPlanningRoute ? '#BDBDBD' : '#4CAF50')
                  .fontColor(Color.White)
                  .enabled(!this.isPlanningRoute)
                  .onClick(() => this.startRoutePlanning())

                Button('🗑️ 清空')
                  .fontSize(14)
                  .height(36)
                  .borderRadius(18)
                  .backgroundColor('#F44336')
                  .fontColor(Color.White)
                  .onClick(() => this.clearRoute())
              }
              .width('100%')
              .padding({ left: 10, right: 10, bottom: 6 })
            }
            .width('100%')
            .backgroundColor('#F5F5F5')
            .borderRadius(12)
            .margin({ left: 8, right: 8, top: 4 })
          }

          // 地图类型切换
          Flex({ direction: FlexDirection.Row, justifyContent: FlexAlign.SpaceEvenly, alignItems: ItemAlign.Center }) {
            Button('标准')
              .backgroundColor(this.selectedIndex === 0 ? '#2196F3' : '#9E9E9E')
              .fontColor(Color.White)
              .fontSize(11)
              .height(30)
              .borderRadius(15)
              .onClick(() => {
                this.selectedIndex = 0;
                this.viewModel.switchMapType(mapCommon.MapType.STANDARD);
              })

            Button('地形')
              .backgroundColor(this.selectedIndex === 1 ? '#2196F3' : '#9E9E9E')
              .fontColor(Color.White)
              .fontSize(11)
              .height(30)
              .borderRadius(15)
              .onClick(() => {
                this.selectedIndex = 1;
                this.viewModel.switchMapType(mapCommon.MapType.TERRAIN);
              })

            Button('卫星')
              .backgroundColor(this.selectedIndex === 2 ? '#2196F3' : '#9E9E9E')
              .fontColor(Color.White)
              .fontSize(11)
              .height(30)
              .borderRadius(15)
              .onClick(() => {
                this.selectedIndex = 2;
                this.viewModel.switchMapType(mapCommon.MapType.SATELLITE);
              })

            Button('混合')
              .backgroundColor(this.selectedIndex === 3 ? '#2196F3' : '#9E9E9E')
              .fontColor(Color.White)
              .fontSize(11)
              .height(30)
              .borderRadius(15)
              .onClick(() => {
                this.selectedIndex = 3;
                this.viewModel.switchMapType(mapCommon.MapType.HYBRID);
              })
          }
          .width('100%')
          .padding({
            left: 16,
            right: 16,
            top: 4,
            bottom: 8
          })
        }
        .width('100%')
        .backgroundColor('#FAFAFA')

        // ✅ 搜索结果列表（占据操作栏下方到键盘上方的所有空间）
        if (this.showSearchResults && this.currentSearchResults.length > 0) {
          Column() {
            // 标题栏
            Row() {
              Text(this.activeSearchField === 'origin' ? `🔍 搜索起点 (共${this.currentSearchResults.length}个)` :
                (this.activeSearchField === 'destination' ? `🔍 搜索终点 (共${this.currentSearchResults.length}个)` :
                  `🔍 搜索地点 (共${this.currentSearchResults.length}个)`))
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#333333')
              Blank()
              Image($r('sys.media.ohos_ic_public_cancel'))
                .width(24)
                .height(24)
                .onClick(() => {
                  this.closeSearch();
                })
            }
            .width('100%')
            .padding({
              left: 12,
              right: 12,
              top: 8,
              bottom: 4
            })
            .backgroundColor('#FAFAFA')

            // 搜索结果列表
            List({ space: 5 }) {
              ForEach(this.currentSearchResults, (item: site.Site) => {
                ListItem() {
                  Row({ space: 12 }) {
                    Image($r('app.media.startIcon'))
                      .width(40)
                      .height(40)

                    Column({ space: 4 }) {
                      Text(item.name || '未知')
                        .fontSize(14)
                        .fontWeight(FontWeight.Medium)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })

                      Text(item.formatAddress || '地址未知')
                        .fontSize(12)
                        .fontColor('#666666')
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)

                    // ✅ 如果不是起点/终点搜索模式，显示操作按钮
                    if (!this.activeSearchField) {
                      Column({ space: 4 }) {
                        Button('起点')
                          .fontSize(10)
                          .height(24)
                          .borderRadius(12)
                          .backgroundColor('#2196F3')
                          .fontColor(Color.White)
                          .onClick(async () => {
                            this.activeSearchField = 'origin';
                            await this.selectSiteFromSearch(item);
                          })
                        Button('终点')
                          .fontSize(10)
                          .height(24)
                          .borderRadius(12)
                          .backgroundColor('#4CAF50')
                          .fontColor(Color.White)
                          .onClick(async () => {
                            this.activeSearchField = 'destination';
                            await this.selectSiteFromSearch(item);
                          })
                      }
                    }
                  }
                  .padding(12)
                  .width('100%')
                }
                .onClick(async () => {
                  await this.selectSiteFromSearch(item);
                  this.closeSearch();
                })
              })
            }
            .width('100%')
            .layoutWeight(1)
            .backgroundColor('#FFFFFF')
          }
          .width('100%')
          .layoutWeight(1)
          .backgroundColor('#F5F5F5')
          .borderRadius({ bottomLeft: 12, bottomRight: 12 })
          .shadow({ radius: 10, color: '#33000000', offsetY: 2 })
        }

        // ✅ 周边搜索结果面板
        if (this.showNearbySearch && this.nearbySearchResults.length > 0) {
          Column() {
            Row() {
              Text(`📍 周边地点 (共${this.nearbySearchResults.length}个)`)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#333333')
              Blank()
              Image($r('sys.media.ohos_ic_public_cancel'))
                .width(24)
                .height(24)
                .onClick(() => {
                  this.showNearbySearch = false;
                })
            }
            .width('100%')
            .padding({
              left: 12,
              right: 12,
              top: 8,
              bottom: 4
            })
            .backgroundColor('#FAFAFA')

            List({ space: 5 }) {
              ForEach(this.nearbySearchResults, (item: site.Site) => {
                ListItem() {
                  Row({ space: 12 }) {
                    Image($r('app.media.startIcon'))
                      .width(40)
                      .height(40)

                    Column({ space: 4 }) {
                      Text(item.name || '未知')
                        .fontSize(14)
                        .fontWeight(FontWeight.Medium)
                      Text(item.formatAddress || '地址未知')
                        .fontSize(12)
                        .fontColor('#666666')
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)

                    Column({ space: 4 }) {
                      Button('起点')
                        .fontSize(10)
                        .height(24)
                        .borderRadius(12)
                        .backgroundColor('#2196F3')
                        .fontColor(Color.White)
                        .onClick(async () => {
                          await this.selectNearbySiteAsOrigin(item);
                        })
                      Button('终点')
                        .fontSize(10)
                        .height(24)
                        .borderRadius(12)
                        .backgroundColor('#4CAF50')
                        .fontColor(Color.White)
                        .onClick(async () => {
                          await this.selectNearbySiteAsDestination(item);
                        })
                    }
                  }
                  .padding(12)
                  .width('100%')
                  .backgroundColor(Color.White)
                }
                .onClick(async () => {
                  // ✅ 点击列表项：移动相机到该位置并显示信息窗
                  if (item.location) {
                    await this.moveCameraToLocation(item.location);

                    // ✅ 显示对应 Marker 的信息窗
                    if (item.siteId) {
                      const targetMarker = this.markerMap.get(item.siteId);
                      if (targetMarker) {
                        // 先隐藏其他所有信息窗
                        this.markers.forEach(marker => {
                          marker.setInfoWindowVisible(false);
                        });
                        // 显示目标 Marker 的信息窗
                        targetMarker.setInfoWindowVisible(true);
                        console.info(`===[周边搜索] 显示信息窗: ${item.name}===`);
                      }
                    }

                    console.info(`===[周边搜索] 相机移动到: ${item.name} (${item.location.latitude}, ${item.location.longitude})===`);
                  }
                  this.showNearbySearch = false;
                })
              })
            }
            .width('100%')
            .layoutWeight(1)
            .backgroundColor('#FFFFFF')
          }
          .width('100%')
          .layoutWeight(1)
          .backgroundColor('#F5F5F5')
          .borderRadius({ bottomLeft: 12, bottomRight: 12 })
          .shadow({ radius: 10, color: '#33000000', offsetY: 2 })
        }

        // 路线规划结果面板
        if (this.viewModel.showRoutePanel) {
          RoutePanel({
            routes: this.viewModel.routePlans,
            selectedRouteId: this.viewModel.selectedRouteId,
            onRouteSelected: (route: RoutePlanData) => {
              this.viewModel.selectRoute(route);
            },
            onClose: () => {
              this.viewModel.showRoutePanel = false;
            }
          })
            .width('100%')
            .height('35%')
            .position({ x: 0, y: '45%' })
            .zIndex(200)
        }
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
  }
}