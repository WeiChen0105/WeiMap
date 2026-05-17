import {MapComponent,mapCommon,map,site, sceneMap} from '@kit.MapKit'
import {AsyncCallback}from'@kit.BasicServicesKit'
import { abilityAccessCtrl, bundleManager, PermissionRequestResult, Permissions,common} from '@kit.AbilityKit'
import {geoLocationManager} from '@kit.LocationKit'
import {SiteDetailDialog} from '../components/SiteDetailDialog'
import { setPointAnnotationOptions }   from  './tsFunction/setPointAnnotationOptions'
@Entry
@Component
struct MapPage {
  private TAG="Huawei Map Demo"
  private mapOptions?:mapCommon.MapOptions;
  private callback?:AsyncCallback<map.MapComponentController>;
  private mapController?:map.MapComponentController;
  private mapEventManager?:map.MapEventManager;
  private marker?:map.Marker;
  @State markers: map.Marker[] = [];    // 新增
  private markerMap: Map<string, map.Marker> = new Map();
  private siteMap: Map<string, site.Site> = new Map();   // 新增：siteId -> site 对象映射
  @Provide('selectedSite') site: site.Site | null = null;  // 共享给 dialog
  private siteDetailDialog?: CustomDialogController;
  private poiTypeList:Array<string>=[
    "Watch_Store",
    "SUBWAY",
    "PRIMARY_SCHOOL",
    "GENERAL_AUTO_REPAIR_SERVICE_CENTER",
    "SHOP"
  ]
  private clearAllMarkers() {
    this.markers.forEach(m => m.remove());
    this.markers = [];
    this.markerMap.clear();
    this.siteMap.clear();  // 新增
  }
  // "STANDARD","TERRAIN","SATELLITE","HYBRID"
  private typeList:string[]=["STANDARD","TERRAIN","SATELLITE","HYBRID"]
  @State selectedIndex:number=0
  //搜索
  @State keyword:string=""
  searchController:SearchController=new SearchController()
  @State sitesList:Array<site.Site>=[]
  @State isShowLocationList:boolean=false;
  //初始化中心点
  @State lo:mapCommon.LatLng={
    latitude:39.9,
    longitude:116.4
  }
  aboutToAppear(): void {
    let point:mapCommon.MapPoint={
      positionX:10,
      positionY:100
    }
    this.mapOptions={
      position:{
        target:this.lo,
        zoom:10
      },
      mapType:mapCommon.MapType.STANDARD,
      scaleControlsEnabled:true,
      rotateGesturesEnabled:true,
      zoomGesturesEnabled:true,
      scrollGesturesEnabled:true,
      alwaysShowScaleEnabled:true,
      compassControlsEnabled:true
    };
    //初始化可以在回调函数中再一次设置属性
    this.callback=async (err,mapController)=>{
      if(!err){
        this.mapController=mapController;
        this.mapEventManager=this.mapController.getEventManager();
        let permission = await this.checkPermissions();
        this.mapController.setScalePosition(point)
        // 显示审图号
        this.mapController.setApproveNumberEnabled(true);
        if (!permission) {
          this.requestPermissions();
          // 启用我的位置按钮
          this.mapController?.setMyLocationControlsEnabled(true);
        }
        let callback=()=>{
          console.info(this.TAG,'on-mapLoad')
        }
        this.mapEventManager.on("mapLoad",callback);
        await this.searchBySiteId("922204635355451392")
        if(this.site!=null){
          this.siteMap.set("922204635355451392",this.site)
        }
        this.markerSet(this.lo,"天安门","922204635355451392").then(() => {
          const marker = this.markerMap.get("922204635355451392");
          marker?.setInfoWindowVisible(true);
        });
        await setPointAnnotationOptions(this.mapController, this.lo, this.siteMap.get("922204635355451392")?.name || "");
        let callback1=()=>{
          console.info("=======getMyLocation========")
          this.getMyLocation()
        }
        this.mapEventManager.on("myLocationButtonClick",callback1)
        this.mapEventManager.on("infoWindowClick", (marker: map.Marker) => {
          // 方式一：如果 Marker 支持 getTag
          const siteId = marker.getTag() as string;
          if (siteId) {
            // this.queryLocationDetail(siteId);
            // 获取完整的 site 对象
            const siteData = this.siteMap.get(siteId)!;
            // 更新共享数据
            this.site = siteData;
            // 打开自定义对话框
            if (!this.siteDetailDialog) {
              this.siteDetailDialog = new CustomDialogController({
                builder: SiteDetailDialog(),
                alignment: DialogAlignment.Center,
                customStyle: true
              });
            }
            this.siteDetailDialog.open();
          } else {
            console.warn("No siteId bound to this marker");
          }
        });
      }
      else{
        console.error(`Failed to initialize the map, code is：${err}`);
      }
    }
  }
  // 校验应用是否被授予定位权限，可以通过调用checkAccessToken()方法来校验当前是否已经授权。
  async checkPermissions(): Promise<boolean> {
    const permissions: Array<Permissions> = ['ohos.permission.LOCATION', 'ohos.permission.APPROXIMATELY_LOCATION'];
    for (let permission of permissions) {
      let grantStatus: abilityAccessCtrl.GrantStatus = await this.checkAccessToken(permission);
      if (grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        // 启用我的位置图层，mapController为地图操作类对象
        this.mapController?.setMyLocationEnabled(true);
        // 启用我的位置按钮
        this.mapController?.setMyLocationControlsEnabled(true);
        return true;
      }
    }
    return false;
  }

