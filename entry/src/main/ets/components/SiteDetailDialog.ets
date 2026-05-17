import {MapComponent,mapCommon,map,site, sceneMap} from '@kit.MapKit'
import { common } from '@kit.AbilityKit';
import {MapViewModel}  from  '../viewmodel/MapViewModel'

@CustomDialog
export struct SiteDetailDialog {
  controller: CustomDialogController
  @Consume('selectedSite') site: site.Site | null;
  // 辅助获取行政区划（可选）
  private get addrComp(){
    return this.site?.addressComponent;
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

  build() {
    Column() {
      if (!this.site) {
        Text("数据加载中...")
          .fontSize(16)
          .padding(20)
        Button('关闭')
          .onClick(() => this.controller.close())
      } else {
        // 原有的展示逻辑，将 this.site 替换为 this.selectedSite
        this.buildContent(this.site)
      }
    }
    .width('90%')
    .backgroundColor(Color.White)
    .borderRadius(16)
    .padding(16)
    .constraintSize({ maxHeight: '80%' })
  }

  @Builder
  buildContent(site: site.Site) {
    Column() {
      // 标题
      Text(site.name || '地点详情')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 12 })

      Scroll() {
        Column({ space: 8 }) {
          // 地址
          this.infoRow('地址', site.formatAddress || '无')
          // 距离
          if (site.distance) {
            this.infoRow('距离', `${site.distance.toFixed(1)}米`)
          }

          // POI 信息
          if (site.poi) {
            Divider().margin({ top: 8, bottom: 8 })
            Text('POI 详细信息')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .margin({ bottom: 8 })

            if (site.poi.phone) this.infoRow('电话', site.poi.phone)
            if (site.poi.internationalPhone) this.infoRow('国际电话', site.poi.internationalPhone)
            if (site.poi.rating && site.poi.rating > 0) this.infoRow('评分', `${site.poi.rating} 星`)
            if (site.poi.starRating && site.poi.starRating > 0) this.infoRow('星级', `${site.poi.starRating} 星`)
            if (site.poi.businessStatus) this.infoRow('营业状态', site.poi.businessStatus)
            if (site.poi.openingHours?.texts?.length) this.infoRow('营业时间', site.poi.openingHours.texts.join('；'))
            if (site.poi.brand) this.infoRow('品牌', site.poi.brand)
            if (site.poi.email) this.infoRow('邮箱', site.poi.email)
            if (site.poi.websiteUrl) this.infoRow('网址', site.poi.websiteUrl)
            if (site.poi.comment) {
              if (site.poi.comment.averageRating) this.infoRow('平均评分', `${site.poi.comment.averageRating} 星`)
              if (site.poi.comment.total) this.infoRow('评论总数', `${site.poi.comment.total} 条`)
            }
            if (site.poi.poiTypes?.length) this.infoRow('分类', site.poi.poiTypes.join('、'))
          } else {
            // 普通地点信息
            Divider().margin({ top: 8, bottom: 8 })
            Text('基础信息')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .margin({ bottom: 8 })
            if (site.location) {
              this.infoRow('坐标', `${site.location.latitude.toFixed(4)}, ${site.location.longitude.toFixed(4)}`)
            }
            if (site.utcOffset) this.infoRow('时区偏移', `${site.utcOffset} 分钟`)
          }
          if(this.site?.poi?.description){
            Divider().margin({ top: 8, bottom: 8 })
            Text('地点描述')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .margin({ bottom: 8 })
            if(this.site.poi.description)this.infoRow('地点描述',this.site.poi.description)
          }
        }
        .width('100%')
        .padding(12)
      }
      .height('70%')
      .scrollBar(BarState.Auto)
      .layoutWeight(1)

      Button('关闭')
        .width('90%')
        .height(40)
        .margin({ top: 16, bottom: 12 })
        .onClick(() => this.controller.close())
      Button('系统详情与导航跳转')
        .width('90%')
        .height(40)
        .margin({ top: 16, bottom: 12 })
        .onClick(() => {
          this.queryLocationDetail(site.siteId)
          this.controller.close()
        })
    }
  }

  @Builder
  infoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .width(80)
      Text(value)
        .fontSize(14)
        .fontColor('#333333')
        .layoutWeight(1)
        .wordBreak(WordBreak.BREAK_WORD)
    }
    .width('100%')
    .margin({ bottom: 6 })
  }
}