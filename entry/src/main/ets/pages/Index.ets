import {router} from '@kit.ArkUI'
@Entry
@Component
struct Index {
  @State message: string = 'Hello World';

  build() {
    RelativeContainer() {
      Button("初始化地图")
        .onClick(()=>{
          router.push({url:'pages/MapPage1'})
        })
    }
    .height('100%')
    .width('100%')
  }
}