import { PixivNovel, PixivTag } from '../services/PixivTypes'
import { PixivImageComponent } from './PixivImage'
import { PixState } from '../entryability/AppState'


/**
 * 小说列表视图
 */
@ComponentV2
export struct NovelListView {

  @Param novelList: PixivNovel[] = []
  @Param contentEndOffset: number = 0
  @Param nestedScroll: NestedScrollOptions | undefined = undefined
  @Event onItemClick: (novel: PixivNovel) => void
  @Event onReachEnd: () => void

  build() {
    List({ space: 0 }) {
      ForEach(this.novelList, (novel: PixivNovel) => {
        ListItem() {
          this.NovelItem(novel)
        }
      }, (novel: PixivNovel) => novel.id.toString())
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .nestedScroll(this.nestedScroll)
    .contentEndOffset(PixState.bottomRectHeight + this.contentEndOffset)
    .padding({ left: PixState.PageMarginValue, right: PixState.PageMarginValue })
    // 分割线留出左侧封面的位置：左边距 = 图片宽70 + 左右间距12 + 列表左margin
    .divider({ strokeWidth: 0.5, color: $r('sys.color.comp_divider'), startMargin: 100, endMargin: 16 })
    .onReachEnd(() => {
      this.onReachEnd()
    })
  }

  @Builder NovelItem(novel: PixivNovel) {
    Row({ space: 12 }) {
      // 左侧封面
      PixivImageComponent({
        imageUrl: novel.image_urls?.medium || '',
        imageWidth: 70,
        imageHeight: 90,
        imageBorder: { radius: 8 }
      })

      // 右侧信息
      Column({ space: 4 }) {
        // 标题
        Text(novel.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%') // 强制占满父容器宽度，防止长标题撑开列

        // 标签 (取前几个展示)
        if (novel.tags && novel.tags.length > 0) {
          Row({ space: 4 }) {
            ForEach(novel.tags.slice(0, 4), (tag: PixivTag) => {
              Text(`#${tag.name}`)
                .fontSize(11)
                .fontColor(PixState.currentThemeColor)
                .maxLines(1) // 防止标签名字过长换行
                .constraintSize({ maxWidth: '40%' }) // 限制单个标签最大宽度
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }, (tag: PixivTag, index: number) => `${tag.name}_${index}`)
          }
          .width('100%')
        }

        // 作者与字数
        Row({ space: 8 }) {
          Text(novel.user?.name || '')
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1) // 占据剩余空间，超长时省略号截断

          if (novel.text_length) {
            Text($r('app.string.num_words', novel.text_length))
              .fontSize(11)
              .fontColor($r('sys.color.font_tertiary'))
              .flexShrink(0)
          }
        }
        .width('100%')
        .margin({ top: 2 })

        // 系列信息
        if (novel.series && novel.series.title) {
          Text() {
            Span($r('app.string.series'))
            Span('：')
            Span(novel.series.title)
          }
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 2 })
          .width('100%')
        }
      }
      .layoutWeight(1) // 占据剩余空间
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .onClick(() => {
      this.onItemClick(novel)
    })
  }

}
