import { PixivImageComponent } from "../components/PixivImage";
import { PixState } from "../entryability/AppState";
import { GridColumnsTemplate } from "../common/utils/breakpoint/BreakPoint";
import { IllustDetailViewModel } from "../viewmodel/IllustDetailViewModel";
import { SnapShotUtils } from "../common/utils/SnapShotUtils";
import { PixivIllust, PixivImage, PixivTag } from "../services/PixivTypes";
import { LengthMetrics, SymbolGlyphModifier } from "@kit.ArkUI";
import { pasteboard } from "@kit.BasicServicesKit";
import { homeViewModel } from "../viewmodel/HomeViewModel";
import { DetailPageParams, IIllustSwiperProvider } from "../common/entity/DetailEntity";
import { UserItem } from "../components/UserItem";
import { PixivImageViewer } from "../components/ImageViewer";
import { NaviContainer } from "../components/NaviContainer";
import { appSettings } from "../common/entity/SettingsModel";
import { hdsEffect } from "@kit.UIDesignKit";
import { ColorUtils } from "../common/utils/ColorUtils";
import { LongTakeAnimationProperties } from "../common/utils/customtransition/LongTakeAnimationProperties";
import { CustomTransition } from "../common/utils/customtransition/CustomNavigationUtils";
import { CardUtil } from "../common/utils/CardUtil";
import { createLogger } from "../common/utils/Logger";
import { CommentPanel } from "./CommentPanel";
import { muteFilter, MuteReason } from "../services/MuteFilter";
import { bookTagStore } from "../services/BookTagStore";
import { toastUtil } from "../common/utils/ToastUtils";

const logger = createLogger('IllustDetail')


@Builder
export function IllustDetailBuilder(name: string, param: Object) {
  IllustDetail()
}

// 外层：负责 Swiper 容器与转场动画
@ComponentV2
struct IllustDetail {

  @Local illustTitle: string = ''
  @Local showLargeImage: boolean = false
  @Local currentSwiperIndex: number = 0
  @Local showMenu: boolean = false
  @Local currentIllust: PixivIllust | null = null

  private pageStack: NavPathStack = new NavPathStack()
  private swiperProvider: IIllustSwiperProvider | undefined = undefined
  private initialId: number = 0
  private sharedId: string = ''
  private longTakeAnimationProperties: LongTakeAnimationProperties = new LongTakeAnimationProperties();

  build() {
    NaviContainer({
      title: this.illustTitle,
      hideTitleBar: this.showLargeImage,
      content: () => { this.Content() },
      onReady: (ctx) => {
        this.pageStack = ctx.pathStack
        this.handleTransitionReady(ctx)
      },
      onBackPressed: () => {
        if (this.showLargeImage) {
          this.showLargeImage = false
          return true
        }
        return false
      },
      onNaviDisAppear: () => {
        homeViewModel.restoreIllustVisibility();
        SnapShotUtils.clear();
      },
      showMenu: this.showMenu,
      buttons: this.detailButtons(),
      menusBuilder: () => { this.DetailMenu() }
    })
  }

  // 标题栏按钮：屏蔽菜单入口
  private detailButtons(): NavigationMenuItem[] {
    return [
      {
        value: '',
        symbolIcon: new SymbolGlyphModifier($r('sys.symbol.dot_grid_2x2')),
        action: () => {
          this.showMenu = !this.showMenu
        }
      }
    ]
  }

  // 屏蔽菜单
  @Builder
  DetailMenu() {
    Menu() {
      MenuItem({ content: $r('app.string.mute_this_illust') })
        .enabled(!!this.currentIllust)
        .onClick(() => {
          this.showMenu = false
          this.muteCurrentIllust()
        })
      MenuItem({ content: $r('app.string.mute_this_artist') })
        .enabled(!!this.currentIllust)
        .onClick(() => {
          this.showMenu = false
          this.muteCurrentArtist()
        })
      MenuItem({ content: $r('app.string.mute_settings') })
        .onClick(() => {
          this.showMenu = false
          PixState.pushPage('mute_settings', null, true)
        })
    }
  }

