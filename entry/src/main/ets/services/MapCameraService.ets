// services/MapCameraService.ts
import { map,mapCommon } from '@kit.MapKit';
import { geoLocationManager } from '@kit.LocationKit';

export class MapCameraService {
  // ✅ 显式声明私有字段
  private mapController?: map.MapComponentController;

  // ✅ 构造函数参数移除 private 关键字，改为手动赋值
  constructor(mapController?: map.MapComponentController) {
    this.mapController = mapController;
  }

  setMapController(controller: map.MapComponentController): void {
    this.mapController = controller;
  }

  async moveTo(location: mapCommon.LatLng, zoom: number = 10, duration: number = 1000): Promise<void> {
    const cameraPosition: mapCommon.CameraPosition = {
      target: location,
      zoom: zoom,
      tilt: 0,
      bearing: 0,
    };
    const cameraUpdate = map.newCameraPosition(cameraPosition);
    await this.mapController?.animateCamera(cameraUpdate, duration);
  }

  async zoomTo(amount: number): Promise<void> {
    await map.zoomTo(amount);
  }

  setMyLocation(location: geoLocationManager.Location): void {
    this.mapController?.setMyLocation(location);
    this.mapController?.setMyLocationEnabled(true);
    this.mapController?.setMyLocationControlsEnabled(true);
  }

  setMapType(mapType: mapCommon.MapType): void {
    this.mapController?.setMapType(mapType);
  }
}