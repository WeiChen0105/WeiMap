// services/MapMarkerService.ts
import { map,mapCommon } from '@kit.MapKit';
import { BusinessError } from '@kit.BasicServicesKit';

export class MapMarkerService {
  private markers: Map<string, map.Marker> = new Map();

  // ✅ 显式声明私有字段
  private mapController?: map.MapComponentController;

  // ✅ 构造函数参数移除 private 关键字，改为手动赋值
  constructor(mapController?: map.MapComponentController) {
    this.mapController = mapController;
  }

  setMapController(controller: map.MapComponentController): void {
    this.mapController = controller;
  }

  async addMarker(siteId: string, position: mapCommon.LatLng, title: string): Promise<map.Marker | null> {
    if (!this.mapController) return null;
    const markerOptions: mapCommon.MarkerOptions = {
      position: position,
      rotation: 0,
      visible: true,
      clickable: true,
      draggable: false,
    };
    try {
      const marker = await this.mapController.addMarker(markerOptions);
      if (marker) {
        marker.setTitle(title);
        marker.setTag(siteId);
        this.markers.set(siteId, marker);
      }
      return marker;
    } catch (e) {
      const error = e as BusinessError;
      console.error(`===[标记服务] 添加 Marker 失败: siteId=${siteId}, code=${error.code}, message=${error.message}===`);
      return null;
    }
  }

  removeMarker(siteId: string): void {
    const marker = this.markers.get(siteId);
    if (marker) {
      marker.remove();
      this.markers.delete(siteId);
    }
  }

  clearAllMarkers(): void {
    this.markers.forEach(marker => marker.remove());
    this.markers.clear();
  }

  getMarker(siteId: string): map.Marker | undefined {
    return this.markers.get(siteId);
  }

  showInfoWindow(siteId: string): void {
    this.markers.get(siteId)?.setInfoWindowVisible(true);
  }
}