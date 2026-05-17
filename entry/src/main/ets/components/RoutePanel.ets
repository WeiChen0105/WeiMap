
import { RoutePlanData, TravelMode } from '../models/RouteModels';

@Component
export struct RoutePanel {
  @Prop routes: RoutePlanData[] = [];
  @Prop selectedRouteId: string = '';
  onRouteSelected: (route: RoutePlanData) => void = () => {};
  onClose: () => void = () => {};

  build() {
    Column() {
      Row() {
        Text('路线方案')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')

        Blank()

        Button() {
          Image($r('sys.media.ohos_ic_public_cancel'))
            .width(20)
            .height(20)
            .fillColor('#666666')
        }
        .backgroundColor(Color.Transparent)
        .onClick(() => this.onClose())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Divider()
        .color('#E0E0E0')
        .strokeWidth(1)

      List({ space: 8 }) {
        ForEach(this.routes, (route: RoutePlanData) => {
          ListItem() {
            this.RouteCard(route)
          }
        }, (route: RoutePlanData) => route.id)
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
    .borderRadius({ topLeft: 16, topRight: 16 })
  }

  @Builder
  RouteCard(route: RoutePlanData) {
    Row({ space: 12 }) {
      Column() {
        Image(this.getModeIcon(route.mode))
          .width(32)
          .height(32)
          .fillColor(route.color)
      }
      .width(48)
      .height(48)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(`${route.color}15`)
      .borderRadius(24)

      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text(route.modeName)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333333')

          Text(route.distanceText)
            .fontSize(14)
            .fontColor('#666666')

          Text(route.durationText)
            .fontSize(14)
            .fontColor('#666666')
        }

        if (route.summary) {
          Text(route.summary)
            .fontSize(12)
            .fontColor('#999999')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.selectedRouteId === route.id) {
        Image($r('sys.media.ohos_save_button_line'))
          .width(24)
          .height(24)
          .fillColor(route.color)
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.selectedRouteId === route.id ? `${route.color}10` : Color.White)
    .borderRadius(8)
    .border({
      width: 2,
      color: this.selectedRouteId === route.id ? route.color : '#E0E0E0'
    })
    .onClick(() => this.onRouteSelected(route))
  }

  private getModeIcon(mode: TravelMode): Resource {
    switch (mode) {
      case TravelMode.DRIVING:
        return $r('sys.media.car_fill');
      case TravelMode.WALKING:
        return $r('sys.media.car_fill');
      case TravelMode.CYCLING:
        return $r('sys.media.car_fill');
      case TravelMode.TRANSIT:
        return $r('sys.media.car_fill');
      default:
        return $r('sys.media.car_fill');
    }
  }
}