  private muteCurrentIllust(): void {
    const illust = this.currentIllust
    if (!illust) return
    muteFilter.addRule('illust', String(illust.id), illust.title).then((ok: boolean) => {
      toastUtil.showToast({ message: ok ? $r('app.string.mute_added') : $r('app.string.mute_add_failed') })
    })
  }

  private muteCurrentArtist(): void {
    const illust = this.currentIllust
    if (!illust) return
    muteFilter.addRule('user', String(illust.user.id), illust.user.name).then((ok: boolean) => {
      toastUtil.showToast({ message: ok ? $r('app.string.mute_added') : $r('app.string.mute_add_failed') })
    })
  }

  // 处理转场动画初始化
  private handleTransitionReady(ctx: NavDestinationContext) {
    const params = ctx?.pathInfo?.param as DetailPageParams;
    if (!params) return;

    this.initialId = params.id;
    this.swiperProvider = params.swiperProvider;

    const fromId = params.fromId as string;
    const pageId = ctx.navDestinationId;
    if (!pageId || !fromId) {
      this.longTakeAnimationProperties.setFinalStatus();
      return;
    }
    this.sharedId = CardUtil.getPostPageImageId(fromId) || fromId;

    this.longTakeAnimationProperties.init(fromId, () => {
      homeViewModel.restoreIllustVisibility();
    });

    CustomTransition.getInstance().registerNavParam(pageId, 2000, (proxy: NavigationTransitionProxy) => {
      this.longTakeAnimationProperties.doAnimation(proxy);
    });
  }

  @Builder Content() {
    if (this.swiperProvider && appSettings.swiper_browsing) {
      // === Swiper 模式 ===
      Swiper() {
        Repeat<number>(this.swiperProvider.illustIds)
          .virtualScroll({ totalCount: this.swiperProvider.illustIds.length, reusable: false }) // 禁用复用，触发加载
          .key((id: number) => id.toString())
          .each((ri: RepeatItem<number>) => {
            IllustDetailContent({
              illustId: ri.item,
              sharedId: ri.item === this.initialId ? this.sharedId : '',
              pageStack: this.pageStack,
              showLargeImage: this.showLargeImage,
              onImageLarge: (show) => { this.showLargeImage = show },
              onTitle: (title) => { this.illustTitle = title },
              onIllust: (illust) => { this.currentIllust = illust }
            })
          })
      }
      .index(this.swiperProvider.illustIds.indexOf(this.initialId) || 0)
      .indicator(false)
      .loop(false)
      .cachedCount(0, false)
      .onChange((index: number) => {
        const total = this.swiperProvider?.illustIds.length || 0;
        // logger.debug(`[Swiper Log] >>> 滑动变化! 当前Index: ${index}, 列表总数:${total}, 当前ID: ${this.swiperProvider?.illustIds[index]}`);
        this.currentSwiperIndex = index;
        this.tryLoadMore(index);
      })
      .width('100%')
      .height('100%')
    } else {
      // === 单页模式 ===
      IllustDetailContent({
        illustId: this.initialId,
        sharedId: this.sharedId,
        pageStack: this.pageStack,
        showLargeImage: this.showLargeImage,
        onImageLarge: (show) => { this.showLargeImage = show },
        onTitle: (title) => { this.illustTitle = title },
        onIllust: (illust) => { this.currentIllust = illust }
      })
        .width('100%')
        .height('100%')
    }
  }

  // 触底预加载逻辑
  private tryLoadMore(index: number) {
    if (!this.swiperProvider || !this.swiperProvider.hasMore || this.swiperProvider.isLoading) return;
    const total = this.swiperProvider.illustIds.length;
    // logger.debug(`[Swiper Log] >>> 预加载检查: index=${index}, total=${total}, hasMore=${this.swiperProvider.hasMore}`);
    // 滑到倒数第 2 张时，触发预加载
    if (index >= total - 2) {
      this.swiperProvider.loadMore();
    }
  }

}

// 内层：负责单张插画的数据与 UI
@ComponentV2
struct IllustDetailContent {

  @Param illustId: number = 0
  @Param sharedId: string = ''
  @Param showLargeImage: boolean = false
  @Param pageStack: NavPathStack = new NavPathStack()

