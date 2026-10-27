import { NaviContainer } from "../../components/NaviContainer";
import { PixState } from "../../entryability/AppState";
import BookTagInfo from "../../common/entity/BookTagInfo";
import { bookTagStore } from "../../services/BookTagStore";
import { toastUtil } from "../../common/utils/ToastUtils";
import { searchVM } from "../../viewmodel/SearchViewModel";
import { appSettings } from "../../common/entity/SettingsModel";
import { SearchingPageParams } from "../SearchingPage";

/** 收藏标签（常用标签快捷搜索） */
@Builder
export function BookTagPageBuilder() {
  BookTagPage()
}

@ComponentV2
struct BookTagPage {

  @Local tags: BookTagInfo[] = []

  async aboutToAppear(): Promise<void> {
    await this.refresh()
  }

  build() {
    NaviContainer({
      title: $r('app.string.book_tags'),
      content: () => {
        this.Content()
      },
      onReady: (ctx: NavDestinationContext) => {
      },
      onBackPressed: () => {
        return false
      },
      // 从搜索页返回时刷新列表（使用次数/排序可能已变化）
      onNaviShown: () => {
        this.refresh()
      }
    })
  }

  private async refresh(): Promise<void> {
    this.tags = await bookTagStore.list()
  }

  @Builder
  Content() {
    Column() {
      List({ space: 8 }) {
        if (this.tags.length === 0) {
          ListItem() {
            this.EmptyHint()
          }
        } else {
          ForEach(this.tags, (tag: BookTagInfo) => {
            ListItem() {
              this.TagRow(tag)
            }
          }, (tag: BookTagInfo) => `${tag.id}`)
        }
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .padding({ left: PixState.PageMarginValue, right: PixState.PageMarginValue, top: 4, bottom: PixState.bottomRectHeight })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }

  /** 空态提示 */
  @Builder
  EmptyHint() {
    Column() {
      Text($r('app.string.book_tag_empty'))
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
        .lineHeight(20)
    }
    .width('100%')
    .padding({ top: 48, left: 24, right: 24 })
    .constraintSize({ minHeight: 200 })
    .justifyContent(FlexAlign.Start)
  }

  /** 标签行：点击搜索，右侧删除 */
  @Builder
  TagRow(tag: BookTagInfo) {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text(`#${tag.name}`)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (tag.translation) {
          Text(tag.translation)
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (tag.useCount > 0) {
        Text($r('app.string.book_tag_use_count', tag.useCount))
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
      }

      Button() {
        SymbolGlyph($r('sys.symbol.trash'))
          .fontSize(17)
          .fontColor([$r('sys.color.font_secondary')])
      }
      .width(32)
      .height(32)
      .borderRadius(16)
      .padding(0)
      .backgroundColor($r('sys.color.comp_background_list_card'))
      .onClick(() => {
        this.deleteTag(tag)
      })
    }
    .width('100%')
    .padding({ left: 16, right: 12, top: 12, bottom: 12 })
    .borderRadius(12)
    .backgroundColor($r('sys.color.comp_background_list_card'))
    .onClick(() => {
      this.searchTag(tag)
    })
  }

  /** 点击标签：直接发起搜索（常用标签快捷搜索） */
  private searchTag(tag: BookTagInfo): void {
    searchVM.keyword = tag.name
    searchVM.searchType = appSettings.novel_mode ? 'novel' : 'illust'
    searchVM.doSearch(true)
    bookTagStore.touch(tag.name)
    const params: SearchingPageParams = { mainStack: true };
    PixState.pushPage('searching_page', params, true)
  }

  /** 删除收藏标签 */
  private deleteTag(tag: BookTagInfo): void {
    bookTagStore.remove(tag.name).then((ok: boolean) => {
      if (ok) {
        this.refresh()
        toastUtil.showToast({ message: $r('app.string.book_tag_deleted_name', tag.name) })
      }
    })
  }
}
