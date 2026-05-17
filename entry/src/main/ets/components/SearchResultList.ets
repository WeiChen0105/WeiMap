// components/SearchResultList.ets
import { site } from '@kit.MapKit';

@Component
export struct SearchResultList {
  @Prop sitesList: site.Site[] = [];
  onItemClick: (item: site.Site) => Promise<void> = async () => {};

  build() {
    List({ space: 5 }) {
      if (this.sitesList.length > 0) {
        ForEach(this.sitesList, (item: site.Site) => {
          ListItem() {
            Row({ space: 12 }) {
              Image($r('app.media.startIcon'))
                .width(40)
                .height(40)

              Column({ space: 4 }) {
                Text(item.name || '未知')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)

                Text(item.formatAddress || '地址未知')
                  .fontSize(12)
                  .fontColor('#666666')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .padding(12)
            .width('100%')
          }
          .onClick(async () => await this.onItemClick(item))
        })
      } else {
        ListItem() {
          Column() {
            Text('暂无搜索结果')
              .fontSize(14)
              .fontColor('#999999')
              .margin({ top: 20, bottom: 20 })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
      }
    }
    .width('100%')
    .height('100%')
  }
}