  @Local currentImageIndex: number = 0
  @Local showCommentPanel: boolean = false
  @Local iDV: IllustDetailViewModel = new IllustDetailViewModel()
  /** 命中的屏蔽规则（进入已屏蔽作品时非空） */
  @Local muteReason: MuteReason | null = null
  /** 本次浏览中暂时查看被屏蔽内容 */
  @Local tempViewMuted: boolean = false
  /** 长按标签：选中的标签 + 详情半模态 */
  @Local selectedTag: PixivTag | null = null
  @Local showTagDetail: boolean = false
  /** 当前选中标签是否已收藏 */
  @Local tagBookmarked: boolean = false

  @Event onImageLarge: (show: boolean) => void
  @Event onTitle: (title: string) => void
  @Event onIllust: (illust: PixivIllust | null) => void

  async aboutToAppear(): Promise<void> {
    // 根据 ID 加载详情
    this.iDV.loadIllustDetail(this.illustId);
    this.iDV.loadRelated(this.illustId);
  }

  /** 详情数据变化：上报给外层菜单 + 检查屏蔽状态 */
  @Monitor('iDV.detailData')
  onDetailDataChanged(): void {
    const illust = this.iDV.detailData
    this.onIllust(illust)
    if (!illust || this.tempViewMuted) {
      return
    }
    this.muteReason = muteFilter.checkIllust(illust)
  }

