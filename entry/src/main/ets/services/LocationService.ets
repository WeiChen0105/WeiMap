// services/LocationService.ts
import { abilityAccessCtrl, bundleManager, Permissions, common } from '@kit.AbilityKit';
import { geoLocationManager } from '@kit.LocationKit';
import { BusinessError } from '@kit.BasicServicesKit';

export class LocationService {
  private static readonly REQUIRED_PERMISSIONS: Array<Permissions> = [
    'ohos.permission.LOCATION',
    'ohos.permission.APPROXIMATELY_LOCATION'
  ];

  // ✅ 修复1：将 this.REQUIRED_PERMISSIONS 改为 LocationService.REQUIRED_PERMISSIONS
  static async checkPermissions(): Promise<boolean> {
    for (const permission of LocationService.REQUIRED_PERMISSIONS) {
      const grantStatus = await LocationService.checkAccessToken(permission);
      if (grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        return true;
      }
    }
    return false;
  }

  // ✅ 修复2：将 this.REQUIRED_PERMISSIONS 改为 LocationService.REQUIRED_PERMISSIONS
  static async requestPermissions(context: common.UIAbilityContext): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    try {
      const result = await atManager.requestPermissionsFromUser(
        context,
        LocationService.REQUIRED_PERMISSIONS
      );
      return result.authResults.every(status => status === 0);
    } catch (err) {
      const error = err as BusinessError;
      console.error(`===[位置服务] 权限请求失败: code=${error.code}, message=${error.message}===`);
      return false;
    }
  }

  static async getCurrentLocation(): Promise<geoLocationManager.Location | null> {
    const isEnabled = await geoLocationManager.isLocationEnabled();
    if (!isEnabled) {
      console.info('===[位置服务] 定位服务未开启===');
      return null;
    }
    return await geoLocationManager.getCurrentLocation();
  }

  private static async checkAccessToken(permission: Permissions): Promise<abilityAccessCtrl.GrantStatus> {
    const atManager = abilityAccessCtrl.createAtManager();
    const bundleInfo = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
    const tokenId = bundleInfo.appInfo.accessTokenId;
    return await atManager.checkAccessToken(tokenId, permission);
  }
}