import { LengthMetrics } from '@kit.ArkUI';
import webview from '@ohos.web.webview';
import { NovelDetailViewModel } from '../viewmodel/NovelDetailViewModel';
import { PixivImageComponent } from '../components/PixivImage';
import { PixState } from '../entryability/AppState';
import { PixivTag } from '../services/PixivTypes';
import { NaviContainer } from '../components/NaviContainer';
import { CommentPanel } from './CommentPanel';
import { ColorUtils } from '../common/utils/ColorUtils';
import { createLogger } from '../common/utils/Logger';
import { getThemeConfig, ReadingTheme } from '../common/entity/NovelModel';
import { NovelDetailParams } from '../common/entity/DetailEntity';
import { toastUtil } from '../common/utils/ToastUtils';
import { UISettings } from '../common/entity/SettingsModel';

const logger = createLogger('NovelDetailPage');

@Builder
export function NovelDetailBuilder(name: string, param: Object) {
  NovelDetail()
}


@ComponentV2
struct NovelDetail {

  @Local vm: NovelDetailViewModel | null = null;
  @Local isReadingMode: boolean = false;
  @Local showReadingSettings: boolean = false;
  @Local showCommentPanel: boolean = false;
  @Local showReadingBars: boolean = true;

  private webController: webview.WebviewController = new webview.WebviewController();
  private pageStack: NavPathStack = new NavPathStack();
  private htmlLoaded: boolean = false;
  private novelId: number = 0;

  build() {
    Stack() {
      NaviContainer({
        title: this.isReadingMode ? undefined : '小说详情',
        onReady: (ctx: NavDestinationContext) => {
          this.pageStack = ctx.pathStack;
          let params: NovelDetailParams | null = null;
          if (ctx?.pathInfo?.param) {
            params = ctx.pathInfo.param as NovelDetailParams;
          }
          if (params && params.id) {
            this.novelId = params.id;
            try {
              this.vm = new NovelDetailViewModel(this.novelId);
              this.vm.fetchDetail();
              this.vm.fetchNovelContent();
            } catch (e) {
              logger.error('[onReady] Init Error:', e);
            }
          }
        },
        onBackPressed: () => {
          if (this.isReadingMode) {
            this.isReadingMode = false;
            this.htmlLoaded = false;
            return true;
          }
          return false;
        },
        content: () => {
          this.Content()
        }
      })
        .bindSheet(this.showReadingSettings!!, this.ReadingSettingsPanel(), {
          height: '50%',
          dragBar: true,
        })
    }
    .width('100%').height('100%')
    .bindSheet(this.showCommentPanel!!, this.CommentPanelBuilder(), {
      height: '70%',
      dragBar: true
    })
  }

  @Builder
  Content() {
    if (!this.vm || this.vm!.isLoading) {
      this.LoadingView()
    } else if (this.isReadingMode) {
      this.ReadingMode()
    } else {
      this.DetailMode()
    }
  }

  @Builder
  LoadingView(tips?: ResourceStr) {
    Column() {
      LoadingProgress()
        .width(48).height(48)
        .color($r('sys.color.ohos_id_color_primary'))
      if (tips) {
        Text(tips)
          .fontSize(14)
          .margin({ top: 12 })
          .fontColor($r('sys.color.font_tertiary'))
      }
    }.width('100%').height('100%')
    .justifyContent(FlexAlign.Center)
  }

