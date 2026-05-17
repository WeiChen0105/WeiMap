// services/SiteSearchService.ts
import { site, sceneMap, mapCommon } from '@kit.MapKit';
import {common}  from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit';

export class SiteSearchService {
  private siteCache: Map<string, site.Site> = new Map();

  async searchNearby(location: mapCommon.LatLng, poiTypes: string[]): Promise<site.Site[]> {
    const params: site.NearbySearchParams = { location, poiTypes };
    try {
      const result = await site.nearbySearch(params);
      this.cacheSites(result.sites);
      return result.sites || [];
    } catch (err) {
      const error = err as BusinessError;
      console.error(`===[地点搜索] 周边搜索失败: code=${error.code}, message=${error.message}===`);
      return [];
    }
  }

  async searchByKeyword(keyword: string): Promise<site.Site[]> {
    const params: site.GeocodeParams = { query: keyword, language: "zh-CN" };
    try {
      const result = await site.geocode(params);
      this.cacheSites(result.sites);
      return result.sites || [];
    } catch (err) {
      const error = err as BusinessError;
      console.error(`===[地点搜索] 关键字搜索失败: code=${error.code}, message=${error.message}===`);
      return [];
    }
  }

  async autoComplete(keyword: string, location: mapCommon.LatLng): Promise<site.Site[]> {
    const params: site.QueryAutoCompleteParams = {
      query: keyword,
      location: location,
      language: "zh-CN",
      isChildren: true
    };
    try {
      const result = await site.queryAutoComplete(params);
      this.cacheSites(result.sites);
      return result.sites || [];
    } catch (err) {
      const error = err as BusinessError;
      console.error(`===[地点搜索] 自动补全失败: code=${error.code}, message=${error.message}===`);
      return [];
    }
  }

  async searchById(siteId: string): Promise<site.Site | null> {
    if (this.siteCache.has(siteId)) {
      return this.siteCache.get(siteId)!;
    }
    const params: site.SearchByIdParams = { siteId, language: "zh-CN" };
    try {
      const result = await site.searchById(params);
      if (result.site) {
        this.siteCache.set(siteId, result.site);
      }
      return result.site || null;
    } catch (err) {
      const error = err as BusinessError;
      console.error(`===[地点搜索] ID搜索失败: siteId=${siteId}, code=${error.code}, message=${error.message}===`);
      return null;
    }
  }

  async openLocationDetail(context: common.UIAbilityContext, siteId: string): Promise<void> {
    const queryLocationOptions: sceneMap.LocationQueryOptions = { siteId };
    try {
      await sceneMap.queryLocation(context, queryLocationOptions);
    } catch (err) {
      const error = err as BusinessError;
      console.error(`===[地点搜索] 打开地点详情失败: siteId=${siteId}, code=${error.code}, message=${error.message}===`);
    }
  }

  private cacheSites(sites: site.Site[] = []): void {
    sites.forEach(s => {
      if (s.siteId) this.siteCache.set(s.siteId, s);
    });
  }
}