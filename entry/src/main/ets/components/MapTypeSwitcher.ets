// components/MapTypeSwitcher.ets
import {mapCommon}from '@kit.MapKit'
@Component
export struct MapTypeSwitcher {
  private typeList: string[] = ["STANDARD", "TERRAIN", "SATELLITE", "HYBRID"];
  @Prop selectedIndex: number = 0;
  onTypeSelected: (type: string, index: number) => void = () => {};

  build() {
    Flex() {
      ForEach(this.typeList, (item: string, index: number) => {
        Button(item)
          .backgroundColor(this.selectedIndex === index ? Color.Blue : Color.Orange)
          .fontColor(Color.White)
          .fontSize(10)
          .height(40)
          .layoutWeight(1)
          .width('25%')
          .onClick(() => this.onTypeSelected(item, index))
      }, (item: string) => item)
    }
    .height('100%')
    .width('100%')
  }
}