  // 如果没有被授予定位权限，动态向用户申请授权
  requestPermissions(): void {
    let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    atManager.requestPermissionsFromUser(this.getUIContext().getHostContext() as common.UIAbilityContext,
      ['ohos.permission.LOCATION', 'ohos.permission.APPROXIMATELY_LOCATION'])
      .then((data: PermissionRequestResult) => {
        // 启用我的位置图层
        this.mapController?.setMyLocationEnabled(true);
      })
      .catch((err: BusinessError) => {
        console.error(`Failed to request permissions from user. Code is ${err.code}, message is ${err.message}`);
      })
  }

  async checkAccessToken(permission: Permissions): Promise<abilityAccessCtrl.GrantStatus> {
    let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    let grantStatus: abilityAccessCtrl.GrantStatus = abilityAccessCtrl.GrantStatus.PERMISSION_DENIED;

    // 获取应用程序的accessTokenID
    let tokenId: number = 0;
    let bundleInfo: bundleManager.BundleInfo =
      await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
    console.info('Succeeded in getting Bundle.');
    let appInfo: bundleManager.ApplicationInfo = bundleInfo.appInfo;
    tokenId = appInfo.accessTokenId;

    // 校验应用是否被授予权限
    grantStatus = await atManager.checkAccessToken(tokenId, permission);
    console.info('Succeeded in checking access token.');
    return grantStatus;
  }

  async getMyLocation(){
    // 检查定位是否开启
    const isEnabled = await geoLocationManager.isLocationEnabled();
    if (!isEnabled) {
      console.info('定位服务未开启');
      return;
    }
    console.info("geoLocationManager获取location")
    let location=await geoLocationManager.getCurrentLocation()
    this.moveMap(location)
    if(location!=null){
      this.lo=location
    }
    if(this.mapController){
      console.info("setMyLocation前",location.latitude,location.longitude)
      this.mapController.setMyLocation(location)
      console.info("setMyLocation后",location.latitude,location.longitude)
    }
  }
  onPageShow(): void {
    if(this.mapController!==undefined){
      this.mapController.show()
    }
  }
  onPageHide(): void {
    if(this.mapController!==undefined){
      this.mapController.hide()
    }
  }

  // 切换地图类型的方法
  private switchMapType(type: string,index:number) {
    this.selectedIndex=index
    // 通过地图控制器切换地图类型
    if (this.mapController) {
      this.mapController.setMapType(this.getMapTypeValue(type))
    }
  }

