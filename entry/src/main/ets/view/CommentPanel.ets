import { CommentViewModel } from '../viewmodel/CommentViewModel';
import { PixState } from '../entryability/AppState';
import { PixivComment } from '../services/PixivTypes';
import { PixivImageComponent } from '../components/PixivImage';


@ComponentV2
export struct CommentPanel {

  @Param type: 'illust' | 'novel' = 'illust';
  // 接收参数
  @Param targetId: number = -1;

  private vm: CommentViewModel = new CommentViewModel();

  aboutToAppear() {
    this.vm.init(this.type, this.targetId);
  }

  build() {
    Column() {
      // 顶部标题栏
      this.TitleBar();
      // 评论列表
      this.CommentList();
      // 底部输入框
      this.InputArea();
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }

  @Builder
  TitleBar() {
    Row() {
      Text($r('app.string.comment_area'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
    }
    .height(56)
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding(({ left: PixState.PageMarginValue, right: PixState.PageMarginValue }))
  }

  @Builder
  CommentList() {
    List({ space: 0 }) {
      // 全局 Loading 状态（首次加载时显示）
      if (this.vm.isLoading && this.vm.comments.length === 0) {
        ListItem() {
          Column() {
            LoadingProgress().width(24).height(24).color($r('sys.color.font_secondary'))
            Text('加载中...').fontSize(12).fontColor($r('sys.color.font_secondary')).margin({ top: 8 })
          }
          .width('100%')
          .height(200)
          .justifyContent(FlexAlign.Center)
        }
      }
      // 空状态展示
      if (this.vm.comments.length === 0 && !this.vm.isLoading) {
        ListItem() {
          Column() {
            SymbolGlyph($r('sys.symbol.message_on_message'))
              .fontSize(40)
              .fontColor([$r('sys.color.font_fourth')])
              .margin({ bottom: 8 })
            Text() {
              Span($r('app.string.no_comments'))
              Span('~')
            }.fontColor($r('sys.color.font_tertiary'))
            .fontSize(14)
          }
          .width('100%')
          .height(350)
          .justifyContent(FlexAlign.Center)
        }
      }
      // 评论列表循环
      ForEach(this.vm.comments, (comment: PixivComment) => {
        ListItem() {
          this.CommentItem(comment)
        }
      }, (comment: PixivComment) => comment.id.toString())
      // 底部状态（加载更多 / 到底了 / 加载更多失败）
      if (this.vm.comments.length > 0) {
        ListItem() {
          Row() {
            if (this.vm.isFetchingMore) {
              LoadingProgress().width(24).height(24).color($r('sys.color.font_secondary'))
              Text() {
                Span($r('app.string.loading_more'))
              }.fontSize(12).fontColor($r('sys.color.font_secondary')).margin({ left: 8 })
            } else if (this.vm.nextUrl) {
              // 还有下一页时，显示可点击的文字
              Text($r('app.string.click_load_more'))
                .fontSize(14)
                .fontColor(PixState.currentThemeColor) // 用主题色突出可点击
                .padding({ top: 12, bottom: 12 })
                .onClick(() => {
                  this.vm.fetchComments(false);
                })
            } else if (!this.vm.nextUrl && this.vm.comments.length > 0) {
              Text('') {
                Span('—— ')
                Span($r('app.string.already_over'))
                Span(' ——')
              }.fontSize(12).fontColor($r('sys.color.font_fourth'))
            }
          }
          .width('100%')
          .height(50)
          .justifyContent(FlexAlign.Center)
        }
      }
    }
    .width('100%')
    .cachedCount(5)
    .layoutWeight(1)
    // .onReachEnd(() => {
    //   // 滑到底部，加载更多评论
    //   this.vm.fetchComments(false);
    // })
    .padding(({ left: PixState.PageMarginValue, right: PixState.PageMarginValue, bottom: PixState.bottomRectHeight - 10 || 8 }))
    .divider(this.vm.comments.length != 0 ? { strokeWidth: 0.5, color: $r('sys.color.comp_divider'), startMargin: 60, endMargin: 16 } : undefined)
  }

  @Builder
  CommentItem(comment: PixivComment) {
    Row() {
      // 左侧头像
      PixivImageComponent({
        imageUrl: comment.user.profile_image_urls.medium,
        imageWidth: 36, imageHeight: 36, imageBorder: { radius: 18 },
        placeholderSrc: $r('sys.media.ohos_user_auth_icon_face')
      })
      // 右侧内容区
      Column({ space: 4 }) {
        // 用户名 + 时间
        Row() {
          Text(comment.user.name)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          // 时间格式化 (这里简单截取，实际可用 dayjs)
          Text(comment.date.substring(0, 10))
            .fontSize(11)
            .fontColor($r('sys.color.font_fourth'))
        }
        .width('100%')

        // 回复的父评论 (楼中楼)
        if (comment.parent_comment) {
          Row() {
            Text() {
              Span($r('app.string.reply'))
              Span(` @${comment.parent_comment.user.name}: ${comment.parent_comment.comment}`)
            }
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .backgroundColor($r('sys.color.background_secondary'))
            .borderRadius(4)
            .padding(4)
          }
          .width('100%')
        }

        // 评论正文（文本或贴图）
        if (comment.stamp) {
          // 贴图评论
          Image(comment.stamp.stamp_url)
            .width(80)
            .aspectRatio(1)
            .borderRadius(4)
            .margin({ top: 4 })
        } else {
          // 文本评论
          Text(comment.comment)
            .fontSize(14)
            .fontColor($r('sys.color.font_primary'))
            .margin({ top: 4 })
        }

        // 楼中楼子评论区
        if (comment.has_replies || (comment.replies && comment.replies.length > 0)) {
          Column({ space: 6 }) {
            // 渲染已有的子评论列表
            if (comment.replies && comment.replies.length > 0) {
              ForEach(comment.replies, (reply: PixivComment) => {
                Row() {
                  Text(`${reply.user.name}: `)
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(PixState.currentThemeColor)
                  Text(reply.stamp ? '[贴图]' : reply.comment) // 子评论暂简单处理贴图
                    .fontSize(12)
                    .fontColor($r('sys.color.font_primary'))
                    .layoutWeight(1)
                }
                .width('100%')
              }, (reply: PixivComment) => reply.id.toString())
            }

            // 加载更多回复按钮 / 加载中状态
            Row() {
              if (comment.isLoadingReplies) {
                LoadingProgress().width(16).height(16).color($r('sys.color.font_secondary'))
                Text() {
                  Span($r('app.string.loading_more'))
                }.fontSize(11).fontColor($r('sys.color.font_secondary')).margin({ left: 4 })
              } else if (comment.repliesNextUrl) {
                // 有下一页子评论
                Text($r('app.string.click_load_more_reply'))
                  .fontSize(11)
                  .fontColor(PixState.currentThemeColor)
                  .onClick(() => this.vm.fetchCommentReplies(comment.id))
              } else if (!comment.replies || comment.replies.length === 0) {
                // 还没拉取过子评论，且 has_replies 为 true
                Text($r('app.string.view_reply'))
                  .fontSize(11)
                  .fontColor(PixState.currentThemeColor)
                  .onClick(() => this.vm.fetchCommentReplies(comment.id))
              }
            }
          }
        }

        // 回复按钮
        Row() {
          Text($r('app.string.reply'))
            .fontSize(12)
            .fontColor($r('sys.color.font_tertiary'))
            .padding({ top: 4, bottom: 4 })
            .onClick(() => {
              this.vm.setReplyTarget(comment);
            })
        }
      }
      .layoutWeight(1)
      .margin({ left: 10 })
      .alignItems(HorizontalAlign.Start)
    }
    .alignItems(VerticalAlign.Top)
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  @Builder
  InputArea() {
    Column() {
      // 如果正在回复某人，显示回复条
      if (this.vm.replyTarget) {
        Row() {
          Text() {
            Span($r('app.string.reply'))
            Span(` @${this.vm.replyTarget.user.name}`)
          }
          .fontSize(12)
          .fontColor(PixState.currentThemeColor)
          .layoutWeight(1)
          SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
            .fontSize(16)
            .fontColor([$r('sys.color.font_tertiary')])
            .onClick(() => this.vm.cancelReply())
        }
        .width('100%')
        .height(28)
        .padding({ left: 12, right: 8 })
        .backgroundColor($r('sys.color.background_secondary'))
        .borderRadius({ topLeft: 8, topRight: 8 })
      }

      // 输入框和发送按钮
      Row({ space: 8 }) {
        TextInput({
          text: this.vm.inputText,
          placeholder: this.vm.replyTarget ? $r('app.string.replying', this.vm.replyTarget.user.name) : $r('app.string.say_something')
        })
          .type(InputType.Normal)
          .layoutWeight(1)
          .height(40)
          .borderRadius(20)
          .backgroundColor($r('sys.color.background_secondary'))
          .onChange((v) => this.vm.inputText = v)

        Button('发送')
          .height(40)
          .borderRadius(20)
          .fontSize(14)
          .type(ButtonType.Normal)
          .backgroundColor(PixState.currentThemeColor)
          .fontColor(Color.White)
          .enabled(this.vm.inputText.trim().length > 0)
          .onClick(() => this.vm.sendComment())
      }
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor($r('sys.color.background_primary'))
    }
    .expandSafeArea([SafeAreaType.KEYBOARD], [SafeAreaEdge.BOTTOM])
    .padding(({ left: PixState.PageMarginValue, right: PixState.PageMarginValue, bottom: PixState.bottomRectHeight - 10 || 8 }))
  }

}