  build() {
    if (this.muteReason && !this.tempViewMuted) {
      this.MuteOverlay()
    } else {
      Stack({ alignContent: 8 - PixState.buttonPosition }) {
      Row() {
        List({ space: 10 }) {
          ForEach(this.iDV.imageList, (illust: PixivImage, index: number) => {
            ListItem() {
              PixivImageComponent({
                imageUrl: this.iDV.detailImageUrls[index] || illust.medium,
                imageObjectFit: ImageFit.Auto,
                imageBorder: { radius: 0 },
              })
                .id(index === 0 ? this.sharedId : illust.medium)
            }
            .onClick(() => {
              this.currentImageIndex = index
              this.onImageLarge(true)
            })
          })

          if (PixState.widthBp < 2 && this.iDV.detailData) {
            this.IntroContent()
          }
        }
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .contentEndOffset(PixState.bottomRectHeight == 0 ? PixState.PageMarginValue : PixState.bottomRectHeight)
        .padding(({ left: PixState.PageMarginValue, right: PixState.PageMarginValue }))
        .width(PixState.widthBp < 2 ? '100%' : PixState.windowWidth / 2)

        if (PixState.widthBp >= 2 && this.iDV.detailData) {
          List({ space: 10 }) {
            this.IntroContent()
          }
          .height('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .contentEndOffset(PixState.bottomRectHeight == 0 ? PixState.PageMarginValue : PixState.bottomRectHeight)
          .contentStartOffset(60 + PixState.topRectHeight)
          .width(PixState.windowWidth / 2)
          .padding(({ left: PixState.PageMarginValue, right: PixState.PageMarginValue }))
        }
      }
      .justifyContent(FlexAlign.SpaceBetween)
      .bindSheet(this.showCommentPanel!!, this.CommentPanel(), {
        height: '70%',
        dragBar: true,
        onWillAppear: () => {},
        onWillDisappear: () => {
        }
      })
      this.FloatingControlButton()

      // 全屏大图查看器：条件渲染 + hideTitleBar 联动实现全屏
      // （bindContentCover 全屏模态内嵌套自定义组件不渲染，无法使用）
      if (this.showLargeImage) {
        PixivImageViewer({
          imageUrls: this.iDV.imageList,
          startIndex: this.currentImageIndex,
          onClose: () => {
            this.onImageLarge(false)
          },
          onDownload: (index) => {
            this.iDV.downloadCurrentImage(index);
            if (appSettings.collecting_when_download) {
              this.iDV.bookmarkOrCancel(true)
            }
          },
          onShare: (url, index) => {}
        })
          .width('100%')
          .height('100%')
          .backgroundColor('#000000')
          .transition(TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.EaseOut }))
      }
    }
    }
  }

  /** 被屏蔽作品的拦截页 */
  @Builder
  MuteOverlay() {
    Column({ space: 16 }) {
      SymbolGlyph($r('sys.symbol.eye_slash'))
        .fontSize(64)
        .fontColor([$r('sys.color.font_tertiary')])
      Text($r('app.string.mute_blocked_illust'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      if (this.muteReason?.kind === 'illust') {
        Text($r('app.string.mute_reason_illust'))
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
          .constraintSize({ maxWidth: '80%' })
      } else if (this.muteReason?.kind === 'user') {
        Text($r('app.string.mute_reason_user', this.muteReason?.name ?? ''))
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
          .constraintSize({ maxWidth: '80%' })
      } else {
        Text($r('app.string.mute_reason_tag', this.muteReason?.name ?? ''))
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
          .constraintSize({ maxWidth: '80%' })
      }
      Row({ space: 12 }) {
        Button($r('app.string.mute_temp_view'))
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .fontColor($r('sys.color.font_primary'))
          .onClick(() => {
            this.tempViewMuted = true
          })
        Button($r('app.string.mute_unblock'))
          .backgroundColor(PixState.currentThemeColor)
          .onClick(() => {
            this.unblockCurrent()
          })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('sys.color.background_primary'))
  }

  /** 解除当前命中的屏蔽规则 */
  private unblockCurrent(): void {
    const reason = this.muteReason
    if (!reason) {
      return
    }
    muteFilter.removeRule(reason.kind, reason.key).then(() => {
      this.muteReason = null
      toastUtil.showToast({ message: $r('app.string.mute_removed') })
    })
  }

  /** 长按标签：屏蔽该标签 */
  private muteTag(tag: PixivTag): void {
    muteFilter.addRule('tag', tag.name, tag.name).then((ok: boolean) => {
      toastUtil.showToast({ message: ok ? $r('app.string.mute_added') : $r('app.string.mute_add_failed') })
      // 当前页保持可见（本次浏览内不再检查屏蔽）
      this.tempViewMuted = true
    })
  }

  /** 标签详情半模态（完整标签名 + 翻译 + 收藏/屏蔽/复制操作） */
  @Builder
  TagDetailSheet() {
    Column({ space: 16 }) {
      Column({ space: 8 }) {
        Text(`#${this.selectedTag?.name ?? ''}`)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .width('100%')
          .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
        if (this.selectedTag?.translated_name) {
          Text(this.selectedTag?.translated_name ?? '')
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
            .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row({ space: 12 }) {
        // 收藏标签（再次点击取消收藏）
        Button(this.tagBookmarked ? $r('app.string.book_tag_cancel') : $r('app.string.book_tag_action'))
          .layoutWeight(1)
          .backgroundColor(this.tagBookmarked ? $r('sys.color.comp_background_list_card') : PixState.currentThemeColor)
          .fontColor(this.tagBookmarked ? $r('sys.color.font_primary') : Color.White)
          .onClick(() => {
            this.toggleBookmark()
          })
        Button($r('app.string.mute_this_tag'))
          .layoutWeight(1)
          .backgroundColor($r('sys.color.comp_background_list_card'))
          .fontColor($r('sys.color.font_primary'))
          .onClick(() => {
            const tag = this.selectedTag
            this.showTagDetail = false
            if (tag) {
              this.muteTag(tag)
            }
          })
      }
      .width('100%')

      Row({ space: 12 }) {
        Button($r('app.string.copy_tag'))
          .layoutWeight(1)
          .backgroundColor($r('sys.color.comp_background_list_card'))
          .fontColor($r('sys.color.font_primary'))
          .onClick(() => {
            this.copyText(this.selectedTag?.name ?? '')
            this.showTagDetail = false
          })
        Button($r('app.string.copy_translation'))
          .layoutWeight(1)
          .enabled(!!this.selectedTag?.translated_name)
          .backgroundColor($r('sys.color.comp_background_list_card'))
          .fontColor($r('sys.color.font_primary'))
          .onClick(() => {
            this.copyText(this.selectedTag?.translated_name ?? '')
            this.showTagDetail = false
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: PixState.bottomRectHeight + 12 })
    .alignItems(HorizontalAlign.Start)
  }

  /** 收藏 / 取消收藏当前标签（半模态内切换，不关闭） */
  private toggleBookmark(): void {
    const tag = this.selectedTag
    if (!tag) {
      return
    }
    if (this.tagBookmarked) {
      bookTagStore.remove(tag.name).then((ok: boolean) => {
        if (ok) {
          this.tagBookmarked = false
          toastUtil.showToast({ message: $r('app.string.book_tag_removed_toast') })
        }
      })
    } else {
      bookTagStore.add(tag.name, tag.translated_name ?? '').then((ok: boolean) => {
        this.tagBookmarked = true
        toastUtil.showToast({ message: ok ? $r('app.string.book_tag_added') : $r('app.string.book_tag_add_failed') })
      })
    }
  }

  /** 复制文本到剪贴板 */
  private copyText(text: string): void {
    if (!text) {
      return
    }
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text)
    pasteboard.getSystemPasteboard().setData(data).then(() => {
      toastUtil.showToast({ message: $r('app.string.copied_to_clipboard') })
    }).catch(() => {
      toastUtil.showToast({ message: text })
    })
  }

  /**
   * 悬浮收藏按钮
   */
  @Builder
  FloatingControlButton() {
    Row() {
      SymbolGlyph(this.iDV.isBookmarked ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
        .fontSize(27).fontColor([this.iDV.isBookmarked ? PixState.currentThemeColor : Color.White])
    }
    .functionButtonStyle(PixState.buttonPosition === 0, this.iDV.isBookmarked)
    .onClick(() => {
      this.iDV.bookmarkOrCancel()
    })
  }

  @Builder
  IntroContent() {
    // 详情信息卡片
    ListItem() {
      this.InfoCard()
    }
    // 评论入口
    ListItem() {
      this.Comment()
    }
    // 相关推荐
    ListItem() {
      this.RelatedSection()
    }
  }

  /** 详情信息卡片 */
  @Builder
  InfoCard() {
    Column({ space: 12 }) {
      // 标题
      Text(this.iDV.detailData!.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
        .onVisibleAreaChange([0.0, 1.0], (isExpanding: boolean, currentRatio: number) => {
          console.debug(`Test Text isExpanding: ${isExpanding}, currentRatio: ${currentRatio}`)
          if (isExpanding && currentRatio >= 1.0) {
            this.onTitle(this.iDV.detailData!.title)
          }
          if (!isExpanding && currentRatio <= 0.0) {
            console.debug('Test Text is completely invisible.')
          }
        })
      // 统计数据行：观看人数 + 喜欢数 + 时间
      Row({ space: 16 }) {
        Text($r('app.string.browse', this.iDV.detailData!.total_view))
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
        Text($r('app.string.num_collection', this.iDV.detailData!.total_bookmarks))
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
        // 格式化时间
        Text(this.iDV.formatDate(this.iDV.detailData!.create_date))
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      // 元数据行：ID + 分辨率
      Row({ space: 16 }) {
        Text(`插画ID: ${this.iDV.detailData!.id}`)
          .fontSize(12)
          .fontColor($r('sys.color.font_fourth'))
        Text(`${this.iDV.detailData!.width} x ${this.iDV.detailData!.height}`)
          .fontSize(12)
          .fontColor($r('sys.color.font_fourth'))
      }
      .width('100%')
      // 分割线
      Divider().color($r('sys.color.ohos_id_color_text_field_sub_bg'))

      // 作者行：头像 + 名称 + 关注按钮
      UserItem({
        user: this.iDV.detailData?.user,
        isFollow: this.iDV.isFollow,
        onButtonClick: (result: boolean, err?: string) => {
          this.iDV.followOrCancel(result, err)
        }
      })

      // 标签
      Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
        ForEach(this.iDV.detailData!.tags, (tag: PixivTag) => {
          Row({ space: 4 }) {
            Text(`#${tag.name}`)
              .fontColor(PixState.currentThemeColor)
              .fontSize(13)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            if (tag.translated_name && tag.translated_name !== tag.name) {
              Text(tag.translated_name)
                .fontColor($r('sys.color.font_secondary'))
                .fontSize(11)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor('#EDF5FF')
          .borderRadius(4)
          .constraintSize({ maxWidth: '100%' })
          // 长按标签：弹出详情半模态
          .gesture(
            LongPressGesture()
              .onAction(() => {
                this.selectedTag = tag
                this.showTagDetail = true
                bookTagStore.exists(tag.name).then((ok: boolean) => {
                  this.tagBookmarked = ok
                })
              })
          )
        }, (tag: PixivTag) => `${tag.name}_${tag.translated_name ?? ''}`)
      }
      .width('100%')
      // 标签详情半模态
      .bindSheet(this.showTagDetail, this.TagDetailSheet(), {
        height: SheetSize.FIT_CONTENT,
        dragBar: true,
        showClose: true,
        onDisappear: () => {
          this.showTagDetail = false
        }
      })
    }
    .width('100%')
    .borderRadius(12)
  }

  /** 评论入口 */
  @Builder
  Comment() {
    Row() {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.ellipsis_message_1'))
          .fontSize(19)
        Text('查看评论')
          .fontSize(16)
      }
      Blank()
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(19)
    }
    .width('100%')
    .borderRadius(12)
    .onClick(() => {
      this.showCommentPanel = true
    })
  }

  @Builder
  CommentPanel() {
    CommentPanel({
      targetId: this.illustId
    })
  }

  /** 相关推荐 */
  @Builder
  RelatedSection() {
    Column({ space: 12 }) {
      // 标题
      Text($r('app.string.related_recommendations'))
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .padding({ left: 4 })

      // 网格布局
      Grid() {
        ForEach(this.iDV.relatedIllusts, (item: PixivIllust) => {
          GridItem() {
            PixivImageComponent({
              imageUrl: item.image_urls.square_medium,
              imageAspectRatio: 1
            })
          }
          .onClick(() => {
            // 点击推荐插画
            const index = this.iDV.relatedIllusts.findIndex(i => i.id === item.id);
            const params: DetailPageParams = {
              id: item.id,
              illust: item,
              swiperProvider: this.iDV,
              swiperIndex: index >= 0 ? index : 0
            }
            PixState.pushPage('illust_detail', params, true);
          })
        })
      }
      .columnsTemplate(GridColumnsTemplate(PixState.widthBp))
      .columnsGap(3)
      .rowsGap(3)
      .width('100%')

      // 底部的加载更多按钮 / 状态提示
      if (this.iDV.hasMore) {
        Row() {
          if (this.iDV.isLoading) {
            LoadingProgress().width(20).height(20)
            Text() {
              Span($r('app.string.loading_recommendations'))
              Span('...')
            }.fontSize(14).margin({ left: 8 })
          } else {
            Text($r('app.string.load_more_recommendations')).fontSize(14).fontColor(PixState.currentThemeColor)
          }
        }
        .width('100%')
        .height(48)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          if (!this.iDV.isLoading) {
            this.iDV.loadMore();
          }
        })
      } else if (this.iDV.relatedIllusts.length > 0) {
        Text($r('app.string.no_further_recommendations'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .fontSize(13)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .margin({ top: 8, bottom: 8 })
      }
    }
    .width('100%')
    .borderRadius(12)
  }

}

@Extend(Row)
function functionButtonStyle(position: boolean, selected: boolean) {
  .aspectRatio(1)
  .borderRadius(30)
  .size({ width: 60, height: 60 })
  .justifyContent(FlexAlign.Center)
  .alignItems(VerticalAlign.Center)
  .offset({ x: position ? -PixState.PageMarginValue : PixState.PageMarginValue, y: -20 })
  .backgroundColor(selected ? ColorUtils.getColorWithAlphaString(PixState.currentThemeColor, 30) : $r('sys.color.ohos_id_color_bottom_tab_icon_auxcolor_off02'))
  .visualEffect(new hdsEffect.HdsEffectBuilder()
    .pointLight({
      sourceType: selected ?
        hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.NONE, // 组件自身发光效果
      illuminatedType: hdsEffect.PointLightIlluminatedType.DEFAULT_FEATHERING_BORDER // 组件受光效果
    })
    .buildEffect())
}
