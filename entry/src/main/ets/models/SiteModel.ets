// model/SiteModel.ts
import { site,mapCommon } from '@kit.MapKit';

// 地点信息（可直接使用 site.Site 或自行封装）
export interface SiteInfo {
  siteId: string;
  name: string;
  formatAddress?: string;
  location?: mapCommon.LatLng;
  rawData?: site.Site;   // 保留原始数据以备扩展
}

// 位置信息
export interface PositionInfo {
  latitude: number;
  longitude: number;
}