  //地图相机移动
  async moveMap(value:mapCommon.LatLng){
    let cameraPosition:mapCommon.CameraPosition={
      target:value,
      zoom: 10,
      tilt: 0,
      bearing: 0,
    }
    let cameraUpdate = map.newCameraPosition(cameraPosition);
    await this.mapController?.animateCamera(cameraUpdate, 1000);
    let amount = 20.0;
    await map.zoomTo(amount);
  }
  //标记初始化
  async markerSet(value:mapCommon.LatLng,name:string,siteId:string){
    // Marker初始化参数
    let markerOptions: mapCommon.MarkerOptions = {
      position: value,
      rotation: 0,
      visible: true,
      zIndex: 0,
      alpha: 1,
      anchorU: 0.5,
      anchorV: 1,
      clickable: true,
      draggable: true,
      flat: false,
    };
    // 创建Marker
    try {
      let marker = await this.mapController?.addMarker(markerOptions);
      if(marker){
        marker.isClickable()
        marker.setTitle(name)
        marker.setInfoWindowAnchor(1,1)
        marker.setTag(siteId)
        this.markers.push(marker)
        this.markerMap.set(siteId,marker)
      }
    } catch (e) {
      console.error(`Failed to create the marker, code is：${e.code}, message is ${e.message}`);
    }
  }
  //获取地点详情
  async queryLocationDetail(value:string){
    let queryLocationOptions: sceneMap.LocationQueryOptions = {
      siteId: value
    };
    // 拉起地点详情页
    sceneMap.queryLocation(this.getUIContext().getHostContext() as common.UIAbilityContext, queryLocationOptions)
      .then(() => {
        console.info("QueryLocation", "Succeeded in querying location.");
      })
      .catch((err: BusinessError) => {
        console.error("QueryLocation", `Failed to query Location, code: ${err.code}, message: ${err.message}`);
      });
  }

  // 将字符串转换为MapType枚举值
  private getMapTypeValue(type: string): mapCommon.MapType {
    switch(type) {
      case "STANDARD":
        return mapCommon.MapType.STANDARD
      case "TERRAIN":
        return mapCommon.MapType.TERRAIN
      case "SATELLITE":
        return mapCommon.MapType.SATELLITE
      case "HYBRID":
        return mapCommon.MapType.HYBRID
      default:
        return mapCommon.MapType.STANDARD
    }
  }

  async searchNearByTextParams(value:mapCommon.LatLng){
    let params: site.NearbySearchParams = {
      location: value,
      poiTypes: this.poiTypeList
    }
    // 返回关键字搜索结果
    try {
      const result = await site.nearbySearch(params);
      this.sitesList = result.sites || []
      this.clearAllMarkers();                // 清除旧的
      for (let item of this.sitesList) {     // 批量新增
        if (item.location) {
          await this.markerSet(item.location, item.name || "",item.siteId);
          this.siteMap.set(item.siteId, item);   // 新增
        }
      }
      console.info(`================Succeeded in searching by text. result is ${JSON.stringify(result)}`);
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      console.error(`===================Failed in searching by text. Code is ${err.code}, message is ${err.message}`);
    }
  }
  async gecodeByKeyword(){
    let params:site.GeocodeParams={
      query:this.keyword,
      language:"zh-CN"
    };
    try{
      const result=await site.geocode(params)
      console.info(`================Succeeded in gecode by text. result is ${JSON.stringify(result)}`);
      this.sitesList = result.sites || []
      this.clearAllMarkers();                // 清除旧的
      for (let item of this.sitesList) {     // 批量新增
        if (item.location) {
          await this.markerSet(item.location, item.name || "",item.siteId);
          this.siteMap.set(item.siteId, item);   // 新增
        }
      }
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      console.error(`===================Failed in gecode by text. Code is ${err.code}, message is ${err.message}`);
    }
  }

  async autoKeyWord(){
    let params: site.QueryAutoCompleteParams = {
      // 自定义关键字
      query: this.keyword,
      // 经纬度坐标
      location: this.lo,
      language: "zh-CN",
      // 返回子节点
      isChildren: true
    };
    // 返回自动补全结果
    try {
      const result = await site.queryAutoComplete(params);
      this.sitesList=result.sites || []
      this.clearAllMarkers();                // 清除旧的
      for (let item of this.sitesList) {     // 批量新增
        if (item.location) {
          await this.markerSet(item.location, item.name || "",item.siteId);
          this.siteMap.set(item.siteId, item);   // 新增
        }
      }
      console.info(`======Succeeded in querying. result is ${JSON.stringify(result)}`);
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      console.error(`======Failed in querying. Code is ${err.code}, message is ${err.message}`);
    }
  }

