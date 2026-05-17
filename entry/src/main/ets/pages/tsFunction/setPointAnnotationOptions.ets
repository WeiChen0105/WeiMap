// tsFunction/setPointAnnotationOptions.ts
import { mapCommon, map } from '@kit.MapKit';

export async function setPointAnnotationOptions(
  mapController: map.MapComponentController | undefined,
  position: mapCommon.LatLng,
  content: string
) {
  if (!mapController) return;

  let pointAnnotationOptions: mapCommon.PointAnnotationParams = {
    position: position,
    repeatable: true,
    collisionRule: mapCommon.CollisionRule.NAME,
    titles: [{
      content: content,
      color: 0xFF000000,
      fontSize: 15,
      strokeColor: 0xFFFFFFFF,
      strokeWidth: 2,
      fontStyle: mapCommon.FontStyle.ITALIC
    }],
    icon: "",          // 如果不提供图标，请确保 showIcon: false
    showIcon: false,   // 改为 false，否则空字符串可能导致不显示文字
    anchorU: 0.5,
    anchorV: 1,
    forceVisible: false,
    priority: 3,
    minZoom: 2,
    maxZoom: 20,
    visible: true,
    zIndex: 10
  };

  try {
    await mapController.addPointAnnotation(pointAnnotationOptions);
    console.info("PointAnnotation added successfully");
  } catch (err) {
    console.error(`Failed to add point annotation: ${err}`);
  }
}