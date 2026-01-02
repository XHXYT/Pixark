import { PixivImage } from "../components/PixivImage";
import { PixState } from "../entryability/AppState";
import { PixivIllust } from "../services/PixivTypes";

@ComponentV2
export struct Home {
  build() {
    List() {
      ForEach(PixState.illustRecommends, (item: PixivIllust) => {
        ListItem() {
          Row() {
            PixivImage({
              imageUrl: item.image_urls.square_medium
            })
              .width(70)
              .height(70)
              .margin({ right: 12 })

            Column() {
              Text(item.title)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .margin({ bottom: 4 });

              Text(item.user.name)
                .fontSize(13)
                .fontColor('#999')
                .margin({ bottom: 4 });

              Text(`❤️ ${item.total_bookmarks}  👀 ${item.total_view}`)
                .fontSize(12)
                .fontColor('#999');
            }
            .alignItems(HorizontalAlign.Start);
          }
          .padding(10);
        }
      }, (item: PixivIllust) => item.id.toString())
    }
    .layoutWeight(1);

  }

}