  async searchBySiteId(value:string){
    let params: site.SearchByIdParams = {
      // 指定主键地点ID
      siteId: value,
      language: "zh-CN",
      // 返回子节点
      // isChildren: true
    };
    // 返回地点详情结果
    try {
      const result = await site.searchById(params);
      this.site=result.site || null;
      console.info(`======Succeeded in searchBySiteId. result is ${JSON.stringify(result)}`);
      return this.site
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      console.error(`======Failed in searchBySiteId. Code is ${err.code}, message is ${err.message}`);
      return null
    }
  }

  build() {
    Column(){
      Search({controller:this.searchController})
        .width('100%')
        .height('10%')
        .searchButton("搜索")
        .onChange((value:string)=>{
          this.keyword=value
          this.autoKeyWord()
        })
        .onSubmit(async ()=>{
          this.isShowLocationList=true
          this.sitesList=[]       // 等待搜索完成
          await this.gecodeByKeyword()
        })
        .onFocus(()=>{
          this.isShowLocationList=true
        })
      MapComponent({mapOptions:this.mapOptions,mapCallback:this.callback})
        .width('100%')
        .height('80%')
      Flex(){
        ForEach(this.typeList,(item:string,index:number)=>{
          Button(item)
            .backgroundColor(this.selectedIndex === index ? Color.Blue : Color.Orange)
            .fontColor(Color.White)
            .fontSize(10)
            .height(40)
            .layoutWeight(1)
            .width('25%')
            .onClick(() => {
              console.info(this.TAG, `按钮被点击: ${item}, 索引: ${index}`)
              this.switchMapType(item, index)
            })
        }, (item: string) => item)
        Button('周边')
          .backgroundColor(Color.Green)
          .fontColor(Color.White)
          .height(40)
          .layoutWeight(1)
          .onClick(() => {
            this.searchNearByTextParams(this.lo);
            this.isShowLocationList=true;
          })
      }
      .height('10%')
      .width('100%')

      // 仅替换build()方法中的搜索结果列表部分即可
      if(this.isShowLocationList){
        List({space: 5}) {
          ForEach(this.sitesList, (item: site.Site) => {
            ListItem() {
              Row({ space: 12 }) {
                // 图标
                Image($r('app.media.startIcon'))
                  .width(40)
                  .height(40)

                // 信息区域
                Column({ space: 4 }) {
                  Text(item.name || '未知')
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)

                  Text(item.formatAddress || '地址未知')
                    .fontSize(12)
                    .fontColor('#666666')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .padding(12)
              .width('100%')
            }
            .onClick(async () => {
              // 点击跳转到对应位置
              // 1. 通过 siteId 获取详细地点信息（包含中文名称等）
              const detailedSite = await this.searchBySiteId(item.siteId);
              if (detailedSite) {
                // 2. 更新 siteMap 中存储的完整地点信息
                this.siteMap.set(item.siteId, detailedSite);
                // 3. 获取对应的 Marker 并更新其标题为详细名称
                const targetMarker = this.markerMap.get(item.siteId);
                if (targetMarker) {
                  targetMarker.setTitle(detailedSite.name || item.name);
                }
                // 4. 移动相机到详细地点所在位置
                const location = detailedSite.location || item.location;
                if (location) {
                  this.lo = location;
                  await this.moveMap(this.lo);
                }
                // 5. 显示信息窗口
                targetMarker?.setInfoWindowVisible(true);
              } else {
                // 降级：无法获取详情时使用搜索返回的原始数据
                this.lo = item.location || this.lo;
                await this.moveMap(this.lo);
                const targetMarker = this.markerMap.get(item.siteId);
                targetMarker?.setInfoWindowVisible(true);
              }
              // 关闭列表并隐藏键盘
              this.isShowLocationList = false;
              this.searchController.stopEditing();
            })
          })
        }
        .width('100%')
        .height('30%')
        .backgroundColor(Color.White)
        .position({ x: 0, y: '10%' })
        .zIndex(100)
      }
    }
    .height('100%')
  }
}