  // 详情界面
  @Builder
  DetailMode() {
    Stack({ alignContent: 8 - PixState.buttonPosition }) {
      Scroll() {
        Column({ space: 0 }) {
          this.HeroCoverSection()
          Column({ space: 20 }) {
            this.StatsRow()
            this.TagsSection()
            this.CaptionSection()
            if (this.vm!.novelInfo?.series) {
              this.SeriesSection()
            }
            this.CommentEntry()
            Divider()
              .color($r('sys.color.ohos_id_color_list_separator'))
              .margin({ left: 16, right: 16, top: 4, bottom: 4 })
            this.TextPreviewSection()
          }
          .padding({ left: 16, right: 16, top: 20, bottom: 120 })
        }
      }
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      // 底部收藏
      this.BottomActionBar()
    }
    .width('100%').height('100%')
  }
  @Builder
  HeroCoverSection() {
    Stack() {
      PixivImageComponent({
        imageUrl: this.vm!.novelInfo?.image_urls?.medium || '',
        imageObjectFit: ImageFit.Cover,
        imageBorder: { radius: 0 }
      }).width('100%').height(280)
      Column() {
        Blank()
        Column({ space: 8 }) {
          Text(this.vm!.novelInfo?.title || '')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .textShadow({ radius: 4, color: '#99000000' })
            .maxLines(2)
            .width('100%')
          Row({ space: 8 }) {
            PixivImageComponent({
              imageUrl: this.vm!.novelInfo?.user?.profile_image_urls?.medium || '',
              imageObjectFit: ImageFit.Cover,
              imageBorder: { radius: 10 }
            }).width(20).height(20)
            Text(this.vm!.novelInfo?.user?.name || '')
              .fontSize(14)
              .fontColor('#CCFFFFFF')
              .textShadow({ radius: 2, color: '#99000000' })
            Blank()
            Text(this.vm!.estimatedReadTime)
              .fontSize(12)
              .fontColor('#99FFFFFF')
              .textShadow({ radius: 2, color: '#99000000' })
          }.width('100%')
        }.width('100%').padding({ left: 16, right: 16, bottom: 16 })
      }
      .width('100%')
      .height('100%')
      .linearGradient({ direction: GradientDirection.Bottom, colors: [['#00000000', 0.4], ['#CC000000', 1.0]] })
    }.width('100%').height(280)
  }
  // 书籍状态
  @Builder
  StatsRow() {
    Row({ space: 20 }) {
      // 字数
      Row({ space: 4 }) {
        SymbolGlyph($r('sys.symbol.doc_text'))
          .fontSize(16)
          .fontColor([$r('sys.color.font_tertiary')]);
        Text(this.vm!.formatWordCount(this.vm!.novelInfo?.text_length || 0))
          .fontSize(13)
          .fontColor($r('sys.color.font_tertiary'))
      }
      // 收藏数
      Row({ space: 4 }) {
        SymbolGlyph($r('sys.symbol.heart'))
          .fontSize(16)
          .fontColor([$r('sys.color.font_tertiary')]);
        Text(`${this.vm!.novelInfo?.total_bookmarks || 0}`)
          .fontSize(13)
          .fontColor($r('sys.color.font_tertiary'))
      }
      // 浏览量
      Row({ space: 4 }) {
        SymbolGlyph($r('sys.symbol.eye'))
          .fontSize(16)
          .fontColor([$r('sys.color.font_tertiary')]);
        Text(`${this.vm!.novelInfo?.total_view || 0}`)
          .fontSize(13)
          .fontColor($r('sys.color.font_tertiary'))
      }
      // 评论区
      if ((this.vm!.novelInfo?.total_comments ?? 0) > 0) {
        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.ellipsis_message_1'))
            .fontSize(16)
            .fontColor([$r('sys.color.font_tertiary')]);
          Text(`${this.vm!.novelInfo?.total_comments}`)
            .fontSize(13)
            .fontColor($r('sys.color.font_tertiary'))
        }
      }
      Blank()
      // AI标识
      if (this.vm!.novelInfo?.novel_ai_type === 2) {
        Text('AI辅助')
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
          .padding({
            left: 6,
            right: 6,
            top: 2,
            bottom: 2
          })
          .borderRadius(4)
          .backgroundColor('#18007DFF')
      } else if (this.vm!.novelInfo?.novel_ai_type === 3) {
        Text('AI生成')
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
          .padding({
            left: 6,
            right: 6,
            top: 2,
            bottom: 2
          })
          .borderRadius(4)
          .backgroundColor('#18007DFF')
      }
      if (this.vm!.novelInfo?.x_restrict !== 0) {
        Text('R-18')
          .fontSize(12)
          .fontColor(Color.Red)
          .fontWeight(FontWeight.Bold)
          .padding({
            left: 6,
            right: 6,
            top: 2,
            bottom: 2
          })
          .borderRadius(4)
          .backgroundColor('#33FF0000')
      }
    }
    .width('100%')
  }
  // 标签
  @Builder
  TagsSection() {
    Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
      ForEach(this.vm!.novelInfo?.tags || [], (tag: PixivTag) => {
        Text(`# ${tag.name}`)
          .fontSize(13)
          .fontColor(PixState.currentThemeColor)
          .padding({
            left: 8,
            right: 8,
            top: 4,
            bottom: 4
          })
          .borderRadius(12)
          .backgroundColor(ColorUtils.getColorWithAlphaString(PixState.currentThemeColor, 15))
      })
    }.width('100%')
  }
  // 简介
  @Builder
  CaptionSection() {
    Text(this.vm!.novelInfo?.caption || '暂无简介')
      .fontSize(14)
      .fontColor($r('sys.color.font_secondary'))
      .maxLines(5)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .width('100%')
  }
  // 作品系列
  @Builder
  SeriesSection() {
    Row() {
      Column({ space: 4 }) {
        Text('系列作品').fontSize(12)
          .fontColor($r('sys.color.font_tertiary'));
        Text(this.vm!.novelInfo?.series?.title || '')
          .fontSize(15)
          .fontColor($r('sys.color.font_primary'))
          .fontWeight(FontWeight.Medium)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(18)
        .fontColor([$r('sys.color.font_tertiary')])
    }.padding(14)
    .width('100%')
    .borderRadius(12)
    .backgroundColor($r('sys.color.ohos_id_color_hover'))
  }
  // 评论入口
  @Builder
  CommentEntry() {
    Row() {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.ellipsis_message_1'))
          .fontColor([$r('sys.color.font_primary')])
          .fontSize(19);
        Text($r('app.string.check_out_comments')).fontSize(16)
      }

      Blank()
      if ((this.vm!.novelInfo?.total_comments ?? 0) > 0) {
        Text(`${this.vm!.novelInfo?.total_comments}`)
          .fontSize(13)
          .fontColor($r('sys.color.font_tertiary'))
          .margin({ right: 4 })
      }
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontColor([$r('sys.color.font_tertiary')])
        .fontSize(19)
    }
    .width('100%')
    .padding(14)
    .borderRadius(12)
    .backgroundColor($r('sys.color.ohos_id_color_hover'))
    .onClick(() => {
      this.showCommentPanel = true
    })
  }
  // 正文预览
  @Builder
  TextPreviewSection() {
    Column({ space: 12 }) {
      Text() {
        if (this.vm!.novelText) {
          Span(this.vm!.novelText.substring(0, 200) + '...')
        } else {
          Span($r('app.string.content_loading'))
          Span('...')
        }
      }
        .fontSize(15)
        .lineHeight(26)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(6)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Button($r('app.string.start_reading'))
        .width('100%')
        .height(48)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor(PixState.currentThemeColor)
        .borderRadius(24)
        .onClick(() => {
          this.enterReadingMode()
        })
    }.width('100%').padding({ top: 8 })
  }
  // 收藏
  @Builder
  BottomActionBar() {
    Column() {
      SymbolGlyph(this.vm!.isBookmarked ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
        .fontSize(24)
        .fontColor([this.vm!.isBookmarked ? PixState.currentThemeColor : $r('sys.color.font_tertiary')])
    }
    .width(48)
    .height(48)
    .justifyContent(FlexAlign.Center)
    .borderRadius(24)
    .offset({ x: PixState.buttonPosition === 0 ? -PixState.PageMarginValue : PixState.PageMarginValue, y: -20 })
    .backgroundColor($r('sys.color.ohos_id_color_hover'))
    .onClick(() => {
      this.vm!.toggleBookmark()
    })
  }

  // 阅读界面
  @Builder
  ReadingMode() {
    Stack() {
      if (this.vm!.isTextLoading) {
        this.LoadingView($r('app.string.content_loading'))
      } else if (this.vm!.readingMode === 'webview') {
        this.WebReader()
      } else if (this.vm!.novelText) {
        this.NativeReader()
      } else {
        Column() {
          SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
            .fontSize(48)
            .fontColor([$r('sys.color.font_tertiary')]);
          Text($r('app.string.content_loading_failed'))
            .fontSize(16)
            .margin({ top: 12 })
            .fontColor($r('sys.color.font_secondary'));
          Button($r('app.string.retry'))
            .margin({ top: 16 })
            .onClick(() => {
              if (this.vm) {
                this.vm.hasTextLoaded = false;
                this.vm.isTextLoading = true;
                this.vm.fetchNovelContent();
              }
            })
        }.width('100%').height('100%')
        .justifyContent(FlexAlign.Center)
      }

      if (this.showReadingBars) {
        this.ReadingTopBar()
        if (this.vm!.isInSeries && this.vm!.hasPrev && this.vm!.hasNext) {
          this.ReadingBottomBar()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(getThemeConfig(UISettings.reading_color_mode).bg)
    .onClick(() => {
      if (!this.vm!.isTextLoading && this.vm!.novelText) {
        toastUtil.animateTo({ duration: 200 }, () => {
          this.showReadingBars = !this.showReadingBars;
        });
      }
    })
  }
  // web阅读器
  @Builder
  WebReader() {
    Web({ src: '', controller: this.webController })
      .width('100%')
      .height('100%')
      .backgroundColor(getThemeConfig(UISettings.reading_color_mode).bg)
      .javaScriptAccess(true)
      .domStorageAccess(true)
      .mixedMode(MixedMode.All)
      .onlineImageAccess(true)
      .zoomAccess(true)
      .textZoomAtio(100)
      .onControllerAttached(() => {
        this.loadWebContent();
      })
  }
  // 原生阅读器
  @Builder
  NativeReader() {
    Scroll() {
      Column() {
        // 顶部留白
        Blank().height(this.showReadingBars ? (PixState.topRectHeight + 52) : PixState.topRectHeight)
        // 正文区域
        Column({ space: 0 }) {
          ForEach(this.getParagraphs(), (paragraph: string) => {
            Text(paragraph)
              .fontSize(this.vm!.fontSize)
              .lineHeight(this.vm!.fontSize * this.vm!.lineHeight)
              .fontColor(getThemeConfig(UISettings.reading_color_mode).text)
              .width('100%')
              .textIndent(this.vm!.fontSize * 2)
              .margin({ bottom: this.vm!.fontSize * 0.3 })
          })
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
        // 底部留白：动态计算，防止文字被底栏/手势条遮挡
        Blank().height(this.calculateBottomPadding())
      }
      .width('100%')
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor(Color.Transparent)
  }
  // 阅读顶栏
  @Builder
  ReadingTopBar() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(24)
          .fontColor([$r('sys.color.font_primary')])
      }.width(40).height(40)
      .backgroundColor($r('sys.color.button_background_color_transparent'))
      .onClick(() => {
        this.isReadingMode = false;
        this.htmlLoaded = false;
      })

      Blank()
      Text(this.vm!.novelInfo?.title || '')
        .fontSize(15)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .padding({ left: 8, right: 8 })
      Blank()
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.ellipsis_message_1'))
          .fontSize(24)
          .fontColor([$r('sys.color.font_primary')])
      }.width(40).height(40)
      .backgroundColor($r('sys.color.button_background_color_transparent'))
      .onClick(() => {
        this.showCommentPanel = true
      })

      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.text_badge_questionmark'))
          .fontSize(24)
          .fontColor([$r('sys.color.font_primary')])
      }
      .width(40)
      .height(40)
      .backgroundColor($r('sys.color.button_background_color_transparent'))
      .margin({ left: 8 })
      .onClick(() => {
        this.showReadingSettings = true
      })
    }
    .width('100%')
    .padding({
      left: 16,
      right: 16,
      top: PixState.topRectHeight,
      bottom: 8
    })
    .position({ x: 0, y: 0 })
    .zIndex(10)
    .linearGradient({ direction: GradientDirection.Bottom, colors: [['#88000000', 0.0], ['#00000000', 1.0]] })
    .transition(TransitionEffect.OPACITY)
  }
  // 阅读底栏
  @Builder
  ReadingBottomBar() {
    Row({ space: 12 }) {
      Button(this.vm!.prevTitle)
        .layoutWeight(1)
        .height(40)
        .fontSize(14)
        .enabled(this.vm!.hasPrev)
        .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
        .fontColor(this.vm!.hasPrev ? $r('sys.color.font_primary') : $r('sys.color.font_fourth'))
        .borderRadius(20)
        .onClick(() => {
          this.navigateToNovel('prev')
        })
      Button(this.vm!.nextTitle)
        .layoutWeight(1)
        .height(40)
        .fontSize(14)
        .enabled(this.vm!.hasNext)
        .backgroundColor(this.vm!.hasNext ? PixState.currentThemeColor : $r('sys.color.ohos_id_color_button_normal'))
        .fontColor(this.vm!.hasNext ? Color.White : $r('sys.color.font_fourth'))
        .borderRadius(20)
        .onClick(() => {
          this.navigateToNovel('next')
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: PixState.bottomRectHeight + 8 })
    .backgroundColor(getThemeConfig(UISettings.reading_color_mode).bg)
    .shadow({ radius: 12, color: '#0D000000', offsetY: -2 })
    .transition(TransitionEffect.OPACITY)
    .position({ x: 0, y: '100%' })
    .translate({ y: '-100%' })
  }

  // 设置面板
  @Builder
  ReadingSettingsPanel() {
    Column({ space: 24 }) {
      Row() {
        Text($r('app.string.reading_srttings'))
          .fontSize(18)
          .layoutWeight(1)
          .fontWeight(FontWeight.Bold)
      }.width('100%')

      Column({ space: 12 }) {
        Text('字号').fontSize(15).fontColor($r('sys.color.font_secondary')).width('100%')
        Row({ space: 16 }) {
          Text('A').fontSize(14).fontColor($r('sys.color.font_secondary'))
          Slider({
            value: this.vm!.fontSize,
            min: 14,
            max: 28,
            step: 1,
            style: SliderStyle.InSet
          })
            .layoutWeight(1)
            .trackColor($r('sys.color.ohos_id_color_hover'))
            .selectedColor(PixState.currentThemeColor)
            .onChange((value: number) => {
              if (this.vm) {
                this.vm.fontSize = Math.round(value);
                this.htmlLoaded = false;
                if (this.vm.readingMode == 'webview') {
                  this.loadWebContent();
                }
              }
            })
          Text('A').fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('sys.color.font_secondary'))
        }

        Text(`${this.vm!.fontSize}px`)
          .fontSize(13)
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
          .textAlign(TextAlign.Center)
      }

      Column({ space: 12 }) {
        Text('行间距').fontSize(15).fontColor($r('sys.color.font_secondary')).width('100%')
        Row({ space: 8 }) {
          ForEach([1.5, 1.8, 2.0, 2.5, 3.0], (lh: number) => {
            Column() {
              Text(`${lh}`)
                .fontSize(14)
                .fontColor(this.vm!.lineHeight === lh ? Color.White : $r('sys.color.font_primary'))
            }
            .width(52)
            .height(40)
            .justifyContent(FlexAlign.Center)
            .borderRadius(18)
            .backgroundColor(
              this.vm!.lineHeight === lh ? PixState.currentThemeColor : $r('sys.color.ohos_id_color_hover'))
            .onClick(() => {
              if (this.vm) {
                this.vm.lineHeight = lh;
                this.htmlLoaded = false;
                if (this.vm.readingMode == 'webview') {
                  this.loadWebContent();
                }
              }
            })
          })
        }
      }

      Column({ space: 12 }) {
        Text('阅读主题').fontSize(15).fontColor($r('sys.color.font_secondary')).width('100%')
        Row({ space: 12 }) {
          this.ThemeButton('light', '☀️ 日间', '#FFFFFF', '#333333')
          this.ThemeButton('sepia', '🌿 护眼', '#FBF5E5', '#5B4640')
          this.ThemeButton('dark', '🌙 夜间', '#1A1A2E', '#E0E0E0')
        }
      }
    }.padding(24).width('100%')
  }
  // 主题按钮
  @Builder
  ThemeButton(theme: string, label: string, bgColor: ResourceColor, textColor: ResourceColor) {
    Column() {
      Text(label)
        .fontSize(14)
        .fontColor(UISettings.reading_color_mode === theme ? Color.White : textColor)
    }
    .height(44)
    .layoutWeight(1)
    .borderRadius(12)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(UISettings.reading_color_mode === theme ? PixState.currentThemeColor : bgColor)
    .border({ width: UISettings.reading_color_mode === theme ? 0 : 1, color: $r('sys.color.ohos_id_color_list_separator') })
    .onClick(() => {
      if (this.vm) {
        UISettings.reading_color_mode = theme as ReadingTheme;
        this.htmlLoaded = false;
        if (this.vm.readingMode == 'webview') {
          this.loadWebContent();
        }
      }
    })
  }

  // 评论区面板
  @Builder
  CommentPanelBuilder() {
    CommentPanel({ type: 'novel', targetId: this.novelId })
  }

  // 进入阅读正文界面
  async enterReadingMode() {
    if (!this.vm) {
      return;
    }
    if (!this.vm.hasTextLoaded) {
      this.vm.isTextLoading = true;
    }
    this.showReadingBars = true;
    toastUtil.animateTo({ duration: 250, curve: Curve.EaseInOut }, () => {
      this.isReadingMode = true;
    });
    if (!this.vm.hasTextLoaded) {
      await this.vm.fetchNovelContent();
    }
  }

  // 加载web文本
  private loadWebContent() {
    if (!this.vm || this.htmlLoaded) {
      return;
    }
    const html = this.vm.getReadingHTML();
    logger.info(`loadWebContent: HTML length = ${html.length}`);
    this.webController.loadData(html, 'text/html', 'UTF-8');
    this.htmlLoaded = true;
  }

  // 智能计算底部留白高度
  private calculateBottomPadding(): number {
    // 如果控制栏隐藏，只需避开系统手势条高度 + 少量呼吸空间
    if (!this.showReadingBars) {
      return PixState.bottomRectHeight + 20;
    }
    // 如果有翻页底栏，需要留出底栏高度 + 手势条高度
    if (this.vm!.isInSeries) {
      return PixState.bottomRectHeight + 76;
    }
    // 如果没有翻页底栏，同样只需留出手势条高度 + 呼吸空间
    return PixState.bottomRectHeight + 20;
  }

  // 获取正文段落
  private getParagraphs(): string[] {
    const text = this.vm?.novelText || '';
    if (!text) {
      return ['正文加载失败...'];
    }
    return text.split('\n').filter(line => {
      const trimmed = line.trim();
      return trimmed.length > 0 && !trimmed.startsWith('[chapter:') && !trimmed.startsWith('[newpage]') &&
        !trimmed.startsWith('[pixivimage:') && !trimmed.startsWith('[jump:');
    });
  }

  // 翻页控制
  private navigateToNovel(direction: 'prev' | 'next') {
    const novel = direction === 'prev' ? this.vm?.prevNovel : this.vm?.nextNovel;
    if (!novel) return;
    if (!novel.viewable) return; // 不可阅读的直接拦截

    this.htmlLoaded = false;
    this.vm = new NovelDetailViewModel(novel.id);
    this.vm.fetchDetail();
    this.vm.fetchNovelContent();
  }

}
